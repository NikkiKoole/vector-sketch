-- hair: a spike for long hair that swings (src/hair-locks.lua; parked, docs/HAIR-LOCKS.md). One
-- Mipo with locks of hair on its head; the panel (play mode, tab) sets how many, how long, how
-- stiff, how curly, how wild. Throw the Mipo around and watch them.
-- keys: r: lay the locks out again   h: hide/show the panel

local s = {}
local opts = {}
local showPanel = true

local function attachAll()
    for _, instance in pairs(state.mipoInstances) do hairLocks.attach(instance, opts) end
end

function s.onStart()
    worldState.paused = false
    for k, v in pairs(hairLocks.defaults) do opts[k] = v end
    attachAll()
end

function s.onUnload()
    for _, instance in pairs(state.mipoInstances) do instance.hairLocks = nil end
end

function s.onKeyPress(key)
    if key == 'r' then attachAll() end
    if key == 'h' then showPanel = not showPanel end
end

function s.update(dt)
    hairLocks.update(dt)
end

function s.drawBelow()
    hairLocks.draw('back') -- behind the Mipos (and everything else, for now)
end

function s.draw()
    hairLocks.draw('front') -- bangs and front locks, over the faces
end

local SLIDERS = {
    { key = 'count', min = 1, max = 40, step = 1 },
    { key = 'points', min = 3, max = 16, step = 1 },
    { key = 'segment', min = 6, max = 60 },
    { key = 'stiffness', min = 0, max = 1 },
    { key = 'droop', min = 0, max = 1.5 },
    { key = 'curl', min = -1, max = 1 },
    { key = 'wild', min = 0, max = 1 },
    { key = 'damping', min = 0.8, max = 1 },
    { key = 'width', min = 0.05, max = 0.6 },
    { key = 'spread', min = 0.3, max = 6.2 },
    { key = 'texture', min = 1, max = 11, step = 1 },
    { key = 'frontLocks', min = 0, max = 10, step = 1 },
    { key = 'bangs', min = 0, max = 15, step = 1 },
    { key = 'bangPoints', min = 2, max = 8, step = 1 },
    { key = 'bangSegment', min = 6, max = 40 },
    { key = 'bangSpread', min = 0.2, max = 3 },
}

function s.drawUI()
    if not (state.playMode and showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 34, 8, 380
    local h = BH * (#SLIDERS + 1) + pad * (#SLIDERS + 2) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• hair ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local changed = false
        for _, sl in ipairs(SLIDERS) do
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('hair' .. sl.key, x, y, 160, sl.min, sl.max, opts[sl.key], nil, sl.step)
            if v and v ~= opts[sl.key] then
                if sl.step then v = math.floor(v + 0.5) end
                opts[sl.key] = v
                changed = true
            end
            ui.label(x + 260, y, sl.key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'new random locks') then
            opts.seed = (opts.seed or 1) + 1
            changed = true
        end
        if changed then attachAll() end
    end)
end

return s
