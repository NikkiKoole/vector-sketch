-- riso: the textures we use (soil, plaster, planks, bark …) as a risograph print (two or three spot inks) or a
-- photocopy (black toner, a copy of a copy) a watercolour (washes, edges, granulation)
-- a woodcut / linocut (carved lines, wood grain, colour blocks), a misprinted CMYK (dithered plates off register),
-- gouache (flat opaque poster paint) or cut paper (an Eric Carle kind of collage); for all: boil, paper on the world
-- (docs/RISO.md; Nikki 2026-11-11: "a riso-print shader, im wondering what that would do with some of the cc0
-- textures we use now, for soil etc, i hope it might end up looking more handmade").
-- Each colour is split into ink densities (the inks multiply on the paper, so in log space a colour is a sum
-- of inks: solved by least squares for the chosen inks), each ink screened on its own (grain: riso's
-- stochastic dots; or round dots at its own angle), each plate printed a little off (misregistration),
-- the ink a little uneven, on a paper with tooth. Views: 'textures' (a sheet of them) and 'scene' (the whole
-- world through it, Mipo and all). Hold space: the original. Keys: space, v view, h panel.
local s = {}

local GROUND_Y = 600

-- the print processes (shaders, inks, papers, settings): scripts/spikes/print-looks.lua, shared with burrow
local looks

local TEXTURES = { 'ground/soil-01.jpg', 'ground/earth-01.jpg', 'ground/moss-01.jpg', 'ground/grass-01.jpg',
    'walls/plaster-02.jpg', 'walls/planks-01.jpg', 'walls/concrete-01.jpg', 'bark/bark-01.jpg' }

local function st()
    if not state.riso then
        state.riso = looks.defaults({ showPanel = true, view = 'textures' })
    end
    return state.riso
end
looks = love.filesystem.load('scripts/spikes/print-looks.lua')()(st, cam)
local INKS, SETS, PAPERS, COPY_PAPERS, TONERS = looks.INKS, looks.SETS, looks.PAPERS, looks.COPY_PAPERS, looks.TONERS
local WATER_PAPERS, WOOD_PAPERS, WOOD_INKS = looks.WATER_PAPERS, looks.WOOD_PAPERS, looks.WOOD_INKS
local CMYK_PAPERS, CMYK_MODES, GOUACHE_PAPERS, CUT_PAPERS = looks.CMYK_PAPERS, looks.CMYK_MODES, looks.GOUACHE_PAPERS, looks.CUT_PAPERS
local hex, inkNamed, apply, paperColour = looks.hex, looks.inkNamed, looks.apply, looks.paperColour
local copySettings, waterSettings, woodSettings = looks.copySettings, looks.waterSettings, looks.woodSettings
local cmykSettings, gouacheSettings, cutSettings = looks.cmykSettings, looks.gouacheSettings, looks.cutSettings

-- ── the scene: soil, a few textured blocks, a Mipo ──
local function mipo()
    for _, inst in pairs(mipoRegistry.getAll()) do
        if mipoKit.isAlive(inst) then return inst end
    end
end
local function block(label, x, y, w, h, url, tile)
    if getObjectsByLabel(label)[1] then return end
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h, bodyType = 'static',
        label = label })
    if not thing then return end
    local extra = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    extra.main = extra.main or {}
    extra.main.bgURL, extra.opacity, extra.tileWidthM, extra.tileHeightM = url, 1, tile, tile
end
local function ensureScene()
    block('ground', 0, GROUND_Y + 300, 6000, 600, 'world/ground/soil-01.jpg', 0.6)
    block('plaster', 450, GROUND_Y - 250, 500, 500, 'world/walls/plaster-02.jpg', 1)
    block('planks', -700, GROUND_Y - 150, 300, 300, 'world/walls/planks-01.jpg', 0.8)
    block('moss', 1000, GROUND_Y - 60, 400, 120, 'world/ground/moss-01.jpg', 0.5)
    if not mipo() then
        local inst = characterManager.createCharacter('humanoid', -150, GROUND_Y - 900, 0.9)
        if inst then characterManager.randomizeMipoConstrained(inst) end
    end
end

function s.onStart()
    worldState.paused = false
    st()
    ensureScene()
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel end
    if key == 'v' then c.view = c.view == 'scene' and 'textures' or 'scene' end
end

local function original() return love.keyboard.isDown('space') end

-- 'scene': the world drawn into a canvas, then laid down through the print
local canvas, previous
function s.drawBelow()
    local c = st()
    c.capturing = false
    if c.view ~= 'scene' or original() then return end
    local w, h = love.graphics.getDimensions()
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        canvas = love.graphics.newCanvas(w, h)
    end
    previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(1, 1, 1, 1) -- the world's dark backdrop would print as solid ink: bare paper instead
    c.capturing = true
end

function s.draw()
    local c = st()
    if not c.capturing then return end
    c.capturing = false
    if previous then love.graphics.setCanvas({ previous, stencil = true }) else love.graphics.setCanvas() end
    previous = nil
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    apply(1 / canvas:getWidth(), 1 / canvas:getHeight())
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
end

-- 'textures': a sheet of them, each printed
local images = {}
local function image(path)
    if not images[path] then
        local img = love.graphics.newImage('textures/world/' .. path)
        img:setWrap('repeat', 'repeat')
        images[path] = img
    end
    return images[path]
end
local function drawSheet(sw, sh)
    local cols, rows, gap = 4, 2, 10
    local x0, y0 = 20, 20
    local tw = (sw - 460 - x0 - gap * (cols - 1)) / cols
    local th = (sh - 40 - gap) / rows
    love.graphics.setColor(paperColour())
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    for i, path in ipairs(TEXTURES) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, y = x0 + col * (tw + gap), y0 + row * (th + gap)
        local img = image(path)
        local scale = 0.5 -- texture px per screen px x2: a 1024 texture over 512 px
        local quad = love.graphics.newQuad(0, 0, tw / scale, th / scale, img:getWidth(), img:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        if not original() then apply(1 / (img:getWidth() * scale), 1 / (img:getHeight() * scale)) end
        love.graphics.draw(img, quad, x, y, 0, scale, scale)
        love.graphics.setShader()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.print(path:match('([^/]+)%.jpg$'), x + 6, y + th - 18)
    end
end

-- ── the panel ──
local P = { w = 420, row = 30, pad = 10 }
local SLIDERS = { { 'dot', 'dot size', 1, 8, 0.5 }, { 'offset', 'misregister', 0, 8, 0.5 },
    { 'grain', 'grain', 0, 1, 0.05 }, { 'density', 'ink', 0.3, 1.6, 0.05 }, { 'contrast', 'contrast', 0.5, 2.5, 0.05 } }
local COPY_SLIDERS = { { 'darkness', 'darkness', 0, 1, 0.02 }, { 'contrast', 'contrast', 0.5, 4, 0.05 },
    { 'copies', 'copies', 0, 5, 1 }, { 'grit', 'grit', 0, 1, 0.05 }, { 'speckle', 'dust', 0, 2, 0.05 },
    { 'streaks', 'streaks', 0, 1, 0.05 }, { 'detail', 'detail', 0, 1, 0.05 } }
local WATER_SLIDERS = { { 'wobble', 'wobble', 0, 2, 0.05 }, { 'soften', 'soften', 0, 8, 0.25 },
    { 'bleed', 'bleed', 0, 1, 0.05 }, { 'edges', 'edges', 0, 3, 0.05 }, { 'pigment', 'pigment', 0, 1.5, 0.05 },
    { 'granulation', 'granulation', 0, 1.5, 0.05 }, { 'water', 'water', 0, 1, 0.05 } }
local WOOD_SLIDERS = { { 'darkness', 'darkness', 0, 1, 0.02 }, { 'spacing', 'line gap', 2, 14, 0.5 },
    { 'angle', 'angle', 0, 3.14, 0.05 }, { 'bend', 'bend', 0, 12, 0.25 }, { 'chips', 'gouge', 0, 1.5, 0.05 },
    { 'outline', 'outline', 0, 4, 0.1 }, { 'grain', 'wood grain', 0, 1, 0.05 }, { 'colour', 'colour', 0, 1, 0.05 },
    { 'levels', 'colours', 2, 6, 1 }, { 'offset', 'off register', 0, 8, 0.5 } }
local CMYK_SLIDERS = { { 'pixel', 'pixel', 1, 8, 0.5 }, { 'misreg', 'misregister', 0, 16, 0.5 },
    { 'slip', 'slip', 0, 2, 0.05 }, { 'ghost', 'ghost', 0, 1, 0.05 }, { 'starve', 'ink runs out', 0, 1, 0.05 },
    { 'gain', 'dot gain', 0, 1, 0.05 }, { 'blackgen', 'black', 0, 1, 0.05 }, { 'contrast', 'contrast', 0.5, 2.5, 0.05 } }
local GOUACHE_SLIDERS = { { 'radius', 'patches', 1, 14, 0.5 }, { 'flatness', 'flat', 0, 1, 0.05 },
    { 'chalk', 'chalk', 0, 1, 0.05 }, { 'brush', 'brush', 0, 1.5, 0.05 }, { 'dry', 'dry', 0, 1, 0.05 },
    { 'wobble', 'wobble', 0, 2, 0.05 } }
local CUT_SLIDERS = { { 'levels', 'papers', 2, 12, 1 }, { 'soften', 'soften', 0, 24, 0.5 },
    { 'tear', 'tear', 0, 2, 0.05 }, { 'fringe', 'fringe', 0, 5, 0.25 }, { 'shadow', 'shadow', 0, 2, 0.05 },
    { 'paint', 'paint', 0, 1.5, 0.05 } }

local function buttonRow(x, y, inner, bh, names, picked, onPick)
    local bw = (inner - (#names - 1) * 4) / #names
    for i, name in ipairs(names) do
        if ui.button(x + (i - 1) * (bw + 4), y, bw, picked(i, name) and ('[' .. name .. ']') or name, bh) then
            onPick(i, name)
        end
    end
end
local function sliders(x, y, inner, list, values, prefix)
    for _, sl in ipairs(list) do
        ui.label(x, y + 5, sl[2])
        local value = ui.sliderWithInput(prefix .. sl[1], x + 100, y - 4, inner - 190, sl[3], sl[4], values[sl[1]],
            nil, sl[5])
        if value then values[sl[1]] = value + 0 end
        y = y + P.row
    end
    return y
end
local function names(list)
    local out = {}
    for i, item in ipairs(list) do out[i] = item[1] end
    return out
end

local function drawRisoControls(c, x, y, inner, bh)
    -- the three ink drums: < name >, '-' for none (not the first)
    for k = 1, 3 do
        local i = c.inks[k]
        local col = i and hex(INKS[i][2]) or { 0.5, 0.5, 0.5 }
        love.graphics.setColor(col[1], col[2], col[3], i and 1 or 0.3)
        love.graphics.rectangle('fill', x, y + 2, 22, bh - 2, 4, 4)
        local function step(d)
            local n = #INKS + (k > 1 and 1 or 0)
            local cur = i or (#INKS + 1)
            cur = (cur - 1 + d) % n + 1
            c.inks[k] = cur <= #INKS and cur or nil
        end
        if ui.button(x + 30, y, 34, '<', bh) then step(-1) end
        ui.label(x + 72, y + 5, 'ink ' .. k .. ': ' .. (i and INKS[i][1] or '-'))
        if ui.button(x + inner - 34, y, 34, '>', bh) then step(1) end
        y = y + P.row
    end
    local pairings = {}
    for i in ipairs(SETS) do pairings[i] = tostring(i) end
    buttonRow(x, y, inner, bh, pairings, function() return false end, function(i)
        local set = SETS[i]
        c.inks = { inkNamed(set[1]), inkNamed(set[2]), set[3] and inkNamed(set[3]) or nil }
    end)
    y = y + P.row
    buttonRow(x, y, inner, bh, names(PAPERS), function(i) return c.paper == i end, function(i) c.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, { 'grain', 'dots' }, function(_, n) return c.mode == n end, function(_, n) c.mode = n end)
    y = y + P.row
    return sliders(x, y, inner, SLIDERS, c, 'riso-')
end

local function drawGouacheControls(x, y, inner, bh)
    local k = gouacheSettings()
    buttonRow(x, y, inner, bh, names(GOUACHE_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    return sliders(x, y, inner, GOUACHE_SLIDERS, k, 'gouache-')
end

local function drawCutControls(x, y, inner, bh)
    local k = cutSettings()
    buttonRow(x, y, inner, bh, names(CUT_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    return sliders(x, y, inner, CUT_SLIDERS, k, 'cut-')
end

local function drawCmykControls(x, y, inner, bh)
    local k = cmykSettings()
    buttonRow(x, y, inner, bh, names(CMYK_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, CMYK_MODES, function(i) return k.mode == i end, function(i) k.mode = i end)
    y = y + P.row
    return sliders(x, y, inner, CMYK_SLIDERS, k, 'cmyk-')
end

local function drawWoodControls(x, y, inner, bh)
    local k = woodSettings()
    buttonRow(x, y, inner, bh, names(WOOD_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, names(WOOD_INKS), function(i) return k.ink == i end, function(i) k.ink = i end)
    y = y + P.row
    return sliders(x, y, inner, WOOD_SLIDERS, k, 'wood-')
end

local function drawWaterControls(x, y, inner, bh)
    local k = waterSettings()
    buttonRow(x, y, inner, bh, names(WATER_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    return sliders(x, y, inner, WATER_SLIDERS, k, 'water-')
end

local function drawCopyControls(x, y, inner, bh)
    local k = copySettings()
    buttonRow(x, y, inner, bh, names(COPY_PAPERS), function(i) return k.paper == i end, function(i) k.paper = i end)
    y = y + P.row
    buttonRow(x, y, inner, bh, names(TONERS), function(i) return k.toner == i end, function(i) k.toner = i end)
    y = y + P.row
    return sliders(x, y, inner, COPY_SLIDERS, k, 'copy-')
end

function s.drawUI()
    local c = st()
    local sw, sh = ui.getDimensions()
    if c.view == 'textures' then drawSheet(sw, sh) end
    if not c.showPanel then return end
    ui.startFrame()
    local process = c.process or 'riso'
    local own = { riso = 3 + 1 + 2 + #SLIDERS, photocopy = 2 + #COPY_SLIDERS, watercolor = 1 + #WATER_SLIDERS,
        woodcut = 2 + #WOOD_SLIDERS, cmyk = 2 + #CMYK_SLIDERS, gouache = 1 + #GOUACHE_SLIDERS,
        cutpaper = 1 + #CUT_SLIDERS }
    local rows = 2 + own[process] + 2 + 2
    local w, h = P.w, P.row * rows + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• ' .. process .. ' ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local bh = P.row - 6
        -- two rows: print, then paint and paper
        local ROWS = { { { 'riso', 'riso' }, { 'photocopy', 'copy' }, { 'woodcut', 'wood' }, { 'cmyk', 'cmyk' } },
            { { 'watercolor', 'water' }, { 'gouache', 'gouache' }, { 'cutpaper', 'cut paper' } } }
        for _, row in ipairs(ROWS) do
            local labels = {}
            for i, item in ipairs(row) do labels[i] = item[2] end
            buttonRow(x, y, inner, bh, labels, function(i) return process == row[i][1] end,
                function(i) c.process = row[i][1] end)
            y = y + P.row
        end
        if process == 'photocopy' then y = drawCopyControls(x, y, inner, bh)
        elseif process == 'watercolor' then y = drawWaterControls(x, y, inner, bh)
        elseif process == 'woodcut' then y = drawWoodControls(x, y, inner, bh)
        elseif process == 'cmyk' then y = drawCmykControls(x, y, inner, bh)
        elseif process == 'gouache' then y = drawGouacheControls(x, y, inner, bh)
        elseif process == 'cutpaper' then y = drawCutControls(x, y, inner, bh)
        else y = drawRisoControls(c, x, y, inner, bh) end
        -- for all of them: boil, and the paper moving with the world
        c.boil = c.boil or 0
        y = sliders(x, y, inner, { { 'boil', 'boil (fps)', 0, 15, 1 } }, c, 'all-')
        local ac, av = ui.checkbox(x, y + 2, c.anchor ~= false, 'the paper moves with the world (scene)')
        if ac then c.anchor = av end
        y = y + P.row
        buttonRow(x, y, inner, bh, { 'textures', 'scene' }, function(_, n) return c.view == n end,
            function(_, n) c.view = n end)
        y = y + P.row
        ui.label(x, y + 5, 'space: the original   v view   h panel')
    end)
end

return s
