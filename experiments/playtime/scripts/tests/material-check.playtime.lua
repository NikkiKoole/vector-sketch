-- material-check: materials on Nikki's own drawings, under one light: metal, velvet, a leaf the light shines through, smoke
-- MATERIALS take two (docs/MATERIALS.md, 2026-11-06). The first spike made its materials from noise
-- alone and read as "computer"; here every material is one of the drawn pictures (outline + mask),
-- its roundness baked from the mask (src/render/form-bake.lua), and the material is only how that
-- roundness takes the light. Each row is the same picture, so the material is the only difference.
--   rows 1-2: a Mipo body shape as drawn | brass | tin | copper | velvet plum | velvet moss
--   row 3:    leaves (as drawn, then lit: from the front waxy, from behind the light comes through)
--   right:    smoke puffs (the body shapes as puffs), rising, growing, wearing away at the edges
-- The light is where the mouse is: in front of the pictures, or behind them (b).
-- keys:
--   b light in front / behind   f the light stays put / follows the mouse   c light: sun / candle / moon
--   p painted (the light in a few steps, like poster paint) / smooth   o outlines on / off
--   n another shape for rows 1-2   l other leaves   s smoke: steam / smoke / soot   w wind
--   m the bake's rise: dome / cushion / pebble (how round the shapes are)

local s = {}

local COLUMNS = { -1200, -750, -300, 150, 600, 1050 }
local ROWS = { -700, -230 }
local LEAF_ROW = 290
local CELL = 380 -- a picture's longer side, in world units
local SMOKE = { x = 1560, y = 760 }

-- what a cell is: the shader's mode and its colour
local MATERIALS = {
    { name = 'as drawn', mode = 0, base = { 0.86, 0.55, 0.42 } },
    { name = 'brass', mode = 1, base = { 0.95, 0.72, 0.3 } },
    { name = 'tin', mode = 1, base = { 0.78, 0.8, 0.85 } },
    { name = 'copper', mode = 1, base = { 0.93, 0.5, 0.32 } },
    { name = 'velvet plum', mode = 2, base = { 0.45, 0.12, 0.3 } },
    { name = 'velvet moss', mode = 2, base = { 0.22, 0.36, 0.14 } },
}
local SHAPES = { 'mipo/body/body-12', 'mipo/body/body-04', 'mipo/body/body-01', 'mipo/body/body-06',
    'mipo/body/body-15', 'mipo/body/body-17', 'mipo/patch/patch-01', 'mipo/patch/patch-03' }
local LEAF_SETS = {
    { 'plants/oval-02', 'plants/oval-04', 'plants/frond-01', 'plants/oval-03', 'plants/oval-01', 'plants/oval-05' },
    { 'plants/oval-03', 'plants/petal-02', 'plants/oval-02', 'plants/petal-05', 'plants/sprout-01', 'plants/oval-04' },
}
local LEAF_COLOURS = { { 0.36, 0.55, 0.18 }, { 0.3, 0.5, 0.22 }, { 0.42, 0.58, 0.16 }, { 0.5, 0.6, 0.2 },
    { 0.28, 0.46, 0.2 }, { 0.4, 0.52, 0.14 } }
local LIGHTS = {
    { name = 'sun', colour = { 1.0, 0.96, 0.88 }, ambient = { 0.42, 0.45, 0.52 }, wall = { 0.93, 0.88, 0.78 } },
    { name = 'candle', colour = { 1.0, 0.68, 0.36 }, ambient = { 0.22, 0.18, 0.2 }, wall = { 0.55, 0.42, 0.34 } },
    { name = 'moon', colour = { 0.66, 0.76, 1.0 }, ambient = { 0.12, 0.14, 0.24 }, wall = { 0.3, 0.33, 0.42 } },
}
local SMOKES = {
    { name = 'steam', colour = { 0.96, 0.96, 0.97 }, alpha = 0.55 },
    { name = 'smoke', colour = { 0.66, 0.64, 0.62 }, alpha = 0.7 },
    { name = 'soot', colour = { 0.2, 0.19, 0.19 }, alpha = 0.8 },
}
local PUFFS = { 'mipo/body/body-01', 'mipo/body/body-03', 'mipo/body/body-05', 'mipo/body/body-11',
    'mipo/body/body-13', 'mipo/body/body-16' }
local RISES = { { 'dome', 1 }, { 'cushion', 0.5 }, { 'pebble', 0.2 } }
local LIGHT_DEPTH = 420 -- how far in front of (or behind) the pictures the light is

local function lab()
    state.materialCheck = state.materialCheck or {
        back = false, frozen = false, light = 1, painted = false, outlines = true, shape = 1, leaves = 1,
        smoke = 1, wind = 0, rise = 1, puffs = {}, spawn = 0, lx = 0, ly = -900,
    }
    return state.materialCheck
end

---------------------------------------------------------------- the shader

local shader
local function materialShader()
    shader = shader or love.graphics.newShader([[
        uniform Image form;      // the baked roundness: r height, g b the normal's x y (0.5 flat)
        uniform vec3 toLight;    // in the picture's own frame (y down), normalised
        uniform vec3 lightColour;
        uniform vec3 ambient;
        uniform vec3 base;
        uniform float mode;      // 0 flat, 1 metal, 2 velvet, 3 leaf, 4 smoke
        uniform float bands;     // 0 smooth, else the light in this many steps
        uniform float seed;
        uniform float dissolve;  // smoke: 0 new, 1 gone
        uniform vec2 formTexel;  // one texel of the form map

        float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float vnoise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
        }
        float st(float x) { return bands > 0.5 ? floor(x * bands + 0.5) / bands : x; }

        vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
            vec4 m4 = Texel(tex, uv);
            float m = m4.r * m4.a;
            if (m < 0.01) return vec4(0.0);
            // the bake's normal has small steps (whole-texel distances) that a mirror shows as
            // stripes: averaged over a few texels around
            vec4 f = vec4(0.0);
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) f += Texel(form, uv + vec2(float(i), float(j)) * formTexel * 1.6);
            }
            f /= 9.0;
            float h = f.r;
            vec2 nxy = (f.gb - 0.5) * 2.0;
            vec3 n = normalize(vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy)))));
            vec3 L = normalize(toLight);
            float ndl = dot(n, L);
            vec3 col = base;
            float alpha = m;

            if (mode < 0.5) {
                col = base;
            } else if (mode < 1.5) {
                // metal: the room reflected (a bright sky above, a dark band at the horizon, the
                // warm floor below), lit by the lamp, and its highlight in the metal's own colour
                vec3 R = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
                float up = -R.y;
                float env = mix(0.42, 1.0, smoothstep(-0.05, 0.25, up));
                env -= 0.32 * (1.0 - smoothstep(0.0, 0.12, abs(up + 0.02)));
                env = mix(env, 0.6, 0.35 * n.z * n.z);
                float lit = st(clamp(0.45 + 0.55 * ndl, 0.0, 1.0));
                float spec = st(pow(max(dot(R, L), 0.0), 70.0)) * 1.5 + pow(max(dot(R, L), 0.0), 6.0) * 0.25;
                col = base * st(env) * (ambient * 0.6 + lightColour * lit) + spec * mix(base, vec3(1.0), 0.45) * lightColour;
            } else if (mode < 2.5) {
                // velvet: the middle soaks up the light, the edges where the pile lies over shine
                float wrap = max(0.0, (ndl + 0.4) / 1.4);
                float rim = pow(1.0 - n.z, 2.0);
                float side = 0.35 + 0.65 * max(0.0, dot(normalize(n.xy + 1e-4), normalize(L.xy + 1e-4)));
                float pile = 0.93 + 0.14 * hash(floor(uv * 260.0));
                float sheen = st(rim * side * (L.z < 0.0 ? 1.7 : 1.0));
                col = base * 0.55 * (ambient + st(wrap) * lightColour) * pile
                    + sheen * mix(base, vec3(1.0), 0.45) * lightColour * 0.9;
            } else if (mode < 3.5) {
                // leaf: from the front a soft waxy shine; from behind the light comes through,
                // most where it's thin (the edges), warmer and yellower than the leaf itself
                float back = clamp(-L.z * 2.0, 0.0, 1.0);
                float wrap = max(0.0, (ndl + 0.3) / 1.3);
                vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
                float wax = st(pow(max(dot(n, H), 0.0), 18.0)) * 0.3;
                vec3 front = base * (ambient + st(wrap) * lightColour) + wax * lightColour;
                float thin = 1.0 - 0.6 * h;
                vec3 glow = mix(base * 1.6, vec3(0.86, 0.95, 0.32), 0.45) * lightColour * st(thin);
                vec3 behind = base * ambient * 0.6 + glow;
                col = mix(front, behind, back);
            } else {
                // smoke: soft, light wrapped far round, wearing away from its edges as it goes;
                // from behind, its thin edges glow
                float wear = vnoise(uv * 5.0 + seed) * 0.55 + h * 0.75;
                alpha = m * smoothstep(dissolve - 0.12, dissolve + 0.12, wear);
                float back = clamp(-L.z * 2.0, 0.0, 1.0);
                float wrap = st(0.55 + 0.45 * ndl);
                float glow = st((1.0 - h) * back);
                col = base * (ambient * 0.8 + wrap * lightColour * (1.0 - 0.5 * back)) + glow * lightColour * 0.7;
            }
            return vec4(col, alpha) * colour;
        }
    ]])
    return shader
end

---------------------------------------------------------------- the pictures, baked once per rise

local looks = {}
local function lookOf(name)
    local rise = RISES[lab().rise][2]
    local key = name .. '|' .. rise
    if looks[key] == nil then
        local base = 'textures/' .. name
        if love.filesystem.getInfo(base .. '-mask.png', 'file') then
            local line = love.graphics.newImage(base .. '.png', { mipmaps = true })
            local mask = love.graphics.newImage(base .. '-mask.png', { mipmaps = true })
            line:setFilter('linear', 'linear')
            mask:setFilter('linear', 'linear')
            local form = love.graphics.newImage(formBake.bakeData(love.image.newImageData(base .. '-mask.png'), rise))
            form:setFilter('linear', 'linear')
            looks[key] = { line = line, mask = mask, form = form }
        else
            looks[key] = false
        end
    end
    return looks[key] or nil
end

local function lightColour()
    return LIGHTS[lab().light]
end

-- toward the light from (x, y), turned into the picture's frame (its rotation)
local function toLightFrom(x, y, rot)
    local c = lab()
    local dx, dy = c.lx - x, c.ly - y
    local dz = c.back and -LIGHT_DEPTH or LIGHT_DEPTH
    local ca, sa = math.cos(-(rot or 0)), math.sin(-(rot or 0))
    local rx, ry = dx * ca - dy * sa, dx * sa + dy * ca
    local len = math.sqrt(rx * rx + ry * ry + dz * dz)
    return { rx / len, ry / len, dz / len }
end

-- one picture in a material at (x, y), its longer side `size`
local function drawPicture(name, mode, base, x, y, size, opts)
    local look = lookOf(name)
    if not look then return end
    opts = opts or {}
    local c, L = lab(), lightColour()
    local w, h = look.mask:getDimensions()
    local scale = size / math.max(w, h)
    local rot = opts.rot or 0
    local sh = materialShader()
    love.graphics.setShader(sh)
    sh:send('form', look.form)
    local fw, fh = look.form:getDimensions()
    sh:send('formTexel', { 1 / fw, 1 / fh })
    sh:send('toLight', toLightFrom(x, y, rot))
    sh:send('lightColour', L.colour)
    sh:send('ambient', L.ambient)
    sh:send('base', base)
    sh:send('mode', mode)
    sh:send('bands', c.painted and 4 or 0)
    sh:send('seed', opts.seed or 0)
    sh:send('dissolve', opts.dissolve or 0)
    love.graphics.setColor(1, 1, 1, opts.alpha or 1)
    love.graphics.draw(look.mask, x, y, rot, scale, scale, w / 2, h / 2)
    love.graphics.setShader()
    if c.outlines then
        local ink = opts.ink or { 0.12, 0.09, 0.08 }
        love.graphics.setColor(ink[1], ink[2], ink[3], (opts.alpha or 1) * (opts.inkAlpha or 1))
        love.graphics.draw(look.line, x, y, rot, scale, scale, w / 2, h / 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------- smoke

local function updateSmoke(dt)
    local c = lab()
    c.spawn = c.spawn - dt
    if c.spawn <= 0 then
        c.spawn = 0.45 + love.math.random() * 0.25
        c.puffs[#c.puffs + 1] = {
            x = SMOKE.x + (love.math.random() - 0.5) * 40, y = SMOKE.y,
            vx = (love.math.random() - 0.5) * 30, vy = -(110 + love.math.random() * 50),
            age = 0, life = 6 + love.math.random() * 2.5, size = 190 + love.math.random() * 90,
            rot = love.math.random() * math.pi * 2, spin = (love.math.random() - 0.5) * 0.5,
            pic = PUFFS[love.math.random(#PUFFS)], seed = love.math.random() * 100,
            wobble = love.math.random() * 6.28,
        }
    end
    local keep = {}
    for _, p in ipairs(c.puffs) do
        p.age = p.age + dt
        if p.age < p.life then
            local t = p.age / p.life
            -- rising slows as it spreads; the wind takes more of it higher up
            p.x = p.x + (p.vx + c.wind * (40 + 160 * t) + math.sin(p.age * 0.9 + p.wobble) * 25) * dt
            p.y = p.y + p.vy * (1 - 0.55 * t) * dt
            p.rot = p.rot + p.spin * dt
            keep[#keep + 1] = p
        end
    end
    c.puffs = keep
end

local function drawSmoke()
    local c = lab()
    local kind = SMOKES[c.smoke]
    for _, p in ipairs(c.puffs) do
        local t = p.age / p.life
        local size = p.size * (0.5 + 1.6 * t)
        local fadeIn = math.min(1, p.age / 0.5)
        drawPicture(p.pic, 4, kind.colour, p.x, p.y, size, {
            rot = p.rot, seed = p.seed, dissolve = 0.3 + t ^ 1.2 * 0.85, alpha = kind.alpha * fadeIn,
            inkAlpha = 0.25 * (1 - t), ink = { kind.colour[1] * 0.4, kind.colour[2] * 0.4, kind.colour[3] * 0.4 },
        })
    end
end

---------------------------------------------------------------- the scene

function s.onStart()
    worldState.paused = false
    cam:setScale(0.27)
    cam:setTranslation(40, -130)
end

function s.onUnload()
    looks = {}
end

function s.update(dt)
    local c = lab()
    if not c.frozen then c.lx, c.ly = mouseWorldPos() end
    updateSmoke(dt or 0)
end

function s.onKeyPress(key)
    local c = lab()
    if key == 'b' then
        c.back = not c.back
    elseif key == 'f' then
        c.frozen = not c.frozen
    elseif key == 'c' then
        c.light = c.light % #LIGHTS + 1
    elseif key == 'p' then
        c.painted = not c.painted
    elseif key == 'o' then
        c.outlines = not c.outlines
    elseif key == 'n' then
        c.shape = c.shape % #SHAPES + 1
    elseif key == 'l' then
        c.leaves = c.leaves % #LEAF_SETS + 1
    elseif key == 's' then
        c.smoke = c.smoke % #SMOKES + 1
    elseif key == 'w' then
        c.wind = (c.wind == 0 and 1) or (c.wind == 1 and -1) or 0
    elseif key == 'm' then
        c.rise = c.rise % #RISES + 1
    end
end

-- the paper wall behind, in the light's mood
function s.drawBelow()
    local wall = lightColour().wall
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(wall[1], wall[2], wall[3], 1)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    love.graphics.setColor(1, 1, 1, 1)
end

local function label(text, x, y)
    local font = love.graphics.getFont()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.print(text, x - font:getWidth(text) * 1.25 + 3, y + 3, 0, 2.5, 2.5)
    love.graphics.setColor(1, 0.97, 0.9, 1)
    love.graphics.print(text, x - font:getWidth(text) * 1.25, y, 0, 2.5, 2.5)
end

local function drawLight()
    local c, L = lab(), lightColour()
    local r, g, b = L.colour[1], L.colour[2], L.colour[3]
    if c.back then
        love.graphics.setColor(r, g, b, 0.8)
        love.graphics.setLineWidth(6)
        love.graphics.circle('line', c.lx, c.ly, 40)
        love.graphics.setLineWidth(1)
    else
        for k = 4, 1, -1 do
            love.graphics.setColor(r, g, b, 0.12)
            love.graphics.circle('fill', c.lx, c.ly, 20 + k * 22)
        end
        love.graphics.setColor(r, g, b, 1)
        love.graphics.circle('fill', c.lx, c.ly, 22)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local c = lab()
    local shape = SHAPES[c.shape]
    local second = SHAPES[c.shape % #SHAPES + 1]
    for i, x in ipairs(COLUMNS) do
        local mat = MATERIALS[i]
        drawPicture(shape, mat.mode, mat.base, x, ROWS[1], CELL)
        drawPicture(second, mat.mode, mat.base, x, ROWS[2], CELL)
        label(mat.name, x, ROWS[1] - CELL / 2 - 70)
    end
    for i, x in ipairs(COLUMNS) do
        local leaf = LEAF_SETS[c.leaves][i]
        drawPicture(leaf, i == 1 and 0 or 3, LEAF_COLOURS[i], x, LEAF_ROW, CELL * 1.15)
    end
    label('leaf, as drawn', COLUMNS[1], LEAF_ROW + CELL * 0.6 + 20)
    label('leaf, lit (b: from behind)', (COLUMNS[2] + COLUMNS[6]) / 2, LEAF_ROW + CELL * 0.6 + 20)
    drawSmoke()
    label(SMOKES[c.smoke].name, SMOKE.x, SMOKE.y + 20)
    drawLight()
end

function s.drawUI()
    local c = lab()
    local lines = {
        'b light in front / behind   f light stays / follows the mouse   c sun / candle / moon   p painted   o outlines'
            .. '   n shape   l leaves   s steam / smoke / soot   w wind   m rise',
        string.format('light: %s, %s%s   %s   rise: %s   smoke: %s, wind %s   outlines %s',
            LIGHTS[c.light].name, c.back and 'behind' or 'in front', c.frozen and ' (stays)' or '',
            c.painted and 'painted in 4 steps' or 'smooth', RISES[c.rise][1], SMOKES[c.smoke].name,
            c.wind == 0 and 'still' or (c.wind > 0 and 'to the right' or 'to the left'), c.outlines and 'on' or 'off'),
    }
    for i, line in ipairs(lines) do
        local y = love.graphics.getHeight() - 20 - (#lines - i + 1) * 20
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(line, 121, y + 1)
        love.graphics.setColor(1, 0.95, 0.8, 1)
        love.graphics.print(line, 120, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return s
