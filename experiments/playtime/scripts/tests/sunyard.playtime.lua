-- sunyard: a yard for the engine's light in 3D — a wall standing on a floor, grass in front, the sky's day running
-- (docs/SKY.md, LIGHT-AND-SHADOW LS22). Everything here is engine: walls (src/walls.lua), the floor as a scene
-- setting (light 'full', src/scene-light.lua), the sky and its clock (src/scene-sky.lua, src/sky-light.lua); the
-- script only puts three Mipos on the grass. The wall's foot is where the floor starts (standY - depth), so the
-- 3D shadows run along the floor and up the wall, long in the morning and evening, short at noon.
-- Three lamps throw 3D shadows too (a point light's '3D shadows', LIGHT-AND-SHADOW LS33): a cool one close in front
-- (big shadows), a warm one, a pink one further out; at night they light the wall and floor round them.
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

-- the lamps: x, y, colour, how far in front of the things (made once, not saved: the script makes them)
local LAMPS = {
    { -700, 300, '7ab0ffff', 120, 'cool lamp' },
    { 450, 420, 'ffb060ff', 300, 'warm lamp' },
    { 1300, 250, 'ff7ac8ff', 700, 'pink lamp' },
}
local function makeLamps()
    for _, l in ipairs(LAMPS) do
        if not getObjectsByLabel(l[5])[1] then
            local thing = objectManager.addThing('circle', { x = l[1], y = l[2], radius = 30, bodyType = 'static',
                label = l[5] })
            for _, f in ipairs(thing.body:getFixtures()) do f:setSensor(true) end -- touches nothing
            local extra = fixtures.createSFixture(thing.body, 0, 0, 'light', { radius = 10 }):getUserData().extra
            extra.lightType, extra.colorHex, extra.intensity, extra.range = 'point', l[3], 1.2, 900
            extra.shadows3D, extra.inFront = true, l[4]
        end
    end
end

function s.onStart()
    worldState.paused = false
    makeLamps()
    if #mipoKit.alive(check().mipos) == 0 then newMipos() end
end

function s.onKeyPress(key)
    if key == 'r' then newMipos() end
end

return s
