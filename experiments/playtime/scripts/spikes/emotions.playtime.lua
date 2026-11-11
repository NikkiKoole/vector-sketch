-- emotions: Mipos showing how they feel with their faces: brows, mouth, eyes, pupils, a blush (src/mipo-emotion.lua)
-- (docs/EMOTIONS.md; Nikki 2026-11-11 "could we experiment a system where mipos show emotion with their faces").
-- The panel: a feeling for every Mipo or only the one you last touched, how strongly, mixed into what it
-- feels already or instead of it. Keys: e every Mipo a random feeling, n all neutral, h the panel.
local s = {}

local GROUND_Y = 600
local MIPO_SCALE = 0.6 -- bigger than the spikes' 0.3: faces to read

local function st()
    state.emotions = state.emotions or { amount = 1, all = true, mix = false, showPanel = true }
    return state.emotions
end

local function mipos()
    local list = {}
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then list[#list + 1] = inst end
    end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return list
end

local function ensureGround()
    if getObjectsByLabel('ground')[1] then return end
    local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 300, width = 6000, height = 600,
        bodyType = 'static', label = 'ground' })
    if not thing then return end
    local tile = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    tile.main = tile.main or {}
    tile.main.bgURL, tile.opacity, tile.tileWidthM, tile.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
end

local function ensureMipos()
    if #mipos() > 0 then return end
    for i = 1, 4 do
        local inst = characterManager.createCharacter('humanoid', -1050 + (i - 1) * 700, GROUND_Y - 700, MIPO_SCALE)
        if inst then characterManager.randomizeMipoConstrained(inst) end
    end
end

-- the Mipos a button acts on: all, or the one last touched
local function targets()
    local c = st()
    if c.all then return mipos() end
    local picked = c.picked and mipoRegistry.getAll()[c.picked]
    return picked and mipoKit.isAlive(picked) and { picked } or {}
end

local function feel(name)
    local c = st()
    for _, inst in ipairs(targets()) do mipoEmotion.set(inst, name, c.amount, nil, c.mix) end
end

function s.onStart()
    worldState.paused = false
    st()
    ensureGround()
    ensureMipos()
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'n' then for _, inst in ipairs(mipos()) do mipoEmotion.clear(inst) end end
    if key == 'e' then
        for _, inst in ipairs(mipos()) do
            mipoEmotion.set(inst, mipoEmotion.NAMES[love.math.random(#mipoEmotion.NAMES)], c.amount)
        end
    end
end

-- the Mipo nearest a press on the stage (not on a panel) becomes the picked one
local wasDown = false
local function pick()
    local down = love.mouse.isDown(1)
    if down and not wasDown and not ui.overPanel then
        local wx, wy = cam:getWorldCoordinates(love.mouse.getPosition())
        local best, bestD = nil, 600 * 600
        for _, inst in ipairs(mipos()) do
            local x, y = inst.parts.torso1.body:getPosition()
            local d = (x - wx) ^ 2 + (y - wy) ^ 2
            if d < bestD then best, bestD = inst, d end
        end
        if best then st().picked = best.id end
    end
    wasDown = down
end

function s.update(dt)
    pick()
    mipoEmotion.update(dt)
end

-- the panel, bottom right: a button per feeling, neutral, how strongly, all or the picked one, mix
local PANEL = { w = 330, row = 34, pad = 6 }
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local buttons = { 'neutral' }
    for _, name in ipairs(mipoEmotion.NAMES) do buttons[#buttons + 1] = name end
    local rows = math.ceil(#buttons / 2) + 4
    local w, h = PANEL.w, PANEL.row * rows + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    local half = (w - PANEL.pad * 3) / 2
    ui.panel(x0, y0, w, h, '•• feelings ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        for i = 1, #buttons, 2 do
            local x, y = row()
            for k = 0, 1 do
                local name = buttons[i + k]
                if name and ui.button(x + k * (half + PANEL.pad), y, half, name, PANEL.row - 6) then feel(name) end
            end
        end
        local x, y = row()
        ui.label(x, y + 4, 'amount')
        local v = ui.sliderWithInput('emotion-amount', x + 80, y - 2, 120, 0, 1, c.amount, nil, 0.05)
        if v then c.amount = v + 0 end
        x, y = row()
        local ac, av = ui.checkbox(x, y, c.all, 'every Mipo')
        if ac then c.all = av end
        local mc, mv = ui.checkbox(x + half + PANEL.pad, y, c.mix, 'mix in')
        if mc then c.mix = mv end
        x, y = row()
        local picked = c.picked and mipoRegistry.getAll()[c.picked]
        local now = {}
        for name, wgt in pairs(picked and mipoEmotion.feelings(picked) or {}) do
            now[#now + 1] = string.format('%s %.1f', name, wgt)
        end
        ui.label(x, y + 4, picked and ('picked: ' .. (#now > 0 and table.concat(now, ', ') or 'neutral'))
            or 'touch a Mipo to pick it')
        x, y = row()
        ui.label(x, y + 4, 'e random  n neutral  h panel')
    end)
end

return s
