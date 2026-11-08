-- bark-look: trees drawn in real bark (not a scene): the bark pictures (textures/world/bark), the bark shader
-- (each branch a round stem, the bark's normal map under a light) and the eyes on the trunk. Loaded with
-- love.filesystem.load('scripts/spikes/bark-look.lua')() -> { begin, drawTree, placeEyes, reset, shader }.
-- A tree to draw: { def = { bark, mirrored, tint }, parts (tree-mesh.lua), eyes, mipoEyes (placeEyes) }.
--   begin(settings) once a frame: lightPos {x, y, out}, lightColour, ambient, detail, look (0 photo,
--     1 tinted, 2 relief), bands (0 smooth), debugView (0 off, 1 normals, 2 light), barkWidth
--   drawTree(tree, { eyes = bool, mipoEyes = bool, outlines = bool })
--   placeEyes(def, kind, trunkPts, rng, age) -> eyes, mipoEyes (on the bare trunk, where branches were; none
--     on a young tree, more on an old one)
--   reset() drops the loaded pictures (a scene's onUnload)
-- From the bark spike (docs/BARK.md).
local lib = {}

-- The eyes: branch scars from photos (Wikimedia Commons, CC0: textures/world/bark/bark-eyes.png, BARK.md),
-- cells side by side, each eye's white made 1 so it multiplies into any bark: 1 the aspen eye, 2 the
-- birch's big scar, 3 its small one; 4-10 the Mipo eyes (eye-01..07, outline in ink, a round pupil), for
-- m. EYE_CELL: a cell's height over its width.
local EYE_CELLS = 10
local MIPO_EYE_CELLS = { 4, 10 }
local EYE_CELL = 320 / 512
local MAX_EYES = 6
local eyeAtlas

local barks = {}
local function barkOf(id, mirrored)
    if barks[id] then return barks[id] end
    local function load(path)
        local image = love.graphics.newImage(path, { mipmaps = true })
        local wrap = mirrored and 'mirroredrepeat' or 'repeat'
        image:setWrap(wrap, wrap)
        image:setMipmapFilter('linear')
        image:setFilter('linear', 'linear', 8)
        return image
    end
    local base = 'textures/world/bark/' .. (id:match('^%d') and ('bark-' .. id) or id)
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
    uniform Image eyeMap;      // the eyes, side by side
    uniform vec4 eyes[6];      // round the stem (angle), up it, how wide, which
    uniform int eyeCount;
    uniform float eyeCell;     // a cell's height / width
    uniform float eyeCells;    // how many cells
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
        // the eyes: each in the stem's own frame, so one round the side is squeezed like the bark
        for (int i = 0; i < 6; ++i) {
            if (i >= eyeCount) break;
            vec4 e = eyes[i];
            float ex = (th - e.x) * r / e.z;
            float ey = (vFrame.z - e.y) / (e.z * eyeCell);
            if (abs(ex) < 0.5 && abs(ey) < 0.5) {
                vec4 t = Texel(eyeMap, vec2((e.w + ex + 0.5) / eyeCells, 0.5 - ey));
                col *= mix(vec3(1.0), t.rgb, t.a);
            }
        }
        vec3 light = ambient + lightColour * d * 1.1;
        if (debugView == 1) return vec4(Nw * 0.5 + 0.5, 1.0) * color.a;
        if (debugView == 2) return vec4(light * 0.8, 1.0) * color.a;
        return vec4(col * light, 1.0) * color.a;
    }
]])

function lib.placeEyes(t, k, trunk, rng, age)
    local eyes, mipoEyes = {}, {}
    age = age or 1
    -- its eyes, the same every time: up the trunk (the bare part, where branches were), round it
    -- either way, about as wide as the trunk there (laid round the curve, they show narrower)
    local count = t.eyes or (rng:random() < 0.35 and 1 or 0)
    -- a young tree has shed no branches yet; an old one more
    if age < 1 then count = math.floor(count * age) end
    if age > 1 then count = count + math.floor((age - 1) * (t.eyes and 3 or 1) + 0.5) end -- aspens, birches most
    local top = k.fork and 0.9 or (k.trunkStart + 0.1)
    for e = 1, math.min(count, MAX_EYES) do
        local u = 0.1 + (top - 0.1) * (e - 1 + rng:random()) / math.max(1, count)
        local p = trunk[math.floor(u * (#trunk - 1)) + 1]
        local kinds = t.kinds or { 1, 2, 3 }
        local eye = { (rng:random() - 0.5) * 1.7, p.along, p.w * (0.7 + 0.8 * rng:random()),
            kinds[rng:random(1, #kinds)] - 1 }
        eyes[#eyes + 1] = eye
        -- the same eye as a Mipo's (m): a little smaller, they're rounder than the scars
        mipoEyes[#mipoEyes + 1] = { eye[1], eye[2], eye[3] * 0.8,
            rng:random(MIPO_EYE_CELLS[1], MIPO_EYE_CELLS[2]) - 1 }
    end
    return eyes, mipoEyes
end

function lib.begin(settings)
    for key, v in pairs(settings) do barkShader:send(key, v) end
    if not eyeAtlas then
        -- no mipmaps: it's looked up only inside an eye's box, and at the box's edge the GPU picks a far
        -- too blurred level (a faint box round every eye)
        eyeAtlas = love.graphics.newImage('textures/world/bark/bark-eyes.png')
        eyeAtlas:setFilter('linear', 'linear')
    end
    barkShader:send('eyeMap', eyeAtlas)
    barkShader:send('eyeCell', EYE_CELL)
    barkShader:send('eyeCells', EYE_CELLS)
end

function lib.drawTree(tree, opts)
    local b = barkOf(tree.def.bark, tree.def.mirrored)
    barkShader:send('normalMap', b.normal)
    barkShader:send('heightMap', b.height)
    barkShader:send('aspect', b.aspect)
    barkShader:send('meanLum', b.meanLum)
    barkShader:send('tint', tree.def.tint)
    for _, part in ipairs(tree.parts) do
        love.graphics.setShader(barkShader)
        local eyeCount = (part.isStem and opts.eyes) and #tree.eyes or 0
        barkShader:send('eyeCount', eyeCount)
        if eyeCount > 0 then barkShader:send('eyes', unpack(opts.mipoEyes and tree.mipoEyes or tree.eyes)) end
        love.graphics.setColor(1, 1, 1, 1)
        part.mesh:setTexture(b.colour)
        love.graphics.draw(part.mesh)
        love.graphics.setShader()
        if opts.outlines then
            love.graphics.setColor(0.13, 0.1, 0.09, 1)
            for _, mesh in ipairs(part.strokes) do love.graphics.draw(mesh) end
        end
    end
end

function lib.reset()
    barks = {}
    eyeAtlas = nil
end

lib.shader = barkShader

return lib
