-- hands-mess: Mipos holding hands in a big knot (saved paused from the vanilla scene, 2026-11-01,
-- after the untangle gives up on a Mipo that keeps re-hooking): hands, arms and feet through each other.
-- The floor is the vanilla scene's, made here (a script's body isn't saved with the scene).
-- keys: p: pause

local s = {}

local GROUND_Y = 900

function s.onStart()
    state.handsMess = state.handsMess or {}
    local f = state.handsMess
    if not (f.ground and not f.ground:isDestroyed()) then
        f.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
        love.physics.newFixture(f.ground, love.physics.newRectangleShape(3000, 100)):setFriction(0.9)
    end
end

function s.onUnload()
    local f = state.handsMess
    if f and f.ground and not f.ground:isDestroyed() then f.ground:destroy() end
    if f then f.ground = nil end
end

function s.onKeyPress(key)
    if key == 'p' then worldState.paused = not worldState.paused end
end

return s
