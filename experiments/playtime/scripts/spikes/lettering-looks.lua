-- lettering-looks: the hand-drawn letters (src/lettering.lua) dressed up: a pseudo-3D graffiti look and friends
-- (Nikki 2026-11-12: "do some pixel joy with them, like a pseudo 3d graffiti outline ... as an option,
-- tweakable"). The lettering spike's reusable part, loaded with
-- love.filesystem.load('scripts/spikes/lettering-looks.lua')()(lettering).
--
--   looks.draw(text, x, y, opts, look) -> width, height   (x, y: the text's top left, as lettering.draw)
--   looks.LOOKS: name -> look, looks.NAMES: their order
--   looks.TWEAKS: the sliders; looks.defaults(name) -> slider values; looks.tweaked(name, values) -> a look
--
-- How: the text is drawn white into a canvas (the mask). The mask stamped in rings around itself makes the
-- band shape (the letters plus the band round them), and that again, a little wider, the rim (band plus a
-- thin line). On screen, back to front: a soft drop shadow; the rim swept along the depth direction in the
-- line colour (the whole 3D block's silhouette with its edge); the band shape swept inside it, light near the
-- front and dark at the back (the block's sides); the band at the front; then the face through a shader: a
-- three-stop gradient top to bottom, a light rim on the edges facing the light and a dark one on the others
-- (the mask against itself shifted: a bevel); last a few sparkles.
-- The canvases are drawn again every frame (boiling letters change), kept per text, so made only once.
return function(lettering)
    local looks = {}

    local function hex(h, a)
        h = h:gsub('#', '')
        return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255,
            a or 1 }
    end

    -- band (the outline round the face), line (the thin edge round it all), depth, shadow: parts of the size.
    -- dir: the extrusion's direction (down right). near/far: the block's sides, front to back.
    looks.LOOKS = {
        graffiti = { top = hex('ffe14d'), mid = hex('ff9a3c'), bottom = hex('ff3d8b'), band = hex('fff6e0'),
            bandW = 0.06, line = hex('1a0f2e'), lineW = 0.025, near = hex('8a4fd0'), far = hex('2b1250'),
            depth = 0.18, dir = { 0.55, 1 }, hi = hex('ffffff', 0.9), lo = hex('8a1050', 0.6), bevel = 0.035,
            shadow = 0.25, sparkles = 3 },
        candy = { top = hex('bff4ff'), mid = hex('5cc8ff'), bottom = hex('3a6bff'), band = hex('ffffff'),
            bandW = 0.07, line = hex('0b1a4a'), lineW = 0.02, near = hex('3a5fcf'), far = hex('0b1a4a'),
            depth = 0.12, dir = { 0.3, 1 }, hi = hex('ffffff', 1), lo = hex('1a2f99', 0.5), bevel = 0.04,
            shadow = 0.2, sparkles = 2 },
        chrome = { top = hex('ffffff'), mid = hex('6f7f99'), bottom = hex('e9eef5'), band = hex('2a3140'),
            bandW = 0.045, line = hex('06080c'), lineW = 0.02, near = hex('8a95a8'), far = hex('1a1f28'),
            depth = 0.12, dir = { 0.8, 1 }, hi = hex('ffffff', 1), lo = hex('202838', 0.6), bevel = 0.03,
            shadow = 0.2, sparkles = 4 },
        magnet = { top = hex('ff5a4a'), mid = hex('e8352a'), bottom = hex('c4221c'), band = hex('e8352a'),
            bandW = 0, line = hex('5c0d0a'), lineW = 0, near = hex('a81c16'), far = hex('5c0d0a'),
            depth = 0.08, dir = { 0.35, 1 }, hi = hex('ffd0c8', 0.8), lo = hex('600c08', 0.45), bevel = 0.03,
            shadow = 0.3, sparkles = 0 },
        gold = { top = hex('fff2b0'), mid = hex('f2c14e'), bottom = hex('b8781a'), band = hex('5a3510'),
            bandW = 0.04, line = hex('1f1206'), lineW = 0.015, near = hex('c98b2a'), far = hex('4a2a08'),
            depth = 0.1, dir = { 0, 1 }, hi = hex('fffbe6', 1), lo = hex('5a3208', 0.5), bevel = 0.03,
            shadow = 0.15, sparkles = 2 },
        toxic = { top = hex('eaff6b'), mid = hex('7dff4f'), bottom = hex('1fbf6a'), band = hex('101010'),
            bandW = 0.07, line = hex('101010'), lineW = 0.02, near = hex('ff3dd2'), far = hex('5a0f63'),
            depth = 0.22, dir = { -0.6, 1 }, hi = hex('ffffff', 0.85), lo = hex('0a5a3a', 0.6), bevel = 0.035,
            shadow = 0, sparkles = 3 },
    }
    looks.NAMES = { 'graffiti', 'candy', 'chrome', 'magnet', 'gold', 'toxic' }

    -- the sliders: { key, label, min, max, step }. angle: the extrusion's direction in degrees from straight
    -- down (positive: to the right); hue: every colour of the look turned round the colour wheel.
    looks.TWEAKS = { { 'bandW', 'band', 0, 0.2, 0.005 }, { 'lineW', 'line', 0, 0.08, 0.005 },
        { 'depth', 'depth', 0, 0.5, 0.01 }, { 'angle', 'angle', -90, 90, 1 }, { 'bevel', 'bevel', 0, 0.08, 0.005 },
        { 'shadow', 'shadow', 0, 0.6, 0.02 }, { 'sparkles', 'sparkles', 0, 6, 1 }, { 'hue', 'hue', 0, 360, 1 } }

    -- a look's numbers as slider values
    function looks.defaults(name)
        local l = looks.LOOKS[name]
        return { bandW = l.bandW, lineW = l.lineW, depth = l.depth, bevel = l.bevel, shadow = l.shadow,
            sparkles = l.sparkles, angle = math.floor(math.deg(math.atan2(l.dir[1], l.dir[2])) + 0.5), hue = 0 }
    end

    local function hueRotate(c, deg)
        if not c or deg == 0 then return c end
        local a = math.rad(deg)
        local co, si = math.cos(a), math.sin(a)
        local r, g, b = c[1], c[2], c[3]
        local function cl(v) return math.max(0, math.min(1, v)) end
        return { cl(r * (0.213 + 0.787 * co - 0.213 * si) + g * (0.715 - 0.715 * co - 0.715 * si)
            + b * (0.072 - 0.072 * co + 0.928 * si)),
            cl(r * (0.213 - 0.213 * co + 0.143 * si) + g * (0.715 + 0.285 * co + 0.140 * si)
                + b * (0.072 - 0.072 * co - 0.283 * si)),
            cl(r * (0.213 - 0.213 * co - 0.787 * si) + g * (0.715 - 0.715 * co + 0.715 * si)
                + b * (0.072 + 0.928 * co + 0.072 * si)), c[4] }
    end

    -- the look `name` with the slider values `t` on it
    function looks.tweaked(name, t)
        local l = looks.LOOKS[name]
        if not l then return nil end
        local out = {}
        for k, v in pairs(l) do out[k] = v end
        for k, v in pairs(t or {}) do out[k] = v end
        if out.angle then
            local a = math.rad(out.angle)
            out.dir = { math.sin(a), math.cos(a) }
        end
        local hue = t and t.hue or 0
        for _, k in ipairs({ 'top', 'mid', 'bottom', 'band', 'line', 'near', 'far', 'hi', 'lo' }) do
            out[k] = hueRotate(out[k], hue)
        end
        return out
    end

    local FACE = love.graphics.newShader([[
        extern vec4 top; extern vec4 mid; extern vec4 bottom;
        extern vec4 hi; extern vec4 lo;
        extern vec2 off;
        extern vec2 band;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            float a = Texel(tex, uv).a;
            float t = clamp((uv.y - band.x) / (band.y - band.x), 0.0, 1.0);
            vec3 c = t < 0.5 ? mix(top.rgb, mid.rgb, t * 2.0) : mix(mid.rgb, bottom.rgb, t * 2.0 - 1.0);
            float h = a * (1.0 - Texel(tex, uv - off).a);
            float l = a * (1.0 - Texel(tex, uv + off).a);
            c = mix(c, lo.rgb, l * lo.a);
            c = mix(c, hi.rgb, h * hi.a);
            return vec4(c * a, a) * color.a;
        }
    ]])

    local cache = {}

    local function canvases(key, w, h)
        local e = cache[key]
        if e and e.w == w and e.h == h then return e end
        e = { w = w, h = h, mask = love.graphics.newCanvas(w, h), shape = love.graphics.newCanvas(w, h),
            rim = love.graphics.newCanvas(w, h) }
        cache[key] = e
        return e
    end

    -- `from` stamped into `to` at itself and in rings round it out to radius r (premultiplied, white)
    local function grow(from, to, r)
        love.graphics.setCanvas(to)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.draw(from, 0, 0)
        if r <= 0 then return end
        local rings = math.max(1, math.ceil(r / 3))
        for ring = 1, rings do
            local rr = r * ring / rings
            local n = math.max(8, math.ceil(rr * 2))
            for i = 0, n - 1 do
                local ang = i / n * math.pi * 2
                love.graphics.draw(from, math.cos(ang) * rr, math.sin(ang) * rr)
            end
        end
    end

    -- a premultiplied tint for drawing a white canvas
    local function tint(c, k)
        local a = (c[4] or 1) * (k or 1)
        love.graphics.setColor(c[1] * a, c[2] * a, c[3] * a, a)
    end

    local function mixed(a, b, t)
        return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
    end

    -- a four-pointed star as a fan of triangles (LÖVE fills only convex polygons)
    local function star(x, y, r)
        local pts = {}
        for i = 0, 7 do
            local ang = i * math.pi / 4 - math.pi / 2
            local rr = i % 2 == 0 and r or r * 0.25
            pts[#pts + 1] = { x + math.cos(ang) * rr, y + math.sin(ang) * rr }
        end
        for i = 1, 8 do
            local p, q = pts[i], pts[i % 8 + 1]
            love.graphics.polygon('fill', x, y, p[1], p[2], q[1], q[2])
        end
    end

    function looks.draw(text, x, y, opts, look)
        if type(look) == 'string' then look = looks.LOOKS[look] end
        if not look then return lettering.draw(text, x, y, opts) end
        local size = opts.size or 48
        local tw, th = lettering.measure(text, opts)
        local bandW = math.max(0, look.bandW * size)
        local lineW = math.max(0, look.lineW * size)
        local dl = math.sqrt(look.dir[1] ^ 2 + look.dir[2] ^ 2)
        local dx, dy = look.dir[1] / dl, look.dir[2] / dl
        local depth = look.depth * size
        local pad = math.ceil(bandW + lineW + size * 0.2)
        local w, h = math.ceil(tw + pad * 2), math.ceil(th + pad * 2)
        local e = canvases(text .. '|' .. (opts.font or 'comic') .. '|' .. size, w, h)

        love.graphics.push('all')
        love.graphics.origin()
        love.graphics.setShader()
        love.graphics.setCanvas(e.mask)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        lettering.draw(text, pad, pad, opts)
        love.graphics.setBlendMode('alpha', 'premultiplied')
        grow(e.mask, e.shape, bandW)
        grow(e.shape, e.rim, lineW)
        love.graphics.pop()

        local ox, oy = x - pad, y - pad
        local steps = math.max(0, math.floor(depth))
        love.graphics.push('all')
        love.graphics.setBlendMode('alpha', 'premultiplied')
        -- a soft drop shadow, past the block
        if look.shadow > 0 then
            for i = 1, 4 do
                local k = depth + size * 0.05 * i
                tint({ 0, 0, 0 }, look.shadow / 4)
                love.graphics.draw(e.rim, ox + dx * k, oy + dy * k)
            end
        end
        -- the block: its silhouette in the line colour, its sides inside that, back to front
        if lineW > 0 then
            tint(look.line)
            for i = steps, 0, -1 do love.graphics.draw(e.rim, ox + dx * i, oy + dy * i) end
        end
        for i = steps, 1, -1 do
            tint(mixed(look.near, look.far, i / math.max(1, steps)))
            love.graphics.draw(e.shape, ox + dx * i, oy + dy * i)
        end
        -- the band at the front
        if bandW > 0 then
            tint(look.band)
            love.graphics.draw(e.shape, ox, oy)
            -- a thin line between the band and the face, when the band is light
            if lineW > 0 then
                tint(look.line, 0.8)
                for i = 0, 5 do
                    local ang = i / 6 * math.pi * 2
                    love.graphics.draw(e.mask, ox + math.cos(ang) * lineW * 0.5, oy + math.sin(ang) * lineW * 0.5)
                end
            end
        end
        -- the face
        love.graphics.setShader(FACE)
        FACE:send('top', look.top)
        FACE:send('mid', look.mid)
        FACE:send('bottom', look.bottom)
        FACE:send('hi', look.hi)
        FACE:send('lo', look.lo)
        FACE:send('off', { look.bevel * size / w, look.bevel * size / h })
        FACE:send('band', { pad / h, (pad + th) / h })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(e.mask, ox, oy)
        love.graphics.setShader()
        -- sparkles on the letters' top half, from the text (they twinkle at the boil's speed)
        if look.sparkles >= 1 then
            love.graphics.setBlendMode('alpha')
            local tick = (opts.boil or 0) > 0 and math.floor(love.timer.getTime() * opts.boil) or 0
            for i = 1, math.floor(look.sparkles) do
                local v = math.sin(i * 91.7 + #text * 13.1 + (opts.seed or 1) * 7.3) * 43758.5453
                v = v - math.floor(v)
                local r = size * (0.12 + 0.04 * ((tick + i) % 3))
                local sx, sy = x + tw * (0.08 + 0.84 * v), y + size * (0.3 + (i % 2) * 0.35)
                love.graphics.setColor(look.line)
                star(sx, sy, r + size * 0.03)
                love.graphics.setColor(1, 1, 1)
                star(sx, sy, r)
            end
        end
        love.graphics.pop()
        return tw, th
    end

    return looks
end
