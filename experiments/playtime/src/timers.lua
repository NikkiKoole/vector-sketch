-- Timers and tweens for the scene: "do this later" and "move this smoothly".
-- hump.timer (vendor/hump-timer.lua) underneath:
--   timers.after(0.5, function() ... end)                 once, later
--   timers.every(3, blink)                                 again and again (return false to stop)
--   timers.tween(0.3, head, {angle = 0.4}, 'out-back')     a value eased to a target
--   timers.script(function(wait) squeak() wait(0.4) look() end)   a little play, step by step
-- Each returns a handle for timers.cancel(handle).
-- It runs with the physics: paused world, paused timers; the world's speed slider speeds them up.
-- A scene load clears it, so a script's waits never outlive its bodies.
local lib = {}
local state = require('src.state')
local Timer = require('vendor.hump-timer')

-- Kept on state (not a module local) so a lurker hot-reload of this file keeps the
-- timers that are running.
state.sceneTimer = state.sceneTimer or Timer.new()

function lib.after(delay, func) return state.sceneTimer:after(delay, func) end
function lib.every(delay, func, count) return state.sceneTimer:every(delay, func, count) end
function lib.during(delay, func, after) return state.sceneTimer:during(delay, func, after) end
function lib.tween(duration, subject, target, method, after, ...)
    return state.sceneTimer:tween(duration, subject, target, method, after, ...)
end
function lib.script(func) return state.sceneTimer:script(func) end
function lib.cancel(handle) state.sceneTimer:cancel(handle) end
function lib.clear() state.sceneTimer:clear() end
function lib.update(dt) state.sceneTimer:update(dt) end

return lib
