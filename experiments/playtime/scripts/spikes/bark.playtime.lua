-- bark: tree trunks in real bark (15 scanned barks: colour, normal, height), lit by the mouse's light, crayon outlines
-- BARK.md (2026-11-08). The main stems only: two rows of trunks, each its own shape (tall and slim,
-- old and thick with roots flaring, leaning, bent) wrapped in one of the barks as a round stem: the
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
local s = {}

local STROKE = love.filesystem.load('scripts/spikes/drawn-stroke.lua')()

-- the two rows' ground lines (world y) and where they start; trunks every STEP
local ROWS = { { ground = 0, x = -1650 }, { ground = 1550, x = -1450 } }
local STEP = 470
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

-- The trees: which bark, a name for it, and the stem's shape. h height, w0 width at the ground (above
-- the flare), w1 at the top, flare (roots: how much wider at the very bottom), lean (sideways over the
-- whole height), bend (an S: sideways in the middle), branch (a stub: how far up, which side, how long).
-- tint: the colour for tinted and relief, picked from the bark's photo.
local TREES = {
    { bark = '01', name = 'oak', h = 1150, w0 = 270, w1 = 190, flare = 0.7, lean = 0, bend = 40,
        branch = { at = 0.72, side = -1, len = 330 }, tint = { 0.42, 0.4, 0.37 } },
    { bark = '02', name = 'elm', h = 1250, w0 = 190, w1 = 140, flare = 0.35, lean = 60, bend = -30,
        tint = { 0.52, 0.45, 0.35 } },
    { bark = '03', name = 'smooth brown', h = 1300, w0 = 150, w1 = 110, flare = 0.25, lean = -40, bend = 25,
        branch = { at = 0.6, side = 1, len = 260 }, tint = { 0.55, 0.42, 0.3 } },
    { bark = '04', name = 'pine', h = 1350, w0 = 170, w1 = 105, flare = 0.3, lean = 0, bend = 10,
        tint = { 0.6, 0.5, 0.47 } },
    { bark = '06', name = 'lichen', h = 1150, w0 = 210, w1 = 160, flare = 0.45, lean = 80, bend = -50,
        branch = { at = 0.55, side = 1, len = 300 }, tint = { 0.55, 0.56, 0.58 } },
    { bark = '07', name = 'cracked', h = 1250, w0 = 160, w1 = 120, flare = 0.3, lean = -60, bend = 0,
        tint = { 0.66, 0.66, 0.5 } },
    { bark = '08', name = 'olive', h = 1200, w0 = 230, w1 = 120, flare = 0.5, lean = 30, bend = 70,
        branch = { at = 0.8, side = -1, len = 240 }, tint = { 0.56, 0.5, 0.28 } },
    { bark = '09', name = 'plane', h = 1300, w0 = 180, w1 = 140, flare = 0.3, lean = -20, bend = -35,
        tint = { 0.8, 0.8, 0.66 } },
    { bark = '10', name = 'beech', h = 1300, w0 = 200, w1 = 160, flare = 0.55, lean = 0, bend = 15,
        branch = { at = 0.65, side = -1, len = 280 }, tint = { 0.58, 0.6, 0.53 } },
    { bark = '11', name = 'grey', h = 1250, w0 = 140, w1 = 100, flare = 0.2, lean = 70, bend = 20,
        tint = { 0.62, 0.64, 0.6 } },
    { bark = '12', name = 'cork', h = 1150, w0 = 250, w1 = 180, flare = 0.6, lean = -30, bend = -40,
        tint = { 0.56, 0.45, 0.28 } },
    { bark = '13', name = 'mossy', h = 1200, w0 = 230, w1 = 170, flare = 0.65, lean = 20, bend = 50,
        branch = { at = 0.5, side = 1, len = 320 }, tint = { 0.47, 0.5, 0.33 } },
    { bark = '14', name = 'red', h = 1300, w0 = 190, w1 = 130, flare = 0.4, lean = -50, bend = 0,
        tint = { 0.5, 0.33, 0.26 } },
    { bark = '15', name = 'striped', h = 1250, w0 = 200, w1 = 150, flare = 0.4, lean = 40, bend = -25,
        tint = { 0.55, 0.47, 0.33 } },
    { bark = '16', name = 'old mossy', h = 1100, w0 = 290, w1 = 200, flare = 0.8, lean = -10, bend = 60,
        branch = { at = 0.7, side = 1, len = 300 }, tint = { 0.4, 0.4, 0.3 } },
}

local function lab()
    state.barkSpike = state.barkSpike or { look = 1, painted = false, outlines = true, light = 1, frozen = false,
        detail = 3, size = 2, debug = 1, lx = 0, ly = -600, lightUp = 450 }
    return state.barkSpike
end

---------------------------------------------------------------- the barks

local barks = {}
local function barkOf(id)
    if barks[id] then return barks[id] end
    local function load(path)
        local image = love.graphics.newImage(path, { mipmaps = true })
        image:setWrap('repeat', 'repeat')
        image:setMipmapFilter('linear')
        image:setFilter('linear', 'linear', 8)
        return image
    end
    local base = 'textures/world/bark/bark-' .. id
    local b = { colour = load(base .. '.jpg'), normal = load(base .. '-normal.jpg'),
        height = load(base .. '-height.jpg') }
    -- its average brightness, for tinted (every bark as bright as its tint, whatever the photo's exposure)
    local data = love.image.newImageData(base .. '.jpg')
    local w, h = data:getDimensions()
    local sum, n = 0, 0
    for y = 0, h - 1, 16 do
        for x = 0, w - 1, 16 do
            local r, g, bl = data:getPixel(x, y)
            sum = sum + r * 0.3 + g * 0.59 + bl * 0.11
            n = n + 1
        end
    end
    b.meanLum = sum / n
    b.aspect = h / w
    barks[id] = b
    return b
end

---------------------------------------------------------------- the shader

-- A stem is a strip along its middle line. Per vertex: Across (-1 left edge .. 1 right edge, the stem's
-- radius there) and Frame (the way up the stem, x y; how far up it, along the line; a seed that turns
-- the bark round so neighbours differ). The fragment turns across into the angle round the stem
-- (asin), so the bark squeezes toward the edges and the stem's normal leans out there; the bark's
-- normal map tilts that normal, the light at the mouse lights it.
local barkShader = love.graphics.newShader([[
    attribute vec2 Across;
    attribute vec4 Frame;
    varying vec2 vAcross;
    varying vec4 vFrame;
    varying vec2 vWorld;
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        vAcross = Across;
        vFrame = Frame;
        vWorld = vertex_position.xy;
        return transform_projection * vertex_position;
    }
]], [[
    varying vec2 vAcross;
    varying vec4 vFrame;
    varying vec2 vWorld;
    uniform Image normalMap;
    uniform Image heightMap;
    uniform float barkWidth;   // world units per bark picture's width
    uniform float aspect;      // the picture's height / width
    uniform vec3 lightPos;     // world x, y, and how far in front of the trees
    uniform vec3 lightColour;
    uniform vec3 ambient;
    uniform float detail;
    uniform int look;          // 0 photo, 1 tinted, 2 relief
    uniform vec3 tint;
    uniform float meanLum;
    uniform float bands;       // 0 smooth, else the light in this many steps
    uniform int debugView;     // 0 off, 1 normals, 2 the light alone
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        float a = clamp(vAcross.x, -0.995, 0.995);
        float th = asin(a);
        float r = vAcross.y;
        vec2 uv = vec2(th * r / barkWidth + vFrame.w, -vFrame.z / (barkWidth * aspect));
        vec3 albedo = Texel(tex, uv).rgb;
        vec3 nm = Texel(normalMap, uv).rgb * 2.0 - 1.0;
        float h = Texel(heightMap, uv).r;
        // the stem's frame: across (round the stem), along (up it), out (toward us)
        vec3 N0 = vec3(sin(th), 0.0, cos(th));
        vec3 T = vec3(cos(th), 0.0, -sin(th));
        vec3 N = normalize(T * nm.x * detail + vec3(0.0, 1.0, 0.0) * nm.y * detail + N0 * max(nm.z, 0.3));
        // into the world: across is the strip's right, along its way up
        vec2 up = vFrame.xy;
        vec2 right = vec2(-up.y, up.x);
        vec3 Nw = vec3(right * N.x + up * N.y, N.z);
        vec3 L = normalize(vec3(lightPos.xy - vWorld, lightPos.z));
        float d = max(dot(Nw, L), 0.0);
        if (bands > 0.5) d = floor(d * bands + 0.5) / bands;
        // the cracks: darker deep in, more so in relief (no photo to carry them)
        float crack = smoothstep(0.0, 0.55, h);
        vec3 col;
        if (look == 0) {
            col = albedo;
            col *= mix(1.0, 0.75 + 0.25 * crack, detail * 0.4);
        } else if (look == 1) {
            float lum = dot(albedo, vec3(0.3, 0.59, 0.11));
            col = tint * clamp(lum / max(meanLum, 0.05), 0.0, 1.8);
        } else {
            col = tint * mix(1.0, 0.55 + 0.45 * crack, min(detail, 1.5) * 0.6);
        }
        vec3 light = ambient + lightColour * d * 1.1;
        if (debugView == 1) return vec4(Nw * 0.5 + 0.5, 1.0) * color.a;
        if (debugView == 2) return vec4(light * 0.8, 1.0) * color.a;
        return vec4(col * light, 1.0) * color.a;
    }
]])

---------------------------------------------------------------- the stems

local MESH_FORMAT = {
    { 'VertexPosition', 'float', 2 },
    { 'Across', 'float', 2 },
    { 'Frame', 'float', 4 },
}
local SEGMENTS = 48

-- the middle line from the ground up: points, the width at each, how far up it is
local function stemLine(t, x0, y0)
    local pts = {}
    for i = 0, SEGMENTS do
        local u = i / SEGMENTS
        local x = x0 + t.lean * u + t.bend * math.sin(u * math.pi) + t.bend * 0.3 * math.sin(u * math.pi * 2.3)
        local y = y0 - t.h * u
        local width = t.w0 + (t.w1 - t.w0) * u ^ 0.8
        width = width * (1 + t.flare * (1 - math.min(1, u * 7)) ^ 2) -- the roots flaring out at the foot
        pts[#pts + 1] = { x = x, y = y, w = width }
    end
    return pts
end

-- a stub: from a point on the stem, out and up, thinning
local function branchLine(t, stem)
    local b = t.branch
    local i0 = math.floor(b.at * SEGMENTS)
    local start = stem[i0 + 1]
    local w0 = start.w * 0.45
    local pts = {}
    local n = 16
    for i = 0, n do
        local u = i / n
        local x = start.x + b.side * (b.len * u + 20 * math.sin(u * 3))
        local y = start.y - b.len * 0.75 * u ^ 1.3
        pts[#pts + 1] = { x = x, y = y, w = w0 * (1 - 0.55 * u) }
    end
    return pts
end

-- the strip: two vertices per point, its way up and its length so far; the edges for the outline
local function stripMesh(pts, seed)
    local verts, left, right = {}, {}, {}
    local along = 0
    for i, p in ipairs(pts) do
        local a, b = pts[math.max(1, i - 1)], pts[math.min(#pts, i + 1)]
        local ux, uy = b.x - a.x, b.y - a.y
        local len = math.sqrt(ux * ux + uy * uy)
        ux, uy = ux / len, uy / len
        if i > 1 then
            local q = pts[i - 1]
            along = along + math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2)
        end
        local rx, ry = -uy, ux -- the strip's right (as the shader's)
        local half = p.w / 2
        verts[#verts + 1] = { p.x - rx * half, p.y - ry * half, -1, half, ux, uy, along, seed }
        verts[#verts + 1] = { p.x + rx * half, p.y + ry * half, 1, half, ux, uy, along, seed }
        left[#left + 1] = { p.x - rx * half, p.y - ry * half }
        right[#right + 1] = { p.x + rx * half, p.y + ry * half }
    end
    local mesh = love.graphics.newMesh(MESH_FORMAT, verts, 'strip', 'static')
    return mesh, left, right
end

-- every tree's meshes and outline, made once (the bark's size changes only the shader's numbers)
local built
local function build()
    built = {}
    local i = 0
    for r, row in ipairs(ROWS) do
        local count = r == 1 and 8 or 7
        for k = 1, count do
            i = i + 1
            local t = TREES[i]
            if not t then break end
            local x0 = row.x + (k - 1) * STEP
            local stem = stemLine(t, x0, row.ground)
            -- each part with its own outline, drawn in order (the branch, then the stem over it: the
            -- branch's outline where it goes into the stem is hidden behind it)
            local tree = { def = t, x = x0, ground = row.ground, parts = {} }
            local function add(pts, seed)
                local mesh, left, right = stripMesh(pts, seed)
                local w = 13
                tree.parts[#tree.parts + 1] = { mesh = mesh, lines = {
                    { pts = left, width = w },
                    { pts = right, width = w },
                    { pts = { left[#left], right[#right] }, width = w }, -- the cut across the top
                } }
            end
            if t.branch then add(branchLine(t, stem), i * 0.37 + 0.5) end
            add(stem, i * 0.61)
            built[#built + 1] = tree
        end
    end
    for _, tree in ipairs(built) do
        for _, part in ipairs(tree.parts) do part.strokes = STROKE.meshes(part.lines, 0.6, 0, true) end
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
    cam:setScale(0.24)
    cam:setTranslation(100, 300)
    build()
end

function s.onUnload()
    barks = {}
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
    if not built then build() end
    local c = lab()
    local L = LIGHTS[c.light]
    barkShader:send('lightPos', { c.lx, c.ly, c.lightUp })
    barkShader:send('lightColour', L.colour)
    barkShader:send('ambient', L.ambient)
    barkShader:send('detail', DETAILS[c.detail][2])
    barkShader:send('look', c.look - 1)
    barkShader:send('bands', c.painted and 4 or 0)
    barkShader:send('debugView', c.debug - 1)
    barkShader:send('barkWidth', SIZES[c.size][2])
    for _, tree in ipairs(built) do
        local b = barkOf(tree.def.bark)
        barkShader:send('normalMap', b.normal)
        barkShader:send('heightMap', b.height)
        barkShader:send('aspect', b.aspect)
        barkShader:send('meanLum', b.meanLum)
        barkShader:send('tint', tree.def.tint)
        for _, part in ipairs(tree.parts) do
            love.graphics.setShader(barkShader)
            love.graphics.setColor(1, 1, 1, 1)
            part.mesh:setTexture(b.colour)
            love.graphics.draw(part.mesh)
            love.graphics.setShader()
            if c.outlines then
                love.graphics.setColor(0.13, 0.1, 0.09, 1)
                for _, mesh in ipairs(part.strokes) do love.graphics.draw(mesh) end
            end
        end
    end
    for _, tree in ipairs(built) do
        label(tree.def.bark .. ' ' .. tree.def.name, tree.x, tree.ground + 30)
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
    local w, h = PANEL.w, PANEL.row * 6 + 34
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
        local followClicked, follow = ui.checkbox(x, y, not c.frozen, 'follows mouse')
        if followClicked then c.frozen = not follow end
        if cycle(x + half + PANEL.pad, y, 'sees: ' .. DEBUGS[c.debug]) then c.debug = c.debug % #DEBUGS + 1 end
        x, y = row()
        ui.label(x, y + 4, 'light out')
        local v = ui.sliderWithInput('bark-lightUp', x + 118, y - 2, 120, 60, 1500, c.lightUp, nil, 1)
        if v then c.lightUp = v + 0 end
    end)
end

return s
