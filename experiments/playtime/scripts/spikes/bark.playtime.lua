-- bark: tree trunks in real bark (15 scanned barks: colour, normal, height), lit by the mouse's light, crayon outlines
-- BARK.md (2026-11-08). Two rows of bare trees, each grown by its kind (KINDS: an oak's wide crooked
-- limbs, an elm's vase, a pine's whorls, aspens bare below), every branch wrapped in the bark as a round stem: the
-- bark squeezes toward the edges as it turns away, and its normal map takes the light on top of the
-- stem's own roundness. The barks are CC0 scans from ambientCG (textures/world/bark/bark-NN.jpg,
-- -normal, -height; 512 px). The outline is Nikki's crayon strokes (drawn-stroke.lua).
-- Three looks, to see how much of the photo the drawn world can take:
--   photo   the bark as photographed
--   tinted  the bark's light and dark in the tree's own colour (one colour, the photo's grain)
--   relief  a flat colour; only the bark's bumps and cracks take the light (the craft-table look)
-- keys:
--   v the look: photo / tinted / relief      p painted: the light in a few steps / smooth
--   o outlines on / off      c light: sun / candle / moon      f the light follows the mouse / stays
--   d bark detail (how strongly the bumps take the light): flat / soft / normal / deep
--   s the bark's size: small / middle / big      g what the shader sees: off / normals / light alone
--   e the eyes on / off (branch scars from photos: aspens and the birch have several, other trees now and then)
--   m Mipo eyes instead of the scars (the Mipos' own eye drawings, a round pupil), in the same places
-- the panel's 'organic' slider: 0 straight, even branches, 1 as tuned (slow turns, collars, bumpy edges), 2 wild;
-- 'wind': the wind the trees grew up in (-1 from the right .. 1 from the left): leaning, combed crowns;
-- 'sun': where their light came from (-1 left, 0 overhead, 1 right): they reach for it; 'crowd' 0..1: how
-- much they keep out of each other's space (crowded trees grow up, narrow); 'age' 0 a sapling, 1 grown, 2
-- ancient (bare lower trunk with eyes, broad sagging crown, broken stubs, a dead top)
-- The trees come from modules any scene can load (docs/BARK.md): tree-kinds.lua (how each kind grows),
-- tree-grow.lua (a kind + a seed -> branches), tree-mesh.lua (branches -> meshes, crayon outlines),
-- bark-look.lua (the bark pictures, the shader, the eyes). This scene is the layout, the panel, the light.
local s = {}

-- the trees and their bark, shared with any scene (docs/BARK.md): how each kind grows, the grower, the
-- meshes and outlines, the bark shader and eyes
local KINDS = love.filesystem.load('scripts/spikes/tree-kinds.lua')()
local treeGrow = love.filesystem.load('scripts/spikes/tree-grow.lua')()
local treeMesh = love.filesystem.load('scripts/spikes/tree-mesh.lua')()
local barkLook = love.filesystem.load('scripts/spikes/bark-look.lua')()

-- the two rows' ground lines (world y) and where they start; trunks every STEP
local ROWS = { { ground = 0, x = -3120, count = 9 }, { ground = 1750, x = -3120, count = 9 } }
local STEP = 780
local LOOKS = { 'photo', 'tinted', 'relief' }
local DETAILS = { { 'flat', 0 }, { 'soft', 0.6 }, { 'normal', 1.1 }, { 'deep', 2 } }
local SIZES = { { 'small', 220 }, { 'middle', 340 }, { 'big', 520 } } -- world units per bark picture's width
local LIGHTS = {
    { name = 'sun', colour = { 1.0, 0.95, 0.86 }, ambient = { 0.36, 0.38, 0.44 }, wall = { 0.9, 0.86, 0.76 },
        ground = { 0.55, 0.47, 0.34 } },
    { name = 'candle', colour = { 1.0, 0.66, 0.34 }, ambient = { 0.17, 0.14, 0.16 }, wall = { 0.5, 0.39, 0.32 },
        ground = { 0.33, 0.25, 0.18 } },
    { name = 'moon', colour = { 0.62, 0.72, 1.0 }, ambient = { 0.1, 0.12, 0.2 }, wall = { 0.27, 0.3, 0.4 },
        ground = { 0.17, 0.18, 0.24 } },
}
local DEBUGS = { 'off', 'normals', 'light alone' }

-- The trees: which bark, a name for it, how it grows (KINDS), its own lean, and the eyes (how many
-- branch-scar eyes, else one tree in three gets one; which kinds, the eye cells 1-3). tint: the colour for
-- tinted and relief, picked from the bark's photo; mirrored: a photo that doesn't tile, repeated
-- mirror-wise. size scales the whole tree (an old one low and wide).
local TREES = {
    { bark = 'aspen-01', name = 'aspen', kind = 'aspen', lean = -0.04, eyes = 5, kinds = { 1, 1, 1, 2 },
        mirrored = true, tint = { 0.88, 0.88, 0.84 } },
    { bark = '01', name = 'oak', kind = 'oak', lean = 0.03, tint = { 0.42, 0.4, 0.37 } },
    { bark = '02', name = 'elm', kind = 'elm', lean = 0.02, tint = { 0.52, 0.45, 0.35 } },
    { bark = '03', name = 'smooth brown', kind = 'beech', lean = -0.05, tint = { 0.55, 0.42, 0.3 } },
    { bark = '04', name = 'pine', kind = 'pine', lean = 0.0, tint = { 0.6, 0.5, 0.47 } },
    { bark = '06', name = 'lichen', kind = 'oak', lean = 0.07, size = 0.9, tint = { 0.55, 0.56, 0.58 } },
    { bark = '07', name = 'cracked', kind = 'elm', lean = -0.06, tint = { 0.66, 0.66, 0.5 } },
    { bark = '08', name = 'olive', kind = 'olive', lean = 0.05, tint = { 0.56, 0.5, 0.28 } },
    { bark = '09', name = 'plane', kind = 'plane', lean = -0.03, tint = { 0.8, 0.8, 0.66 } },
    { bark = 'birch-01', name = 'birch', kind = 'birch', lean = 0.05, eyes = 3, kinds = { 2, 3 },
        mirrored = true, tint = { 0.9, 0.89, 0.86 } },
    { bark = 'aspen-01', name = 'aspen', kind = 'aspen', lean = 0.03, eyes = 4, kinds = { 1, 1, 3 },
        mirrored = true, size = 0.9, tint = { 0.86, 0.87, 0.84 } },
    { bark = '10', name = 'beech', kind = 'beech', lean = 0.0, tint = { 0.58, 0.6, 0.53 } },
    { bark = '11', name = 'grey', kind = 'poplar', lean = 0.04, tint = { 0.62, 0.64, 0.6 } },
    { bark = '12', name = 'cork', kind = 'olive', lean = -0.04, size = 1.15, tint = { 0.56, 0.45, 0.28 } },
    { bark = '13', name = 'mossy', kind = 'oak', lean = -0.02, tint = { 0.47, 0.5, 0.33 } },
    { bark = '14', name = 'red', kind = 'pine', lean = -0.03, size = 0.95, tint = { 0.5, 0.33, 0.26 } },
    { bark = '15', name = 'striped', kind = 'beech', lean = 0.05, tint = { 0.55, 0.47, 0.33 } },
    { bark = '16', name = 'old mossy', kind = 'oak', lean = -0.05, size = 0.8, tint = { 0.4, 0.4, 0.3 } },
}

local function lab()
    state.barkSpike = state.barkSpike or { look = 1, painted = false, outlines = true, light = 1, frozen = false,
        detail = 3, size = 2, debug = 1, lx = 0, ly = -600, lightUp = 450 }
    if state.barkSpike.eyes == nil then state.barkSpike.eyes = true end -- added later: a live state lacks it
    state.barkSpike.organic = state.barkSpike.organic or 1
    state.barkSpike.wind = state.barkSpike.wind or 0
    state.barkSpike.sun = state.barkSpike.sun or 0
    state.barkSpike.crowd = state.barkSpike.crowd or 0
    state.barkSpike.age = state.barkSpike.age or 1
    return state.barkSpike
end

---------------------------------------------------------------- the trees

-- every tree grown and made into meshes once (again when the organic slider moves)
local built
local function build(env)
    built = { key = table.concat({ env.organic, env.wind, env.sun, env.crowd, env.age }, '|') }
    local i = 0
    for _, row in ipairs(ROWS) do
        for col = 1, row.count do
            i = i + 1
            local t = TREES[i]
            if not t then break end
            local k = KINDS[t.kind]
            local x0 = row.x + (col - 1) * STEP
            local rng = love.math.newRandomGenerator(i * 7919 + 13)
            -- the room to the next tree on each side: half the gap (none at a row's ends)
            local treeEnv = { organic = env.organic, wind = env.wind, sun = env.sun, crowd = env.crowd,
                age = env.age, left = col > 1 and STEP / 2 or nil, right = col < row.count and STEP / 2 or nil }
            local branches, aged = treeGrow.grow(k, rng, x0, row.ground, -math.pi / 2 + t.lean, t.size or 1,
                treeEnv)
            local tree = { def = t, x = x0, ground = row.ground, parts = treeMesh.parts(branches, i * 0.61),
                branchCount = #branches }
            tree.eyes, tree.mipoEyes = barkLook.placeEyes(t, aged, branches[1].pts, rng, env.age)
            built[#built + 1] = tree
        end
    end
end

---------------------------------------------------------------- the scene

local function overPanel()
    local r = lab().panelRect
    if not r or r.folded then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.onStart()
    worldState.paused = false
    cam:setScale(0.135)
    cam:setTranslation(0, 200)
    local c = lab()
    build({ organic = c.organic, wind = c.wind, sun = c.sun, crowd = c.crowd, age = c.age })
end

function s.onUnload()
    barkLook.reset()
    built = nil
end

function s.update()
    local c = lab()
    if not c.frozen and not overPanel() then c.lx, c.ly = mouseWorldPos() end
end

function s.onKeyPress(key)
    local c = lab()
    if key == 'v' then c.look = c.look % #LOOKS + 1
    elseif key == 'p' then c.painted = not c.painted
    elseif key == 'o' then c.outlines = not c.outlines
    elseif key == 'c' then c.light = c.light % #LIGHTS + 1
    elseif key == 'f' then c.frozen = not c.frozen
    elseif key == 'd' then c.detail = c.detail % #DETAILS + 1
    elseif key == 's' then c.size = c.size % #SIZES + 1
    elseif key == 'g' then c.debug = c.debug % #DEBUGS + 1
    elseif key == 'e' then c.eyes = not c.eyes
    elseif key == 'm' then c.mipoEyes = not c.mipoEyes
    end
end

-- the paper wall, the ground under each row
function s.drawBelow()
    local L = LIGHTS[lab().light]
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(L.wall[1], L.wall[2], L.wall[3], 1)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    for _, row in ipairs(ROWS) do
        love.graphics.setColor(L.ground[1], L.ground[2], L.ground[3], 1)
        love.graphics.rectangle('fill', x0, row.ground - 10, x1 - x0, 130)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function label(text, x, y)
    local font = love.graphics.getFont()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(text, x - font:getWidth(text) * 1.25 + 3, y + 3, 0, 2.5, 2.5)
    love.graphics.setColor(1, 0.97, 0.9, 1)
    love.graphics.print(text, x - font:getWidth(text) * 1.25, y, 0, 2.5, 2.5)
end

function s.draw()
    local c = lab()
    -- a regrow takes ~0.1 s: while a slider (organic, wind) moves, wait until it rests a moment
    local now = love.timer.getTime()
    local key = table.concat({ c.organic, c.wind, c.sun, c.crowd, c.age }, '|')
    if key ~= c.growSeen then c.growSeen, c.growAt = key, now end
    if not built or (built.key ~= key and now - (c.growAt or 0) > 0.15) then
        build({ organic = c.organic, wind = c.wind, sun = c.sun, crowd = c.crowd, age = c.age })
    end
    local L = LIGHTS[c.light]
    barkLook.begin({ lightPos = { c.lx, c.ly, c.lightUp }, lightColour = L.colour, ambient = L.ambient,
        detail = DETAILS[c.detail][2], look = c.look - 1, bands = c.painted and 4 or 0, debugView = c.debug - 1,
        barkWidth = SIZES[c.size][2] })
    local opts = { eyes = c.eyes, mipoEyes = c.mipoEyes, outlines = c.outlines }
    for _, tree in ipairs(built) do barkLook.drawTree(tree, opts) end
    for _, tree in ipairs(built) do
        local id = tree.def.bark
        label(id:match('^%d') and (id .. ' ' .. tree.def.name) or tree.def.name, tree.x, tree.ground + 30)
    end
    -- the light: a small sun where the mouse is
    love.graphics.setColor(L.colour[1], L.colour[2], L.colour[3], 0.9)
    love.graphics.circle('fill', c.lx, c.ly, 28)
    love.graphics.setColor(1, 1, 1, 1)
end

-- the panel: the keys as buttons and sliders
local PANEL = { w = 330, row = 36, pad = 6 }
function s.drawUI()
    local c = lab()
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local w, h = PANEL.w, PANEL.row * 12 + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    c.panelRect = { x0, y0, w, h, folded = ui.isPanelFolded('•• bark ••') }
    local half = (w - PANEL.pad * 3) / 2
    ui.panel(x0, y0, w, h, '•• bark ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local function cycle(x, y, text) return ui.button(x, y, half, text, PANEL.row - 6) end
        local function check(x, y, key, text)
            local clicked, v = ui.checkbox(x, y, c[key], text)
            if clicked then c[key] = v end
        end
        local x, y = row()
        if cycle(x, y, 'look: ' .. LOOKS[c.look]) then c.look = c.look % #LOOKS + 1 end
        if cycle(x + half + PANEL.pad, y, 'light: ' .. LIGHTS[c.light].name) then c.light = c.light % #LIGHTS + 1 end
        x, y = row()
        if cycle(x, y, 'detail: ' .. DETAILS[c.detail][1]) then c.detail = c.detail % #DETAILS + 1 end
        if cycle(x + half + PANEL.pad, y, 'size: ' .. SIZES[c.size][1]) then c.size = c.size % #SIZES + 1 end
        x, y = row()
        check(x, y, 'painted', 'painted')
        check(x + half + PANEL.pad, y, 'outlines', 'outlines')
        x, y = row()
        check(x, y, 'eyes', 'eyes')
        check(x + half + PANEL.pad, y, 'mipoEyes', 'mipo eyes')
        x, y = row()
        local followClicked, follow = ui.checkbox(x, y, not c.frozen, 'follows mouse')
        if followClicked then c.frozen = not follow end
        if cycle(x + half + PANEL.pad, y, 'sees: ' .. DEBUGS[c.debug]) then c.debug = c.debug % #DEBUGS + 1 end
        x, y = row()
        ui.label(x, y + 4, 'light out')
        local v = ui.sliderWithInput('bark-lightUp', x + 118, y - 2, 120, 60, 1500, c.lightUp, nil, 1)
        if v then c.lightUp = v + 0 end
        x, y = row()
        ui.label(x, y + 4, 'organic')
        local o = ui.sliderWithInput('bark-organic', x + 118, y - 2, 120, 0, 2, c.organic, nil, 0.05)
        if o then c.organic = o + 0 end
        x, y = row()
        ui.label(x, y + 4, 'wind')
        local wv = ui.sliderWithInput('bark-wind', x + 118, y - 2, 120, -1, 1, c.wind, nil, 0.05)
        if wv then c.wind = wv + 0 end
        x, y = row()
        ui.label(x, y + 4, 'sun')
        local sv = ui.sliderWithInput('bark-sun', x + 118, y - 2, 120, -1, 1, c.sun, nil, 0.05)
        if sv then c.sun = sv + 0 end
        x, y = row()
        ui.label(x, y + 4, 'crowd')
        local cv = ui.sliderWithInput('bark-crowd', x + 118, y - 2, 120, 0, 1, c.crowd, nil, 0.05)
        if cv then c.crowd = cv + 0 end
        x, y = row()
        ui.label(x, y + 4, 'age')
        local av = ui.sliderWithInput('bark-age', x + 118, y - 2, 120, 0, 2, c.age, nil, 0.05)
        if av then c.age = av + 0 end
    end)
end

return s
