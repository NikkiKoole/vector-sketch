-- glass: a spike for glass beads made from Nikki's own closed shapes (the Mipo parts' outline + mask), white outline, see-through glass
-- Every bead is one of the drawn OMP pictures (bodies, patches, rings, a heart): its mask is the
-- glass, its outline is drawn on top in white. The glass gets its roundness from the mask: how far
-- in from the edge a point is gives a height (baked once per picture, small), the height a normal.
-- With the normal the bead bends what's behind it (the paper wall, drawn into a canvas first),
-- tints it more where it's thicker, darkens and brightens at the rim, and gets a sharp highlight
-- from the top left and the light gathered on the far side. A tinted shadow on the wall behind.
-- The centre is partly clear, so a Mipo behind a bead still shows.
--
-- play mode (tab): drag the beads and Mipos about.
-- keys: b a bead at the mouse   m a Mipo   r new beads   p a pattern inside the glass (or off)
--       g glass / plain OMP (to compare)   w the wall   h the panel

local s = {}

local SOURCES = {
    'body/body-01', 'body/body-03', 'body/body-04', 'body/body-05', 'body/body-06', 'body/body-11',
    'body/body-12', 'body/body-13', 'body/body-14', 'body/body-15', 'body/body-16', 'body/body-17',
    'body/body-18', 'patch/patch-01', 'patch/patch-02', 'patch/patch-03', 'patch/patch-04',
    'eye/eye-06', 'eye/eye-07', 'nose/nose-02', 'foot/foot-07', 'leg/leg-06',
}
local GLASS = {
    { 0.95, 0.62, 0.15 }, -- amber
    { 0.18, 0.38, 0.92 }, -- cobalt
    { 0.15, 0.7, 0.42 },  -- green
    { 0.9, 0.16, 0.24 },  -- ruby
    { 0.55, 0.82, 0.9 },  -- aqua
    { 0.6, 0.32, 0.85 },  -- violet
    { 0.92, 0.94, 0.96 }, -- clear
    { 0.98, 0.5, 0.62 },  -- pink
}
local WALLS = {
    { base = { 0.96, 0.9, 0.72 }, line = { 0.85, 0.62, 0.45 } },
    { base = { 0.8, 0.88, 0.86 }, line = { 0.45, 0.62, 0.7 } },
    { base = { 0.93, 0.8, 0.84 }, line = { 0.7, 0.45, 0.55 } },
    { base = { 0.22, 0.22, 0.28 }, line = { 0.45, 0.42, 0.55 } },
}
local PATTERNS = { false, 'type0', 'type1', 'type2t', 'type3_', 'type4', 'type5', 'type6', 'type7', 'type8' } -- the Mipo look's (alpha)
local GROUND = { x = 0, w = 4200, h = 140 } -- its top at y = 0
local LIGHT = { -0.55, -0.83 }              -- towards the light, on the screen: the top left
local HMAP = 96                             -- the height bake's longer side, in texels

local function glass()
    state.glass = state.glass or {
        beads = {}, statics = {}, mipos = {}, wall = 1, pattern = 1, plain = false, showPanel = true,
        settings = { bend = 1, tint = 1, clear = 0.35, shine = 1, outline = 0.95, shadow = 1, offset = 42 },
    }
    -- added later: live states lack them
    local set = state.glass.settings
    set.offset = set.offset or 42
    set.lens, set.wave, set.waves = set.lens or 1, set.wave or 0.6, set.waves or 1.5
    return state.glass
end

local function pick(list) return list[love.math.random(#list)] end

---------------------------------------------------------------- the pictures, baked once

-- per picture: the outline and mask images, the height map, and a convex outline for the body
local looks = {}

local function hull(points)
    table.sort(points, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
    local function cross(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
    local lower, upper = {}, {}
    for _, p in ipairs(points) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do table.remove(lower) end
        lower[#lower + 1] = p
    end
    for i = #points, 1, -1 do
        local p = points[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do table.remove(upper) end
        upper[#upper + 1] = p
    end
    table.remove(lower); table.remove(upper)
    for _, p in ipairs(upper) do lower[#lower + 1] = p end
    return lower
end

-- drop the corner that adds the least area until there are at most n (Box2D takes 8)
local function simplify(poly, n)
    while #poly > n do
        local best, bestArea = 1, math.huge
        for i = 1, #poly do
            local a, b, c = poly[(i - 2) % #poly + 1], poly[i], poly[i % #poly + 1]
            local area = math.abs((b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]))
            if area < bestArea then best, bestArea = i, area end
        end
        table.remove(poly, best)
    end
    return poly
end

local function bake(name)
    if looks[name] ~= nil then return looks[name] or nil end
    local base = 'textures/mipo/' .. name
    if not love.filesystem.getInfo(base .. '-mask.png', 'file') then looks[name] = false; return nil end
    local line = love.graphics.newImage(base .. '.png', { mipmaps = true })
    local mask = love.graphics.newImage(base .. '-mask.png', { mipmaps = true })
    line:setFilter('linear', 'linear'); mask:setFilter('linear', 'linear')
    local data = love.image.newImageData(base .. '-mask.png')
    local iw, ih = data:getDimensions()
    local step = math.max(iw, ih) / HMAP
    local gw, gh = math.ceil(iw / step), math.ceil(ih / step)
    -- inside or not, on a small grid
    local inside, dist = {}, {}
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            -- the average over the cell: some masks are painted with a grainy brush
            local sum, n = 0, 0
            for sy = math.floor(gy * step), math.min(ih - 1, math.floor((gy + 1) * step) - 1), 2 do
                for sx = math.floor(gx * step), math.min(iw - 1, math.floor((gx + 1) * step) - 1), 2 do
                    sum = sum + data:getPixel(sx, sy); n = n + 1
                end
            end
            local k = gy * gw + gx
            inside[k] = n > 0 and sum / n > 0.3
            dist[k] = inside[k] and 1e9 or 0
        end
    end
    -- small holes (the grain) filled; big ones stay holes (a ring, the triangle frame)
    local seen = {}
    for start = 0, gw * gh - 1 do
        if not inside[start] and not seen[start] then
            local stack, comp, open = { start }, {}, false
            seen[start] = true
            while #stack > 0 do
                local k = table.remove(stack)
                comp[#comp + 1] = k
                local gx, gy = k % gw, math.floor(k / gw)
                if gx == 0 or gy == 0 or gx == gw - 1 or gy == gh - 1 then open = true end
                for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    local nx, ny = gx + d[1], gy + d[2]
                    local nk = ny * gw + nx
                    if nx >= 0 and ny >= 0 and nx < gw and ny < gh and not inside[nk] and not seen[nk] then
                        seen[nk] = true
                        stack[#stack + 1] = nk
                    end
                end
            end
            if not open and #comp < gw * gh * 0.03 then
                for _, k in ipairs(comp) do inside[k] = true; dist[k] = 1e9 end
            end
        end
    end
    -- how far in from the edge (a chamfer distance, two passes)
    local function at(gx, gy)
        if gx < 0 or gy < 0 or gx >= gw or gy >= gh then return 0 end
        return dist[gy * gw + gx]
    end
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            local k = gy * gw + gx
            if inside[k] then
                dist[k] = math.min(dist[k], at(gx - 1, gy) + 1, at(gx, gy - 1) + 1,
                    at(gx - 1, gy - 1) + 1.414, at(gx + 1, gy - 1) + 1.414)
            end
        end
    end
    local dmax = 1
    for gy = gh - 1, 0, -1 do
        for gx = gw - 1, 0, -1 do
            local k = gy * gw + gx
            if inside[k] then
                dist[k] = math.min(dist[k], at(gx + 1, gy) + 1, at(gx, gy + 1) + 1,
                    at(gx + 1, gy + 1) + 1.414, at(gx - 1, gy + 1) + 1.414)
                if dist[k] > dmax then dmax = dist[k] end
            end
        end
    end
    -- the height: round at the edge like a pebble, flatter on top; then smoothed once
    local rise = math.min(dmax, 14) -- texels from the edge to full height (a ring stays a ring)
    local height = {}
    for k = 0, gw * gh - 1 do
        local t = math.min(1, dist[k] / rise)
        height[k] = inside[k] and math.sqrt(1 - (1 - t) * (1 - t)) or 0
    end
    local function h(gx, gy)
        gx = math.max(0, math.min(gw - 1, gx)); gy = math.max(0, math.min(gh - 1, gy))
        return height[gy * gw + gx]
    end
    for _ = 1, 2 do
        local smooth = {}
        for gy = 0, gh - 1 do
            for gx = 0, gw - 1 do
                local sum = 0
                for oy = -1, 1 do for ox = -1, 1 do sum = sum + h(gx + ox, gy + oy) end end
                smooth[gy * gw + gx] = sum / 9
            end
        end
        height = smooth
    end
    -- the map: r the height, g b the normal's x y (0.5 is flat), a inside (the holes filled)
    local map = love.image.newImageData(gw, gh)
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            local dx = (h(gx + 1, gy) - h(gx - 1, gy)) * 0.5 * rise
            local dy = (h(gx, gy + 1) - h(gx, gy - 1)) * 0.5 * rise
            local len = math.sqrt(dx * dx + dy * dy + 1)
            map:setPixel(gx, gy, h(gx, gy), 0.5 - dx / len * 0.5, 0.5 - dy / len * 0.5,
                inside[gy * gw + gx] and 1 or 0)
        end
    end
    local hmap = love.graphics.newImage(map)
    hmap:setFilter('linear', 'linear')
    -- the lens: one wide smooth dome over the whole inside (the height above is a pebble's, flat
    -- on top), for how much the middle magnifies
    local lensData = love.image.newImageData(gw, gh)
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            local t = math.min(1, dist[gy * gw + gx] / dmax)
            local dome = inside[gy * gw + gx] and 1 - (1 - t) * (1 - t) or 0
            lensData:setPixel(gx, gy, dome, dome, dome, 1)
        end
    end
    local lensMap = love.graphics.newImage(lensData)
    lensMap:setFilter('linear', 'linear')
    -- the body: the convex outline of the inside's edge, in picture pixels from its centre
    local edge = {}
    for gy = 0, gh - 1 do
        for gx = 0, gw - 1 do
            local k = gy * gw + gx
            if inside[k] and (at(gx - 1, gy) == 0 or at(gx + 1, gy) == 0 or at(gx, gy - 1) == 0 or at(gx, gy + 1) == 0) then
                edge[#edge + 1] = { (gx + 0.5) * step - iw / 2, (gy + 0.5) * step - ih / 2 }
            end
        end
    end
    local outline = #edge >= 3 and simplify(hull(edge), 8) or nil
    local look = { line = line, mask = mask, hmap = hmap, lensMap = lensMap, w = iw, h = ih, outline = outline }
    looks[name] = look
    return look
end

---------------------------------------------------------------- shaders

local glassShader = love.graphics.newShader([[
uniform Image hmap;
uniform Image back;      // the wall behind, as on the screen
uniform Image pat;
uniform vec2 screen;     // pixels
uniform vec3 tint;
uniform vec2 lightDir;   // towards the light, on the screen
uniform float angle;     // the bead's turn, to bring its normal onto the screen
uniform float bend;      // how far the edge bends what's behind, in pixels
uniform float tintK;
uniform float clearK;
uniform float shine;
uniform float patOn;
uniform vec4 patCol;
uniform float patScale;
uniform Image lensMap;
uniform vec2 centre;     // the bead's middle, in pixels
uniform float lens;      // how much the middle magnifies (below 0 it shrinks)
uniform float wave;      // the funhouse mirror: bands stretched wide and squeezed thin
uniform float waves;     // how many bands across the bead

vec4 effect(vec4 color, Image mask, vec2 uv, vec2 pc) {
    // the mask, its grain filled in (some masks are painted with a grainy brush)
    float cov = max(smoothstep(0.02, 0.3, Texel(mask, uv).r), smoothstep(0.6, 0.95, Texel(hmap, uv).a));
    if (cov < 0.01) discard;
    vec4 hm = Texel(hmap, uv);
    float h = hm.r;
    vec2 nb = (hm.gb - 0.5) * 2.0;                    // the normal in the bead's frame
    float c = cos(angle), s = sin(angle);
    vec2 ns = vec2(nb.x * c - nb.y * s, nb.x * s + nb.y * c);
    float nz = sqrt(max(0.0, 1.0 - dot(ns, ns)));
    vec3 n = vec3(ns, nz);
    float edge = 1.0 - nz;                             // 0 on top, 1 at the rim

    // what's behind, bent: a lens pulls the far side in, so it shows upside down near the rim
    // the funhouse mirror: what's behind is looked at magnified, more in the middle, and
    // stretched in bands along the bead (wide here, thin there), in the bead's own frame
    float dome = Texel(lensMap, uv).r;
    vec2 d = pc - centre;
    vec2 dl = vec2(d.x * c + d.y * s, -d.x * s + d.y * c);
    float bandY = sin(uv.y * waves * 6.2832);
    float bandX = sin(uv.x * waves * 6.2832 + 1.7);
    float zx = max(0.25, 1.0 + lens * dome + wave * bandY * (0.3 + dome));
    float zy = max(0.25, 1.0 + lens * dome + wave * 0.6 * bandX * (0.3 + dome));
    dl /= vec2(zx, zy);
    vec2 look = centre + vec2(dl.x * c - dl.y * s, dl.x * s + dl.y * c);
    // and the rim bends it more: a lens pulls the far side in
    vec2 off = -ns * bend * (0.4 + 0.6 * h);
    vec3 behind = Texel(back, (look + off) / screen).rgb;
    // a pattern inside the glass, under its curve
    if (patOn > 0.5) {
        vec2 puv = uv * patScale + ns * 0.08;
        float pa = Texel(pat, puv).a * patCol.a * smoothstep(0.05, 0.4, h);
        behind = mix(behind, patCol.rgb, pa);
    }
    // thicker glass, more colour
    float thick = clamp(0.25 + h * 0.85, 0.0, 1.0) * tintK;
    vec3 col = behind * mix(vec3(1.0), tint, clamp(thick, 0.0, 1.0)) + tint * 0.06 * tintK;
    // the rim: darker where the light bounces away inside, a pale line right at the edge
    float fres = pow(edge, 2.2);
    col *= mix(1.0, 0.55, fres * 0.9);
    col += vec3(1.0) * pow(edge, 6.0) * 0.35 * shine;
    // light gathered on the far side from the light (the caustic)
    vec2 ld = normalize(lightDir);
    float far = max(0.0, dot(normalize(ns + 1e-4), -ld));
    col += mix(tint, vec3(1.0), 0.35) * far * smoothstep(0.1, 0.6, edge) * smoothstep(1.0, 0.7, edge) * 0.55 * shine;
    // the highlight: a sharp one and a soft one, from the top left
    vec3 L = normalize(vec3(ld, 0.9));
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
    float nh = max(0.0, dot(n, H));
    col += vec3(1.0) * (pow(nh, 90.0) * 1.1 + pow(nh, 12.0) * 0.12) * shine;
    // see-through in the middle, so what's in front of the wall (a Mipo) still shows
    float a = cov * (1.0 - clearK * smoothstep(0.3, 0.9, h) * (1.0 - fres));
    return vec4(col, a) * color;
}
]])

-- a mask picture as a shape: its red is how much is inside
local maskShader = love.graphics.newShader([[
vec4 effect(vec4 color, Image mask, vec2 uv, vec2 pc) {
    return vec4(color.rgb, color.a * smoothstep(0.02, 0.3, Texel(mask, uv).r));
}
]])

---------------------------------------------------------------- bodies

local function alive(list)
    local out = {}
    for _, t in ipairs(list) do
        if t.body and not t.body:isDestroyed() then out[#out + 1] = t end
    end
    return out
end

local function aliveMipos(b)
    local out = {}
    for _, inst in ipairs(b.mipos) do
        local torso = inst.parts and inst.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then out[#out + 1] = inst end
    end
    return out
end

local function addBead(b, x, y, name)
    name = name or pick(SOURCES)
    local look = bake(name)
    if not (look and look.outline) then return end
    local size = 170 + love.math.random() * 150
    local scale = size / math.max(look.w, look.h)
    local verts = {}
    for _, p in ipairs(look.outline) do
        verts[#verts + 1] = p[1] * scale; verts[#verts + 1] = p[2] * scale
    end
    local cx, cy = mathutils.computeCentroid(verts)
    for i = 1, #verts, 2 do verts[i] = verts[i] - cx; verts[i + 1] = verts[i + 1] - cy end
    local thing = objectManager.addThing('custom', { x = x, y = y, vertices = verts, bodyType = 'dynamic',
        label = 'glass-bead', density = 0.5 })
    if not thing then return end
    for _, fixture in ipairs(thing.body:getFixtures()) do
        fixture:setFriction(0.4); fixture:setRestitution(0.25)
    end
    thing.body:setAngle((love.math.random() - 0.5) * 1.2)
    b.beads[#b.beads + 1] = { body = thing.body, name = name, scale = scale, ox = -cx, oy = -cy,
        tint = pick(GLASS) }
end

local function stock(b)
    for _, t in ipairs(alive(b.beads)) do objectManager.destroyBody(t.body) end
    b.beads = {}
    for i = 1, 18 do addBead(b, -1500 + (i % 9) * 360, -900 - math.floor(i / 9) * 420) end
end

local function staticBox(b, x, y, w, h)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'static', label = 'glass-table' })
    if thing then
        for _, fixture in ipairs(thing.body:getFixtures()) do fixture:setFriction(0.8) end
        b.statics[#b.statics + 1] = { body = thing.body }
    end
end

local function buildTable(b)
    if #alive(b.statics) > 0 then return end
    b.statics = {}
    staticBox(b, GROUND.x, GROUND.h / 2, GROUND.w, GROUND.h)
    staticBox(b, GROUND.x - GROUND.w / 2 - 20, -1200, 40, 2400)
    staticBox(b, GROUND.x + GROUND.w / 2 + 20, -1200, 40, 2400)
end

local function spawnMipo(b, x, y)
    local inst = characterManager.createCharacter('humanoid', x, y, 0.3)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    if inst then b.mipos[#b.mipos + 1] = inst end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = glass()
    buildTable(b)
    b.beads = alive(b.beads)
    if #b.beads == 0 then stock(b) end
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then spawnMipo(b, -300, -1400) end
end

function s.onUnload()
    local b = state.glass
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = glass()
    local mx, my = mouseWorldPos()
    if key == 'b' then addBead(b, mx, my)
    elseif key == 'm' then spawnMipo(b, mx, my)
    elseif key == 'r' then stock(b)
    elseif key == 'p' then b.pattern = b.pattern % #PATTERNS + 1
    elseif key == 'g' then b.plain = not b.plain
    elseif key == 'w' then b.wall = b.wall % #WALLS + 1
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

---------------------------------------------------------------- drawing

local backCanvas
local patImages = {}
local function patImage(name)
    if not name then return nil end
    if not patImages[name] then
        local img = love.graphics.newImage('textures/pat/' .. name .. '.png')
        img:setWrap('mirroredrepeat', 'mirroredrepeat')
        patImages[name] = img
    end
    return patImages[name]
end

-- the picture behind the glass: the wall, the table, the Mipos, as on the screen. Same size and
-- antialiasing as the window, so the Mipos look the same drawn through it.
local function backdrop()
    local pw, ph = love.graphics.getPixelDimensions()
    local w, h = love.graphics.getDimensions()
    local _, _, flags = love.window.getMode()
    local msaa = flags.msaa or 0
    if not backCanvas or backCanvas:getPixelWidth() ~= pw or backCanvas:getPixelHeight() ~= ph then
        if backCanvas then backCanvas:release() end
        backCanvas = love.graphics.newCanvas(w, h, { msaa = msaa })
    end
    return backCanvas
end

-- the wall: paper with stripes and dots, so the glass has something to bend
local function drawWall(b)
    local wall = WALLS[b.wall]
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getDimensions())
    love.graphics.setColor(wall.base)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    love.graphics.setColor(wall.line[1], wall.line[2], wall.line[3], 0.55)
    local stripe = 90
    for x = math.floor(x0 / (stripe * 2)) * stripe * 2, x1, stripe * 2 do
        love.graphics.rectangle('fill', x, y0, stripe * 0.35, y1 - y0)
    end
    love.graphics.setColor(wall.line[1], wall.line[2], wall.line[3], 0.8)
    local grid = 180
    for y = math.floor(y0 / grid) * grid, math.min(y1, 0), grid do
        for x = math.floor(x0 / grid) * grid, x1, grid do
            love.graphics.circle('fill', x + grid / 2, y + grid / 2, 22)
        end
    end
end

-- the table, in front of the wall and the shadows on it
local function drawTable()
    local _, y1 = cam:getWorldCoordinates(love.graphics.getDimensions())
    love.graphics.setColor(0.62, 0.45, 0.32)
    love.graphics.rectangle('fill', GROUND.x - GROUND.w / 2, 0, GROUND.w, math.max(GROUND.h, y1))
    love.graphics.setColor(0.75, 0.58, 0.42)
    love.graphics.rectangle('fill', GROUND.x - GROUND.w / 2, 0, GROUND.w, 18)
end

-- each bead's shadow on the wall: its shape, tinted with its glass, a little down and right
local function drawShadows(b)
    love.graphics.setShader(maskShader)
    local k = b.settings.shadow
    local off = b.settings.offset -- how far the wall is behind the beads: the shadow's distance, away from the light
    for _, t in ipairs(b.beads) do
        local look = bake(t.name) -- a hot reload of this file empties the cache
        if look then
            local x, y = t.body:getPosition()
            local a = t.body:getAngle()
            local ca, sa = math.cos(a), math.sin(a)
            local cx, cy = x + t.ox * ca - t.oy * sa, y + t.ox * sa + t.oy * ca
            local c = t.tint
            love.graphics.setColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.6, 0.32 * k)
            love.graphics.draw(look.mask, cx - LIGHT[1] * off, cy - LIGHT[2] * off, a, t.scale, t.scale, look.w / 2, look.h / 2)
        end
    end
    love.graphics.setShader()
end

local function drawBead(b, t, outlineAlpha)
    local look = bake(t.name)
    if not look then return end
    local x, y = t.body:getPosition()
    local a = t.body:getAngle()
    local ca, sa = math.cos(a), math.sin(a)
    local cx, cy = x + t.ox * ca - t.oy * sa, y + t.ox * sa + t.oy * ca
    if b.plain then
        love.graphics.setShader(maskShader)
        love.graphics.setColor(t.tint)
        love.graphics.draw(look.mask, cx, cy, a, t.scale, t.scale, look.w / 2, look.h / 2)
        love.graphics.setShader()
    else
        love.graphics.setShader(glassShader)
        glassShader:send('hmap', look.hmap)
        glassShader:send('lensMap', look.lensMap)
        local sx, sy = cam:getScreenCoordinates(cx, cy)
        local dpi = love.graphics.getDPIScale()
        glassShader:send('centre', { sx * dpi, sy * dpi })
        glassShader:send('tint', t.tint)
        glassShader:send('angle', a)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(look.mask, cx, cy, a, t.scale, t.scale, look.w / 2, look.h / 2)
        love.graphics.setShader()
    end
    love.graphics.setColor(1, 1, 1, outlineAlpha)
    love.graphics.draw(look.line, cx, cy, a, t.scale, t.scale, look.w / 2, look.h / 2)
end

function s.drawBelow()
    local b = state.glass
    if not b then return end
    b.beads = alive(b.beads)
    -- the wall, the shadows and the table into a canvas (as on the screen), and the canvas stays
    -- on: the game draws the Mipos and the other bodies into it too, so the glass can bend them.
    -- s.draw puts it on the screen. (A Mipo part baked mid-frame sets the screen back; that frame
    -- the Mipos drawn after it miss the canvas: a flicker at most.)
    local canvas = backdrop()
    b.before = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvas, stencil = true }) -- the mouths clip with a stencil
    love.graphics.clear(0, 0, 0, 1)
    drawWall(b)
    drawShadows(b)
    drawTable()
    -- the Mipos draw themselves; the plain outlines of our beads would show
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.glass
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    -- everything so far onto the screen; the beads go over it, bending it
    love.graphics.setCanvas(b.before)
    b.before = nil
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(backCanvas, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.pop()
    local set = b.settings
    local pw, ph = love.graphics.getPixelDimensions()
    local dpi = love.graphics.getDPIScale()
    glassShader:send('back', backCanvas)
    glassShader:send('screen', { pw, ph })
    glassShader:send('lightDir', LIGHT)
    glassShader:send('bend', 34 * set.bend * cam:getScale() / 0.35 * dpi)
    glassShader:send('tintK', set.tint)
    glassShader:send('clearK', set.clear)
    glassShader:send('shine', set.shine)
    glassShader:send('lens', set.lens)
    glassShader:send('wave', set.wave)
    glassShader:send('waves', set.waves)
    local pat = patImage(PATTERNS[b.pattern])
    glassShader:send('patOn', pat and 1 or 0)
    if pat then
        glassShader:send('pat', pat)
        glassShader:send('patCol', { 1, 1, 1, 0.55 })
        glassShader:send('patScale', 2.5)
    end
    for _, t in ipairs(b.beads) do drawBead(b, t, set.outline) end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.glass and glass()
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'bend', 0, 3 }, { 'tint', 0, 2 }, { 'clear', 0, 1 }, { 'shine', 0, 2 },
        { 'outline', 0, 1 }, { 'shadow', 0, 2 }, { 'offset', 0, 150 },
        { 'lens', -0.8, 3 }, { 'wave', 0, 1.5 }, { 'waves', 0.25, 4 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• glass ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('glass' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, (b.plain and 'plain OMP' or 'glass') .. ' (g)  pattern ' ..
            tostring(PATTERNS[b.pattern] or 'off') .. ' (p)  wall (w)')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'b bead  m Mipo  r new beads  h panel')
    end)
end

return s
