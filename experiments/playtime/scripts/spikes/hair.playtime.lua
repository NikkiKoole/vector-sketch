-- hair: a spike for long hair that swings (src/hair-locks.lua; docs/HAIR-LOCKS.md). One Mipo with
-- hair; the panel (play mode, tab) in sections, each switched on or off on its left and opened to
-- show its sliders: head hair, bangs, haircut, curls, body hair (round the torso's edge), fur
-- (many short locks standing out round it, instead of the body hair), coat (strands over the body,
-- like chest hair, kept off the face), physics. Throw the Mipo around and watch them.
-- A box beside it wears the same head hair: pick it up and swing it, or let it rest (its hair sleeps).
-- A lamp (its section): a warm point light and a soft sky, to see the hair lit and its shadow; hold l
-- and it follows the mouse.
-- keys: r: lay the locks out again   h: hide/show the panel   m: a new random Mipo   l: move the lamp

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

-- The lamp: a small body that touches nothing (label hair-lamp, found again on reload) with a point
-- light and a sky light on it. Off, it's taken away altogether: lights set to 0 would leave the scene
-- dark (with every light off the shaders get one dark light), without any it has its default light.
local function lampBody()
    local found = getObjectsByLabel('hair-lamp')[1]
    return found and found.body and not found.body:isDestroyed() and found.body or nil
end

local function lampLights(body)
    local point, sky
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.subtype == 'light' then
            if ud.extra.lightType == 'sky' then sky = ud.extra else point = ud.extra end
        end
    end
    return point, sky
end

local function updateLamp()
    local body = lampBody()
    if not opts.lampOn then
        if body then objectManager.destroyBody(body) end
        return
    end
    if not body then
        local x, y = 0, 0
        for _, instance in pairs(state.mipoInstances) do
            local head = instance.parts and (instance.parts.head or instance.parts.torso1)
            if head and head.body and not head.body:isDestroyed() then x, y = head.body:getPosition() end
        end
        local thing = objectManager.addThing('circle', { x = x - 350, y = y - 300, radius = 12,
            bodyType = 'kinematic', label = 'hair-lamp' })
        if not thing then return end
        body = thing.body
        for _, f in ipairs(body:getFixtures()) do f:setSensor(true) end -- it touches nothing
        fixtures.createSFixture(body, 0, 0, 'light', { radius = 8 })
        local skyFixture = fixtures.createSFixture(body, 0, 0, 'light', { radius = 8 })
        skyFixture:getUserData().extra.lightType = 'sky'
    end
    local point, sky = lampLights(body)
    if point then
        point.lightType, point.colorHex = 'point', 'ffd9a6ff'
        point.intensity, point.range = opts.lampStrength or 2.5, opts.lampRange or 900
    end
    if sky then
        sky.colorHex, sky.groundHex = 'c9d8ffff', '6b5a40ff'
        sky.intensity = opts.lampSky or 0.35
    end
end

local function copyOpts()
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    return o
end

-- The coat's strands for a body (`share` of them at coat 1).
local function coat(o, share)
    o.surface = opts.coatOn and math.floor((opts.coat or 0.5) * share + 0.5) or 0
    o.surfaceLength = opts.coatLength or 22
    o.surfaceCurly = opts.coatCurly or 0
    -- its own width, in the head hair's units (hair-locks takes it as a share of `width`)
    o.surfaceWidth = (opts.coatWidth or 0.021) / math.max(o.width or 0.06, 0.001)
end

-- The torso's hair: fur (many short locks standing out, roots almost on the outline), or the body
-- hair (24 locks round its outline, `bodyHair` times the head's length), or neither (only a coat).
local function bodyOpts()
    local o = copyOpts()
    o.bangs, o.frontLocks = 0, 0
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
    coat(o, 400) -- last: its width is a share of the width set above
    return o
end

-- The head's haircut (none when head hair is off: only bangs and coat then, when those are on).
local function headOpts()
    local o = copyOpts()
    if not opts.headOn then o.count = 0 end
    if not opts.bangsOn then o.bangs = 0 end
    coat(o, 0) -- no coat on the head (on a potato head the body's coat keeps off the face)
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
    updateLamp()
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
    opts.headOn, opts.bangsOn, opts.bodyOn, opts.furOn, opts.coatOn = true, true, false, false, false
    opts.bodyHair = 0.5
    opts.fur, opts.furLength = 0.5, 20
    opts.coat, opts.coatLength, opts.coatCurly, opts.coatWidth = 0.5, 17, 0, 0.05
    opts.lampOn, opts.lampStrength, opts.lampRange, opts.lampSky = false, 2.5, 900, 0.35
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
    local lamp = opts.lampOn and lampBody()
    if lamp and love.keyboard.isDown('l') then lamp:setPosition(mouseWorldPos()) end
end

function s.drawBelow()
    hairLocks.draw('back') -- behind the Mipos (and everything else, for now)
end

function s.draw()
    hairLocks.draw('front') -- bangs, front locks and coats, over the faces
    local lamp = opts.lampOn and lampBody()
    if lamp then -- the bulb
        local x, y = lamp:getPosition()
        love.graphics.setColor(1, 0.85, 0.6, 1)
        love.graphics.circle('fill', x, y, 14)
        love.graphics.setColor(0.2, 0.15, 0.1, 1)
        love.graphics.circle('line', x, y, 14)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Haircuts: buttons that set the head hair's sliders at once (then tune from there). 'long' is the
-- defaults (hanging, Nikki's look of 2026-11-09); 'short up' a short cut standing up.
local CUTS = {
    { name = 'long', set = {} }, -- the defaults: applyCut puts every key a cut sets back to them first
    { name = 'short up', set = { count = 26, points = 4, segment = 12, stand = 0.85, stiffness = 0.6,
        droop = 0.1, spread = 2.4, frontLocks = 0, width = 0.14, curly = 0, ringlets = 0, cut = 0,
        lenMiddle = 1, lenSides = 1 }, bangs = false },
}
local function applyCut(cut)
    local d = hairLocks.defaults
    for k in pairs(CUTS[2].set) do opts[k] = d[k] end -- every key a cut sets back to the long look,
    opts.bangsOn = true
    for k, v in pairs(cut.set) do opts[k] = v end -- then this cut's
    if cut.bangs == false then opts.bangsOn = false end
    opts.headOn = true
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
        { key = 'coatWidth', min = 0.005, max = 0.1 },
    } },
    { name = 'lamp (hold l)', toggle = 'lampOn', sliders = {
        { key = 'lampStrength', min = 0, max = 6 },
        { key = 'lampRange', min = 200, max = 2500 },
        { key = 'lampSky', min = 0, max = 1.5 },
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
    local _, sh = ui.getDimensions() -- the screen in UI units (a phone's ui.scale)
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
        local by, bw = y0 + 24 + (rows - 1) * (BH + pad), (w - 5 * pad - 20) / 4
        for k, cut in ipairs(CUTS) do
            if ui.button(x0 + k * pad + (k - 1) * bw, by, bw, cut.name) then
                applyCut(cut)
                changed = true
            end
        end
        if ui.button(x0 + 3 * pad + 2 * bw, by, bw, 'new locks') then
            opts.seed = (opts.seed or 1) + 1
            changed = true
        end
        if ui.button(x0 + 4 * pad + 3 * bw, by, bw, 'random Mipo') then randomizeMipos() end
        if changed then attachAll() end
    end)
end

return s
