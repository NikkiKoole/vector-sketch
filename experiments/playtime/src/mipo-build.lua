-- src/mipo-build.lua (split from character-manager.lua, SPLIT2)
local lib = {}

local mipoDna = require('src.mipo-dna')
local appearance = require('src.mipo-appearance')
local shape8Dict = require('src.shape8-dict')
local balance = require('src.mipo-balance')
local textures = require('src.mipo-textures')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local uuid = require('src.uuid')
local utils = require('src.utils')
local mathutils = require('src.math-utils')
local subtypes = require('src.subtypes')
local JT = require('src.joint-types')
local BT = require('src.body-types')
local NT = require('src.node-types')
local mipoRegistry = require('src.mipo-registry')
local state = require('src.state')
local D = require('src.dna-defaults')
local topology = require('src.character-topology')
local units = require('src.physics-units')
local registry = require('src.registry')
local dna, earJoint = mipoDna.dna, mipoDna.earJoint
local TORSO_SKIN_Z, TORSO_HAIR_ABOVE_SKIN = mipoDna.TORSO_SKIN_Z, mipoDna.TORSO_HAIR_ABOVE_SKIN
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
    local partDNA = instance.dna.parts[partName]
    local limits = partDNA and partDNA.j and partDNA.j.limits
    if not (limits and limits.low and limits.up) then return end
    local rest = footRest[partName] or partDNA.stanceAngle or 0
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
local function partSettings(partName, partData, scale, x, y)
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
    local xangle = topology.getAngleOffset(partName, instance, entry)

    -- Rotate own offset into parent space
    local rotatedOwnX, rotatedOwnY = mathutils.rotatePoint(ownOffsetX, ownOffsetY, 0, 0, prevA + xangle)

    settings.x = settings.x + rotatedOwnX
    settings.y = settings.y + rotatedOwnY

    local thing = objectManager.addThing(settings.shapeType, settings)

    if thing then
        thing.body:setAngle(prevA + xangle)
        thing.mipoId = instance.id
        thing.mipoPartName = partName
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
            }
            -- logger:info('joint:', parent, partName)
            -- todo we dont really need this yet...
            instance.joints[parent .. '->' .. partName] = jointCreationData.id

            local offX, offY = topology.getOffsetFromParent(partName, instance, entry)
            jointCreationData.offsetA.x = jointCreationData.offsetA.x + offX
            jointCreationData.offsetA.y = jointCreationData.offsetA.y + offY
            local joint = joints.createJoint(jointCreationData)
            local limits = jointData.limits

            if joint and limits and limits.low and limits.up then
                joint:setLimits(limits.low, limits.up)
                joint:setLimitsEnabled(true)
            end
            applyShoulderLimits(joint, partName)
            applyLegLimits(instance, joint, partName)
        end
    end
end

local function getPoseCache(instance)
    local poseCache = {}
    for partName, part in pairs(instance.parts) do
        local body = part.body

        local groupIndex = body:getFixtures()[1]:getGroupIndex()
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
    if partName:find('^torso%d') then balance.applySpine(instance) end

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
    makePart(partName, instance, partSettings(partName, partData, instance.scale or 1, oldPosX, oldPosY))

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
    updateSinglePart(partName, data, instance)
    balance.balanceMasses(instance)
    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end
end

-- given an instance with dna and a new creation, this function is made to change
-- a creation of a humanoid during runtime.
-- its alos used by initially creating a character.
function lib.rebuildFromCreation(instance, newCreation)
    -- Step 1: Update the creation settings
    for k, v in pairs(newCreation) do
        instance.dna.creation[k] = v
    end

    local torsoX, torsoY = instance.parts['torso1'].body:getPosition()
    local torsoAngle = instance.parts['torso1'].body:getAngle()

    local poseCache = getPoseCache(instance)

    local positionTorso = { instance.parts['torso1'].body:getPosition() }

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

    -- Step 2: Remove all existing parts
    for _, part in pairs(instance.parts) do
        objectManager.destroyBody(part.body)
    end

    instance.parts = {}
    instance.joints = {}
    lib.createCharacterFromExistingDNA(instance, torsoX, torsoY, torsoAngle)

    applyPoseCache(instance, poseCache)
    if positionTorso then fixDrift(positionTorso, instance) end

    -- Re-select the same part (or torso1 if the old part no longer exists)
    if selectedPartName then
        local newPart = instance.parts[selectedPartName] or instance.parts['torso1']
        if newPart then
            state.selection.selectedObj = newPart
        end
    end
end

-- Old saved DNA moved over to what builds now.
local function migrateDNA(instance)
    for partName, partDNA in pairs(instance.dna.parts or {}) do
        -- noses saved when they drew at z 490, above the arms
        if partName:find('^nose') and partDNA.appearance then
            for _, block in pairs(partDNA.appearance) do
                if type(block) == 'table' and block.zOffset == 490 then block.zOffset = 350 end
            end
        end
        -- ears on a hinge (saved before the soft weld): the next rebuild makes them springy
        if (partName == 'lear' or partName == 'rear') and partDNA.j and partDNA.j.type == JT.REVOLUTE then
            partDNA.j = earJoint()
        end
        local skin = partName:find('^torso%d') and partDNA.appearance and partDNA.appearance.skin
        if skin and skin.zOffset == 200 then skin.zOffset = TORSO_SKIN_Z end
        -- the duck beak upper lip is out (shape-catalogs.lua)
        local face = partDNA.appearance and partDNA.appearance.face
        if face and face.mouth and face.mouth.upperLipShape == 4 then face.mouth.upperLipShape = 1 end
    end
end

-- Defaults for what older DNA lacks, old saves moved over, and the body plan (topology).
local function prepareDNA(instance)
    D.ensureDefaults(instance.dna.creation, D.creation)
    migrateDNA(instance)
    instance.dna.faceMagnitude = instance.dna.faceMagnitude or D.faceMagnitude
    instance.dna.positioners = instance.dna.positioners or {}
    D.ensureDefaults(instance.dna.positioners, D.positioners)
    local topo = topology.resolve(instance.dna.creation)
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
                    main = initBlock('leg5'),
                    zOffset = 350, -- trunk: in front of body/legs, behind arms and hands
                }
            end
            -- connected-hair is optional; added via UI when the user picks a hair texture
        end
    end

    for i = 1, #ordered do
        local partName = ordered[i]
        makePart(partName, instance, partSettings(partName, instance.dna.parts[partName], instance.scale, x, y))
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

function lib.createCharacterFromJustDNA(mydna, x, y, scale)
    return lib.createCharacterFromExistingDNA(newInstance(mydna, scale), x, y, false)
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
            version = 1,
            id = instance.id,
            scale = instance.scale or 1,
            zGroupOffset = instance.zGroupOffset,
            dna = utils.deepCopy(instance.dna),
        }
    end
    return result
end

-- Reconstruct a character instance from saved data and a map of already-loaded bodies.
-- partBodies: { [partName] = body } — the bodies that were just recreated by io.buildWorld.
-- Ensures DNA defaults so new fields added to dna-defaults are auto-populated on old saves.
function lib.reconstructInstance(charData, partBodies)
    if not partBodies then return nil end
    local instance = newInstance(charData.dna, charData.scale, charData.id)
    instance.zGroupOffset = charData.zGroupOffset
    prepareDNA(instance)
    balance.applyNeck(instance) -- neck limits (bend budget) before the rest-pose limits below
    balance.applyTrunk(instance)
    for partName, body in pairs(partBodies) do
        local thing = utils.thingOf(body)
        if thing then
            instance.parts[partName] = thing
            applyFootMaterial(thing, partName) -- scenes saved before feet had grip
            -- scenes saved when every nose was drawn at z 490, above the arms; and when
            -- torsos drew at the head's 200/210 (TORSO_SKIN_Z)
            for _, fixture in ipairs(body:getFixtures()) do
                local fud = fixture:getUserData()
                if fud and fud.extra and partName:find('^torso%d') and fud.subtype == subtypes.TEXFIXTURE then
                    if fud.extra.zOffset == 200 then
                        fud.extra.zOffset = TORSO_SKIN_Z
                    elseif fud.extra.zOffset == 210 then
                        fud.extra.zOffset = TORSO_SKIN_Z + TORSO_HAIR_ABOVE_SKIN
                    end
                end
                if fud and fud.label == 'upperlip' and fud.extra and fud.extra.main
                    and fud.extra.main.bgURL == 'upperlip4.png' then -- the duck beak is out
                    fud.extra.main.bgURL, fud.extra.main.fgURL = 'upperlip1.png', 'upperlip1-mask.png'
                    fud.extra.dirty = true
                end
                if fud and fud.extra and fud.extra.zOffset == 490 then
                    if fud.label == 'nose' then
                        fud.extra.zOffset = 254
                    elseif partName:find('^nose') then
                        fud.extra.zOffset = 350
                    end
                end
            end
            do -- limits relative to the rest pose
                for _, joint in ipairs(body:getJoints()) do
                    local _, bodyB = joint:getBodies()
                    if bodyB == body then
                        applyShoulderLimits(joint, partName)
                        applyLegLimits(instance, joint, partName)
                    end
                end
            end
        end
        -- keep the saved group index so a rebuild doesn't hand out a new one
        local first = body:getFixtures()[1]
        if not instance.groupIndex and first and first:getGroupIndex() < 0 then
            instance.groupIndex = first:getGroupIndex()
        end
    end
    -- instance.joints ('parent->child' = joint id) is what texture rebuilds use
    -- for connected-texture nodes. It isn't saved, so rebuild it from the bodies;
    -- left empty, redrawing textures on a loaded Mipo pointed leg textures at
    -- missing joints (untextured legs).
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
    -- connected textures saved with missing joints (from the bug above): redraw
    local brokenTextures = false
    for _, part in pairs(instance.parts) do
        for _, fixture in ipairs(part.body:getFixtures()) do
            local fud = fixture:getUserData()
            for _, node in ipairs(fud and fud.extra and fud.extra.nodes or {}) do
                if node.type == NT.JOINT and not registry.getJointByID(node.id) then brokenTextures = true end
            end
        end
    end

    -- repair scenes saved before allocation skipped values in use: two Mipos
    -- sharing a group index never collide, sharing a zGroupOffset interleaves textures
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
    mipoRegistry.register(instance)
    if brokenTextures then
        textures.rebuildTextures(instance)
        applyGroupAndZ(instance, true) -- the redrawn texture fixtures start in group 0
    end
    balance.applyNeck(instance, true)
    balance.balanceMasses(instance)
    balance.settlePose(instance)
    return instance
end



return lib
