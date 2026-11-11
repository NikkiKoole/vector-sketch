-- src/mipo-build.lua (split from character-manager.lua, SPLIT2)
local lib = {}

local mipoDna = require('src.mipo-dna')
local appearance = require('src.mipo-appearance')
local shape8Dict = require('src.shape8-dict')
local shapeCatalogs = require('src.shape-catalogs')
local balance = require('src.mipo-balance')
local textures = require('src.mipo-textures')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local uuid = require('src.uuid')
local utils = require('src.utils')
local mathutils = require('src.math-utils')
local BT = require('src.body-types')
local NT = require('src.node-types')
local mipoRegistry = require('src.mipo-registry')
local state = require('src.state')
local D = require('src.dna-defaults')
local topology = require('src.character-topology')
local units = require('src.physics-units')
local registry = require('src.registry')
local facing = require('src.mipo-facing')
local torsoLobes = require('src.torso-lobes')
local dna = mipoDna.dna
local migrations = require('src.save-migrations')
local initBlock = appearance.initBlock
local applyGroupAndZ = textures.applyGroupAndZ
local makeTransformedVertices = mathutils.scalePolygonPoints

-- Negative group index counter for character self-collision prevention.
-- Each character gets a unique negative index so its fixtures never collide
-- with each other, but fixtures from different characters (different indices)
-- still collide normally.
-- Both counters restart every session, while characters loaded from a scene keep
-- their saved values, so allocation skips anything already in use (a shared
-- group index means two Mipos pass through each other).
local nextGroupIndex = -1
local nextZGroupOffset = 1

local function allocateGroupIndex()
    local candidate = nextGroupIndex
    if state.physicsWorld then
        for _, body in ipairs(state.physicsWorld:getBodies()) do
            for _, fixture in ipairs(body:getFixtures()) do
                local gi = fixture:getGroupIndex()
                if gi <= candidate then candidate = gi - 1 end
            end
        end
    end
    nextGroupIndex = candidate - 1
    return candidate
end

local function allocateZGroupOffset(instance)
    local candidate = nextZGroupOffset
    for _, other in pairs(mipoRegistry.getAll()) do
        if other ~= instance and other.zGroupOffset and other.zGroupOffset >= candidate then
            candidate = other.zGroupOffset + 1
        end
    end
    nextZGroupOffset = candidate + 1
    return candidate
end

local function extractNeckIndex(name)
    local index = string.match(name, "^neck(%d+)$")
    return index and tonumber(index) or nil
end

local function extractTorsoIndex(name)
    local index = string.match(name, "^torso(%d+)$")
    return index and tonumber(index) or nil
end


-- Shoulders and elbows: range relative to the parent part (0 = hanging straight
-- in line, + = toward the Mipo's left), converted with the joint's own reference
-- angle. The DNA shoulder limits were relative to a T-pose (reference +-90),
-- which only allowed the upper half: arms rested horizontal and tipped over to
-- the other side. Elbows had no limits, so forearms crossed under the body.
lib.armRange = {
    luarm = { 0, 180 }, ruarm = { -180, 0 },   -- shoulder: from hanging down, out, up
    llarm = { -10, 150 }, rlarm = { -150, 10 }, -- elbow: bends outward/up only
} -- degrees

-- Legs, feet, hands, ears: the DNA limits are meant relative to the rest pose
-- (0 = in line with the parent; ears at their stanceAngle), but a joint's limits
-- count from its reference angle, which is whatever angle the part had when the
-- joint was made. Rebuilt while bent, 'upright' fell outside the hip limits and
-- feet got locked upside down (ankle references of 179 / -111 deg); keep-angle
-- then fought the limits at full spin (shaking, noise). Convert the DNA limits
-- with the actual reference angle.
-- A foot's rest pose is flat: it is built turned a quarter turn from its shin
-- (character-topology.lua angleOffset). Counting the ankle range from 'in line
-- with the shin' (0) centred it on a foot pointing straight down: Mipos stood
-- on the tips of their feet.
local footRest = { lfoot = math.pi / 2, rfoot = -math.pi / 2 }

-- Not only legs and feet: every part with DNA limits (torso segments, spine bands, neck,
-- head). A scene saved before joints kept their reference angle came back with each joint
-- counting from the pose it was saved in: a spine saved mid-sway was held crooked by its
-- motor and the Mipo hopped forever; necks and heads were limited off-centre.
local function applyLegLimits(instance, joint, partName)
    if not joint or joint:isDestroyed() or joint:getType() ~= 'revolute' then return end
    local source = facing.source(instance, partName) -- facing a side: this side's leg (mipo-facing)
    local partDNA = instance.dna.parts[source]
    local limits = partDNA and partDNA.j and partDNA.j.limits
    if not (limits and limits.low and limits.up) then return end
    local rest = footRest[source] or partDNA.stanceAngle or 0
    local ref = joint:getReferenceAngle()
    joint:setLimits(rest + limits.low - ref, rest + limits.up - ref)
    joint:setLimitsEnabled(true)
end

local function applyShoulderLimits(joint, partName)
    local range = lib.armRange[partName]
    if not range or not joint or joint:isDestroyed() or joint:getType() ~= 'revolute' then return end
    local ref = joint:getReferenceAngle()
    joint:setLimits(math.rad(range[1]) - ref, math.rad(range[2]) - ref)
    joint:setLimitsEnabled(true)
end

-- Feet grip and don't bounce. With LÖVE's default friction (0.2) on both feet
-- and floor, Mipos stood on ice and slid into a split.
lib.footFriction = 1.0 -- spec/standing_spec.lua, 3 x 12 random Mipos: 1.0 -> 6/36 unsettled,
                       -- 0.45 -> 12/36 (a single 12-run said otherwise: physics here is chaotic)
lib.footRestitution = 0

local function applyFootMaterial(thing, partName)
    if partName ~= 'lfoot' and partName ~= 'rfoot' then return end
    if not thing or not thing.body or thing.body:isDestroyed() then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:isSensor() then
            fixture:setFriction(lib.footFriction)
            fixture:setRestitution(lib.footRestitution)
        end
    end
end

-- How makePart builds a part from its DNA at this scale.
local function partSettings(partName, partData, scale, x, y, instance)
    -- feet are mirrored left/right like hands; a hand picture the other way round, so it
    -- stands on its palm edge with the thumb up, not on the thumb. Facing a side, both feet
    -- take that side's picture (src/mipo-facing.lua).
    if (partName == 'lfoot' or partName == 'rfoot') and partData.shape8URL then
        local source = instance and facing.source(instance, partName) or partName
        local mirrored = (source == 'rfoot') ~= shapeCatalogs.isHandPicture(partData.shape8URL)
        local size = math.abs(partData.dims.sx or 1)
        partData.dims.sx = mirrored and -size or size
    end
    local settings = {
        x = x,
        y = y,
        bodyType = BT.DYNAMIC,
        shapeType = partData.shape,
        shape8URL = partData.shape8URL,
        label = partName,
        density = partData.density or 1,
        behaviors = partData.behaviors,
        radius = (partData.dims.r or 0) * scale,
        width = (partData.dims.w or 0) * scale,
        width2 = (partData.dims.w2 or 0) * scale,
        width3 = (partData.dims.w3 or 0) * scale,
        height = (partData.dims.h or 0) * scale,
        height2 = (partData.dims.h2 or 0) * scale,
        height3 = (partData.dims.h3 or 0) * scale,
        height4 = (partData.dims.h4 or 0) * scale,
    }
    if partData.shape8URL and shape8Dict[partData.shape8URL] then
        local raw = topology.shape8Vertices(partData) -- a spine band, or the whole shape
        settings.vertices = makeTransformedVertices(raw, (partData.dims.sx or 1) * scale,
            (partData.dims.sy or 1) * scale)
        -- with lobes, the torso's collision stops where they start (src/torso-lobes.lua)
        if instance then settings.vertices = torsoLobes.collision(instance, partName, settings.vertices, scale) end
    end
    return settings
end

local function makePart(partName, instance, settings)
    local entry = instance.entryMap[partName]
    if not entry then return end
    local parent = entry.parent
    local prevA = 0

    if parent then
        if instance.parts[parent] then
            prevA = instance.parts[parent].body:getAngle()
            local parentOffsetX, parentOffsetY = topology.getOffsetFromParent(partName, instance, entry)
            local px, py = instance.parts[parent].body:getWorldPoint(parentOffsetX, parentOffsetY)
            settings.x = px
            settings.y = py
        end
    end

    local ownOffsetX, ownOffsetY = topology.getOwnOffset(partName, instance, entry)
    local source = facing.source(instance, partName) -- facing a side: this side's foot angle
    local xangle = topology.getAngleOffset(source, instance, instance.entryMap[source] or entry)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

    local thing = objectManager.addThing(settings.shapeType, settings)

    if thing then
        thing.body:setAngle(prevA + xangle)
        thing.mipoId = instance.id
        thing.mipoPartName = partName
        registry.updateSFixtureMasks(thing.body) -- a foot keeps its contacts (registry.GROUND_PARTS)
        applyFootMaterial(thing, partName)

        if extractNeckIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
        end
        if extractTorsoIndex(partName) then
            thing.body:setAngularDamping(.1)
            thing.body:setLinearDamping(.1)
            local f = thing.body:getFixtures()
            for i = 1, #f do
                f[i]:setDensity(1)
            end
        end

        instance.parts[partName] = thing
    end

    if parent then
        local partA_thing = instance.parts[parent]
        local partB_thing = instance.parts[partName]

        if (partA_thing and partB_thing) then
            local jointData = instance.dna.parts[partName].j
            local sourceJoint = instance.dna.parts[source] and instance.dna.parts[source].j
            local jointCreationData = {
                body1 = partA_thing.body,
                body2 = partB_thing.body,
                jointType = jointData.type,
                collideConnected = false, -- Default to false
                id = uuid.generateID(),
                offsetA = { x = 0, y = 0 },
                offsetB = { x = 0, y = 0 },
                frequency = jointData.frequency and units.rate(jointData.frequency),
                dampingRatio = jointData.dampingRatio,
                maxLength = jointData.maxLength and jointData.maxLength * instance.scale,
            }
            -- logger:info('joint:', parent, partName)
            -- todo we dont really need this yet...
            instance.joints[parent .. '->' .. partName] = jointCreationData.id

            local offX, offY = topology.getOffsetFromParent(partName, instance, entry)
            jointCreationData.offsetA.x = jointCreationData.offsetA.x + offX
            jointCreationData.offsetA.y = jointCreationData.offsetA.y + offY
            local joint = joints.createJoint(jointCreationData)
            local limits = (sourceJoint or jointData).limits

            if joint and limits and limits.low and limits.up then
                joint:setLimits(limits.low, limits.up)
                joint:setLimitsEnabled(true)
            end
            applyShoulderLimits(joint, facing.source(instance, partName))
            applyLegLimits(instance, joint, partName)
            if joint and torsoLobes.isLobe(partName) then
                torsoLobes.makeSprings(instance, partName, partA_thing.body, partB_thing.body)
            end
        end
    end
end

local function getPoseCache(instance)
    local poseCache = {}
    for partName, part in pairs(instance.parts) do
        local body = part.body

        -- a body a failed rebuild left without fixtures has no group to remember (MEASURING M6)
        local first = body:getFixtures()[1]
        local groupIndex = first and first:getGroupIndex()
        poseCache[partName] = {
            pos = { body:getPosition() },
            angle = body:getAngle(),
            linearVelocity = { body:getLinearVelocity() },
            angularVelocity = body:getAngularVelocity(),
            groupIndex = groupIndex or 0
        }
    end
    return poseCache
end
-- Parts with a stance angle (ears, feet) should keep the angle from makePart
-- rather than restoring the cached angle, since their stanceAngle may have changed.
local stanceAngleParts = { lear = true, rear = true, lfoot = true, rfoot = true }
local function applyPoseCache(instance, poseCache)
    -- using the cache
    for partName, pose in pairs(poseCache) do
        if instance.parts[partName] and pose then
            local body = instance.parts[partName].body
            if not stanceAngleParts[partName] then
                body:setAngle(pose.angle)
            end
            body:setLinearVelocity(pose.linearVelocity[1], pose.linearVelocity[2])
            body:setAngularVelocity(pose.angularVelocity)

            local gi = instance.groupIndex or pose.groupIndex
            local bodyFixtures = body:getFixtures()
            for j = 1, #bodyFixtures do
                bodyFixtures[j]:setGroupIndex(gi)
            end
        end
    end
end

local function fixDrift(positionTorso, instance)
    if positionTorso then
        local newPosX, newPosY = instance.parts['torso1'].body:getPosition()
        local dx = positionTorso[1] - newPosX
        local dy = positionTorso[2] - newPosY

        for _, part in pairs(instance.parts) do
            local bx, by = part.body:getPosition()
            part.body:setPosition(bx + dx, by + dy)
        end
    end
end

-- The lowest point of the Mipo's solid fixtures (world y grows downward), nil without any.
local function lowestPoint(instance)
    local low
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then
            for _, fixture in ipairs(part.body:getFixtures()) do
                if not fixture:isSensor() then
                    local _, _, _, bottom = fixture:getBoundingBox()
                    low = math.max(low or bottom, bottom)
                end
            end
        end
    end
    return low
end

-- A rebuild keeps torso1 where it was, so a Mipo that came out taller (longer legs, a bigger body,
-- bigger feet) started with its feet inside the floor, and Box2D pushed them out in one step: the dice
-- in the Mipo maker shot Mipos thousands of px up (measured 2026-11-09: feet 307 px into the floor).
-- Its lowest point is put back where the old one was: not into the floor, and a smaller Mipo set down
-- rather than dropped (the old feet were there, so the space is free).
local function keepLowestWhereItWas(instance, oldLowest)
    local newLowest = lowestPoint(instance)
    if not (oldLowest and newLowest) or math.abs(newLowest - oldLowest) <= 0.5 then return end
    local dy = oldLowest - newLowest
    for _, part in pairs(instance.parts) do
        local bx, by = part.body:getPosition()
        part.body:setPosition(bx, by + dy)
    end
end
lib.lowestPoint = lowestPoint

local function updateSinglePart(partName, data, instance)
    local partData = instance.dna.parts[partName]
    if not partData then return end


    for k, v in pairs(data) do
        if (partData.dims[k]) then
            partData.dims[k] = v
        elseif partData[k] then
            partData[k] = v
        end
    end
    -- a spine's bands all take torso1's shape (rebuilt below as its children)
    if partName:find('^torso%d') then
        balance.applySpine(instance)
        torsoLobes.apply(instance)
    end

    local oldPosX, oldPosY = 0, 0
    local oldAngle = 0

    -- Remove old body
    local wasSelected = false
    if instance.parts[partName] then
        local oldBody = instance.parts[partName].body
        oldPosX, oldPosY = oldBody:getPosition()
        oldAngle = oldBody:getAngle()
        wasSelected = (state.selection.selectedObj and state.selection.selectedObj.body == oldBody)
        objectManager.destroyBody(oldBody)
        instance.parts[partName] = nil
    end

    local children = instance.childrenMap[partName] or {}
    makePart(partName, instance, partSettings(partName, partData, instance.scale or 1, oldPosX, oldPosY, instance))

    if not instance.parts[partName] then return end

    -- after making a part set it to its angle so the children will be using that angle in their calculations.
    instance.parts[partName].body:setAngle(oldAngle)

    -- Re-select the new body if the old one was selected
    if wasSelected and instance.parts[partName] then
        local thing = utils.thingOf(instance.parts[partName].body)
        if thing then
            state.selection.selectedObj = thing
        end
    end

    for _, childName in ipairs(children) do
        local childData = instance.dna.parts[childName]
        if childData then
            updateSinglePart(childName, {}, instance) -- trigger rebuild
        end
    end
end

-- Update a character body part's shape/dimensions and recreate it.
-- data: {shape8URL, sx, sy, w, h}
function lib.updatePart(partName, data, instance)
    local positionTorso = nil
    if partName == 'torso1' then
        positionTorso = { instance.parts['torso1'].body:getPosition() }
    end

    -- filling the cache
    local poseCache = getPoseCache(instance)
    local oldLowest = lowestPoint(instance)
    updateSinglePart(partName, data, instance)
    -- a new torso shape can have another number of lobes: build the Mipo again
    local lobes, built = torsoLobes.names(instance), 0
    for name in pairs(instance.entryMap or {}) do
        if torsoLobes.isLobe(name) then built = built + 1 end
    end
    if lobes and #lobes ~= built then return lib.rebuildFromCreation(instance, {}) end
    balance.balanceMasses(instance)
    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
    keepLowestWhereItWas(instance, oldLowest)
end

-- The joint limits of a built part set again: after its facing changed (switchFacing).
local function reapplyLimits(instance, partName)
    local part, entry = instance.parts[partName], instance.entryMap[partName]
    local parent = entry and entry.parent and instance.parts[entry.parent]
    if not (part and parent) then return end
    local source = facing.source(instance, partName)
    local j = instance.dna.parts[source] and instance.dna.parts[source].j
    for _, joint in ipairs(part.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent.body and b == part.body and joint:getType() == 'revolute' then
            if j and j.limits and j.limits.low and j.limits.up then
                joint:setLimits(j.limits.low, j.limits.up)
                joint:setLimitsEnabled(true)
            end
            applyShoulderLimits(joint, source)
            applyLegLimits(instance, joint, partName)
        end
    end
end

local LIMBS = { 'luleg', 'ruleg', 'llleg', 'rlleg', 'luarm', 'ruarm', 'llarm', 'rlarm' }
local FEET = { 'lfoot', 'rfoot' }

-- A built Mipo turned to another facing ('left' / 'front' / 'right', src/mipo-facing.lua)
-- without rebuilding it: torso, head, legs and arms keep their bodies (and how they move), the
-- limbs get the new side's joint limits, the foot that turns and the ears are remade (their
-- angle, picture and attach point change) and the textures redrawn (the draw order with them).
function lib.switchFacing(instance, want)
    local before, earsBefore = {}, facing.earFacing(instance)
    for _, name in ipairs(FEET) do before[name] = facing.source(instance, name) end
    instance.dna.facing = want
    for _, name in ipairs(LIMBS) do reapplyLimits(instance, name) end
    -- only a foot that turns is remade (in one step that's one foot): the other keeps its pose
    local turned = {}
    for _, name in ipairs(FEET) do
        turned[name] = facing.source(instance, name) ~= before[name]
        if turned[name] and instance.parts[name] then lib.updatePart(name, {}, instance) end
    end
    -- the ears only when theirs changed (dna.earFacing keeps them: a staggered turn moves them later)
    if facing.earFacing(instance) ~= earsBefore then
        for _, name in ipairs({ 'lear', 'rear' }) do
            if instance.parts[name] then lib.updatePart(name, {}, instance) end
        end
    end
    -- updatePart keeps a part's angle; a turned foot goes to its new rest instead
    for _, name in ipairs(FEET) do
        local foot, entry = instance.parts[name], instance.entryMap[name]
        local shin = entry and instance.parts[entry.parent]
        if turned[name] and foot and shin then
            local source = facing.source(instance, name)
            local offset = topology.getAngleOffset(source, instance, instance.entryMap[source] or entry)
            foot.body:setAngle(shin.body:getAngle() + offset)
        end
    end
    textures.rebuildTextures(instance)
    applyGroupAndZ(instance, true)
end

-- The arms alone turned to another facing (dna.armFacing; nil again follows the body): their
-- joint limits and draw order, at their own moment in a turn (scripts/spikes/facing).
function lib.switchArms(instance, want)
    instance.dna.armFacing = want
    for _, name in ipairs({ 'luarm', 'ruarm', 'llarm', 'rlarm' }) do reapplyLimits(instance, name) end
    textures.rebuildTextures(instance)
    applyGroupAndZ(instance, true)
end

-- The ears alone turned to another facing (dna.earFacing; nil again follows the body): remade, their
-- attach point and the back ear's place, at their own moment in a turn (src/mipo-walk.lua).
function lib.switchEars(instance, want)
    local was = facing.earFacing(instance)
    instance.dna.earFacing = want
    if facing.earFacing(instance) == was then return end
    for _, name in ipairs({ 'lear', 'rear' }) do
        if instance.parts[name] then lib.updatePart(name, {}, instance) end
    end
    textures.rebuildTextures(instance)
    applyGroupAndZ(instance, true)
end

-- given an instance with dna and a new creation, this function is made to change
-- a creation of a humanoid during runtime.
-- its alos used by initially creating a character.
function lib.rebuildFromCreation(instance, newCreation)
    -- Step 1: Update the creation settings. The counts name parts (torso1..torsoN, neck1..neckN): a
    -- fraction ('torso3.25', from a dragged slider) left the arms, neck and head hanging from a part
    -- that doesn't exist, so they fell off (Mipo maker, 2026-11-09). Whole numbers only.
    for k, v in pairs(newCreation) do
        if (k == 'torsoSegments' or k == 'neckSegments' or k == 'noseSegments') and type(v) == 'number' then
            v = math.floor(v + 0.5)
        end
        instance.dna.creation[k] = v
    end

    local torsoX, torsoY = instance.parts['torso1'].body:getPosition()
    local torsoAngle = instance.parts['torso1'].body:getAngle()

    local poseCache = getPoseCache(instance)

    local positionTorso = { instance.parts['torso1'].body:getPosition() }
    local oldLowest = lowestPoint(instance)

    -- Track which part was selected so we can re-select after rebuild
    local selectedPartName = nil
    local selectedObj = state.selection.selectedObj
    if selectedObj and selectedObj.body and not selectedObj.body:isDestroyed() then
        for pName, part in pairs(instance.parts) do
            if part == selectedObj then
                selectedPartName = pName
                break
            end
        end
    end

    -- Step 2: Remove all existing parts (in a fixed order: Box2D reuses what's freed in that order)
    for _, part in utils.sortedPairs(instance.parts) do
        objectManager.destroyBody(part.body)
    end

    instance.parts = {}
    instance.joints = {}
    lib.createCharacterFromExistingDNA(instance, torsoX, torsoY, torsoAngle)

    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
    keepLowestWhereItWas(instance, oldLowest)

    -- Re-select the same part (or torso1 if the old part no longer exists)
    if selectedPartName then
        local newPart = instance.parts[selectedPartName] or instance.parts['torso1']
        if newPart then
            state.selection.selectedObj = newPart
        end
    end
end

-- Defaults for what older DNA lacks, old saves moved over, and the body plan (topology).
local function prepareDNA(instance)
    D.ensureDefaults(instance.dna.creation, D.creation)
    -- old saves moved over (src/save-migrations.lua); once, the instance's DNA is today's after
    local partSteps
    partSteps, instance.dnaVersion = migrations.upgradeDNA(instance.dna, instance.dnaVersion)
    instance.oldPartSteps = #partSteps > 0 and partSteps or nil
    instance.dna.faceMagnitude = instance.dna.faceMagnitude or D.faceMagnitude
    instance.dna.positioners = instance.dna.positioners or {}
    D.ensureDefaults(instance.dna.positioners, D.positioners)
    local topo = topology.resolve(instance.dna.creation, instance.dna.positioners, torsoLobes.names(instance))
    instance.topology = topo
    instance.entryMap = topology.buildEntryMap(topo)
    instance.childrenMap = topology.buildChildrenMap(topo)
    return topo
end

-- A new Mipo instance around a copy of this DNA (no bodies yet).
local function newInstance(mipoDNA, scale, id)
    return {
        id = id or uuid.generateID(),
        dna = utils.deepCopy(mipoDNA),
        scale = scale or 1,
        parts = {},  -- [partName] = thing
        joints = {}, -- ['parent->child'] = joint id (connected textures follow them)
    }
end

function lib.createCharacterFromExistingDNA(instance, x, y, optionalTorsoAngle)
    -- same logic as in createCharacter, but uses `instance.dna` and skips the `deepCopy`
    -- rebuilds the ordered list, generates torso/neck segments, limbs, etc.

    local ordered = topology.buildOrderedNames(prepareDNA(instance))

    -- Ensure template-based parts have their DNA filled in
    local torsoSegments = instance.dna.creation.torsoSegments
    for i = 1, torsoSegments do
        local partName = 'torso' .. i
        if not instance.dna.parts[partName] then
            if not instance.dna.parts['torso-segment-template'] then
                error("Missing 'torso-segment-template' in DNA parts")
            end
            instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['torso-segment-template'])
        end
    end
    balance.applySpine(instance)
    torsoLobes.apply(instance)

    if not instance.dna.creation.isPotatoHead and instance.dna.creation.neckSegments > 0 then
        for i = 1, instance.dna.creation.neckSegments do
            instance.dna.parts['neck' .. i] = utils.deepCopy(instance.dna.parts['neck-segment-template'])
        end
        balance.applyNeck(instance)
    end

    local noseSegments = instance.dna.creation.noseSegments
    local noseMode = instance.dna.creation.noseMode or 'overlay'

    -- Skip physics nose entirely for overlay mode with 1 segment
    local physicsNoseCount = noseSegments
    if noseSegments == 1 and noseMode == 'overlay' then
        physicsNoseCount = 0
    end

    if physicsNoseCount > 0 then
        if physicsNoseCount == 1 and noseMode == 'physics' then
            -- Single SHAPE8 nose
            if not instance.dna.parts['nose1'] then
                instance.dna.parts['nose1'] = utils.deepCopy(instance.dna.parts['nose-single-template'])
            end
        else
            -- Segmented capsule trunk
            for i = 1, physicsNoseCount do
                local partName = 'nose' .. i
                if not instance.dna.parts[partName] then
                    instance.dna.parts[partName] = utils.deepCopy(instance.dna.parts['nose-segment-template'])
                end
            end
            balance.applyTrunk(instance)
            local nose1 = instance.dna.parts['nose1']
            if not nose1.appearance then nose1.appearance = {} end
            if not nose1.appearance['connected-skin'] then
                nose1.appearance['connected-skin'] = {
                    main = initBlock('mipo/leg/leg-05'),
                    zOffset = 350, -- trunk: in front of body/legs, behind arms and hands
                }
            end
            -- connected-hair is optional; added via UI when the user picks a hair texture
        end
    end

    for i = 1, #ordered do
        local partName = ordered[i]
        local partData = instance.dna.parts[partName]
        makePart(partName, instance, partSettings(partName, partData, instance.scale, x, y, instance))
        if optionalTorsoAngle and partName == 'torso1' then
            instance.parts['torso1'].body:setAngle(optionalTorsoAngle)
        end
    end


    -- here we will build up the sfixtures we need.
    --logger:info('calling defaultSetupTextures')


    textures.rebuildTextures(instance)

    -- Assign a unique negative group index to prevent self-collision.
    -- Reuse existing index if this is a rebuild, otherwise allocate a new one.
    if not instance.groupIndex then
        instance.groupIndex = allocateGroupIndex()
    end
    -- Assign a unique zGroupOffset so each character's textures occupy a
    -- separate z-range (composedZ = zGroupOffset * 1000 + zOffset).
    if not instance.zGroupOffset then
        instance.zGroupOffset = allocateZGroupOffset(instance)
    end
    applyGroupAndZ(instance, true)

    balance.balanceMasses(instance)
    mipoRegistry.register(instance)
    return instance
end

-- A Mipo out of the world: its parts, their joints and snaps, and its registry entry. A finger
-- holding one of its parts lets go first (as a Mipo going through a door, src/doors.lua).
function lib.removeCharacter(instance)
    if not instance then return end
    require('src.physics.box2d-pointerjoints').resetPointerJoints()
    state.interaction.draggingObj = nil
    local snap = require('src.physics.snap')
    for _, part in utils.sortedPairs(instance.parts or {}) do
        if part.body and not part.body:isDestroyed() then
            snap.destroySnapJointAboutBody(part.body)
            objectManager.destroyBody(part.body)
        end
    end
    mipoRegistry.unregister(instance.id)
end

-- dnaVersion: the DNA's save version when it comes from a file (src/save-migrations.lua; nil, from
-- before versions or unknown: the old saves' steps run, which leave today's DNA as it is)
function lib.createCharacterFromJustDNA(mydna, x, y, scale, dnaVersion)
    local instance = newInstance(mydna, scale)
    instance.dnaVersion = dnaVersion
    return lib.createCharacterFromExistingDNA(instance, x, y, false)
end

-- One-shot post-spawn pose: rigidly rotate each arm chain about its shoulder so
-- the character appears in T-pose the moment it's added. No KEEP_ANGLE — physics
-- takes over on the next step and the arms behave naturally.
-- Assumes arms were created at angle 0 (hanging). Safe to call on a fresh instance.
function lib.poseTpose(instance)
    local chains = {
        { parts = { 'luarm', 'llarm', 'lhand' }, delta = math.pi / 2 },
        { parts = { 'ruarm', 'rlarm', 'rhand' }, delta = -math.pi / 2 },
    }
    for _, chain in ipairs(chains) do
        local upper = instance.parts[chain.parts[1]]
        if upper and upper.body and upper.height then
            -- Shoulder = top of the upper arm in its hanging pose (local y = -h/2).
            local sx, sy = upper.body:getWorldPoint(0, -upper.height / 2)
            for _, partName in ipairs(chain.parts) do
                local part = instance.parts[partName]
                if part and part.body then
                    local cx, cy = part.body:getPosition()
                    local nx, ny = mathutils.rotatePoint(cx, cy, sx, sy, chain.delta)
                    part.body:setPosition(nx, ny)
                    part.body:setAngle(part.body:getAngle() + chain.delta)
                    part.body:setAngularVelocity(0)
                    part.body:setLinearVelocity(0, 0)
                end
            end
        end
    end
end

-- Posing a Mipo by hand, before physics takes over (sitting it in a cart, on a bike): find a joint, swing a
-- chain of parts about it, slide the whole Mipo, measure it. ENGINE-MERGE EM5, 2026-11-11: the copies in
-- the bike, facing, rides and soapbox spikes (the same code) moved here; in a scene script through
-- characterManager.
local function alive(body) return body and not body:isDestroyed() end

-- where the joint between parent and part sits (a hip, a knee, an ankle): world x, y, nil if there's none
function lib.jointPoint(instance, parentName, partName)
    local part, parent = instance.parts[partName], instance.parts[parentName]
    if not (part and parent) then return nil end
    for _, joint in ipairs(part.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == parent.body and b == part.body then
            local x, y = joint:getAnchors()
            return x, y
        end
    end
end

-- bodies turned rigidly by delta (radians) about px, py: a Mipo's leg, a whole bike
function lib.turnBodies(bodies, px, py, delta)
    local cs, sn = math.cos(delta), math.sin(delta)
    for _, b in ipairs(bodies) do
        if alive(b) then
            local x, y = b:getPosition()
            local rx, ry = x - px, y - py
            b:setPosition(px + rx * cs - ry * sn, py + rx * sn + ry * cs)
            b:setAngle(b:getAngle() + delta)
        end
    end
end

-- the same for a Mipo's parts by name: lib.turnParts(inst, { 'luleg', 'llleg', 'lfoot' }, hipX, hipY, a)
function lib.turnParts(instance, names, px, py, delta)
    local bodies = {}
    for _, name in ipairs(names) do
        if instance.parts[name] then bodies[#bodies + 1] = instance.parts[name].body end
    end
    lib.turnBodies(bodies, px, py, delta)
end

-- the whole Mipo slid by dx, dy, and stilled
function lib.moveAll(instance, dx, dy)
    for _, part in pairs(instance.parts) do
        local b = part.body
        if alive(b) then
            local px, py = b:getPosition()
            b:setPosition(px + dx, py + dy)
            b:setLinearVelocity(0, 0)
            b:setAngularVelocity(0)
        end
    end
end

-- how tall it stands: its solid shapes, top to bottom (world units)
function lib.mipoHeight(instance)
    local top, bottom = math.huge, -math.huge
    for _, part in pairs(instance.parts) do
        for _, fixture in ipairs(alive(part.body) and part.body:getFixtures() or {}) do
            if not fixture:isSensor() then
                local _, y0, _, y1 = fixture:getBoundingBox()
                top, bottom = math.min(top, y0), math.max(bottom, y1)
            end
        end
    end
    return bottom - top
end

function lib.createCharacter(template, x, y, scale)
    if dna[template] then
        local instance = newInstance(dna[template], scale)
        instance.templateName = template
        return lib.createCharacterFromExistingDNA(instance, x, y, false)
    end
end

-- Serialize all registered character instances to a plain-table array suitable
-- for JSON encoding. Each entry is versioned so future loaders can migrate.
-- dna.metadata is preserved verbatim — use it for archetype kind, mipo codes, etc.
function lib.serializeCharacters()
    local result = {}
    for _, instance in pairs(mipoRegistry.getAll()) do
        result[#result + 1] = {
            version = migrations.DNA_VERSION, -- src/save-migrations.lua
            id = instance.id,
            scale = instance.scale or 1,
            zGroupOffset = instance.zGroupOffset,
            dna = utils.deepCopy(instance.dna),
        }
    end
    return result
end

-- A loaded body taken in as the instance's part: its thing, foot grip (scenes saved before feet
-- had it), old fixtures updated, the limits of the joint to its parent relative to the rest pose.
local function adoptPart(instance, partName, body)
    local thing = utils.thingOf(body)
    if not thing then return end
    instance.parts[partName] = thing
    applyFootMaterial(thing, partName)
    for _, step in ipairs(instance.oldPartSteps or {}) do step(body, partName) end -- old saves' fixtures
    for _, joint in ipairs(body:getJoints()) do
        local _, bodyB = joint:getBodies()
        if bodyB == body then
            applyShoulderLimits(joint, facing.source(instance, partName))
            applyLegLimits(instance, joint, partName)
        end
    end
end

-- instance.joints ('parent->child' = joint id) is what texture rebuilds use for
-- connected-texture nodes. It isn't saved, so rebuild it from the bodies; left empty,
-- redrawing textures on a loaded Mipo pointed leg textures at missing joints (untextured legs).
local function rebuildJointIds(instance)
    for parentName, children in pairs(instance.childrenMap or {}) do
        local parent = instance.parts[parentName]
        for _, childName in ipairs(children) do
            local child = instance.parts[childName]
            if parent and child and parent.body and child.body then
                for _, joint in ipairs(child.body:getJoints()) do
                    local a, b = joint:getBodies()
                    local jud = joint:getUserData()
                    if a == parent.body and b == child.body and jud and jud.id then
                        instance.joints[parentName .. '->' .. childName] = jud.id
                    end
                end
            end
        end
    end
end

-- connected textures saved with missing joints (from the bug above) need redrawing
local function hasBrokenTextures(instance)
    for _, part in pairs(instance.parts) do
        for _, fixture in ipairs(part.body:getFixtures()) do
            local fud = fixture:getUserData()
            for _, node in ipairs(fud and fud.extra and fud.extra.nodes or {}) do
                if node.type == NT.JOINT and not registry.getJointByID(node.id) then return true end
            end
        end
    end
    return false
end

-- repair scenes saved before allocation skipped values in use: two Mipos sharing a group
-- index never collide, sharing a zGroupOffset interleaves textures
local function repairGroupAndZ(instance)
    local groupTaken, zTaken = false, false
    for id, other in pairs(mipoRegistry.getAll()) do
        if id ~= instance.id then
            if instance.groupIndex and other.groupIndex == instance.groupIndex then groupTaken = true end
            if instance.zGroupOffset and other.zGroupOffset == instance.zGroupOffset then zTaken = true end
        end
    end
    if groupTaken then instance.groupIndex = allocateGroupIndex() end
    if zTaken then instance.zGroupOffset = allocateZGroupOffset(instance) end
    if groupTaken or zTaken then applyGroupAndZ(instance, true) end
end

-- Reconstruct a character instance from saved data and a map of already-loaded bodies.
-- partBodies: { [partName] = body } — the bodies that were just recreated by io.buildWorld.
-- Ensures DNA defaults so new fields added to dna-defaults are auto-populated on old saves.
function lib.reconstructInstance(charData, partBodies)
    if not partBodies then return nil end
    local instance = newInstance(charData.dna, charData.scale, charData.id)
    instance.zGroupOffset = charData.zGroupOffset
    instance.dnaVersion = charData.version -- old saves are moved over in prepareDNA
    prepareDNA(instance)
    balance.applyNeck(instance) -- neck limits (bend budget) before the rest-pose limits below
    balance.applyTrunk(instance)
    for partName, body in pairs(partBodies) do
        adoptPart(instance, partName, body)
        -- keep the saved group index so a rebuild doesn't hand out a new one
        local first = body:getFixtures()[1]
        if not instance.groupIndex and first and first:getGroupIndex() < 0 then
            instance.groupIndex = first:getGroupIndex()
        end
    end
    instance.oldPartSteps = nil
    rebuildJointIds(instance)
    local brokenTextures = hasBrokenTextures(instance)
    repairGroupAndZ(instance)
    mipoRegistry.register(instance)
    if brokenTextures then
        textures.rebuildTextures(instance)
    end
    balance.applyNeck(instance, true)
    balance.balanceMasses(instance)
    balance.settlePose(instance)
    return instance
end

-- Stubby Mipos get wide leg shapes (Nikki 2026-11-10: a Mipo with short legs under a big head and
-- torso did the splits, hopped up (mipo-joint-guard standUp), and did them again, for good; wider leg
-- shapes, the drawing left as it is, stood it). Measured on random Mipos, front and facing a side,
-- dropped twice, with the stance muscles (src/mipo-stance.lua): on the usual legs (dims.w 80, 24 px
-- at scale 0.3) about 1 in 10 doesn't stand; those have short legs under a tall body, and need
-- 100-200. Not every stubby one does, and no measure told them apart, so: legs under lib.stubbyLeg
-- px and a body over lib.stubbyRatio times as tall get lib.stubbyLegW. 180 px / 1.75: 13 of 80 wide,
-- 4 still fell (all facing a side); 270 / 1.5: 31 of 80 wide, all 80 stand (Nikki: standing first).
-- Wide legs knot more in piles (5 piles of 8, knots left after 30 s: 23 against 15); knots are
-- their own problem. Drawn width for every Mipo was tried first: drawn legs are 24-60 px, piles
-- knotted twice as often, and for the stubbiest it wasn't wide enough either.
-- Measured on the built parts: run after the build; `rebuild` remakes the legs (then redraw the
-- textures). Returns the width it set.
lib.legW = 80
lib.stubbyLegW = 200
lib.stubbyLeg = 270    -- px, thigh + shin, at the Mipo's scale
lib.stubbyRatio = 1.5  -- body (torso segments, neck, head) height over leg length
local LEGS = { 'luleg', 'ruleg', 'llleg', 'rlleg' }

local function tallness(body)
    local y1, y2 = math.huge, -math.huge
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then
            local _, top, _, bottom = fixture:getBoundingBox(1)
            y1, y2 = math.min(y1, top), math.max(y2, bottom)
        end
    end
    return y2 > y1 and y2 - y1 or 0
end

-- leg length and body height (px), from the built parts
function lib.legProportions(instance)
    local parts, partsDNA = instance.parts, instance.dna.parts
    if not (partsDNA.luleg and partsDNA.llleg) then return nil end
    local legLength = (partsDNA.luleg.dims.h + partsDNA.llleg.dims.h) * (instance.scale or 1)
    local body = 0
    for name, part in pairs(parts) do
        if (name == 'head' or name:match('^torso%d+$') or name:match('^neck%d+$'))
            and part.body and not part.body:isDestroyed() then
            body = body + tallness(part.body)
        end
    end
    return legLength, body
end

function lib.fitLegWidth(instance, rebuild)
    local legLength, body = lib.legProportions(instance)
    if not legLength then return end
    local stubby = legLength < lib.stubbyLeg and body > lib.stubbyRatio * legLength
    local w = stubby and lib.stubbyLegW or lib.legW
    for _, name in ipairs(LEGS) do
        local dims = instance.dna.parts[name] and instance.dna.parts[name].dims
        if dims and dims.w ~= w then
            dims.w = w
            if rebuild and instance.parts[name] then lib.updatePart(name, { w = w }, instance) end
        end
    end
    return w
end

return lib
