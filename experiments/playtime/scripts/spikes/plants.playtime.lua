-- plants: a spike for growing plants from L-systems with Nikki's drawn leaves and petals and crayon-stroke stems
-- A row of plants, each grown from an L-system with its own seed: a daisy, a sunflower, a tulip,
-- a fern, a berry bush, grass tufts, a succulent, a yucca, a fern of drawn fronds. The stems are
-- ribbons of Nikki's crayon strokes (a dark one under a green one, so they have an outline); the
-- leaves, petals and flower hearts are her drawn shapes (outline + mask, textures/plants: from the
-- scans and from vehicles-vegetation), tinted.
-- Each plant grows from a sprout: segment by segment from the root up (the turtle runs every frame
-- with the grown lengths, so a branch starts where its stem has got to), leaves unfold after their
-- stem, buds come last and open into flowers. A grown plant has a spine of a few light bodies on
-- soft welds: grab it and pull, throw a Mipo in, and it bends and springs back; the wind on it.
--
-- play mode (tab): press grow (or g) a few times, or grow all the way.
-- keys: g grow a step   f fully grown   n new seeds (sprouts again)   p a plant at the mouse   h the panel

local s = {}

local STROKE = love.filesystem.load('scripts/spikes/drawn-stroke.lua')()
local OUTLINE = { 0.17, 0.13, 0.1 }
local GROUND_Y = 0

local function plants()
    state.plants = state.plants or { list = {}, showPanel = true, time = 0, mipos = {}, seed = 1,
        settings = { sway = 1, speed = 1, size = 1 } }
    return state.plants
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end
local function smooth(x) x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end

---------------------------------------------------------------- the drawn parts

local maskShader = love.graphics.newShader([[
vec4 effect(vec4 color, Image mask, vec2 uv, vec2 pc) {
    return vec4(color.rgb, color.a * smoothstep(0.1, 0.5, Texel(mask, uv).r));
}
]])

local PARTS = {}
local function part(name)
    if PARTS[name] ~= nil then return PARTS[name] or nil end
    local base = 'textures/plants/' .. name
    if not love.filesystem.getInfo(base .. '.png', 'file') then PARTS[name] = false; return nil end
    local line = love.graphics.newImage(base .. '.png', { mipmaps = true })
    line:setMipmapFilter('linear')
    local mask
    if love.filesystem.getInfo(base .. '-mask.png', 'file') then
        mask = love.graphics.newImage(base .. '-mask.png', { mipmaps = true })
        mask:setMipmapFilter('linear')
    end
    local w, h = line:getDimensions()
    PARTS[name] = { line = line, mask = mask, w = w, h = h }
    return PARTS[name]
end

-- a part with its base at (x, y), pointing along angle (0 = up), length long world units
local function drawPart(name, x, y, angle, long, fill, line, alpha, widthK)
    local p = part(name)
    if not p or long <= 0.5 then return end
    local k = long / p.h
    local kx = k * (widthK or 1)
    alpha = alpha or 1
    if p.mask and fill then
        love.graphics.setShader(maskShader)
        love.graphics.setColor(fill[1], fill[2], fill[3], alpha)
        love.graphics.draw(p.mask, x, y, angle, kx, k, p.w / 2, p.h)
        love.graphics.setShader()
    end
    local c = line or OUTLINE
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.draw(p.line, x, y, angle, kx, k, p.w / 2, p.h)
end

---------------------------------------------------------------- the stems: crayon ribbons

local ribbonMesh = love.graphics.newMesh(4000, 'triangles', 'stream')
-- a polyline (flat x, y list) with a width per point, as a strip of the stroke picture repeated
-- mirror-wise along it (seamless; drawn-stroke.lua's cut pictures)
local function drawRibbon(pts, widths, pic, color)
    local n = #pts / 2
    if n < 2 or not pic then return end
    local verts = {}
    local thick = pic.alongX and pic.h or pic.w
    local long = pic.alongX and pic.w or pic.h
    local tileLen = long * ((widths[1] or 10) / thick)
    local dist = 0
    local function side(i)
        local a = math.max(1, i - 1)
        local c = math.min(n, i + 1)
        local dx, dy = pts[c * 2 - 1] - pts[a * 2 - 1], pts[c * 2] - pts[a * 2]
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1e-6 then len = 1 end
        local w = widths[i] / 2
        local nx, ny = -dy / len * w, dx / len * w
        local x, y = pts[i * 2 - 1], pts[i * 2]
        return x + nx, y + ny, x - nx, y - ny
    end
    local function vert(x, y, across, d)
        local along = d / tileLen
        if pic.alongX then return { x, y, along, across } end
        return { x, y, across, along }
    end
    local ax, ay, bx, by = side(1)
    for i = 2, n do
        local seg = math.sqrt((pts[i * 2 - 1] - pts[i * 2 - 3]) ^ 2 + (pts[i * 2] - pts[i * 2 - 2]) ^ 2)
        local d0, d1 = dist, dist + seg
        local cx, cy, dx, dy = side(i)
        local q1, q2, q3, q4 = vert(ax, ay, 0, d0), vert(bx, by, 1, d0), vert(cx, cy, 0, d1), vert(dx, dy, 1, d1)
        verts[#verts + 1] = q1; verts[#verts + 1] = q2; verts[#verts + 1] = q3
        verts[#verts + 1] = q2; verts[#verts + 1] = q4; verts[#verts + 1] = q3
        ax, ay, bx, by, dist = cx, cy, dx, dy, d1
        if #verts > 3900 then break end
    end
    if #verts < 3 then return end
    ribbonMesh:setVertices(verts)
    ribbonMesh:setDrawRange(1, #verts)
    ribbonMesh:setTexture(pic.image)
    love.graphics.setColor(color)
    love.graphics.draw(ribbonMesh)
end

---------------------------------------------------------------- L-systems

-- Symbols: F a stem segment, + - turn, [ ] a branch, L a leaf, l a small leaf, B a berry,
-- H a flower head, T a tulip cup, U a frond leaflet pair, R Y D a fan of leaves out of one point
-- (a succulent's rosette, a yucca's crown, drawn fern fronds). Rules can have several choices with
-- weights (stochastic); a final pass turns what's left of X into something.
local TYPES = {
    daisy = {
        axiom = 'X', iter = 6, angle = 38, len = 48, width = 11,
        rules = { X = { { 'F[+L]FX', 1 }, { 'F[-L]FX', 1 }, { 'FFX', 0.5 } } }, final = { X = 'H' },
        leaf = 'oval', leafLen = 90, leafWidth = 0.6, head = 'daisy', headSize = 150,
        stem = { 0.38, 0.56, 0.24 }, leafColor = { 0.42, 0.62, 0.26 },
        petals = { { 0.98, 0.98, 0.95 } }, heartColor = { 0.98, 0.78, 0.2 },
    },
    sunflower = {
        axiom = 'X', iter = 5, angle = 50, len = 46, width = 18,
        rules = { X = { { 'FF[+L]FF[-L]X', 1 }, { 'FFX', 0.6 } } }, final = { X = 'H' },
        leaf = 'oval', leafLen = 150, leafWidth = 0.45, head = 'sun', headSize = 230,
        stem = { 0.4, 0.55, 0.22 }, leafColor = { 0.36, 0.56, 0.22 },
        petals = { { 0.98, 0.8, 0.15 }, { 0.98, 0.7, 0.12 } }, heartColor = { 0.45, 0.28, 0.14 },
    },
    tulip = {
        axiom = '[--L][++L]FFFFFT', iter = 0, angle = 14, len = 58, width = 10,
        rules = {}, final = {},
        leaf = 'oval', leafLen = 260, leafWidth = 0.28, leafSpread = 0.25, head = 'tulip', headSize = 120,
        stem = { 0.42, 0.6, 0.3 }, leafColor = { 0.4, 0.62, 0.34 },
        petals = { { 0.9, 0.22, 0.25 }, { 0.98, 0.5, 0.2 }, { 0.92, 0.45, 0.65 }, { 0.98, 0.85, 0.3 } },
    },
    fern = {
        axiom = '[--X][-X][X][+X][++X]', iter = 8, angle = 16, len = 34, width = 8, curl = 3.5,
        rules = { X = { { 'FUX', 1 } } }, final = { X = 'U' },
        leaf = 'petal', leafLen = 46, leafWidth = 0.45,
        stem = { 0.3, 0.48, 0.22 }, leafColor = { 0.34, 0.58, 0.26 },
    },
    bush = {
        axiom = 'X', iter = 4, angle = 27, len = 40, width = 10,
        rules = { X = { { 'F[+X]F[-X]+X', 1 }, { 'F[-X][+X]FX', 0.8 } } }, final = { X = 'LB' },
        leaf = 'petal', leafLen = 58, leafWidth = 0.6,
        stem = { 0.4, 0.33, 0.22 }, leafColor = { 0.3, 0.52, 0.24 }, berry = { 0.75, 0.15, 0.3 },
    },
    -- a rosette of fat leaves, opening from the middle; a flower stalk when it's fully grown
    succulent = {
        axiom = 'R', iter = 0, angle = 0, len = 0, width = 0, rules = {}, final = {},
        fan = { { count = 9, spread = 2.3, len = 210, widthK = 0.85, droop = 0.12 },
                { count = 7, spread = 1.7, len = 175, widthK = 0.85, droop = 0.05 },
                { count = 5, spread = 0.9, len = 135, widthK = 0.8, droop = 0 } },
        fanLeaf = 'petal', stem = { 0.5, 0.62, 0.55 },
        leafColors = { { 0.55, 0.72, 0.66 }, { 0.62, 0.76, 0.7 }, { 0.5, 0.66, 0.62 } },
        bloom = { 0.95, 0.55, 0.45 },
    },
    -- a woody trunk, sometimes a branch, each end a crown of long narrow sword leaves
    yucca = {
        axiom = 'FFX', iter = 3, angle = 30, len = 70, width = 30,
        rules = { X = { { 'FF[+FFY]FY', 0.5 }, { 'FFY', 1 }, { 'F[-FY]FFY', 0.4 } } }, final = { X = 'Y' },
        fan = { { count = 15, spread = 4.4, len = 240, widthK = 0.3, droop = 0.45 },
                { count = 9, spread = 2.0, len = 200, widthK = 0.3, droop = 0.1 } },
        fanLeaf = 'oval', stem = { 0.5, 0.4, 0.3 }, stemWidthKeep = true,
        leafColors = { { 0.3, 0.5, 0.3 }, { 0.36, 0.56, 0.32 }, { 0.28, 0.46, 0.3 } },
    },
    -- Nikki's drawn fern fronds, fanning out of the ground
    bracken = {
        axiom = 'D', iter = 0, angle = 0, len = 0, width = 0, rules = {}, final = {},
        fan = { { count = 7, spread = 2.3, len = 380, widthK = 1, droop = 0.4, fronds = true } },
        stem = { 0.38, 0.6, 0.3 }, leafColors = { { 0.38, 0.6, 0.3 }, { 0.32, 0.55, 0.28 }, { 0.44, 0.64, 0.32 } },
    },
    tuft = { tuft = true, stem = { 0.4, 0.6, 0.28 } },
}
local ORDER = { 'daisy', 'yucca', 'tulip', 'sunflower', 'succulent', 'fern', 'bracken', 'bush', 'tuft', 'succulent', 'daisy' }

local function expand(t, rng)
    local str = t.axiom
    for _ = 1, t.iter do
        local out = {}
        for c in str:gmatch('.') do
            local choices = t.rules[c]
            if choices then
                local total = 0
                for _, ch in ipairs(choices) do total = total + ch[2] end
                local r = rng:random() * total
                local pick = choices[#choices][1]
                for _, ch in ipairs(choices) do
                    r = r - ch[2]
                    if r <= 0 then pick = ch[1]; break end
                end
                out[#out + 1] = pick
            else
                out[#out + 1] = c
            end
        end
        str = table.concat(out)
    end
    local out = {}
    for c in str:gmatch('.') do out[#out + 1] = t.final[c] or c end
    str = table.concat(out)
    -- each symbol with its own random numbers, kept
    local tokens = {}
    for c in str:gmatch('.') do
        if c ~= 'X' then tokens[#tokens + 1] = { c = c, r1 = rng:random(), r2 = rng:random(), r3 = rng:random() } end
    end
    return tokens
end

---------------------------------------------------------------- the spine: what you grab

-- Each grown plant has a spine you can grab: a few light bodies stacked up its height, each on a
-- soft weld to the one under it (the bottom one to the ground), so it bends and springs back. The
-- drawing follows it: the turtle turns each stem segment by how much the spine bends there.
local SPINE = 4
local GROUP = -91

local function spineAngle(pl, f)
    local sp = pl.spine
    if not sp or #sp.bodies == 0 then return 0 end
    local x = clamp(f, 0, 1) * #sp.bodies + 0.5
    local i = clamp(math.floor(x), 1, #sp.bodies)
    local j = math.min(#sp.bodies, i + 1)
    local bi, bj = sp.bodies[i], sp.bodies[j]
    if bi:isDestroyed() or bj:isDestroyed() then return 0 end
    local t = clamp(x - i, 0, 1)
    return bi:getAngle() * (1 - t) + bj:getAngle() * t
end

local function dropSpine(pl)
    if not pl.spine then return end
    for _, body in ipairs(pl.spine.bodies) do
        if not body:isDestroyed() then objectManager.destroyBody(body) end
    end
    pl.spine = nil
end

local function makeSpine(b, pl, height)
    dropSpine(pl)
    if height < 60 or not (b.ground and not b.ground:isDestroyed()) then return end
    local h = height / SPINE
    local w = math.max(40, math.min(90, height * 0.12))
    local bodies = {}
    local below = b.ground
    for i = 1, SPINE do
        local cy = GROUND_Y - 4 - (i - 0.5) * h
        local thing = objectManager.addThing('rectangle', { x = pl.x, y = cy, width = w * (1 - i * 0.12), height = h,
            bodyType = 'dynamic', label = 'plant-spine', density = 0.04 })
        if not thing then break end
        local body = thing.body
        -- it collides with nothing (a spine made again inside a Mipo shot it away; a Mipo lying on a
        -- plant pinned it); you can still grab it, and Mipos brush it aside (s.update)
        for _, f in ipairs(body:getFixtures()) do
            f:setGroupIndex(GROUP)
            f:setMask(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
        end
        body:setAngularDamping(2)
        body:setLinearDamping(1)
        body:setGravityScale(0) -- a spring, not a weight: it stands up by itself (with gravity the soft welds folded over)
        local joint = love.physics.newWeldJoint(below, body, pl.x, GROUND_Y - 4 - (i - 1) * h, false)
        joint:setFrequency(8 - i * 1.2)
        joint:setDampingRatio(0.35)
        local id = 'plant-weld-' .. tostring(love.math.random(1e9))
        joint:setUserData({ id = id, label = 'plant' })
        registry.registerJoint(id, joint)
        bodies[#bodies + 1] = body
        below = body
    end
    pl.spine = { bodies = bodies, height = height, grow = pl.grow }
end

-- the turtle: from the root up, every segment as long as it's grown. Returns stems (polylines with
-- widths) and the parts on them (leaves, heads, berries), each with its birth (how far up the
-- plant it is, 0 root .. 1 the furthest tip).
local function turtle(pl, grow, time, sway)
    local t = TYPES[pl.kind]
    local size = pl.size
    local x, y, a = pl.x, GROUND_Y, 0
    local width = t.width * size
    local path = 0
    local stack = {}
    local stems, parts = {}, {}
    local cur = { pts = { x, y }, widths = { width } }
    stems[1] = cur
    local births = pl.births
    if pl.noStem and pl.spine then a = clamp(spineAngle(pl, 1) * 0.5, -0.5, 0.5) end
    for i, tok in ipairs(pl.tokens) do
        local c = tok.c
        local birth = births and births[i] or 0
        if c == 'F' then
            local k = smooth((grow - birth * 0.85) / 0.12)
            local len = t.len * size * (0.8 + tok.r1 * 0.4) * k
            if t.curl then a = a + math.rad(t.curl) * (a >= 0 and 1 or -1) * k end
            -- the bend: as much as the spine turns over this segment
            if pl.maxPath and pl.spine then
                local f0 = path / pl.maxPath
                local f1 = (path + t.len * size) / pl.maxPath
                a = a + spineAngle(pl, f1) - spineAngle(pl, f0)
            end
            x = x + math.sin(a) * len
            y = y - math.cos(a) * len
            path = path + t.len * size
            if not t.stemWidthKeep then width = math.max(3 * size, width * 0.94) end
            cur.pts[#cur.pts + 1] = x
            cur.pts[#cur.pts + 1] = y
            cur.widths[#cur.widths + 1] = width * (0.4 + 0.6 * k)
        elseif c == '+' then a = a + math.rad(t.angle * (0.75 + tok.r1 * 0.5))
        elseif c == '-' then a = a - math.rad(t.angle * (0.75 + tok.r1 * 0.5))
        elseif c == '[' then
            stack[#stack + 1] = { x, y, a, width, path, cur }
            cur = { pts = { x, y }, widths = { width } }
            stems[#stems + 1] = cur
        elseif c == ']' then
            local st = table.remove(stack)
            if st then x, y, a, width, path, cur = st[1], st[2], st[3], st[4], st[5], st[6] end
        else
            parts[#parts + 1] = { c = c, x = x, y = y, a = a, birth = birth, tok = tok, width = width }
        end
        if births == nil then tok.path = path end
    end
    if births == nil then
        -- the first run: where along the plant each symbol is (with full lengths)
        pl.births = {}
        local m = 1
        for _, tok in ipairs(pl.tokens) do m = math.max(m, tok.path or 0) end
        for i, tok in ipairs(pl.tokens) do pl.births[i] = (tok.path or 0) / m end
        pl.maxPath = m
    end
    return stems, parts
end

---------------------------------------------------------------- plants

local function newPlant(kind, x, seed)
    local rng = love.math.newRandomGenerator(seed)
    local t = TYPES[kind]
    local pl = { kind = kind, x = x, seed = seed, grow = 0, target = 0.06, phase = rng:random() * 6,
        size = (0.85 + rng:random() * 0.35) * 1.7, sprout = 1 + rng:random(3), stroke = 1 + rng:random(#STROKE.strokes) - 1 }
    if not t.tuft then
        pl.tokens = expand(t, rng)
        local stems, parts = turtle(pl, 1, 0, 0) -- the births
        pl.noStem = true
        for _, tok in ipairs(pl.tokens) do if tok.c == 'F' then pl.noStem = false; break end end
        -- how tall it gets: the highest point of it, grown
        local top = 0
        for _, st in ipairs(stems) do
            for k = 2, #st.pts, 2 do top = math.max(top, GROUND_Y - st.pts[k]) end
        end
        for _, pp in ipairs(parts) do top = math.max(top, GROUND_Y - pp.y) end
        pl.height = math.max(top, t.fan and t.fan[1].len * pl.size * 0.7 or 0)
    else
        pl.tuftPic = rng:random() < 0.5 and 'tuft-01' or 'tuft-02'
        pl.height = 300 * pl.size
    end
    pl.petal = t.petals and t.petals[rng:random(#t.petals)]
    pl.heartAngle = rng:random() * 6
    return pl
end

local function sowAll(b)
    for _, pl in ipairs(b.list or {}) do dropSpine(pl) end
    b.list = {}
    b.seed = (b.seed or 1) + 1
    for i, kind in ipairs(ORDER) do
        b.list[#b.list + 1] = newPlant(kind, -2300 + (i - 1) * 460 + (love.math.random() - 0.5) * 80,
            b.seed * 100 + i)
    end
end

local function aliveMipos(b)
    local out = {}
    for _, inst in ipairs(b.mipos) do
        local torso = inst.parts and inst.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then out[#out + 1] = inst end
    end
    return out
end

local function growStep(b, amount)
    for _, pl in ipairs(b.list) do pl.target = math.min(1, pl.target + amount) end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = plants()
    if #b.list == 0 then sowAll(b) end
    if not (b.ground and not b.ground:isDestroyed()) then
        local g = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 200, width = 7000, height = 400,
            bodyType = 'static', label = 'plants-ground' })
        if g then b.ground = g.body end
    end
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        local inst = characterManager.createCharacter('humanoid', -200, -500, 0.3) -- in a gap
        if inst then characterManager.randomizeMipoConstrained(inst); b.mipos[1] = inst end
    end
end

function s.onUnload()
    local b = state.plants
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = plants()
    if key == 'g' then growStep(b, 0.2)
    elseif key == 'f' then growStep(b, 1)
    elseif key == 'n' then sowAll(b)
    elseif key == 'p' then
        local mx = mouseWorldPos()
        local kinds = { 'daisy', 'sunflower', 'tulip', 'fern', 'bush', 'tuft', 'succulent', 'yucca', 'bracken' }
        b.list[#b.list + 1] = newPlant(kinds[love.math.random(#kinds)], mx, love.math.random(1e6))
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

function s.update(dt)
    local b = state.plants
    if not b then return end
    b.time = b.time + dt
    -- growing eases towards the target, at about a step in two seconds
    local gx, gy = state.physicsWorld:getGravity()
    local g = math.sqrt(gx * gx + gy * gy)
    for _, pl in ipairs(b.list) do
        if pl.grow < pl.target then pl.grow = math.min(pl.target, pl.grow + dt * 0.11 * b.settings.speed) end
        if pl.grow > pl.target then pl.grow = pl.target end
        -- the spine follows the plant's height as it grows (made again every bit of growth)
        if pl.grow > 0.15 and (not pl.spine or math.abs(pl.grow - pl.spine.grow) > 0.08) then
            makeSpine(b, pl, (pl.height or 0) * pl.grow)
        end
        -- Mipos brush it aside: a push on each spine body a Mipo part is in, the way it's going
        if pl.spine then
            for _, inst in ipairs(b.mipos) do
                for _, mp in pairs(inst.parts or {}) do
                    local mb = mp.body
                    if mb and not mb:isDestroyed() then
                        local mx, my = mb:getPosition()
                        local mvx = mb:getLinearVelocity()
                        for _, sb in ipairs(pl.spine.bodies) do
                            local sx, sy = sb:getPosition()
                            local reach = pl.spine.height / SPINE * 0.7
                            if math.abs(mx - sx) < 60 and math.abs(my - sy) < reach then
                                local side = mx < sx and 1 or -1
                                sb:applyForce((side * 900 + mvx * 3) * sb:getMass(), 0)
                            end
                        end
                    end
                end
            end
        end
        -- the wind on its top
        local sp = pl.spine
        if sp then
            local top = sp.bodies[#sp.bodies]
            if top and not top:isDestroyed() then
                local gust = math.sin(b.time * 1.1 + pl.phase) + 0.5 * math.sin(b.time * 2.7 + pl.phase * 2)
                top:applyForce(gust * top:getMass() * g * 0.1 * b.settings.sway, 0)
            end
        end
    end
end

---------------------------------------------------------------- drawing

local function lighter(c, k) return { math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k) } end

local function drawHead(t, pl, h, open)
    local size = t.headSize * pl.size
    local r = size * 0.5 * (0.25 + 0.75 * open)
    if t.head == 'daisy' then
        -- a heart, then Nikki's daisy drawing over it, white
        love.graphics.setColor(t.heartColor)
        love.graphics.circle('fill', h.x, h.y, r * 0.22)
        local p = part('daisy-01')
        if p then
            local k = r * 2 / p.w
            love.graphics.setColor(1, 1, 1, 0.3 + 0.7 * open)
            love.graphics.draw(p.line, h.x, h.y, h.a + pl.heartAngle, k, k, p.w / 2, p.h / 2)
        end
    elseif t.head == 'sun' then
        -- petals all round (drawn ovals), opening out, a big scribbled heart
        local n = 14
        for k = 0, n - 1 do
            local ang = h.a + pl.heartAngle + k / n * math.pi * 2
            drawPart('petal-0' .. (k % 9 + 1), h.x, h.y, ang, r * (0.55 + 0.45 * open),
                k % 2 == 0 and t.petals[1] or (t.petals[2] or t.petals[1]), OUTLINE, 1, 0.55)
        end
        local hp = part('heart-01')
        if hp then
            local k = r * 1.1 / hp.w
            love.graphics.setShader(maskShader)
            love.graphics.setColor(t.heartColor)
            love.graphics.draw(hp.mask, h.x, h.y, h.a, k, k, hp.w / 2, hp.h / 2)
            love.graphics.setShader()
            love.graphics.setColor(0.25, 0.15, 0.08)
            love.graphics.draw(hp.line, h.x, h.y, h.a, k, k, hp.w / 2, hp.h / 2)
        end
    elseif t.head == 'tulip' then
        -- three petals, closed as a bud, a little apart when open
        local spread = 0.12 + 0.3 * open
        local col = pl.petal or t.petals[1]
        drawPart('oval-02', h.x, h.y + 4, h.a - spread, size * 0.75 * (0.45 + 0.55 * open), lighter(col, 0.85), OUTLINE, 1, 0.8)
        drawPart('oval-03', h.x, h.y + 4, h.a + spread, size * 0.75 * (0.45 + 0.55 * open), lighter(col, 0.85), OUTLINE, 1, 0.8)
        drawPart('oval-01', h.x, h.y + 6, h.a, size * 0.8 * (0.45 + 0.55 * open), col, OUTLINE, 1, 0.75)
    end
end

-- a fan of leaves out of one point (a succulent's rosette, a yucca's crown, fronds): rings from the
-- outside in, each leaf coming out after the one before; the outer ones droop
local function drawFan(b, t, pl, p, g)
    local tok = p.tok
    local base = smooth((g - p.birth * 0.85 - 0.04) / 0.1)
    if base <= 0 then return end
    local rng = love.math.newRandomGenerator(math.floor(tok.r1 * 1e6) + 1)
    for ringI, ring in ipairs(t.fan) do
        local n = ring.count
        for i = 1, n do
            local f = n > 1 and (i - 1) / (n - 1) - 0.5 or 0
            -- from where its point is on the plant to fully grown: outer rings first
            local s0 = p.birth * 0.85 + 0.04
            local span = math.max(0.12, 1 - s0)
            local order = (ringI - 1) / #t.fan * 0.6 + math.abs(f) * 0.1
            local k = smooth((g - s0 - order * span * 0.6) / (span * 0.4))
            local r1, r2, r3 = rng:random(), rng:random(), rng:random()
            if k > 0 then
                local off = f * ring.spread + (r1 - 0.5) * 0.12
                local droop = ring.droop * off * math.abs(off) * 0.35
                local ang = p.a + off + droop + math.sin(b.time * 1.4 + pl.phase + i) * 0.03 * b.settings.sway
                local len = ring.len * pl.size * (0.8 + r2 * 0.4) * k
                local col = t.leafColors[1 + math.floor(r3 * #t.leafColors)]
                if ring.fronds then
                    local name = r2 < 0.6 and 'frond-01' or 'frond-02'
                    local pt = part(name)
                    drawPart(name, p.x, p.y, ang, len, col, pt and pt.mask and OUTLINE or col, 1, 1)
                else
                    drawPart((t.fanLeaf or 'oval') .. '-0' .. (1 + math.floor(r1 * (t.fanLeaf == 'petal' and 9 or 5))),
                        p.x, p.y, ang, len, col, OUTLINE, 1, ring.widthK)
                end
            end
        end
    end
    -- a succulent's flower stalk, once it's all grown
    if t.bloom and g > 0.85 then
        local k = smooth((g - 0.85) / 0.15)
        local pts, widths = {}, {}
        local x, y, a = p.x, p.y, -0.25
        for j = 0, 8 do
            pts[#pts + 1] = x; pts[#pts + 1] = y; widths[#widths + 1] = 6 * pl.size * (1 - j / 12)
            a = a + 0.09
            x, y = x + math.sin(a) * 30 * pl.size * k, y - math.cos(a) * 30 * pl.size * k
        end
        local pic = STROKE.strokes[pl.stroke] and STROKE.strokes[pl.stroke].seamless
        local outer = {}
        for i2, w in ipairs(widths) do outer[i2] = w + 6 end
        drawRibbon(pts, outer, pic, OUTLINE)
        drawRibbon(pts, widths, pic, t.stem)
        for j = 0, 2 do
            drawPart('petal-0' .. (j + 2), x, y, a - 0.6 + j * 0.6, 34 * pl.size * k, t.bloom, OUTLINE, 1, 0.8)
        end
    end
end

local function drawPlant(b, pl, pass)
    local t = TYPES[pl.kind]
    local g = pl.grow
    -- a sprout first (Nikki's sprout drawings), then the plant takes over
    if g < 0.2 then
        local k = smooth(g / 0.12) * (1 - smooth((g - 0.12) / 0.08))
        if k > 0 and pass == 'stems' then
            drawPart('sprout-0' .. pl.sprout, pl.x, GROUND_Y + 6, math.sin(b.time * 1.1 + pl.phase) * 0.05,
                170 * pl.size * k, t.leafColor or (t.leafColors and t.leafColors[1]) or t.stem, OUTLINE, 1)
        end
        if g < 0.1 then return end
    end
    if t.tuft then
        if pass == 'leaves' then
            local k = smooth((g - 0.1) / 0.6)
            local p = part(pl.tuftPic)
            if p and k > 0 then
                local sc = 1.2 * pl.size
                love.graphics.setColor(t.stem)
                love.graphics.draw(p.line, pl.x, GROUND_Y + 8, spineAngle(pl, 1) * 0.8,
                    sc, sc * k, p.w / 2, p.h)
            end
        end
        return
    end
    local stems, parts = turtle(pl, g, b.time, b.settings.sway)
    if pass == 'stems' then
        local pic = STROKE.strokes[pl.stroke] and STROKE.strokes[pl.stroke].seamless
        for _, st in ipairs(stems) do
            if #st.pts >= 4 then
                local outer = {}
                for i, w in ipairs(st.widths) do outer[i] = w + 7 end
                drawRibbon(st.pts, outer, pic, OUTLINE)
                drawRibbon(st.pts, st.widths, pic, t.stem)
            end
        end
        return
    end
    for _, p in ipairs(parts) do
        local tok = p.tok
        local k = smooth((g - p.birth * 0.85 - 0.06) / 0.16)
        if k > 0 then
            if p.c == 'L' or p.c == 'l' then
                local side = tok.r1 < 0.5 and -1 or 1
                local spread = t.leafSpread or 0.7
                local ang = p.a + side * (spread + tok.r2 * spread * 0.7) + math.sin(b.time * 1.6 + pl.phase + p.birth * 5) * 0.06
                local name = t.leaf .. '-0' .. (1 + math.floor(tok.r3 * (t.leaf == 'petal' and 9 or 5)))
                local len = t.leafLen * pl.size * (0.75 + tok.r2 * 0.5) * k * (p.c == 'l' and 0.6 or 1)
                drawPart(name, p.x, p.y, ang, len, lighter(t.leafColor, 0.9 + tok.r1 * 0.25), OUTLINE, 1, t.leafWidth / 0.6)
            elseif p.c == 'U' then -- a frond's pair of leaflets, smaller towards the tip
                local len = t.leafLen * pl.size * (1 - p.birth * 0.6) * k
                for side = -1, 1, 2 do
                    drawPart('petal-0' .. (1 + math.floor(tok.r3 * 9)), p.x, p.y, p.a + side * 1.1, len,
                        lighter(t.leafColor, 0.9 + tok.r1 * 0.2), OUTLINE, 1, 0.7)
                end
            elseif p.c == 'B' and g > 0.7 and tok.r1 < 0.6 then
                local r = 13 * pl.size * smooth((g - 0.7) / 0.25)
                love.graphics.setColor(OUTLINE)
                love.graphics.circle('fill', p.x, p.y, r + 3)
                love.graphics.setColor(t.berry)
                love.graphics.circle('fill', p.x, p.y, r)
                love.graphics.setColor(1, 1, 1, 0.6)
                love.graphics.circle('fill', p.x - r * 0.3, p.y - r * 0.3, r * 0.25)
            elseif p.c == 'R' or p.c == 'Y' or p.c == 'D' then
                drawFan(b, t, pl, p, g)
            elseif p.c == 'H' or p.c == 'T' then
                if g > 0.72 then drawHead(t, pl, p, smooth((g - 0.78) / 0.22)) end
            end
        end
    end
end

function s.drawBelow()
    local b = state.plants
    if not b then return end
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.78, 0.88, 0.92)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
    local x0 = cam:getWorldCoordinates(0, 0)
    local x1 = cam:getWorldCoordinates(w, h)
    love.graphics.setColor(0.52, 0.38, 0.26)
    love.graphics.rectangle('fill', x0 - 100, GROUND_Y, x1 - x0 + 200, 4000)
    love.graphics.setColor(0.45, 0.62, 0.3)
    love.graphics.rectangle('fill', x0 - 100, GROUND_Y - 6, x1 - x0 + 200, 34)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(6)
    love.graphics.line(x0 - 100, GROUND_Y - 6, x1 + 100, GROUND_Y - 6)
    love.graphics.setLineWidth(1)
    for _, pl in ipairs(b.list) do drawPlant(b, pl, 'stems') end
    for _, pl in ipairs(b.list) do drawPlant(b, pl, 'leaves') end
    love.graphics.setColor(1, 1, 1, 1)
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.plants
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.drawUI()
    local b = state.plants
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'sway', 0, 3 }, { 'speed', 0.2, 4 } }
    local h = (BH + pad) * (#rows + 4) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• plants ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 180, 'grow (g)') then growStep(b, 0.2) end
        if ui.button(x + 190, y, 180, 'all the way (f)') then growStep(b, 1) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 180, 'new seeds (n)') then sowAll(b) end
        for _, row in ipairs(rows) do
            local key = row[1]
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('plants' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local g = b.list[1] and b.list[1].target or 0
        ui.label(x, y, string.format('grown %d%%   p a plant at the mouse', math.floor(g * 100 + 0.5)))
    end)
end

return s
