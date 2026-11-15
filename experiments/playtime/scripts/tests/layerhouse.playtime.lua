-- layerhouse: depth layers in the engine — a house you walk in front of, its roof to stand on, a porch railing over you
-- (docs/DEPTH-LAYERS.md DL1, src/depth-layers.lua). Every body's layer is a body setting (the body panel's
-- 'layer'): back (dark grey here) is passed in front of and stood on from above, front (light) is drawn over
-- the Mipos and touches nothing that moves, play is solid. Drag a Mipo through the wall, drop one on the roof,
-- walk it behind the railing; the crate (a toy) does the same. The house is made by this script, not saved.
-- keys: r: three new Mipos

local s = {}

local GROUND_TOP = 904

local function check()
    state.layerHouse = state.layerHouse or { mipos = {} }
    return state.layerHouse
end

-- a rectangle by its left, top, width, height; static unless loose; its layer (nil: play)
local function block(label, x, y, w, h, layer, loose)
    if getObjectsByLabel(label)[1] then return end
    local thing = objectManager.addThing('rectangle', { x = x + w / 2, y = y + h / 2, width = w, height = h,
        bodyType = loose and 'dynamic' or 'static', label = label, layer = layer })
    return thing
end

local function makeHouse()
    local top = GROUND_TOP
    -- the house: walls and roof in the back layer (their tops stood on), a step and a porch floor to play on
    block('house wall', -900, top - 700, 1100, 700, 'back')
    block('house roof', -1000, top - 820, 1300, 120, 'back')
    block('chimney', 0, top - 1050, 110, 230, 'back')
    block('porch floor', 250, top - 90, 700, 90, nil)
    -- the porch, in front: a pillar and a railing over the Mipos
    block('porch pillar', 880, top - 700, 60, 610, 'front')
    block('porch railing', 300, top - 330, 580, 40, 'front')
    block('porch roof', 220, top - 760, 780, 60, 'front')
    -- a loose crate: a toy, in play
    block('crate', 1300, top - 300, 200, 200, nil, true)
end

local function newMipos()
    local c = check()
    for _, inst in ipairs(c.mipos) do
        if mipoKit.isAlive(inst) then characterManager.removeCharacter(inst) end
    end
    c.mipos = {}
    for _, x in ipairs({ -1400, -400, 600 }) do mipoKit.spawn(c.mipos, x, GROUND_TOP - 500) end
end

function s.onStart()
    worldState.paused = false
    makeHouse()
    if #mipoKit.alive(check().mipos) == 0 then newMipos() end
end

function s.onKeyPress(key)
    if key == 'r' then newMipos() end
end

return s
