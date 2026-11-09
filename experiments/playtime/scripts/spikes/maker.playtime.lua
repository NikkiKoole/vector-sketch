-- maker: the Mipo maker's card with Puppetmaker 2's hand-drawn widgets (docs/MIPO-MAKER.md): one card
-- beside a live Mipo, the parts in a row on top, the shapes in a flickable grid, paint blobs, icon
-- sliders on a taped strip, a drawn toggle and the dice. Tap a part of the Mipo to pick it (a drag
-- still pokes). Widgets: src/ui/maker/drawn.lua (makerUI), drawings in textures/ui/maker/.
-- Play mode only (./playtime.sh play maker; tab toggles the editor).
-- keys: r: a new Mipo   h: hide/show the card

local s = {}

local GROUND_Y = 900
local MIPO_X = -420
local ZOOM = 0.42
local SCALE = 0.42
local APPLY_EVERY = 0.12 -- s: a dragged slider rebuilds the Mipo at most this often
local TAP_TIME, TAP_MOVE = 0.3, 12 -- a tap on the Mipo: shorter than this, moved less (px)

-- a palette in Puppetmaker's spirit (16 blobs, 2 rows)
local PALETTE = {
    '020202', 'efebd8', 'f2c9a0', 'd9a066', '9c6b3f', '613d41', 'be193b', 'd6642f',
    'e6c800', '8fb35a', '3f7f5f', '4a90a8', '2f4f8f', '4f3166', 'c98fb8', 'f5f5f5',
}

local function check() -- on state: a script hot reload keeps the Mipo and what's picked
    state.makerSpike = state.makerSpike or { category = 'body', layer = 'fill', show = true,
        grid = { off = 0, vel = 0 }, lastApply = 0 }
    return state.makerSpike
end

local function alive(inst)
    local torso = inst and inst.parts and inst.parts.torso1
    return torso and torso.body and not torso.body:isDestroyed()
end

local function hexToRGB(hex)
    hex = hex or 'ccccccff'
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

local function numberOf(url) return tonumber(tostring(url):match('(%d+)%.?p?n?g?$')) end

local function partData(inst, name) return inst.dna.parts[name] end
local function skinOf(inst, name)
    local p = partData(inst, name)
    return p and p.appearance and p.appearance.skin and p.appearance.skin.main
end
local function faceOwner(inst) return inst.dna.creation.isPotatoHead and 'torso1' or 'head' end
local function face(inst)
    local p = partData(inst, faceOwner(inst))
    return p and p.appearance and p.appearance.face
end
local function haircut(inst)
    local p = partData(inst, faceOwner(inst))
    return p and p.appearance and p.appearance.haircut
end
local function torsos(inst)
    local names = {}
    for i = 1, inst.dna.creation.torsoSegments or 1 do names[i] = 'torso' .. i end
    return names
end

-- a part's shape and scale through the same call the editor's shape panel makes
local function setShape(inst, name, url, sx, sy)
    local p = partData(inst, name)
    if not p then return end
    characterManager.updatePart(name, { shape8URL = url or p.shape8URL, sx = sx or p.dims.sx or 1,
        sy = sy or p.dims.sy or 1 }, inst)
end

local function setSkin(inst, names, key, hex)
    for _, name in ipairs(names) do characterManager.updateSkinOfPart(inst, name, { [key] = hex }) end
end

local function faceSet(inst, values) characterManager.updateFaceOfPart(inst, faceOwner(inst), values) end

-- The categories: what the card shows for each (later src/mipo-maker-catalog.lua, MM2).
-- shapes: the catalog, picked(inst) the url picked now, pick(inst, url); fill(inst) the colour the
-- cells and the icon get; colour(inst, layer, hex); sliders: { less, more, min, max, step, get, set }.
local CATEGORIES = {
    {
        name = 'body', icon = 'icons/body',
        shapes = shapeCatalogs.torsoHeadShapes,
        picked = function(inst) return partData(inst, 'torso1').shape8URL end,
        pick = function(inst, url) setShape(inst, 'torso1', url) end,
        skin = function(inst) return torsos(inst) end,
        sliders = {
            { less = 'icons/body-narrow', more = 'icons/body-wide', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'torso1').dims.sx or 1 end,
                set = function(inst, v) setShape(inst, 'torso1', nil, v, nil) end },
            { less = 'icons/body-small', more = 'icons/body-tall', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'torso1').dims.sy or 1 end,
                set = function(inst, v) setShape(inst, 'torso1', nil, nil, v) end },
        },
    },
    {
        name = 'head', icon = 'icons/head',
        hidden = function(inst) return inst.dna.creation.isPotatoHead end,
        shapes = shapeCatalogs.torsoHeadShapes,
        picked = function(inst) return partData(inst, 'head').shape8URL end,
        pick = function(inst, url) setShape(inst, 'head', url) end,
        skin = function() return { 'head' } end,
        sliders = {
            { less = 'icons/head-narrow', more = 'icons/head-wide', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'head').dims.sx or 1 end,
                set = function(inst, v) setShape(inst, 'head', nil, v, nil) end },
            { less = 'icons/head-small', more = 'icons/head-tall', min = 0.5, max = 2, step = 0.25,
                get = function(inst) return partData(inst, 'head').dims.sy or 1 end,
                set = function(inst, v) setShape(inst, 'head', nil, nil, v) end },
        },
    },
    {
        name = 'eyes', icon = 'icons/eyes', textures = true,
        shapes = shapeCatalogs.eyeShapes,
        picked = function(inst) return face(inst).eye.shape end,
        pick = function(inst, url) faceSet(inst, { eyeShape = numberOf(url) }) end,
        fill = function(inst) return face(inst).eye.fgHex end,
        colour = function(inst, layer, hex) faceSet(inst, layer == 'line' and { eyeBgHex = hex } or { eyeFgHex = hex }) end,
        sliders = {
            { less = 'icons/eye-small', more = 'icons/eye-wide', min = 0.25, max = 2, step = 0.25,
                get = function(inst) return face(inst).eye.wMul end,
                set = function(inst, v) faceSet(inst, { eyeWMul = v }) end },
            { less = 'icons/eye-small2', more = 'icons/eye-tall', min = 0.25, max = 2, step = 0.25,
                get = function(inst) return face(inst).eye.hMul end,
                set = function(inst, v) faceSet(inst, { eyeHMul = v }) end },
            { less = 'icons/eye-close', more = 'icons/eye-far', min = 0, max = 0.5, step = 0.05,
                get = function(inst) return face(inst).positioners.eye.x end,
                set = function(inst, v) faceSet(inst, { eyeX = v }) end },
        },
    },
    {
        name = 'nose', icon = 'icons/nose', textures = true,
        shapes = shapeCatalogs.noseShapes,
        picked = function(inst) return face(inst).nose.shape end,
        pick = function(inst, url) faceSet(inst, { noseShape = numberOf(url) }) end,
        fill = function(inst) return face(inst).nose.fgHex end,
        colour = function(inst, layer, hex) faceSet(inst, layer == 'line' and { noseBgHex = hex } or { noseFgHex = hex }) end,
        sliders = {
            { less = 'icons/nose-narrow', more = 'icons/nose-wide', min = 0.5, max = 3, step = 0.25,
                get = function(inst) return face(inst).nose.wMul end,
                set = function(inst, v) faceSet(inst, { noseWMul = v }) end },
            { less = 'icons/nose-small', more = 'icons/nose-tall', min = 0.5, max = 3, step = 0.25,
                get = function(inst) return face(inst).nose.hMul end,
                set = function(inst, v) faceSet(inst, { noseHMul = v }) end },
        },
    },
    {
        name = 'ears', icon = 'icons/ears',
        hidden = function(inst) return not partData(inst, 'lear') end,
        shapes = shapeCatalogs.earShapes,
        picked = function(inst) return partData(inst, 'lear').shape8URL end,
        pick = function(inst, url)
            setShape(inst, 'lear', url)
            setShape(inst, 'rear', url)
        end,
        skin = function() return { 'lear', 'rear' } end,
        sliders = {
            { less = 'icons/ear-small', more = 'icons/ear-big', min = 0.5, max = 2.5, step = 0.25,
                get = function(inst) return partData(inst, 'lear').dims.sy or 1 end,
                set = function(inst, v)
                    for _, n in ipairs({ 'lear', 'rear' }) do setShape(inst, n, nil, nil, v) end
                end },
        },
    },
    {
        name = 'hair', icon = 'icons/hair',
        hidden = function(inst) return not haircut(inst) end,
        shapes = shapeCatalogs.haircutTextures,
        picked = function(inst) return haircut(inst).main and haircut(inst).main.bgURL end,
        pick = function(inst, url)
            url = url .. '.png'
            local fg = shapeCatalogs.hairsWithMask[url] and url:gsub('%.png', '-mask.png') or ''
            characterManager.updateHaircutOfPart(inst, faceOwner(inst), { bgURL = url, fgURL = fg })
        end,
        fill = function(inst) return haircut(inst).main and haircut(inst).main.bgHex end,
        colour = function(inst, _, hex) characterManager.updateHaircutOfPart(inst, faceOwner(inst), { bgHex = hex }) end,
        sliders = {
            { less = 'icons/hair-thin', more = 'icons/hair-thick', min = 50, max = 800, step = 50,
                get = function(inst) return haircut(inst).width or 250 end,
                set = function(inst, v) characterManager.updateHaircutOfPart(inst, faceOwner(inst), { width = v }) end },
        },
    },
}
local BY_NAME = {}
for _, cat in ipairs(CATEGORIES) do BY_NAME[cat.name] = cat end

-- which category a tapped Mipo part picks
local function categoryOfPart(inst, partName)
    if partName:match('^torso') then return 'body' end
    if partName == 'head' then return 'head' end
    if partName == 'lear' or partName == 'rear' then return 'ears' end
    if partName:match('^nose') then return 'nose' end
    return nil
end

local function fillOf(inst, cat)
    if cat.fill then return cat.fill(inst) end
    local skin = cat.skin and skinOf(inst, cat.skin(inst)[1])
    return skin and skin.fgHex
end

local function colourOf(inst, cat, layer)
    if cat.skin then
        local skin = skinOf(inst, cat.skin(inst)[1])
        return skin and (layer == 'line' and skin.bgHex or skin.fgHex)
    end
    if layer == 'line' and cat.name == 'eyes' then return face(inst).eye.bgHex end
    if layer == 'line' and cat.name == 'nose' then return face(inst).nose.bgHex end
    return fillOf(inst, cat)
end

local function setColour(inst, cat, layer, hex)
    if cat.skin then setSkin(inst, cat.skin(inst), layer == 'line' and 'bgHex' or 'fgHex', hex)
    else cat.colour(inst, layer, hex) end
end

-- edits: done now (a tap) or at most every APPLY_EVERY (a drag); the textures after
local function apply(fn)
    local c = check()
    c.pending, c.live = nil, nil
    fn()
    characterManager.rebuildTextures(c.mipo)
    c.lastApply = love.timer.getTime()
end
local function applySoon(fn) check().pending = fn end

local function newMipo()
    local c = check()
    if alive(c.mipo) then characterManager.removeCharacter(c.mipo) end
    c.mipo = characterManager.createCharacter('humanoid', MIPO_X, GROUND_Y - 600, SCALE)
    if c.mipo then characterManager.randomizeMipo(c.mipo) end
end

local function makeGround()
    local c = check()
    if c.ground and not c.ground:isDestroyed() then return end
    c.ground = love.physics.newBody(world, 0, GROUND_Y + 50, 'static')
    love.physics.newFixture(c.ground, love.physics.newRectangleShape(4000, 100)):setFriction(0.9)
end

local function frame()
    cam:setScale(ZOOM)
    cam:setTranslation(MIPO_X + 380, GROUND_Y - 420)
    check().hold = true
end

function s.onStart()
    worldState.paused = false
    makeGround()
    if not alive(check().mipo) then newMipo() end
    frame()
end

function s.update()
    local c = check()
    if c.pending and love.timer.getTime() - c.lastApply > APPLY_EVERY then apply(c.pending) end
    -- the grid's flick
    local g = c.grid
    if not g.drag and math.abs(g.vel) > 0.5 then
        g.off = g.off + g.vel * love.timer.getDelta()
        g.vel = g.vel * math.exp(-love.timer.getDelta() * 5)
    end
    if c.hold and (love.mouse.isDown(2, 3) or cam.scale ~= ZOOM) then c.hold = false end
end

-- a tap on the Mipo picks its part; a drag pokes it as ever
function s.onPressed(things)
    local c = check()
    c.press = nil
    if not alive(c.mipo) then return end
    for _, thing in ipairs(things or {}) do
        for name, part in pairs(c.mipo.parts) do
            if part.body == thing.body then
                local mx, my = love.mouse.getPosition()
                c.press = { part = name, at = love.timer.getTime(), x = mx, y = my }
                return
            end
        end
    end
end

function s.onReleased()
    local c = check()
    local p = c.press
    c.press = nil
    if not p then return end
    local mx, my = love.mouse.getPosition()
    if love.timer.getTime() - p.at > TAP_TIME or math.abs(mx - p.x) + math.abs(my - p.y) > TAP_MOVE then return end
    local cat = categoryOfPart(c.mipo, p.part)
    if cat and BY_NAME[cat] then
        c.category, c.grid.off, c.grid.vel = cat, 0, 0
        mipoVoice.edited(c.mipo)
    end
end

function s.onKeyPress(key)
    local c = check()
    if key == 'r' then newMipo() end
    if key == 'h' then c.show = not c.show end
end

-- the shapes grid: flick it up and down; a tap picks (not at the end of a flick)
local function drawGrid(c, inst, cat, x, y, w, h)
    local cols = 4
    local cell = w / cols
    local items = cat.shapes or {}
    local rows = math.ceil(#items / cols)
    local g = c.grid
    local maxOff = math.max(0, rows * cell - h)
    local over = ui.mouseX >= x and ui.mouseX <= x + w and ui.mouseY >= y and ui.mouseY <= y + h
    if over and ui.mousePressed then g.drag = { y = ui.mouseY, off = g.off, lastY = ui.mouseY, moved = false } end
    if g.drag then
        if ui.mouseIsDown then
            local dy = ui.mouseY - g.drag.y
            if math.abs(dy) > 8 then g.drag.moved = true end
            if g.drag.moved then
                g.off = g.drag.off - dy
                g.vel = -(ui.mouseY - g.drag.lastY) / math.max(love.timer.getDelta(), 1 / 120)
            end
            g.drag.lastY = ui.mouseY
        else
            g.flicked = g.drag.moved
            g.drag = nil
        end
    end
    if g.off < 0 then g.off, g.vel = 0, 0 end
    if g.off > maxOff then g.off, g.vel = maxOff, 0 end

    local fill = hexToRGB(fillOf(inst, cat))
    local picked = cat.picked(inst)
    ui.pushClip(x, y, w, h)
    for i, url in ipairs(items) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local cx, cy = x + col * cell, y + row * cell - g.off
        if cy + cell > y and cy < y + h then
            local isPicked = picked == url .. '.png' or picked == url or picked == numberOf(url)
            local tapped = makerUI.partCell('maker-cell-' .. i, cx, cy, cell, url, fill, isPicked)
            if tapped and not g.flicked and over then
                apply(function() cat.pick(inst, url) end)
                mipoVoice.edited(inst)
            end
        end
    end
    ui.popClip()
    if not ui.mouseIsDown then g.flicked = false end
end

function s.drawUI()
    local c = check()
    local inst = c.mipo
    local W, H = love.graphics.getDimensions()
    if not state.playMode then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print('maker spike: play mode shows the card (tab)', 20, H - 30)
        return
    end
    if not (c.show and alive(inst)) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame

    local cw = math.min(440, W * 0.37)
    local cx, cy, ch = W - cw - 16, 16, H - 32
    makerUI.card(cx, cy, cw, ch)
    local m = cw * 0.08
    local x, w = cx + m, cw - m * 2
    local y = cy + ch * 0.06

    -- the parts in a row
    local shown = {}
    for _, cat in ipairs(CATEGORIES) do
        if not (cat.hidden and cat.hidden(inst)) then shown[#shown + 1] = cat end
    end
    if not BY_NAME[c.category] or (BY_NAME[c.category].hidden and BY_NAME[c.category].hidden(inst)) then
        c.category = 'body'
    end
    local isize = w / #shown
    for i, cat in ipairs(shown) do
        local fill = hexToRGB(fillOf(inst, cat))
        if makerUI.iconButton('maker-cat-' .. cat.name, x + (i - 1) * isize, y, isize, cat.icon,
                { mask = fill, picked = c.category == cat.name, paper = (i % 7) + 1, bare = true }) then
            c.category, c.grid.off, c.grid.vel = cat.name, 0, 0
            mipoVoice.edited(inst)
        end
    end
    y = y + isize + m * 0.5
    local cat = BY_NAME[c.category]

    -- dice and the colour layer
    local dsize = isize * 0.9
    if makerUI.iconButton('maker-dice', x, y, dsize, 'big-button-dice', { mask = { 0.95, 0.75, 0.4 }, bare = true }) then
        characterManager.randomizeMipo(inst)
        mipoVoice.dice(inst)
    end
    local tw, th = w * 0.32, dsize * 0.5
    local tx = x + w - tw
    love.graphics.setColor(0.2, 0.15, 0.12)
    love.graphics.print(c.layer == 'line' and 'line' or 'fill', tx - 40, y + dsize / 2 - 7)
    love.graphics.setColor(1, 1, 1)
    local on = makerUI.toggle('maker-layer', tx, y + (dsize - th) / 2, tw, th, c.layer == 'line')
    if on ~= nil then c.layer = on and 'line' or 'fill' end
    y = y + dsize + m * 0.4

    -- the sliders on a taped strip, at the bottom
    local ssize = math.min(48, w / 7)
    local rowH = ssize * 1.25
    local slidersH = #cat.sliders * rowH + m * 0.6
    local blobSize = w / 8
    local blobsH = blobSize * 2 + m * 0.4
    local bottom = cy + ch - m * 0.9
    local sy0 = bottom - slidersH
    local by0 = sy0 - blobsH

    drawGrid(c, inst, cat, x, y, w, by0 - y - m * 0.3)

    -- paint blobs
    local current = colourOf(inst, cat, c.layer)
    for i, hex in ipairs(PALETTE) do
        local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
        local isPicked = current and current:sub(1, 6):lower() == hex
        if makerUI.blob('maker-blob-' .. i, x + col * blobSize, by0 + row * blobSize, blobSize, hexToRGB(hex), i, isPicked) then
            apply(function() setColour(inst, cat, c.layer, hex .. 'ff') end)
            mipoVoice.edited(inst)
        end
    end

    makerUI.tape(x - m * 0.4, sy0, w + m * 0.8, slidersH)
    for i, sl in ipairs(cat.sliders) do
        local id = 'maker-' .. cat.name .. '-' .. i
        local shownValue = (c.live and c.live[id]) or sl.get(inst) or sl.min -- dragged, not applied yet
        local v, amount = makerUI.iconSlider(id, x, sy0 + m * 0.3 + (i - 1) * rowH,
            w, ssize, shownValue, sl.min, sl.max, sl.step, sl.less, sl.more)
        if v then
            c.live = c.live or {}
            c.live[id] = v
            applySoon(function() sl.set(inst, v) end)
            mipoVoice.edited(inst, amount)
        end
    end
    -- a slider let go: its last value now
    if c.pending and not ui.mouseIsDown then apply(c.pending) end
end

return s
