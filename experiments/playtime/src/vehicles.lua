-- src/vehicles.lua: vehicles as a kind (docs/KINDS.md KD4), out of the rides spike (scripts/spikes/rides,
-- docs/RIDES.md): a frame and two wheels on wheel joints, made of ordinary things, so they select, save,
-- copy and dissolve like anything else. KD4a: the kart, rolling when pushed. Driving, getting in and
-- the other types (car, skateboard, banana car) come in KD4c / KD4d.
local lib = {}

local objectManager = require('src.object-manager')
local joints = require('src.joints')
local JT = require('src.joint-types')
local uuid = require('src.uuid')
local mathutils = require('src.math-utils')

-- a Mipo's standing height at scale 0.3 (src/props.lua's sizes): the rides spike's S
lib.S = 600

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

-- The kart (the spike's): a low tray, sides a hand high, small fat wheels near its ends. Sizes in S.
lib.TYPES.kart = function(x, y, size)
    local S = lib.S * size
    local len, H, T, r = S * 1.0, S * 0.2, S * 0.05, S * 0.1
    local hl = len / 2
    -- the tray, one body: the outer top-left corner, down the inside, across the floor, up and out
    local verts = { -hl, -H, -hl + T, -H, -hl + T, 0, hl - T, 0, hl - T, -H, hl, -H, hl, T, -hl, T }
    local cx, cy = mathutils.computeCentroid(verts)
    for i = 1, #verts, 2 do verts[i], verts[i + 1] = verts[i] - cx, verts[i + 1] - cy end
    local frame = objectManager.addThing('custom', { x = x + cx, y = y + cy, vertices = verts, label = 'kart' })
    if not frame then return nil end
    setMaterial(frame.body, 0.8, 0.1, 1)
    frame.body:setLinearDamping(0.15)
    local parts = { frame = frame }
    parts.backWheel = addWheel(frame, x, y, cx, cy, -len * 0.38, T + r * 0.6, r)
    parts.frontWheel = addWheel(frame, x, y, cx, cy, len * 0.38, T + r * 0.6, r)
    return parts
end

lib.order = { 'kart' }

-- the kind (src/kinds.lua): settings { type = 'kart', size = 1 }
function lib.make(settings, x, y)
    settings.type = lib.TYPES[settings.type] and settings.type or 'kart'
    settings.size = settings.size or 1
    return lib.TYPES[settings.type](x, y, settings.size)
end

function lib.label(instance) return instance.settings.type or 'vehicle' end

return lib
