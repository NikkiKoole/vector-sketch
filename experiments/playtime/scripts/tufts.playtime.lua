-- tufts: a spike for hair as real physics (src/hair-tufts.lua): a few tufts on top of each
-- Mipo's head, short chains of small Box2D bodies soft-welded like the ears. The panel (play
-- mode, tab) sets how many, how long, how springy. Throw the Mipos around and watch them.
-- keys: r: make the tufts again   h: hide/show the panel

local s = {}
local opts = {}
local showPanel = true

local function attachAll()
    for _, instance in pairs(state.mipoInstances) do hairTufts.attach(instance, opts) end
end

function s.onStart()
    worldState.paused = false
    for k, v in pairs(hairTufts.defaults) do opts[k] = v end
    attachAll()
end

function s.onUnload()
    for _, instance in pairs(state.mipoInstances) do hairTufts.remove(instance) end
end

function s.onKeyPress(key)
    if key == 'r' then attachAll() end
    if key == 'h' then showPanel = not showPanel end
end

function s.draw()
    hairTufts.draw() -- over the Mipos' faces (and everything else, for now)
end

local SLIDERS = {
    { key = 'count', min = 1, max = 9, step = 1 },
    { key = 'segments', min = 1, max = 5, step = 1 },
    { key = 'length', min = 20, max = 250 },
    { key = 'width', min = 6, max = 60 },
    { key = 'spread', min = 0, max = 3 },
    { key = 'lean', min = 0, max = 1.5 },
    { key = 'frequency', min = 0.5, max = 10 },
    { key = 'dampingRatio', min = 0, max = 1.5 },
    { key = 'density', min = 0.02, max = 1 },
    { key = 'drawWidth', min = 0.05, max = 0.6 },
    { key = 'texture', min = 1, max = 11, step = 1 },
}

-- A slider moved: make the tufts again once it's let go (not every frame of the drag:
-- each remake destroys and creates bodies).
local pending = false

function s.drawUI()
    if not (state.playMode and showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 8, 380
    local h = BH * (#SLIDERS + 1) + pad * (#SLIDERS + 2) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• tufts ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, sl in ipairs(SLIDERS) do
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('tufts' .. sl.key, x, y, 160, sl.min, sl.max, opts[sl.key], nil, sl.step)
            if v and v ~= opts[sl.key] then
                if sl.step then v = math.floor(v + 0.5) end
                opts[sl.key] = v
                pending = true
            end
            ui.label(x + 260, y, sl.key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'make them again (r)') then pending = true end
    end)
    if pending and not love.mouse.isDown(1) and #love.touch.getTouches() == 0 then
        pending = false
        attachAll()
    end
end

return s
