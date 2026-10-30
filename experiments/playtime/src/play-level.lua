-- play-level.lua
-- What counts as play for the background music (music.bump; the band joins at music.bandJoins and
-- the level halves every music.activityHalfLife seconds). Impacts, squeaks and snaps bump it where
-- they happen (src/mipo-voice.lua, src/snap-sound.lua); this ticks what the pointer does: holding
-- something counts a little, dragging it counts more the faster it moves, letting go counts by how
-- hard it was thrown. Speeds are at 100 px per metre (src/physics-units.lua). Ticked by src/sound.lua.

local music = require('src.music')
local units = require('src.physics-units')
local pointerJoints = require('src.physics.box2d-pointerjoints')
local mathutils = require('src.math-utils')
local state = require('src.state')

local lib = {}

lib.hold = 0.3        -- per second while something is held (held still settles just under the band)
lib.drag = 1.2        -- more per second at dragSpeed
lib.dragSpeed = 1000  -- px/s at 100 px/m
lib.throw = 2         -- on letting go at throwSpeed or faster
lib.throwSpeed = 2000

-- On `state` so a hot reload doesn't count every held body as thrown
state.playLevel = state.playLevel or { held = {} }
local S = state.playLevel

local function speedOf(body)
    local vx, vy = body:getLinearVelocity()
    return units.toReferenceSpeed(math.sqrt(vx * vx + vy * vy))
end

function lib.update(dt)
    local held = {}
    for _, body in ipairs(pointerJoints.getInteractedWithPointer()) do
        local speed = speedOf(body)
        held[body] = speed
        music.bump(dt * (lib.hold + lib.drag * mathutils.clamp(speed / lib.dragSpeed, 0, 1)))
    end
    for body, speed in pairs(S.held) do
        if not held[body] then
            -- the speed as it left the hand (the last frame it was held): a throw
            music.bump(lib.throw * mathutils.clamp(speed / lib.throwSpeed, 0, 1))
        end
    end
    S.held = held
end

return lib
