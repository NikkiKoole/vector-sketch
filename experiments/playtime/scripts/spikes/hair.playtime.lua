-- hair: a spike for long hair that swings (src/hair-locks.lua; docs/HAIR-LOCKS.md). One Mipo with
-- hair; the panel (play mode, tab) in sections, each switched on or off on its left and opened to
-- show its sliders: head hair, bangs, haircut, curls, body hair (round the torso's edge), fur
-- (many short locks standing out round it, instead of the body hair), coat (strands over the face
-- and body, like chest hair), physics. Throw the Mipo around and watch them.
-- A box beside it wears the same head hair: pick it up and swing it, or let it rest (its hair sleeps).
-- keys: r: lay the locks out again   h: hide/show the panel   m: a new random Mipo

local s = {}
local opts = {}
local showPanel = true
local openSection = 'head hair'

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

local function copyOpts()
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    return o
end

-- The coat's strands for a body (its share: the face gets fewer than the body).
local function coat(o, share)
    o.surface = opts.coatOn and math.floor((opts.coat or 0.5) * share + 0.5) or 0
    o.surfaceLength = opts.coatLength or 22
    o.surfaceCurly = opts.coatCurly or 0
end

-- The torso's hair: fur (many short locks standing out, roots almost on the outline), or the body
-- hair (24 locks round its outline, `bodyHair` times the head's length), or neither (only a coat).
local function bodyOpts()
    local o = copyOpts()
    o.bangs, o.frontLocks = 0, 0
    coat(o, 400)
    if opts.furOn then
        local fur = opts.fur or 0.5
        o.count = math.floor(40 + 140 * fur + 0.5)
        o.points, o.segment = 3, (opts.furLength or 20) / 2
        o.inset, o.stand, o.droop = 0.97, math.max(opts.stand or 0, 0.6), 0.2
        o.curly, o.ringlets, o.cut, o.lenMiddle, o.lenSides = 0, 0, 0, 1, 1
        o.width = math.min(opts.width or 0.06, 0.04)
        o.spread = 2 * math.pi * (1 - 1 / o.count)
    elseif opts.bodyOn then
        local f = opts.bodyHair or 0.5
        o.points = math.max(2, math.floor((opts.points or hairLocks.defaults.points) * f + 0.5))
        o.cut = (opts.cut or 0) * f
        o.spread = 2 * math.pi * (1 - 1 / 24) -- all the way round, the two ends not on one spot
        o.count = 24
    else
        o.count = 0
    end
    return o
end

-- The head's haircut (none when head hair is off: only bangs and coat then, when those are on).
local function headOpts()
    local o = copyOpts()
    if not opts.headOn then o.count = 0 end
    if not opts.bangsOn then o.bangs = 0 end
    coat(o, 120)
    return o
end

local function attachAll()
    for _, instance in pairs(state.mipoInstances) do
        local head = headOpts()
        if head.count > 0 or head.bangs > 0 or head.surface > 0 then
            hairLocks.attach(instance, head)
        else
            instance.hairLocks = nil
        end
        local torso = instance.parts and instance.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed()
                and (opts.bodyOn or opts.furOn or opts.coatOn) then
            local holder = hairLocks.attachBody(torso.body, bodyOpts(), instance)
            holder.dna = instance.dna -- the Mipo's hair colours
        else
            hairLocks.detachBody(instance)
        end
    end
    local box = hairBox()
    if box then
        local o = copyOpts()
        if not opts.bangsOn then o.bangs = 0 end
        hairLocks.attachBody(box, o, 'box')
    end
end

function s.onStart()
    worldState.paused = false
    for k, v in pairs(hairLocks.defaults) do opts[k] = v end
    opts.headOn, opts.bangsOn, opts.bodyOn, opts.furOn, opts.coatOn = true, true, true, false, false
    opts.bodyHair = 0.5
    opts.fur, opts.furLength = 0.5, 20
    opts.coat, opts.coatLength, opts.coatCurly = 0.5, 22, 0
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
    hairLocks.draw('front') -- bangs, front locks and coats, over the faces
end

-- The panel's sections: `toggle` names the opts switch shown on the section's left (none: always on).
local SECTIONS = {
    { name = 'head hair', toggle = 'headOn', sliders = {
        { key = 'count', min = 1, max = 40, step = 1 },
        { key = 'points', min = 3, max = 16, step = 1 },
        { key = 'segment', min = 6, max = 60 },
        { key = 'spread', min = 0.3, max = 6.2 },
        { key = 'frontLocks', min = 0, max = 10, step = 1 },
        { key = 'width', min = 0.02, max = 0.6 },
        { key = 'texture', min = 1, max = 11, step = 1 },
        { key = 'wild', min = 0, max = 1 },
    } },
    { name = 'bangs', toggle = 'bangsOn', sliders = {
        { key = 'bangs', min = 1, max = 15, step = 1 },
        { key = 'bangPoints', min = 2, max = 8, step = 1 },
        { key = 'bangSegment', min = 6, max = 40 },
        { key = 'bangSpread', min = 0.2, max = 3 },
    } },
    { name = 'haircut', sliders = {
        { key = 'cut', min = 0, max = 500 },
        { key = 'lenMiddle', min = 0.2, max = 2 },
        { key = 'lenSides', min = 0.2, max = 2 },
        { key = 'part', min = -1, max = 1 },
        { key = 'droop', min = 0, max = 1.5 },
    } },
    { name = 'curls', sliders = {
        { key = 'curl', min = -1, max = 1 },
        { key = 'curly', min = 0, max = 1 },
        { key = 'ringlets', min = 0, max = 30 },
        { key = 'ringletPitch', min = 8, max = 60 },
    } },
    { name = 'body hair', toggle = 'bodyOn', sliders = {
        { key = 'bodyHair', min = 0.1, max = 1 },
    } },
    { name = 'fur', toggle = 'furOn', sliders = {
        { key = 'fur', min = 0, max = 1 },
        { key = 'furLength', min = 4, max = 60 },
    } },
    { name = 'coat', toggle = 'coatOn', sliders = {
        { key = 'coat', min = 0, max = 1 },
        { key = 'coatLength', min = 4, max = 40 },
        { key = 'coatCurly', min = 0, max = 1 },
    } },
    { name = 'physics', sliders = {
        { key = 'stiffness', min = 0, max = 1 },
        { key = 'stand', min = 0, max = 1 },
        { key = 'springy', min = 0, max = 1 },
        { key = 'damping', min = 0.8, max = 1 },
        { key = 'weight', min = 0, max = 8 },
    } },
}

function s.drawUI()
    if not (state.playMode and showPanel) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad = 32, 4
    local leftW, rightW = 230, 400 -- sections on the left, the open one's sliders on the right
    local w = leftW + rightW + 3 * pad
    local rows = math.max(#SECTIONS, 8) + 1 -- + the buttons
    local h = rows * (BH + pad) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• hair ••', function()
        local changed = false
        local open
        for i, sec in ipairs(SECTIONS) do
            local x, y = x0 + pad, y0 + 24 + (i - 1) * (BH + pad)
            if sec.toggle then
                local clicked, on = ui.checkbox(x, y + 3, opts[sec.toggle], '')
                if clicked then
                    opts[sec.toggle] = on
                    if sec.toggle == 'furOn' and on then opts.bodyOn = false end -- fur instead of body hair
                    if sec.toggle == 'bodyOn' and on then opts.furOn = false end
                    changed = true
                end
            end
            local hx = x + 34
            local label = sec.name .. (sec.toggle and not opts[sec.toggle] and '  (off)' or '')
            if ui.header_button(hx, y, leftW - 34, label, openSection == sec.name) then openSection = sec.name end
            if openSection == sec.name then open = sec end
        end
        if open then
            for j, sl in ipairs(open.sliders) do
                local x, y = x0 + leftW + 2 * pad, y0 + 24 + (j - 1) * (BH + pad)
                local v = ui.sliderWithInput('hair' .. sl.key, x, y, 160, sl.min, sl.max,
                    opts[sl.key] or hairLocks.defaults[sl.key] or 0, nil, sl.step)
                if v and v ~= opts[sl.key] then
                    if sl.step then v = math.floor(v + 0.5) end
                    opts[sl.key] = v
                    changed = true
                end
                ui.label(x + 260, y, sl.key)
            end
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
