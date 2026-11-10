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
-- tap a flower or a fruit: it comes off (a new one grows back), carry it to a Mipo's hand and it holds it
-- keys: g grow a step   f fully grown   n new seeds (sprouts again)   p a plant at the mouse (of that biome)   h the panel
--       m Mipos push plants aside (off: plants are a layer of their own, only the mouse bends them)

local s = {}

local STROKE = drawnStroke()
local OUTLINE = { 0.17, 0.13, 0.1 }
local GROUND_Y = 0

local function plants()
    state.plants = state.plants or { list = {}, showPanel = true, time = 0, mipos = {}, seed = 1,
        settings = { sway = 1, speed = 1, size = 1, brush = false } }
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

-- Dutch wild plants, three biomes (Nikki, 2026-11-05; what they look like and how they grow in
-- docs/PLANTS.md). More symbols: O a pair of opposite leaves, M a marjoram tuft, S a thyme spike,
-- K a devil's-bit ball, Q a field-scabious pincushion, P a loosestrife spike, I an iris,
-- W a water-mint head, w a whorl lower down, V a royal fern's leaflet pair, Z its spore tip.
-- The small flowers are dots of Nikki's drawn crayon rings (textures/plants/berry-0n), green buds
-- that colour as they open.
-- meadow
TYPES.marjolein = { -- wild marjoram: a bushy clump of upright reddish stems, small opposite leaves,
    -- branching at the top into flat-topped tufts of tiny pink flowers on dark purple bracts
    stems = { 3, 7, 0.55 }, stemAxiom = 'X', iter = 5, angle = 9, len = 30, width = 6,
    rules = { X = { { 'FOX', 1 }, { 'FX', 0.5 } } }, final = { X = '[+++FM][---FM]FM' },
    leaf = 'oval', leafLen = 38, leafWidth = 0.55, leafSpread = 1.0, leafShrink = 0.4,
    stem = { 0.5, 0.32, 0.3 }, leafColor = { 0.4, 0.54, 0.3 },
    flowers = { { 0.88, 0.58, 0.78 }, { 0.5, 0.22, 0.42 }, { 0.8, 0.45, 0.68 } }, headSize = 22,
}
TYPES.tijm = { -- large thyme: a low mat of thin stems from a woody base, tiny leaves, each stem a
    -- short spike of lilac-pink flowers
    stems = { 4, 9, 1.5 }, stemAxiom = 'X', iter = 4, angle = 13, len = 15, width = 4,
    rules = { X = { { 'FOX', 1 }, { 'FX', 0.3 } } }, final = { X = 'FS' },
    leaf = 'oval', leafLen = 16, leafWidth = 0.6, leafSpread = 1.1,
    stem = { 0.45, 0.32, 0.26 }, leafColor = { 0.36, 0.48, 0.3 },
    flowers = { { 0.85, 0.6, 0.85 }, { 0.75, 0.48, 0.75 } }, headSize = 40,
}
TYPES.blauweknoop = { -- devil's-bit scabious: a rosette of long whole leaves, a tall thin stem
    -- with a pair of narrow leaves, forking at the top into long stalks, each a round blue-violet knob
    axiom = 'RFFFOFFF[++FFFK][--FFFK]FFFK', iter = 0, angle = 13, len = 48, width = 5,
    rules = {}, final = {},
    fan = { { count = 7, spread = 2.4, len = 150, widthK = 0.42, droop = 0.3 },
            { count = 4, spread = 1.3, len = 120, widthK = 0.42, droop = 0.15 } },
    fanLeaf = 'oval', leaf = 'oval', leafLen = 70, leafWidth = 0.3, leafSpread = 0.6,
    stem = { 0.4, 0.52, 0.3 }, leafColor = { 0.34, 0.5, 0.3 },
    leafColors = { { 0.34, 0.5, 0.3 }, { 0.3, 0.46, 0.28 }, { 0.38, 0.54, 0.32 } },
    flowers = { { 0.36, 0.38, 0.78 }, { 0.45, 0.4, 0.82 }, { 0.3, 0.32, 0.66 } }, headSize = 26,
}
TYPES.beemdkroon = { -- field scabious: a hairy stem with opposite deeply lobed leaves, forking
    -- into flat lilac pincushions, the outer florets bigger than the middle ones
    axiom = 'FOFFOFF[+++FFFQ][---FFFQ]FFFQ', iter = 0, angle = 10, len = 52, width = 6,
    rules = {}, final = {},
    leaf = 'frond', leafLen = 110, leafWidth = 0.7, leafSpread = 0.9, leafShrink = 0.5,
    stem = { 0.42, 0.55, 0.3 }, leafColor = { 0.38, 0.52, 0.3 },
    flowers = { { 0.72, 0.6, 0.86 }, { 0.65, 0.52, 0.8 } }, headSize = 34,
}
-- shaded forest
TYPES.tongvaren = { -- hart's-tongue fern: a tuft of whole strap-shaped leaves, glossy, arching out
    axiom = 'R', iter = 0, angle = 0, len = 0, width = 0, rules = {}, final = {},
    fan = { { count = 9, spread = 2.1, len = 240, widthK = 0.3, droop = 0.45 },
            { count = 6, spread = 1.1, len = 210, widthK = 0.3, droop = 0.2 } },
    fanLeaf = 'oval', stem = { 0.3, 0.45, 0.25 },
    leafColors = { { 0.28, 0.56, 0.3 }, { 0.32, 0.6, 0.32 }, { 0.24, 0.5, 0.28 } },
}
TYPES.mannetjesvaren = { -- male fern: a shuttlecock of long lance-shaped fronds out of one crown
    axiom = 'D', iter = 0, angle = 0, len = 0, width = 0, rules = {}, final = {},
    fan = { { count = 8, spread = 1.9, len = 420, widthK = 0.8, droop = 0.55, fronds = true },
            { count = 4, spread = 0.7, len = 380, widthK = 0.8, droop = 0.1, fronds = true } },
    stem = { 0.32, 0.46, 0.24 }, leafColors = { { 0.3, 0.48, 0.24 }, { 0.26, 0.44, 0.22 }, { 0.34, 0.52, 0.26 } },
}
TYPES.koningsvaren = { -- royal fern: big fronds of oblong leaflets (like an ash's), some topped
    -- with a fertile tip of spore beads that turn from green to rust-brown
    stems = { 3, 7, 1.0 }, stemAxiom = 'X', iter = 9, angle = 15, len = 50, width = 9, curl = 2,
    rules = { X = { { 'FVX', 1 } } }, final = { X = 'Z' },
    leafLen = 85, pinna = 'oval', pinnaWidth = 0.45,
    stem = { 0.45, 0.42, 0.25 }, leafColor = { 0.4, 0.58, 0.3 },
    flowers = { { 0.62, 0.38, 0.18 }, { 0.55, 0.32, 0.15 } }, headSize = 32,
}
-- waterside
TYPES.kattenstaart = { -- purple loosestrife: stiff upright stems, opposite narrow leaves, and long
    -- dense spikes of magenta flowers, opening from the bottom up
    stems = { 1, 4, 0.3 }, stemAxiom = 'X', iter = 6, angle = 6, len = 50, width = 7,
    rules = { X = { { 'FOX', 1 }, { 'FX', 0.4 } } }, final = { X = 'FP' },
    leaf = 'oval', leafLen = 80, leafWidth = 0.32, leafSpread = 0.8, leafShrink = 0.4,
    stem = { 0.5, 0.38, 0.3 }, leafColor = { 0.36, 0.52, 0.3 },
    flowers = { { 0.82, 0.28, 0.62 }, { 0.75, 0.22, 0.58 }, { 0.88, 0.38, 0.7 } }, headSize = 30,
}
TYPES.gelelis = { -- yellow flag iris: a fan of tall sword leaves out of the mud, flower stems
    -- among them with big yellow irises (three falls hanging out, three small standards up)
    axiom = 'Y[-FFFFFFI][+FFFFFI]', iter = 0, angle = 5, len = 64, width = 8,
    rules = {}, final = {},
    fan = { { count = 9, spread = 1.0, len = 560, widthK = 0.15, droop = 0.25 },
            { count = 5, spread = 0.5, len = 470, widthK = 0.15, droop = 0.05 } },
    fanLeaf = 'oval', stem = { 0.42, 0.56, 0.34 }, leafColor = { 0.4, 0.58, 0.36 },
    leafColors = { { 0.4, 0.58, 0.36 }, { 0.36, 0.54, 0.34 }, { 0.44, 0.6, 0.4 } },
    flowers = { { 0.98, 0.84, 0.2 }, { 0.96, 0.78, 0.15 } }, headSize = 105, wet = true,
}
TYPES.watermunt = { -- water mint: square reddish stems, opposite oval toothed leaves, a round lilac
    -- head at the top and a whorl of flowers a little lower
    stems = { 1, 3, 0.35 }, stemAxiom = 'X', iter = 5, angle = 8, len = 34, width = 6,
    rules = { X = { { 'FOX', 1 }, { 'FX', 0.3 } } }, final = { X = 'FwFOW' },
    leaf = 'petal', leafLen = 52, leafWidth = 0.8, leafSpread = 1.1, leafShrink = 0.3,
    stem = { 0.55, 0.3, 0.3 }, leafColor = { 0.34, 0.46, 0.3 },
    flowers = { { 0.78, 0.62, 0.86 }, { 0.7, 0.55, 0.82 } }, headSize = 26,
}

-- more meadow
TYPES.paardenbloem = { -- dandelion: a flat rosette of toothed leaves, hollow leafless stalks, each a
    -- yellow head of many narrow florets, or, gone over, a white clock
    prefix = 'R', stems = { 2, 6, 1.1 }, stemAxiom = 'FFFFC', iter = 0, angle = 0, len = 40, width = 4,
    rules = {}, final = {}, over = 1.3,
    fan = { { count = 8, spread = 2.5, len = 170, widthK = 0.7, droop = 0.15, fronds = true } },
    stem = { 0.55, 0.62, 0.38 }, leafColor = { 0.38, 0.58, 0.3 },
    leafColors = { { 0.38, 0.58, 0.3 }, { 0.42, 0.62, 0.32 } },
    flowers = { { 0.98, 0.82, 0.12 }, { 0.98, 0.72, 0.1 } }, headSize = 34,
}
TYPES.klaproos = { -- corn poppy: hairy branching stems, lobed leaves low, nodding hairy buds that
    -- turn up and open into four crumpled scarlet petals round a dark middle; then a seed capsule
    stems = { 1, 3, 0.5 }, stemAxiom = 'FOFFX', iter = 2, angle = 18, len = 46, width = 4,
    rules = { X = { { 'F[+FFN]FX', 0.6 }, { 'FFX', 1 } } }, final = { X = 'FN' },
    leaf = 'frond', leafLen = 90, leafWidth = 0.6, leafSpread = 0.8, leafShrink = 0.6,
    stem = { 0.42, 0.56, 0.3 }, leafColor = { 0.4, 0.55, 0.3 },
    flowers = { { 0.88, 0.14, 0.1 }, { 0.92, 0.22, 0.12 }, { 0.84, 0.1, 0.12 } }, headSize = 48,
}
TYPES.duizendblad = { -- yarrow: a stiff stem with feathery leaves, a flat-topped umbel of tiny
    -- white flowers, now and then pink
    stems = { 1, 3, 0.35 }, stemAxiom = 'FOFOFOF[++FM][--FM][+FM][-FM]FM', iter = 0, angle = 11, len = 44, width = 5,
    rules = {}, final = {},
    leaf = 'frond', leafLen = 75, leafWidth = 0.35, leafSpread = 0.8, leafShrink = 0.4,
    stem = { 0.42, 0.52, 0.32 }, leafColor = { 0.36, 0.5, 0.3 },
    flowers = { { 0.96, 0.95, 0.9 }, { 0.92, 0.9, 0.84 } }, pinkChance = 0.2, headSize = 26,
}
-- more forest
TYPES.vingerhoedskruid = { -- foxglove: a rosette of big soft leaves, one tall spike of pink bells
    -- hanging to one side, opening from the bottom; sometimes white
    prefix = 'R', stems = { 1, 2, 0.2 }, stemAxiom = 'FFlFFlFFlFG', iter = 0, angle = 10, len = 60, width = 7,
    rules = {}, final = {},
    fan = { { count = 8, spread = 2.4, len = 200, widthK = 0.55, droop = 0.4 },
            { count = 4, spread = 1.2, len = 160, widthK = 0.55, droop = 0.15 } },
    fanLeaf = 'oval', leaf = 'oval', leafLen = 70, leafWidth = 0.5, leafSpread = 0.7,
    stem = { 0.4, 0.5, 0.3 }, leafColor = { 0.36, 0.5, 0.32 },
    leafColors = { { 0.36, 0.5, 0.32 }, { 0.4, 0.54, 0.36 } },
    flowers = { { 0.8, 0.4, 0.66 }, { 0.74, 0.34, 0.6 } }, whiteChance = 0.15, headSize = 40,
}
TYPES.salomonszegel = { -- Solomon's seal: arching stems, oval leaves held out flat along them,
    -- little white-green bells hanging underneath in pairs; blue-black berries later
    stems = { 1, 3, 0.9 }, stemAxiom = 'FFFLJFLJFLJFlJFl', iter = 0, angle = 0, len = 52, width = 5, curl = 7,
    rules = {}, final = {},
    leaf = 'oval', leafLen = 85, leafWidth = 0.55, leafSpread = 1.3,
    stem = { 0.45, 0.56, 0.36 }, leafColor = { 0.34, 0.52, 0.32 },
    flowers = { { 0.92, 0.95, 0.85 }, { 0.86, 0.92, 0.78 } }, headSize = 26,
}
TYPES.bosanemoon = { -- wood anemone: a carpet of short stems, a whorl of lobed leaves, one white
    -- flower of six petals (pink on the back), yellow in the middle
    stems = { 4, 9, 1.6 }, stemAxiom = 'FFOFA', iter = 0, angle = 0, len = 22, width = 3,
    rules = {}, final = {},
    leaf = 'frond', leafLen = 46, leafWidth = 0.6, leafSpread = 1.1,
    stem = { 0.5, 0.42, 0.36 }, leafColor = { 0.34, 0.52, 0.3 },
    flowers = { { 0.97, 0.96, 0.95 }, { 0.96, 0.9, 0.92 } }, heart = { 0.95, 0.82, 0.25 },
    petalCount = 6, petalWidth = 0.75, headSize = 34,
}
-- more waterside
TYPES.lisdodde = { -- bulrush: long narrow grey-green leaves, stiff stems each topped by a brown
    -- velvet cigar and a thin spike; gone over it bursts into fluff
    prefix = 'Y', stems = { 1, 3, 0.18 }, stemAxiom = 'FFFFFFFFE', iter = 0, angle = 0, len = 66, width = 6,
    rules = {}, final = {}, wet = true,
    fan = { { count = 7, spread = 0.7, len = 640, widthK = 0.1, droop = 0.3 },
            { count = 4, spread = 0.35, len = 560, widthK = 0.1, droop = 0.05 } },
    fanLeaf = 'oval', stem = { 0.45, 0.55, 0.38 }, leafColor = { 0.42, 0.55, 0.4 },
    leafColors = { { 0.42, 0.55, 0.4 }, { 0.46, 0.58, 0.42 }, { 0.38, 0.52, 0.38 } },
    flowers = { { 0.4, 0.25, 0.14 }, { 0.45, 0.28, 0.15 } }, headSize = 50,
}
TYPES.dotterbloem = { -- marsh marigold: a clump of round glossy leaves on stalks, golden cups of
    -- five petals
    stems = { 5, 10, 1.6 }, stemAxioms = { 'FFL', 'FFFl', 'FFFFA' }, iter = 0, angle = 0, len = 34, width = 4,
    rules = {}, final = {},
    leaf = 'oval', leafLen = 95, leafWidth = 1.0, leafSpread = 0.15,
    stem = { 0.42, 0.56, 0.32 }, leafColor = { 0.28, 0.5, 0.26 },
    flowers = { { 0.98, 0.8, 0.12 }, { 0.98, 0.74, 0.08 } }, heart = { 0.9, 0.62, 0.1 },
    petalCount = 5, petalWidth = 1.0, cup = true, headSize = 36,
}

-- fruit
TYPES.aardbei = { -- wild strawberry: a low clump of three-part toothed leaves on stalks, white five-
    -- petal flowers, little strawberries hanging, green, then white, then red
    stems = { 5, 9, 1.6 }, stemAxioms = { 'FFt', 'FFFt', 'FFt', 'FFA', 'FFFb', 'FFb' }, iter = 0, angle = 0,
    len = 26, width = 3, rules = {}, final = {},
    leaf = 'petal', leafLen = 55, leafWidth = 0.7,
    stem = { 0.45, 0.5, 0.32 }, leafColor = { 0.3, 0.5, 0.26 },
    flowers = { { 0.97, 0.96, 0.94 } }, heart = { 0.95, 0.85, 0.3 }, petalCount = 5, petalWidth = 0.9,
    fruit = 'strawberry', headSize = 24,
}
TYPES.braam = { -- bramble: arching canes, toothed leaves, clusters of berries ripening green, red,
    -- then glossy black (the ones on one cluster all at their own pace)
    stems = { 2, 4, 1.3 }, stemAxiom = 'FFLFLFb[+FLb]FLFLb[-Fb]FLb', iter = 0, angle = 30, len = 46, width = 6,
    curl = 6, rules = {}, final = {},
    leaf = 'petal', leafLen = 70, leafWidth = 0.75, leafSpread = 0.9,
    stem = { 0.45, 0.3, 0.3 }, leafColor = { 0.28, 0.46, 0.26 },
    flowers = { { 0.95, 0.9, 0.92 } }, fruit = 'blackberry', headSize = 26,
}

local ZONES = {
    { name = 'meadow', x0 = -3500, x1 = -1100, sky = { 0.78, 0.88, 0.92 }, soil = { 0.52, 0.38, 0.26 },
      top = { 0.45, 0.62, 0.3 },
      kinds = { 'marjolein', 'tijm', 'blauweknoop', 'beemdkroon', 'paardenbloem', 'klaproos', 'duizendblad', 'aardbei' } },
    { name = 'forest', x0 = -1100, x1 = 1100, sky = { 0.5, 0.6, 0.52 }, soil = { 0.3, 0.22, 0.15 },
      top = { 0.42, 0.31, 0.19 },
      shade = true,
      kinds = { 'tongvaren', 'mannetjesvaren', 'koningsvaren', 'vingerhoedskruid', 'salomonszegel', 'bosanemoon',
          'braam', 'aardbei' } },
    { name = 'waterside', x0 = 1100, x1 = 3500, sky = { 0.8, 0.9, 0.93 }, soil = { 0.42, 0.37, 0.3 },
      top = { 0.48, 0.6, 0.34 }, water = 1500,
      kinds = { 'watermunt', 'kattenstaart', 'gelelis', 'lisdodde', 'dotterbloem' } },
}
local function zoneAt(x)
    for _, z in ipairs(ZONES) do if x < z.x1 then return z end end
    return ZONES[#ZONES]
end

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
    local t = pl.t or TYPES[pl.kind]
    local size = pl.size
    local x, y, a = pl.x, GROUND_Y, pl.lean or 0
    local stemI = 0
    local width = t.width * size
    local path = 0
    local stack = {}
    local stems, parts = {}, {}
    local cur = { pts = { x, y }, widths = { width } }
    stems[1] = cur
    local births = pl.births
    if pl.noStem then a = 0 end
    if pl.noStem and pl.spine then a = clamp(spineAngle(pl, 1) * 0.5, -0.5, 0.5) end
    for i, tok in ipairs(pl.tokens) do
        local c = tok.c
        local birth = births and births[i] or 0
        if c == 'F' then
            local k = smooth((grow - birth * 0.85) / 0.12)
            local len = t.len * size * (0.8 + tok.r1 * 0.4) * k
            if t.curl then a = a + math.rad(t.curl) * (a >= 0 and 1 or -1) * k end
            a = a + (pl.bend or 0) * k
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
        elseif c == '^' then -- the next stem out of the root, at its own angle
            stemI = stemI + 1
            a = a + (pl.stemAngles and pl.stemAngles[stemI] or 0)
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

-- Every plant its own recipe: the kind's numbers each nudged (how far each may go in JITTER), the
-- leaf colours shifted together (one plant stays one plant), the flowers on their own; in the
-- shade longer stems and bigger leaves. Plus genes the recipe doesn't have: how many stems and at
-- what angles, a lean, a bend as it grows, leaves missing, flowers late (still buds) and gone over.
local JITTER = { angle = 0.25, len = 0.15, width = 0.15, leafLen = 0.2, leafWidth = 0.15, leafSpread = 0.2,
    headSize = 0.15, curl = 0.4, pinnaWidth = 0.15 }
local function shiftColor(c, d)
    return { clamp(c[1] + d[1], 0, 1), clamp(c[2] + d[2], 0, 1), clamp(c[3] + d[3], 0, 1) }
end
local function vary(t, rng, zone)
    local v = {}
    for k, val in pairs(t) do v[k] = val end
    local function j(amount) return 1 + (rng:random() * 2 - 1) * amount end
    for k, amount in pairs(JITTER) do
        if v[k] then v[k] = v[k] * j(amount) end
    end
    if zone and zone.shade then
        if v.len then v.len = v.len * 1.12 end
        if v.leafLen then v.leafLen = v.leafLen * 1.15 end
    end
    local dl = { (rng:random() - 0.5) * 0.1, (rng:random() - 0.5) * 0.1, (rng:random() - 0.5) * 0.08 }
    if v.leafColor then v.leafColor = shiftColor(v.leafColor, dl) end
    if v.stem then v.stem = shiftColor(v.stem, dl) end
    if v.leafColors then
        local lc = {}
        for i, c in ipairs(v.leafColors) do lc[i] = shiftColor(c, dl) end
        v.leafColors = lc
    end
    if v.flowers then
        local base = v.flowers
        if v.whiteChance and rng:random() < v.whiteChance then
            base = { { 0.96, 0.95, 0.93 }, { 0.92, 0.9, 0.9 } }
        elseif v.pinkChance and rng:random() < v.pinkChance then
            base = { { 0.92, 0.7, 0.8 }, { 0.86, 0.62, 0.74 } }
        end
        local df = { (rng:random() - 0.5) * 0.14, (rng:random() - 0.5) * 0.14, (rng:random() - 0.5) * 0.14 }
        local fl = {}
        for i, c in ipairs(base) do fl[i] = shiftColor(c, df) end
        v.flowers = fl
    end
    if v.fan then
        local fan = {}
        for i, ring in ipairs(v.fan) do
            local r = {}
            for k, val in pairs(ring) do r[k] = val end
            r.count = math.max(2, ring.count + rng:random(-2, 2))
            r.spread = ring.spread * j(0.15)
            r.len = ring.len * j(0.18)
            r.droop = ring.droop * j(0.35)
            fan[i] = r
        end
        v.fan = fan
    end
    return v
end

local function newPlant(kind, x, seed, sizeK)
    local rng = love.math.newRandomGenerator(seed)
    local zone = zoneAt(x)
    local t = vary(TYPES[kind], rng, zone)
    local pl = { kind = kind, x = x, seed = seed, grow = 0, target = 0.06, phase = rng:random() * 6,
        size = (0.7 + rng:random() * 0.55) * 1.7 * (sizeK or 1), sprout = 1 + rng:random(3),
        stroke = 1 + rng:random(#STROKE.strokes) - 1, t = t }
    pl.lean = (rng:random() - 0.5) * 0.22
    pl.bend = (rng:random() - 0.5) * 0.05
    pl.sparse = rng:random() < 0.4 and rng:random() * 0.3 or 0
    pl.late = rng:random() * 0.8
    pl.over = rng:random() ^ 2 * (t.over or 0.5)
    if t.stems then
        local n = rng:random(t.stems[1], t.stems[2])
        local ax = t.prefix or ''
        pl.stemAngles = {}
        for i = 1, n do
            local f = n > 1 and (i - 1) / (n - 1) - 0.5 or 0
            pl.stemAngles[i] = f * t.stems[3] + (rng:random() - 0.5) * 0.15
            local sa = t.stemAxioms and t.stemAxioms[rng:random(#t.stemAxioms)] or t.stemAxiom
            ax = ax .. '[^' .. sa .. ']'
        end
        t.axiom = ax
    end
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
    b.layout = 'biomes2'
    local n = 0
    for _, z in ipairs(ZONES) do
        local x = math.max(z.x0, -3300) + 100
        local x1 = math.min(z.x1, 3300) - 100
        local prev, run = nil, 0
        while x < x1 do
            -- often the same as the one before, a little smaller (it spread there), else any of the biome's
            local kind, sizeK
            if prev and run < 3 and love.math.random() < 0.35 then
                kind, sizeK = prev, 0.65 + love.math.random() * 0.3
            else
                kind = z.kinds[love.math.random(#z.kinds)]
            end
            local wet = TYPES[kind].wet
            if z.water and wet and x < z.water + 80 then kind, sizeK = 'kattenstaart', nil end
            if not (z.water and not wet and x > z.water + 500 and love.math.random() < 0.6) then
                n = n + 1
                b.list[#b.list + 1] = newPlant(kind, x, b.seed * 100 + n, sizeK)
                run = (kind == prev) and run + 1 or 1
                prev = kind
            end
            x = x + 110 + love.math.random() * 200
        end
    end
end

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function growStep(b, amount)
    for _, pl in ipairs(b.list) do pl.target = math.min(1, pl.target + amount) end
end

local pickAt -- (picking, below)

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
        local kinds = zoneAt(mx).kinds
        b.list[#b.list + 1] = newPlant(kinds[love.math.random(#kinds)], mx, love.math.random(1e6))
    elseif key == 'm' then b.settings.brush = not b.settings.brush
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

function s.update(dt)
    local b = state.plants
    if not b then return end
    if b.layout ~= 'biomes2' then sowAll(b) end
    b.time = b.time + dt
    b.pickedList = b.pickedList or {}
    b.pickAt = pickAt -- a handle for the bridge (tests)
    -- a fresh press on a flower or fruit picks it (the press on its spine, if any, is taken over)
    local down = love.mouse.isDown(1)
    if down and not b.wasDown and state.playMode then
        local mx, my = love.mouse.getPosition()
        local pr = b.panelRect
        local overPanel = b.showPanel and pr and mx >= pr[1] and mx <= pr[1] + pr[3] and my >= pr[2] and my <= pr[2] + pr[4]
        if not overPanel then
            local wx, wy = mouseWorldPos()
            pickAt(b, wx, wy)
        end
    end
    b.wasDown = down
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
        -- Mipos brush it aside: a push on each spine body a Mipo part is in, the way it's going.
        -- Off by default (m): the plants are a layer of their own, the mouse bends them, Mipos walk through
        if pl.spine and b.settings.brush then
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

---------------------------------------------------------------- small flowers: dots of drawn rings

local function hash(a, b)
    local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return v - math.floor(v)
end
local function mix(c1, c2, k)
    return { c1[1] + (c2[1] - c1[1]) * k, c1[2] + (c2[2] - c1[2]) * k, c1[3] + (c2[3] - c1[3]) * k }
end
local BUD = { 0.46, 0.6, 0.32 }

-- one drawn crayon ring, centred on (x, y), d across, turned a little its own way
local function dot(x, y, d, col, h)
    if d < 1 then return end
    local a = (h - 0.5) * 2
    drawPart('berry-0' .. (1 + math.floor(h * 2.999)), x - math.sin(a) * d * 0.5, y + math.cos(a) * d * 0.5,
        a, d, col, OUTLINE, 1, 1)
end

-- a round head of dots (flat squashes it), the outer ones first so the middle sits on top
local function dotBall(x, y, r, n, cols, seed, open, flat)
    for i = n, 1, -1 do
        local h = hash(seed, i)
        local ang = i * 2.39996 + seed
        local rr = r * math.sqrt((i - 0.5) / n) * (0.4 + 0.6 * open)
        local d = r * 0.62 * (0.8 + h * 0.4) * (0.45 + 0.55 * open)
        local col = mix(BUD, cols[1 + math.floor(h * #cols * 0.999)], open)
        dot(x + math.cos(ang) * rr, y + math.sin(ang) * rr * (flat or 1), d, col, h)
    end
end

-- a spike of dots along angle a, tapering to the tip; they open from the bottom up
local function dotSpike(x, y, a, len, w, n, cols, seed, open)
    local dx, dy = math.sin(a), -math.cos(a)
    for i = 1, n do
        local f = (i - 1) / math.max(1, n - 1)
        local h = hash(seed, i)
        local across = (h - 0.5) * w * (1 - f * 0.5)
        local along = f * len * (0.35 + 0.65 * open)
        local o = smooth(open * 1.8 - f)
        local d = w * 0.6 * (1 - f * 0.45) * (0.55 + 0.45 * o)
        local col = mix(BUD, cols[1 + math.floor(h * #cols * 0.999)], o)
        dot(x + dx * along - dy * across, y + dy * along + dx * across, d, col, h)
    end
end

local DOT_HEADS = { M = true, S = true, K = true, Q = true, P = true, W = true, w = true, Z = true, I = true,
    C = true, N = true, G = true, J = true, A = true, E = true, b = true }
local rememberHead -- (picking, below)
-- what a tap picks off a plant (the fern's spores and the mint's lower whorl stay on)
local PICKABLE = { M = true, S = true, K = true, Q = true, P = true, W = true, I = true, C = true, N = true,
    G = true, J = true, A = true, E = true, b = true, B = true }
local GONE = { 0.55, 0.45, 0.32 }
local LEAFY = { L = true, l = true, O = true, V = true, t = true }

-- the heads of the wild plants; open 0 a bud .. 1 in flower
local function drawWildHead(t, pl, p, open, over)
    local tok = p.tok
    local r = t.headSize * pl.size
    local seed = math.floor(tok.r1 * 1000) + 1
    local x, y, a = p.x, p.y, p.a
    -- gone over: the colour goes out of it (the kinds below with a seed head of their own draw that)
    if over then
        local faded = {}
        for i, c in ipairs(t.flowers) do faded[i] = mix(c, GONE, 0.6) end
        local copy = {}
        for k, v in pairs(t) do copy[k] = v end
        copy.flowers = faded
        t = copy
    end
    if p.c == 'b' then -- fruit, ripening
        if t.fruit == 'strawberry' then -- hanging, green, white, red, with its seeds
            local col = open < 0.5 and mix(BUD, { 0.95, 0.93, 0.82 }, open * 2)
                or mix({ 0.95, 0.93, 0.82 }, { 0.88, 0.14, 0.16 }, (open - 0.5) * 2)
            local len = r * (0.5 + 0.6 * open)
            drawPart('petal-0' .. (1 + math.floor(tok.r3 * 8.99)), x, y, math.pi + (tok.r2 - 0.5) * 0.5, len, col, OUTLINE, 1, 1.1)
            for i = 1, 5 do
                dot(x + (hash(seed, i) - 0.5) * len * 0.5, y + len * (0.25 + hash(seed, i + 5) * 0.55), r * 0.12,
                    { 0.98, 0.88, 0.45 }, hash(seed, i + 2))
            end
            drawPart('petal-05', x, y, (tok.r2 - 0.5), r * 0.35, { 0.32, 0.5, 0.26 }, OUTLINE, 1, 1.4) -- the green cap
        else -- a cluster of drupelets, each ripening at its own pace: green, red, black
            for i = 9, 1, -1 do
                local h = hash(seed, i)
                local ang = i * 2.39996 + seed
                local rr = r * 0.55 * math.sqrt((i - 0.5) / 9)
                local o = clamp(open * 1.3 - h * 0.3, 0, 1)
                local col = o < 0.5 and mix(BUD, { 0.8, 0.15, 0.2 }, o * 2) or mix({ 0.8, 0.15, 0.2 }, { 0.14, 0.1, 0.16 }, (o - 0.5) * 2)
                dot(x + math.cos(ang) * rr, y + r * 0.4 + math.sin(ang) * rr, r * 0.42 * (0.6 + 0.4 * open), col, h)
            end
        end
    elseif p.c == 'C' then -- dandelion: a yellow head of narrow florets, or a white clock
        if over then
            dotBall(x, y - r * 0.9, r * 1.15, 18, { { 0.97, 0.97, 0.95 }, { 0.9, 0.9, 0.88 } }, seed, 1, 1)
            dot(x, y - r * 0.9, r * 0.3, { 0.5, 0.42, 0.3 }, tok.r2)
        else
            for k = 0, 15 do
                drawPart('petal-0' .. (k % 9 + 1), x, y - r * 0.2, a + k / 16 * math.pi * 2 + tok.r2,
                    r * (0.35 + 0.65 * open), mix(BUD, t.flowers[1 + k % #t.flowers], open), OUTLINE, 1, 0.4)
            end
            dotBall(x, y - r * 0.2, r * 0.42, 7, { lighter(t.flowers[2] or t.flowers[1], 0.95) }, seed, open, 0.9)
        end
    elseif p.c == 'N' then -- poppy: a nodding bud, then four petals; gone over a seed capsule
        if over then
            dot(x, y - r * 0.3, r * 0.6, { 0.6, 0.68, 0.45 }, tok.r2)
            dot(x, y - r * 0.62, r * 0.32, { 0.3, 0.26, 0.24 }, tok.r3)
        elseif open < 0.45 then
            drawPart('oval-02', x, y, a + 2.7 - open * 2, r * (0.45 + open * 0.5), { 0.42, 0.55, 0.3 }, OUTLINE, 1, 0.75)
        else
            local o = smooth((open - 0.45) / 0.55)
            for i, ang in ipairs({ -1.25, 1.25, -0.42, 0.42 }) do
                local col = t.flowers[1 + (i - 1) % #t.flowers]
                drawPart('oval-0' .. i, x, y, a + ang * (0.45 + 0.55 * o), r * (0.55 + 0.45 * o),
                    i <= 2 and lighter(col, 0.85) or col, OUTLINE, 1, 1.3)
            end
            dot(x, y - r * 0.3, r * 0.34, { 0.16, 0.12, 0.12 }, tok.r2)
        end
    elseif p.c == 'G' then -- foxglove: bells hanging out to one side up a spike, opening from the bottom
        local n, side = 12, tok.r2 < 0.5 and -1 or 1
        local dx, dy = math.sin(a), -math.cos(a)
        for i = 1, n do
            local f = (i - 1) / (n - 1)
            if not (over and f < 0.5) then
                local o = smooth(open * 1.8 - f)
                local along = f * r * 6.5 * (0.4 + 0.6 * open)
                local sd = (hash(seed, i) < 0.8) and side or -side
                drawPart('oval-0' .. (1 + i % 5), x + dx * along, y + dy * along, a + sd * (1.9 + hash(seed, i + 9) * 0.4),
                    r * (1.5 - f * 0.7) * (0.35 + 0.65 * o), mix(BUD, t.flowers[1 + i % #t.flowers], o), OUTLINE, 1, 1.25)
            end
        end
    elseif p.c == 'J' then -- Solomon's seal: two bells hanging straight down; gone over, dark berries
        for j = 0, 1 do
            local bx = x + (j - 0.5) * r * 0.55
            if over then
                dot(bx, y + r * 0.6, r * 0.45, { 0.2, 0.22, 0.35 }, hash(seed, j))
            else
                drawPart('oval-0' .. (2 + j), bx, y + r * 0.1, math.pi + (j - 0.5) * 0.35, r * (0.5 + 0.5 * open),
                    mix(BUD, t.flowers[1 + j % #t.flowers], open), OUTLINE, 1, 0.55)
            end
        end
    elseif p.c == 'A' then -- a simple flower: a ring of petals (or a cup of them) round a heart of dots
        local n = t.petalCount or 5
        if not over then
            for k = 0, n - 1 do
                local ang
                if t.cup then ang = a + (k / (n - 1) - 0.5) * 2.2 * (0.6 + 0.4 * open)
                else ang = a + tok.r2 + k / n * math.pi * 2 end
                drawPart('oval-0' .. (k % 5 + 1), x, y, ang, r * (0.3 + 0.7 * open),
                    mix(BUD, t.flowers[1 + k % #t.flowers], open), OUTLINE, 1, t.petalWidth or 0.9)
            end
        end
        dotBall(x, y - (t.cup and r * 0.25 or 0), r * 0.32, 6, { over and BUD or (t.heart or t.flowers[1]) }, seed, open, 0.9)
    elseif p.c == 'E' then -- bulrush: a velvet cigar, a thin spike on top; gone over, fluff
        local dx, dy = math.sin(a), -math.cos(a)
        local len = r * 2.4 * (0.5 + 0.5 * open)
        local col = mix(BUD, t.flowers[1], open)
        drawPart('oval-0' .. (1 + math.floor(tok.r2 * 4.99)), x, y, a, len, col, OUTLINE, 1, 0.3)
        drawPart('oval-05', x + dx * len * 0.95, y + dy * len * 0.95, a, r * 1.1, lighter(t.stem, 0.9), OUTLINE, 1, 0.08)
        if over then
            dotBall(x + dx * len * 0.5, y + dy * len * 0.5, r * 0.6, 9, { { 0.93, 0.9, 0.82 } }, seed, 1, 1.4)
        end
    elseif p.c == 'M' then -- marjoram: a little dome of tufts, dark bracts showing through
        dotBall(x, y - r * 0.3, r, 8, t.flowers, seed, open, 0.6)
    elseif p.c == 'S' then -- thyme: a short fat spike
        dotSpike(x, y, a, r, r * 0.6, 7, t.flowers, seed, open)
    elseif p.c == 'K' then -- devil's-bit: a dark round knob, covered in dots
        dot(x, y - r * 0.4, r * 1.9 * (0.5 + 0.5 * open), mix(BUD, lighter(t.flowers[3], 0.85), open), tok.r2)
        dotBall(x, y - r * 0.45, r * 0.85, 11, t.flowers, seed, open, 0.9)
    elseif p.c == 'Q' then -- field scabious: a flat pincushion, the outer florets bigger
        local n = 11
        for k = 0, n - 1 do
            local ang = a + k / n * math.pi * 2 + tok.r2
            drawPart('petal-0' .. (k % 9 + 1), x, y - r * 0.2, ang, r * (0.35 + 0.65 * open) * 1.05,
                mix(BUD, t.flowers[1 + k % #t.flowers], open), OUTLINE, 1, 0.75)
        end
        dotBall(x, y - r * 0.2, r * 0.55, 9, { lighter(t.flowers[1], 1.1) }, seed, open, 0.8)
    elseif p.c == 'P' then -- loosestrife: a long dense spike
        dotSpike(x, y, a, r * 6, r * 1.1, 24, t.flowers, seed, open)
    elseif p.c == 'W' then -- water mint: a round head at the top
        dotBall(x, y - r * 0.5, r, 11, t.flowers, seed, open, 0.95)
    elseif p.c == 'w' then -- and a ring round the stem lower down
        dotBall(x, y, r * 0.75, 7, t.flowers, seed + 7, open, 0.4)
    elseif p.c == 'Z' then -- royal fern: some fronds end in a fertile tip, spore beads green to rust
        if tok.r2 < 0.55 then dotSpike(x, y, a, r * 3, r * 0.9, 14, t.flowers, seed, open) end
    elseif p.c == 'I' then -- yellow flag: a closed bud, then three falls out and down, standards up
        local col = t.flowers[1 + math.floor(tok.r2 * #t.flowers * 0.999)]
        if open < 0.35 then
            drawPart('oval-02', x, y + 4, a, r * (0.5 + open), mix(BUD, col, open * 2), OUTLINE, 1, 0.35)
        else
            local o = smooth((open - 0.35) / 0.65)
            for side = -1, 1, 2 do
                drawPart('oval-0' .. (2 + side), x, y, a + side * (0.6 + 1.4 * o), r * (0.6 + 0.4 * o), col, OUTLINE, 1, 1.0)
            end
            drawPart('oval-04', x, y, a + math.pi * 0.92, r * 0.7 * o, lighter(col, 0.95), OUTLINE, 1, 0.9)
            for side = -1, 1, 2 do
                drawPart('oval-05', x, y, a + side * 0.3, r * 0.55, lighter(col, 1.05), OUTLINE, 1, 0.6)
            end
            -- the dark veins on the falls' bases: a small brown dab
            dot(x, y + r * 0.05, r * 0.2 * o, { 0.5, 0.32, 0.12 }, tok.r3)
        end
    end
end

---------------------------------------------------------------- picking

-- Where a tap takes a head: how far along its stem its middle is and how big a target it is (in
-- head sizes); every drawn head that can be picked is remembered for the next press.
local HIT_ALONG = { P = 3, G = 3, S = 0.5, E = 1.2, M = 0.3, K = 0.45, Q = 0.2, W = 0.5, C = 0.4, N = 0.3,
    A = 0.1, I = 0.2, J = -0.6, b = -0.6 }
local HIT_SIZE = { P = 3, G = 3.3, E = 1.6 }
rememberHead = function(b, pl, pi, p, t)
    local r = t.headSize * pl.size
    local along = (HIT_ALONG[p.c] or 0.3) * r
    b.heads[#b.heads + 1] = { pl = pl, pi = pi, p = p, t = t,
        x = p.x + math.sin(p.a) * along, y = p.y - math.cos(p.a) * along,
        r = math.max(30, r * (HIT_SIZE[p.c] or 1.1)) }
end

local MAX_PICKED = 25

-- Take the head under (wx, wy) off its plant: it becomes a small light body (a stalk with the head on
-- top, a snap point at the stalk's end so a Mipo's hand takes it), carried by the pointer.
pickAt = function(b, wx, wy)
    local best, bestD
    for _, h in ipairs(b.heads or {}) do
        local d = math.sqrt((wx - h.x) ^ 2 + (wy - h.y) ^ 2) / h.r
        if d < 1 and (not bestD or d < bestD) then best, bestD = h, d end
    end
    if not best then return false end
    local pl, p = best.pl, best.p
    pl.picked = pl.picked or {}
    pl.picked[best.pi] = b.time
    local fruit = p.c == 'b'
    local len = (fruit and 30 or 90) * pl.size
    local a = fruit and math.pi or p.a -- fruit hangs: its stalk points up from it
    local cx, cy = p.x - math.sin(a) * len * 0.5, p.y + math.cos(a) * len * 0.5
    local thing = objectManager.addThing('rectangle', { x = cx, y = cy, width = 14, height = len,
        bodyType = 'dynamic', label = fruit and 'picked-fruit' or 'picked-flower', density = 0.3 })
    if not thing then return false end
    local body = thing.body
    body:setAngle(a)
    body:setAngularDamping(1.5)
    snap.addPoint(body, 0, len * 0.5, 16)
    pointerGrab('mouse', body, wx, wy)
    b.pickedList[#b.pickedList + 1] = { body = body, len = len, pl = pl, t = best.t, c = p.c, tok = p.tok,
        fruit = fruit, open = 1 }
    while #b.pickedList > MAX_PICKED do
        local old = table.remove(b.pickedList, 1)
        if not old.body:isDestroyed() then objectManager.destroyBody(old.body) end
    end
    return true
end

-- the picked ones, where their bodies are: a stalk, the head on top (fruit hangs from its stalk)
local function drawPicked(b)
    local alive = {}
    for _, f in ipairs(b.pickedList or {}) do
        if not f.body:isDestroyed() then
            alive[#alive + 1] = f
            local body = f.body
            local tx, ty = body:getWorldPoint(0, -f.len * 0.5)
            local bx, by = body:getWorldPoint(0, f.len * 0.5)
            local a = body:getAngle()
            local pic = STROKE.strokes[f.pl.stroke] and STROKE.strokes[f.pl.stroke].seamless
            local w = 5 * f.pl.size
            drawRibbon({ bx, by, tx, ty }, { w + 6, w + 6 }, pic, OUTLINE)
            drawRibbon({ bx, by, tx, ty }, { w, w }, pic, f.t.stem)
            local hx, hy = tx, ty
            if f.fruit then hx, hy = bx, by end
            drawWildHead(f.t, f.pl, { c = f.c, x = hx, y = hy, a = f.fruit and a + math.pi or a, tok = f.tok,
                birth = 1 }, f.open, false)
        end
    end
    b.pickedList = alive
end

local function drawPlant(b, pl, pass)
    local t = pl.t or TYPES[pl.kind]
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
    for pi, p in ipairs(parts) do
        local tok = p.tok
        local k = smooth((g - p.birth * 0.85 - 0.06) / 0.16)
        -- a few leaves missing (eaten, fallen), more on some plants than others
        if LEAFY[p.c] and hash(tok.r1 * 1000, 9) < (pl.sparse or 0) then k = 0 end
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
                -- a drawn crayon ring (the Mipo eye outlines + masks, textures/plants/berry-0n) hanging
                -- from its stem point, each its own ring and twist, a crayon dab for the shine
                local d = 30 * pl.size * smooth((g - 0.7) / 0.25)
                local ang = math.pi + (tok.r2 - 0.5) * 0.8
                drawPart('berry-0' .. (1 + math.floor(tok.r3 * 3)), p.x, p.y, ang, d,
                    lighter(t.berry, 0.9 + tok.r2 * 0.2), OUTLINE, 1, 0.95 + tok.r1 * 0.15)
                local cx, cy = p.x + math.sin(ang) * d * 0.5, p.y - math.cos(ang) * d * 0.5
                drawPart('berry-shine', cx - d * 0.18, cy - d * 0.05, 0, d * 0.22, nil, { 1, 1, 1 }, 0.7)
            elseif p.c == 'O' then -- a pair of opposite leaves, smaller higher up
                local nm = t.leaf or 'oval'
                for side = -1, 1, 2 do
                    local h = hash(tok.r3 * 100, side)
                    local name = nm == 'frond' and ('frond-0' .. (1 + math.floor(h * 1.999)))
                        or nm .. '-0' .. (1 + math.floor(h * (nm == 'petal' and 8.999 or 4.999)))
                    local ang = p.a + side * (t.leafSpread or 0.9) * (0.85 + tok.r2 * 0.3)
                        + math.sin(b.time * 1.6 + pl.phase + p.birth * 5 + side) * 0.06
                    local len = t.leafLen * pl.size * (0.85 + tok.r2 * 0.3) * k * (1 - p.birth * (t.leafShrink or 0))
                    local pt = part(name)
                    local col = lighter(t.leafColor, 0.9 + tok.r1 * 0.2)
                    drawPart(name, p.x, p.y, ang, len, col, pt and pt.mask and OUTLINE or col, 1, (t.leafWidth or 0.6) / 0.6)
                end
            elseif p.c == 't' then -- a three-part leaf (strawberry): three leaflets out of one point
                for j = -1, 1 do
                    local name = t.leaf .. '-0' .. (1 + math.floor(hash(tok.r3 * 100, j) * 8.999))
                    local ang = p.a + j * 0.75 + math.sin(b.time * 1.6 + pl.phase + j) * 0.05
                    drawPart(name, p.x, p.y, ang, t.leafLen * pl.size * (j == 0 and 1 or 0.85) * k,
                        lighter(t.leafColor, 0.9 + tok.r1 * 0.2), OUTLINE, 1, t.leafWidth / 0.6)
                end
            elseif p.c == 'V' then -- a royal fern's pair of oblong leaflets, smaller towards the tip
                local len = t.leafLen * pl.size * (1 - p.birth * 0.5) * k
                for side = -1, 1, 2 do
                    drawPart(t.pinna .. '-0' .. (1 + math.floor(hash(tok.r3 * 100, side) * 4.999)), p.x, p.y,
                        p.a + side * 1.25, len, lighter(t.leafColor, 0.9 + tok.r1 * 0.2), OUTLINE, 1, t.pinnaWidth / 0.6)
                end
            elseif DOT_HEADS[p.c] then
                -- some heads late (still a bud, fully grown), some gone over
                local late = hash(tok.r2 * 1000, 5) * (pl.late or 0)
                local over = hash(tok.r3 * 1000, 6) < (pl.over or 0)
                local open = smooth((g - 0.68 - late * 0.3) / 0.3)
                -- picked: gone, then a bud again that opens (a new one grows)
                local pk = pl.picked and pl.picked[pi]
                if pk then
                    local back = smooth((b.time - pk - 6) / 14)
                    if back >= 1 then pl.picked[pi] = nil end
                    open = math.min(open, back)
                    over = false
                end
                if g > 0.6 and (not pk or open > 0) then
                    drawWildHead(t, pl, p, open, over and g > 0.95)
                    if PICKABLE[p.c] and not pk and open > 0.3 then rememberHead(b, pl, pi, p, t) end
                end
            elseif p.c == 'R' or p.c == 'Y' or p.c == 'D' then
                drawFan(b, t, pl, p, g)
            elseif p.c == 'H' or p.c == 'T' then
                if g > 0.72 then drawHead(t, pl, p, smooth((g - 0.78) / 0.22)) end
            end
        end
    end
end

---------------------------------------------------------------- the biomes

local drawBiomes, drawWater

-- a zone's colour band, its edges blended into the next over BLEND
local BLEND = 300
local function zoneBands(key, xa, xb, y, h)
    for i, z in ipairs(ZONES) do
        local za, zb = (i == 1) and xa or z.x0, (i == #ZONES) and xb or z.x1
        if zb > xa and za < xb then
            local c = z[key]
            love.graphics.setColor(c)
            love.graphics.rectangle('fill', math.max(za, xa), y, math.min(zb, xb) - math.max(za, xa), h)
        end
    end
    for i, z in ipairs(ZONES) do
        if ZONES[i + 1] then -- this zone's colour fading out into the next one
            local c = z[key]
            for k = 0, 11 do
                love.graphics.setColor(c[1], c[2], c[3], 1 - (k + 0.5) / 12)
                love.graphics.rectangle('fill', z.x1 + k * BLEND / 12, y, BLEND / 12 + 1, h)
            end
        end
    end
end

-- the forest: trunks going up out of view, a dark canopy, a few shafts of light
local TRUNKS = { { -980, 90 }, { -640, 70 }, { -230, 110 }, { 180, 80 }, { 560, 100 }, { 960, 75 } }
local function drawForest(xa, xb)
    local f = ZONES[2]
    if xb < f.x0 - BLEND or xa > f.x1 + BLEND then return end
    local pic = STROKE.strokes[1] and STROKE.strokes[1].seamless
    for i, tr in ipairs(TRUNKS) do
        local pts, ws, ow = {}, {}, {}
        for k = 0, 12 do
            local y = GROUND_Y + 20 - k * 260
            pts[#pts + 1] = tr[1] + math.sin(k * 0.7 + i) * 18
            pts[#pts + 1] = y
            ws[#ws + 1] = tr[2] * (1.25 - k * 0.02) * (k == 0 and 1.4 or 1)
            ow[#ow + 1] = ws[#ws] + 10
        end
        drawRibbon(pts, ow, pic, { 0.18, 0.13, 0.1 })
        drawRibbon(pts, ws, pic, { 0.34 + i % 2 * 0.04, 0.26, 0.19 })
    end
    -- the canopy: big drawn leaf shapes, dark, overlapping
    for i = 0, 26 do
        local h1, h2, h3 = hash(i, 1), hash(i, 2), hash(i, 3)
        local x = f.x0 - 200 + i / 26 * (f.x1 - f.x0 + 400)
        local y = GROUND_Y - 2300 - h1 * 500
        local g = 0.22 + h2 * 0.1
        drawPart('oval-0' .. (1 + math.floor(h3 * 4.999)), x, y + 450, (h2 - 0.5) * 2.4, 900 + h1 * 400,
            { g * 0.8, g + 0.12, g * 0.75 }, OUTLINE, 1, 1.3)
    end
    -- shafts of light falling in between
    for i, sx in ipairs({ -760, 20, 760 }) do
        love.graphics.setColor(1, 0.96, 0.75, 0.07 + 0.02 * (i % 2))
        love.graphics.polygon('fill', sx, GROUND_Y - 1400, sx + 160, GROUND_Y - 1400,
            sx + 420, GROUND_Y, sx + 140, GROUND_Y)
    end
end

drawBiomes = function(xa, xb)
    zoneBands('sky', xa, xb, GROUND_Y - 30000, 30000)
    -- the forest's shade only under its canopy: above it the open sky again
    love.graphics.setColor(ZONES[1].sky)
    love.graphics.rectangle('fill', xa, GROUND_Y - 30000, xb - xa, 30000 - 2300)
    drawForest(xa, xb)
    zoneBands('soil', xa, xb, GROUND_Y, 4000)
    zoneBands('top', xa, xb, GROUND_Y - 6, 34)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(6)
    love.graphics.line(xa, GROUND_Y - 6, xb, GROUND_Y - 6)
    love.graphics.setLineWidth(1)
end

-- the waterside's water, over the plants' feet: shallow, a little see-through, a wobbly top
drawWater = function(b, xa, xb)
    local z = ZONES[3]
    local wx0, wx1 = math.max(z.water, xa), xb
    if wx1 <= wx0 then return end
    local top = GROUND_Y - 70
    local pts = {}
    for x = wx0, wx1, 40 do
        pts[#pts + 1] = x
        pts[#pts + 1] = top + math.sin(x * 0.012 + b.time * 1.3) * 4 + math.sin(x * 0.031 - b.time * 0.9) * 2
    end
    -- the bank: the water's left side slopes down under the ground
    local poly = { z.water + 300, GROUND_Y + 200 }
    if wx0 > z.water then poly[1] = math.max(wx0, poly[1]) end
    for i = 1, #pts do poly[#poly + 1] = pts[i] end
    poly[#poly + 1] = wx1
    poly[#poly + 1] = GROUND_Y + 200
    love.graphics.setColor(0.38, 0.6, 0.74, 0.62)
    local tris = love.math.triangulate(poly)
    for _, tri in ipairs(tris) do love.graphics.polygon('fill', tri) end
    if #pts >= 4 then
        love.graphics.setLineWidth(6)
        love.graphics.setColor(0.85, 0.94, 0.98, 0.9)
        love.graphics.line(pts)
        love.graphics.setLineWidth(1)
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
    drawBiomes(x0 - 100, x1 + 100)
    b.heads = {}
    for _, pl in ipairs(b.list) do drawPlant(b, pl, 'stems') end
    for _, pl in ipairs(b.list) do drawPlant(b, pl, 'leaves') end
    drawWater(b, x0 - 100, x1 + 100)
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
    drawPicked(b)
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
    b.panelRect = { x0, y0, w, h }
    ui.panel(x0, y0, w, h, '•• plants ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 180, 'grow (g)') then growStep(b, 0.2) end
        if ui.button(x + 190, y, 180, 'all the way (f)') then growStep(b, 1) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 180, 'new seeds (n)') then sowAll(b) end
        if ui.button(x + 190, y, 180, b.settings.brush and 'mipos push: on (m)' or 'mipos push: off (m)') then
            b.settings.brush = not b.settings.brush
        end
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
