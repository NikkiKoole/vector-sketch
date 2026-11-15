-- sunyard: a yard for the engine's light in 3D — a wall standing on a floor, grass in front, the sky's day running
-- (docs/SKY.md, LIGHT-AND-SHADOW LS22). Everything here is engine: walls (src/walls.lua), the floor as a scene
-- setting (light 'full', src/scene-light.lua), the sky and its clock (src/scene-sky.lua, src/sky-light.lua); the
-- script only puts three Mipos on the grass. The wall's foot is where the floor starts (standY - depth), so the
-- 3D shadows run along the floor and up the wall, long in the morning and evening, short at noon.
-- keys: r: three new Mipos

local s = {}

local STAND_Y = 904 -- the grass's top: where the Mipos stand (the scene's light floor standY)
local XS = { -900, 0, 900 }

local function check() -- on state: a script hot reload keeps the Mipos
    state.sunyard = state.sunyard or { mipos = {} }
    return state.sunyard
end

local function removeMipos()
    local c = check()
    for _, inst in ipairs(c.mipos) do
        if mipoKit.isAlive(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos = {}
end

local function newMipos()
    removeMipos()
    local c = check()
    for _, x in ipairs(XS) do mipoKit.spawn(c.mipos, x, STAND_Y - 500) end
end

function s.onStart()
    worldState.paused = false
    if #mipoKit.alive(check().mipos) == 0 then newMipos() end
end

function s.onKeyPress(key)
    if key == 'r' then newMipos() end
end

return s
