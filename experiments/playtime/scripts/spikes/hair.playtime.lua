-- hair: a spike for long hair that swings (src/hair-locks.lua; parked, docs/HAIR-LOCKS.md). One
-- Mipo with locks of hair on its head; the panel (play mode, tab) sets how many, how long, how
-- stiff, how curly, how wild. Throw the Mipo around and watch them.
-- Its torso has hair all around too, shorter (bodyHair: its length against the head's, 0 = none),
-- or fur (fur: how thick, 0 = the body hair; furLength: px): many short locks standing out a bit.
-- A box beside it wears the same hair: pick it up and swing it, or let it rest (its hair sleeps).
-- keys: r: lay the locks out again   h: hide/show the panel   m: a new random Mipo

local s = {}
local opts = {}
local showPanel = true

-- The box with hair: the one in the scene (by its label), else a new one beside the Mipo.
local function hairBox()
    local found = getObjectsByLabel('hair-box')[1]
    if found and found.body and not found.body:isDestroyed() then return found.body end
    local x, y = 0, 0
    for _, instance in pairs(state.mipoInstances) do
        local head = instance.parts and instance.parts.head
        if head and head.body and not head.body:isDestroyed() then x, y = head.body:getPosition() end
    end
    local thing = objectManager.addThing('rectangle', { x = x - 500, y = y, width = 220, height = 150,
        label = 'hair-box' })
    return thing and thing.body
end

-- The torso's hair: roots all around its outline, no bangs, all behind, `bodyHair` times as long.
local function bodyOpts()
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    local fur = opts.fur or 0
    if fur > 0 then -- many short locks, roots almost on the outline, standing out a bit
        o.count = math.floor(40 + 140 * fur + 0.5)
        o.points, o.segment = 3, (opts.furLength or 20) / 2
        o.inset, o.stand, o.droop = 0.97, math.max(opts.stand or 0, 0.6), 0.2
        o.curly, o.ringlets, o.cut, o.lenMiddle, o.lenSides = 0, 0, 0, 1, 1
        o.width = math.min(opts.width or 0.06, 0.04)
        o.spread = 2 * math.pi * (1 - 1 / o.count)
        o.bangs, o.frontLocks = 0, 0
        return o
    end
    local f = opts.bodyHair or 0.5
    o.points = math.max(2, math.floor((opts.points or hairLocks.defaults.points) * f + 0.5))
    o.cut = (opts.cut or 0) * f
    o.spread = 2 * math.pi * (1 - 1 / 24) -- all the way round, the two ends not on one spot
    o.count = 24
    o.bangs, o.frontLocks = 0, 0
    return o
end

local function attachAll()
    for _, instance in pairs(state.mipoInstances) do
        hairLocks.attach(instance, opts)
        local torso = instance.parts and instance.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed()
                and ((opts.bodyHair or 0.5) > 0 or (opts.fur or 0) > 0) then
            local holder = hairLocks.attachBody(torso.body, bodyOpts(), instance)
            holder.dna = instance.dna -- the Mipo's hair colours
        else
            hairLocks.detachBody(instance)
        end
    end
    local box = hairBox()
    if box then hairLocks.attachBody(box, opts, 'box') end
end

function s.onStart()
    worldState.paused = false
    for k, v in pairs(hairLocks.defaults) do opts[k] = v end
    opts.bodyHair = 0.5
    opts.fur, opts.furLength = 0, 20
    attachAll()
end

function s.onUnload()
    for _, instance in pairs(state.mipoInstances) do instance.hairLocks = nil end
    hairLocks.detachBodies()
end

-- A new random Mipo (its bodies are made again, so its hair goes back on after), in its own hair
-- colours.
local function randomizeMipos()
    for _, instance in pairs(state.mipoInstances) do characterManager.randomizeMipoConstrained(instance) end
    attachAll()
end

function s.onKeyPress(key)
    if key == 'r' then attachAll() end
    if key == 'm' then randomizeMipos() end
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
    { key = 'curly', min = 0, max = 1 },
    { key = 'stand', min = 0, max = 1 },
    { key = 'ringlets', min = 0, max = 30 },
    { key = 'ringletPitch', min = 8, max = 60 },
    { key = 'springy', min = 0, max = 1 },
    { key = 'cut', min = 0, max = 500 },
    { key = 'lenMiddle', min = 0.2, max = 2 },
    { key = 'lenSides', min = 0.2, max = 2 },
    { key = 'part', min = -1, max = 1 },
    { key = 'bodyHair', min = 0, max = 1 },
    { key = 'fur', min = 0, max = 1 },
    { key = 'furLength', min = 4, max = 60 },
    { key = 'wild', min = 0, max = 1 },
    { key = 'damping', min = 0.8, max = 1 },
    { key = 'weight', min = 0, max = 8 },
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
    local BH, pad, colW = 32, 2, 390 -- two columns of sliders
    local rows = math.ceil(#SLIDERS / 2) + 1
    local w, h = colW * 2 + pad, (BH + pad) * rows + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• hair ••', function()
        local changed = false
        for k, sl in ipairs(SLIDERS) do
            local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
            local x, y = x0 + pad + col * colW, y0 + 24 + row * (BH + pad)
            local v = ui.sliderWithInput('hair' .. sl.key, x, y, 160, sl.min, sl.max,
                opts[sl.key] or hairLocks.defaults[sl.key] or 0, nil, sl.step)
            if v and v ~= opts[sl.key] then
                if sl.step then v = math.floor(v + 0.5) end
                opts[sl.key] = v
                changed = true
            end
            ui.label(x + 260, y, sl.key)
        end
        local by, bw = y0 + 24 + (rows - 1) * (BH + pad), (w - 3 * pad - 20) / 2
        if ui.button(x0 + pad, by, bw, 'new random locks') then
            opts.seed = (opts.seed or 1) + 1
            changed = true
        end
        if ui.button(x0 + 2 * pad + bw, by, bw, 'random Mipo (m)') then randomizeMipos() end
        if changed then attachAll() end
    end)
end

return s
