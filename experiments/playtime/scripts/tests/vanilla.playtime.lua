-- vanilla: one plain Mipo, the humanoid template as it is (not randomized), on a floor, to
-- tweak by hand in the Mipo editor and see what a Mipo is before any breed narrows it.
-- keys: n: a fresh plain Mipo (the old one goes)   p: pause

local s = {}

local GROUND_Y = 900

local function lab() -- on state: a script hot reload keeps the Mipo
    state.vanilla = state.vanilla or {}
    return state.vanilla
end

local function alive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

local function freshMipo()
    local v = lab()
    if alive(v.mipo) then characterManager.removeCharacter(v.mipo) end
    v.mipo = characterManager.createCharacter('humanoid', 0, GROUND_Y - 500, 0.3)
end

function s.onStart()
    worldState.paused = false
    local v = lab()
    if not (v.ground and not v.ground:isDestroyed()) then
        v.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
        love.physics.newFixture(v.ground, love.physics.newRectangleShape(3000, 100)):setFriction(0.9)
    end
    if not alive(v.mipo) then freshMipo() end
    cam:setScale(0.9)
    cam:setTranslation(0, GROUND_Y - 300)
end

function s.onUnload()
    local v = state.vanilla
    if v and v.ground and not v.ground:isDestroyed() then v.ground:destroy() end
    if v then v.ground = nil end
end

function s.onKeyPress(key)
    if key == 'n' then freshMipo() end
    if key == 'p' then worldState.paused = not worldState.paused end
end

return s
