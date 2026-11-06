-- torso-jiggle.lua
-- Jiggle (creation.torsoJiggle): the torso picture as soft flesh, drawn only. Springy
-- points ride torso1 (no bodies, no joints) where src/torso-lobes.lua would put its lobes
-- (on a potato head, the far end is the face). Each lags when the torso speeds up, slows
-- down or turns, and swings back; the picture's grid (spineSkin.drawGrid) and the face
-- (spineSkin.transformAt) move with them. The narrower end takes headJiggle of the swing.
-- Physics doesn't change at all.
local mipoRegistry = require('src.mipo-registry')
local torsoLobes = require('src.torso-lobes')

local lib = {}

lib.columns = 8
lib.rows = 12
lib.maxOffset = 0.3 -- the most a point moves, in its radii

lib.defaults = { jiggleAmount = 0.4, jiggleSpring = 3, jiggleDamping = 0.15, headJiggle = 0.25 }

local function setting(creation, name)
    return creation[name] or lib.defaults[name]
end

function lib.enabled(creation)
    if not (creation and creation.torsoJiggle) then return false end
    if torsoLobes.enabled(creation) then return false end -- physical lobes come first
    return not (creation.torsoSpine and (creation.torsoSegments or 1) > 1)
end

-- [instance] = { key, points = { { x, y, r, gain, ox, oy, vx, vy, lastVX, lastVY } } }
local states = setmetatable({}, { __mode = 'k' })

local function pointsFor(instance)
    local creation = instance.dna.creation
    local part = instance.dna.parts.torso1
    local scale = instance.scale or 1
    local key = table.concat({ part.shape8URL or '', part.dims.sx or 1, part.dims.sy or 1, scale,
        creation.lobeDepth or 0.35 }, ',')
    local s = states[instance]
    if s and s.key == key then return s end
    local layout = torsoLobes.layout(part, creation, scale)
    if not layout then return nil end
    -- the same soft points the lobes would be; the wider end's swing fully, the other end's
    -- by headJiggle (gain nil)
    local points = {}
    for i, lobe in ipairs(layout.lobes) do
        points[i] = { x = lobe.x, y = lobe.y, r = lobe.r, gain = lobe.main and 1 or nil }
    end
    for _, p in ipairs(points) do p.ox, p.oy, p.vx, p.vy = 0, 0, 0, 0 end
    s = { key = key, points = points }
    states[instance] = s
    return s
end

-- Each point a damped spring in torso1's frame, pushed by the opposite of what the torso
-- does at that point: its acceleration there this frame, turned into torso1's frame. The
-- spring is stepped in small steps (a stiff one at 1/60 would blow up).
local SUBSTEP = 1 / 240
local function step(instance, body, dt)
    local s = pointsFor(instance)
    if not s then return end
    local creation = instance.dna.creation
    local w = 2 * math.pi * setting(creation, 'jiggleSpring')
    local k, c = w * w, 2 * setting(creation, 'jiggleDamping') * w
    local amount = setting(creation, 'jiggleAmount')
    local angle = body:getAngle()
    local cos, sin = math.cos(-angle), math.sin(-angle)
    local n = math.max(1, math.ceil(dt / SUBSTEP))
    local h = dt / n
    for _, p in ipairs(s.points) do
        local wx, wy = body:getWorldPoint(p.x, p.y)
        local vx, vy = body:getLinearVelocityFromWorldPoint(wx, wy)
        if p.lastVX then
            local ax, ay = (vx - p.lastVX) / dt, (vy - p.lastVY) / dt
            local gain = amount * (p.gain or setting(creation, 'headJiggle'))
            local fx, fy = -gain * (ax * cos - ay * sin), -gain * (ax * sin + ay * cos)
            for _ = 1, n do
                p.vx = p.vx + (fx - k * p.ox - c * p.vx) * h
                p.vy = p.vy + (fy - k * p.oy - c * p.vy) * h
                p.ox, p.oy = p.ox + p.vx * h, p.oy + p.vy * h
            end
            local limit = lib.maxOffset * p.r
            local d = math.sqrt(p.ox * p.ox + p.oy * p.oy)
            if d > limit then
                p.ox, p.oy = p.ox / d * limit, p.oy / d * limit
                p.vx, p.vy = p.vx * 0.5, p.vy * 0.5
            end
        end
        p.lastVX, p.lastVY = vx, vy
    end
end

-- Once a frame, after the physics (main.lua love.update).
function lib.update(dt)
    if dt <= 0 then return end
    for _, instance in pairs(mipoRegistry.getAll()) do
        if lib.enabled(instance.dna and instance.dna.creation) then
            local part = instance.parts.torso1
            if part and part.body and not part.body:isDestroyed() then step(instance, part.body, dt) end
        end
    end
end

local function deform(points, bones, out)
    return torsoLobes.pushPoints(points, bones.points, out)
end

local bonesCache = setmetatable({}, { __mode = 'k' })
function lib.bonesOf(body)
    local instance, partName = mipoRegistry.getFromBody(body)
    if partName ~= 'torso1' or not lib.enabled(instance.dna and instance.dna.creation) then return nil end
    local s = pointsFor(instance)
    if not s then return nil end
    local bones = bonesCache[instance] or { deform = deform, cols = lib.columns, rows = lib.rows }
    bonesCache[instance] = bones
    bones.points = s.points
    return bones
end

return lib
