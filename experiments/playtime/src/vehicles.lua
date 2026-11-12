-- src/vehicles.lua: vehicles as a kind (docs/KINDS.md KD4), out of the rides spike (scripts/spikes/rides,
-- docs/RIDES.md): a frame and two wheels on wheel joints, made of ordinary things, so they select, save,
-- copy and dissolve like anything else: a kart, a car, a banana car, a skateboard (KD4a, KD4d), rolling
-- when pushed. Driving and getting in come in KD4c.
local lib = {}

local objectManager = require('src.object-manager')
local joints = require('src.joints')
local JT = require('src.joint-types')
local uuid = require('src.uuid')
local mathutils = require('src.math-utils')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')

-- a body's own shape (its first fixture without userdata): the sfixtures (its pictures) come first
function lib.solidFixture(body)
    for _, fixture in ipairs(body:getFixtures()) do
        if fixture:getUserData() == nil then return fixture end
    end
end

-- The wheels' picture (RIDES RD3, the look's first bit): Nikki's crayon wheel from the mipoworld experiment,
-- as an outline (the tread and rim lines, in ink) and a mask (the tyre, in rubber); it turns with the wheel.
lib.WHEEL_PICTURE = 'world/vehicles/wheel-01'
lib.WHEEL_INK, lib.WHEEL_RUBBER = '1c1a18ff', '4a4440ff'

local function dressWheel(body, r)
    local size = 2 * r * 1.06 -- the drawn tyre's outside is a little inside the picture's edge
    local fixture = fixtures.createSFixture(body, 0, 0, subtypes.TEXFIXTURE, { width = size, height = size })
    if not fixture then return end
    local extra = fixture:getUserData().extra
    extra.OMP, extra.dirty = true, true
    extra.main = { bgURL = lib.WHEEL_PICTURE .. '.png', fgURL = lib.WHEEL_PICTURE .. '-mask.png',
        bgHex = lib.WHEEL_INK, fgHex = lib.WHEEL_RUBBER }
end

-- the rides spike's S: a Mipo's standing height (it took its first Mipo's, ~900). Random Mipos at scale 0.3
-- stand 445-923 (measured 2026-11-12, mipoHeight), mostly 650-920; at 600 (the props' size) they hung over
-- their vehicles and the skater fell off the deck
lib.S = 850

local function setMaterial(body, friction, restitution, density)
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            if friction then fixture:setFriction(friction) end
            if restitution then fixture:setRestitution(restitution) end
            if density then fixture:setDensity(density) end
        end
    end
    body:resetMassData()
end

-- A wheel under the frame at frame-local (wx, wy) on a wheel joint (a little suspension, as the
-- skateboard); returns its thing.
local function addWheel(frame, x, y, cx, cy, wx, wy, r)
    local wheel = objectManager.addThing('circle', { x = x + wx, y = y + wy, radius = r, label = 'wheel' })
    if not wheel then return nil end
    setMaterial(wheel.body, 1.2, 0.1, 1)
    dressWheel(wheel.body, r)
    joints.createJoint({
        body1 = frame.body,
        body2 = wheel.body,
        jointType = JT.WHEEL,
        id = uuid.generateID(),
        offsetA = { x = wx - cx, y = wy - cy },
        offsetB = { x = 0, y = 0 },
        axisX = 0,
        axisY = 1,
        springFrequency = 8,
        springDampingRatio = 0.7,
        collideConnected = false,
    })
    return wheel
end

lib.TYPES = {}

-- The four from the rides spike, in S (a Mipo's standing height): length, the sides' height (none: a
-- deck), thickness, wheel radius, how far below the floor's top the axles sit (in wheel radii), the
-- floor's share of the length (the banana's ends curl past it), where the wheels are (share of length).
-- Riding (src/vehicle-rides.lua): the seat's x (in S, for one going right), the rider's pose, top speed (S a
-- second), acceleration (of g), and the change of speed in a frame that throws the rider off (S a second).
lib.TYPES.kart = { len = 1.0, H = 0.2, T = 0.05, r = 0.1, drop = 0.2, floor = 1, wheels = 0.38,
    seat = -0.32, pose = 'legsOut', topSpeed = 6.5, accel = 0.7, crash = 2.6 } -- whizzy (Nikki 2026-11-09)
lib.TYPES.car = { len = 1.05, H = 0.32, T = 0.05, r = 0.13, drop = 0.1, floor = 1, wheels = 0.33,
    seat = -0.126, pose = 'carSeat', topSpeed = 2.6, accel = 0.3, crash = 1.6 }
lib.TYPES.banana = { len = 1.3, H = 0.26, T = 0.05, r = 0.1, drop = 0.3, floor = 0.8, wheels = 0.27,
    seat = -0.104, pose = 'carSeat', topSpeed = 3, accel = 0.35, crash = 1.6 }
lib.TYPES.skateboard = { len = 0.75, T = 0.045, r = 0.06, drop = 1.4, floor = 0.8, wheels = 0.3,
    seat = 0, pose = 'stand', topSpeed = 3.6, accel = 0.22, crash = 1.6 } -- gentle: a standing rider tips
lib.order = { 'kart', 'car', 'banana', 'skateboard' }

-- the frame: a tray (a floor and two low sides, one body), or a deck; its floor's top at y = 0
local function frameVertices(t, S)
    local hl, T = t.len * t.floor * S / 2, t.T * S
    if not t.H then return { -hl, 0, hl, 0, hl, T, -hl, T } end
    local H = t.H * S
    -- the outer top-left corner, down the inside, across the floor, up and out
    return { -hl, -H, -hl + T, -H, -hl + T, 0, hl - T, 0, hl - T, -H, hl, -H, hl, T, -hl, T }
end

local function build(t, label, x, y, size)
    local S = lib.S * size
    local verts = frameVertices(t, S)
    local cx, cy = mathutils.computeCentroid(verts)
    for i = 1, #verts, 2 do verts[i], verts[i + 1] = verts[i] - cx, verts[i + 1] - cy end
    local frame = objectManager.addThing('custom', { x = x + cx, y = y + cy, vertices = verts, label = label })
    if not frame then return nil end
    setMaterial(frame.body, 0.8, 0.1, 1)
    frame.body:setLinearDamping(0.15)
    local r, wx, wy = t.r * S, t.len * t.wheels * S, t.drop * t.r * S
    local parts = { frame = frame }
    parts.backWheel = addWheel(frame, x, y, cx, cy, -wx, wy, r)
    parts.frontWheel = addWheel(frame, x, y, cx, cy, wx, wy, r)
    return parts
end

-- Its shape in the frame's own coordinates (the frame's origin is its outline's centroid): S, length, the
-- floor's top (y), the sides' height, wheel radius, the seat's x for one going right; with its type's riding
-- numbers. For src/vehicle-rides.lua.
function lib.geometry(instance)
    local t = lib.TYPES[instance.settings.type] or lib.TYPES.kart
    local S = lib.S * (instance.settings.size or 1)
    local cx, cy = mathutils.computeCentroid(frameVertices(t, S))
    return { type = t, S = S, len = t.len * S, floorY = -cy, H = (t.H or 0) * S, r = t.r * S,
        axleY = t.drop * t.r * S - cy,
        seatX = t.seat * S - cx, pose = t.pose, topSpeed = t.topSpeed * S, accel = t.accel, crash = t.crash * S }
end

-- the kind (src/kinds.lua): settings { type = 'kart', size = 1 }
function lib.make(settings, x, y)
    settings.type = lib.TYPES[settings.type] and settings.type or 'kart'
    settings.size = settings.size or 1
    return build(lib.TYPES[settings.type], settings.type, x, y, settings.size)
end

function lib.label(instance) return instance.settings.type or 'vehicle' end

-- what it can do, as buttons in its panel (src/ui/kind-editor.lua): { label, run } (src/vehicle-rides.lua)
function lib.actions(instance)
    local rides = require('src.vehicle-rides')
    local list = {}
    if rides.riderOf(instance) then
        list[#list + 1] = { rides.isGoing(instance) and 'stop' or 'drive',
            function() rides.setGoing(instance, not rides.isGoing(instance)) end }
        list[#list + 1] = { 'turn round', function() rides.turnAround(instance) end }
        list[#list + 1] = { 'rider out', function() rides.riderOut(instance) end }
    else
        list[#list + 1] = { 'turn round', function() rides.turnAround(instance) end }
    end
    return list
end

-- its settings in the panel (src/ui/kind-editor.lua): a change makes it again (kinds.rebuild)
lib.rows = {
    { key = 'type', kind = 'choice', options = lib.order },
    { key = 'size', kind = 'number', min = 0.5, max = 2 },
}

-- another one of the same kind: any type, a size near the usual
function lib.roll()
    return { type = lib.order[love.math.random(#lib.order)], size = 0.8 + love.math.random() * 0.5 }
end

-- a part's own rows, live on its body or joint (kept with the bodies; a rebuild starts them over)
local function wheelJoint(thing)
    for _, joint in ipairs(thing.body:getJoints()) do
        if joint:getType() == 'wheel' then return joint end
    end
end

function lib.partRows(partName, thing)
    if partName == 'frame' then
        return { { label = 'drag', min = 0, max = 2,
            get = function() return thing.body:getLinearDamping() end,
            set = function(v) thing.body:setLinearDamping(v) end } }
    end
    local joint = wheelJoint(thing)
    local fixture = lib.solidFixture(thing.body)
    local rows = { { label = 'grip', min = 0, max = 2,
        get = function() return fixture:getFriction() end,
        set = function(v) fixture:setFriction(v) end } }
    if joint then
        rows[#rows + 1] = { label = 'suspension (Hz)', min = 1, max = 20,
            get = function() return joint:getSpringFrequency() end,
            set = function(v) joint:setSpringFrequency(v) end }
    end
    return rows
end
lib.anchor = 'frame' -- where a rebuilt vehicle stays (src/kinds.lua rebuild)

return lib
