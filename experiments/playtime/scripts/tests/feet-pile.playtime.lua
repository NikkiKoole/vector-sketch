-- feet-pile: Mipos standing on each other's feet (saved from the vanilla scene, 2026-11-01):
-- feet that pass through another Mipo's feet, then catch, then hop now and then.
-- The floor is the vanilla scene's, made here (a script's body isn't saved with the scene).
-- keys: p: pause

local s = {}

local GROUND_Y = 900

function s.onStart()
    state.feetPile = state.feetPile or {}
    local f = state.feetPile
    if not (f.ground and not f.ground:isDestroyed()) then
        f.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
        love.physics.newFixture(f.ground, love.physics.newRectangleShape(3000, 100)):setFriction(0.9)
    end
end

function s.onUnload()
    local f = state.feetPile
    if f and f.ground and not f.ground:isDestroyed() then f.ground:destroy() end
    if f then f.ground = nil end
end

function s.onKeyPress(key)
    if key == 'p' then worldState.paused = not worldState.paused end
end

return s
