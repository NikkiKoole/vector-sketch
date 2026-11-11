-- OMP bench: baked part pictures against drawing them live (docs/OMP-LIVE.md OL1).
--
-- Baked is what Playtime does today: each part's outline + mask + pattern (+ patches) flattened
-- once into its own picture (src/render/omp-bake.lua makeTexturedCanvas, half size), drawn as that.
-- Live draws the shared source pictures straight, the same layers mixed in a shader per draw:
-- nothing per Mipo in memory, nothing to bake, a few uniforms sent per part.
--
-- The parts are the 20 Mipos of scripts/tests/crowd.playtime.json (the design limit per room),
-- drawn as quads at the dollhouse's zoom: ribbons (limbs, hair) as quads too, so the frame test is
-- a load test, not a pose. '+patches' gives each Mipo's torso two skin patches (the DNA's default
-- patch1/patch2), the most any Mipo has today (randomize clears them).
--
--   love .          look for yourself: 1-8 option, z zoom
--   love . --auto   every option, writes results/live-<os>.md and quits (~1 min)
--   on the phone:   LOVE_DIR=../omp-bench native/ios/device.sh (from ../playtime): runs --auto by
--                   itself, the table on screen and in the save folder (omp-live-results.md)
--
-- The old shrink/release options (results/results.md, 2026-10-29) are in git history: shrink 2
-- and release went into Playtime.

if jit then jit.off() end -- luacheck: ignore 113 (Playtime runs with the JIT off, iOS has none)

local IOS = love.system.getOS() == 'iOS'
local AUTO = IOS
for _, a in ipairs(arg or {}) do
    if a == '--auto' then AUTO = true end
end
if AUTO then -- an unattended run must not sit on LÖVE's error screen
    love.errorhandler = function(msg)
        print(debug.traceback('Error: ' .. tostring(msg), 3))
    end
end

local ompBake = require('src.render.omp-bake')
local color = require('src.color')
local json = require('vendor.dkjson')

local SCENE = 'scripts/tests/crowd.playtime.json'
local CAMERA_SCALE = 0.35 -- the dollhouse's saved camera zoom
local CLOSE_SCALE = 1.0
local FRAME_TEST_FRAMES = 600
local LITTER = 5          -- Mipos appearing at once (a litter, a randomize of a few)
local RAMP_STEP, RAMP_FRAMES, RAMP_MAX = 10, 60, 300
local RAMP_BUDGET_MS = 17.5 -- a frame later than this has missed 60 fps
local MB = 1024 * 1024
local PATTERN_WRAP = { wrapX = 'mirroredrepeat', wrapY = 'mirroredrepeat' }

-- the DNA's default skin patches (src/mipo-dna.lua humanoid torso skin)
local PATCHES = {
    { bgURL = 'mipo/patch/patch-02.png', fgURL = 'mipo/patch/patch-02-mask.png', pURL = 'type2t.png',
        bgHex = '020202ff', fgHex = 'd94f3dff', pHex = '3d6bd9ff', tx = -0.33, ty = 0 },
    { bgURL = 'mipo/patch/patch-01.png', fgURL = 'mipo/patch/patch-01-mask.png', pURL = 'type2t.png',
        bgHex = '020202ff', fgHex = 'f2c94cff', pHex = '4cf28aff', tx = 0.33, ty = 0 },
}

-- send: how live gets a part's numbers to the shader
--   naive   9 sends a part (17 with patches), one per uniform
--   packed  one send of an array of vec4s; mask/pattern pictures sent only when they change
--   mesh    each part its own mesh with the numbers as vertex attributes; only the pictures sent,
--           when they change (no patches: they'd be 25 more floats a vertex)
--   mesh+rg as mesh, outline and mask in one shared two-channel picture per shape (outline alpha in
--           red, mask in green: the outlines are white, a mask only uses red), so only the pattern
--           is sent, when it changes; a quarter of the two pictures' memory
local OPTIONS = {
    { name = 'baked',          live = false, patches = false },
    { name = 'baked+patches',  live = false, patches = true },
    { name = 'live',           live = true,  patches = false, send = 'naive' },
    { name = 'live+patches',   live = true,  patches = true,  send = 'naive' },
    { name = 'packed',         live = true,  patches = false, send = 'packed' },
    { name = 'packed+patches', live = true,  patches = true,  send = 'packed' },
    { name = 'mesh',           live = true,  patches = false, send = 'mesh' },
    { name = 'mesh+rg',        live = true,  patches = false, send = 'mesh', combined = true },
}

---------------------------------------------------------------- sources

-- Baked: the pictures through Playtime's own cache (no mipmaps, as in the game).
local function bakedSource(url, isPattern)
    if not url or url == '' then return nil end
    return (ompBake.getLoveImage(url, isPattern and PATTERN_WRAP or nil))
end

-- Live: the same files with mipmaps. Drawn at the crowd's zoom a source carries ~4.5 of its pixels
-- per screen pixel; without mipmaps the grain shimmers. (The bake hides that by halving.)
local liveCache = {}
local function liveSource(url, isPattern)
    if not url or url == '' then return nil end
    if liveCache[url] == nil then
        local info = love.filesystem.getInfo(url)
        local img = false
        if info and info.type == 'file' then
            img = love.graphics.newImage(url, { mipmaps = true })
            img:setMipmapFilter('linear')
            if isPattern then img:setWrap('mirroredrepeat', 'mirroredrepeat') end
        end
        liveCache[url] = img
    end
    return liveCache[url] or nil
end

-- outline alpha + mask red in one rg8 picture, mipmapped, made on the GPU once per shape
local combinedCache = {}
local combineShader
local function combinedSource(outlineURL, maskURL)
    local key = outlineURL .. '|' .. (maskURL or '')
    if not combinedCache[key] then
        local outline = liveSource(outlineURL)
        local mask = liveSource(maskURL)
        local w, h = outline:getDimensions()
        local canvas = love.graphics.newCanvas(w, h, { format = 'rg8', mipmaps = 'auto', dpiscale = 1 })
        canvas:setMipmapFilter('linear')
        love.graphics.push('all')
        love.graphics.origin()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setBlendMode('replace')
        love.graphics.setShader(combineShader)
        combineShader:send('maskTex', mask or love.graphics.newImage(love.image.newImageData(1, 1)))
        love.graphics.draw(outline)
        love.graphics.pop()
        combinedCache[key] = canvas
    end
    return combinedCache[key]
end

local function texMB()
    return love.graphics.getStats().texturememory / MB
end

---------------------------------------------------------------- the scene's Mipos

local function bboxSize(vertices)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #vertices, 2 do
        minX = math.min(minX, vertices[i]); maxX = math.max(maxX, vertices[i])
        minY = math.min(minY, vertices[i + 1]); maxY = math.max(maxY, vertices[i + 1])
    end
    return maxX - minX, maxY - minY
end

-- { { part, part, ... }, ... } a list per Mipo; a part is { main = layer, w, h, torso }
local function loadMipos()
    local data = json.decode((love.filesystem.read(SCENE)), 1, nil)
    local groups, order = {}, {}
    for _, body in ipairs(data.bodies) do
        for _, fixture in ipairs(body.fixtures or {}) do
            local extra = fixture.userData and fixture.userData.extra
            if extra and extra.OMP and extra.main and extra.main.bgURL and extra.main.bgURL ~= '' then
                local key = extra.zGroupOffset or 0
                if not groups[key] then
                    groups[key] = {}
                    order[#order + 1] = key
                end
                table.insert(groups[key], extra)
            end
        end
    end
    table.sort(order)
    local mipos = {}
    for _, key in ipairs(order) do
        if #groups[key] >= 5 then -- props aren't Mipos
            local parts, biggest = {}, nil
            for _, extra in ipairs(groups[key]) do
                local outline = bakedSource('textures/' .. extra.main.bgURL)
                if outline then
                    local w, h
                    if extra.vertices then w, h = bboxSize(extra.vertices) else w, h = outline:getDimensions() end
                    local part = { main = extra.main, w = w, h = h }
                    parts[#parts + 1] = part
                    -- the torso: the biggest part with a fill that isn't a ribbon
                    if extra.vertices and extra.main.fgURL and extra.main.fgURL ~= ''
                        and (not biggest or w * h > biggest.w * biggest.h) then
                        biggest = part
                    end
                end
            end
            if biggest then biggest.torso = true end
            mipos[#mipos + 1] = parts
        end
    end
    return mipos
end

---------------------------------------------------------------- baked (today)

local function rgbOf(hex)
    local r, g, b, a = color.hexToColor(hex)
    return { r, g, b }, a
end

-- the same steps as makePatch in omp-bake
local function bakePatch(p)
    local outline = bakedSource('textures/' .. p.bgURL)
    local fill, fillA = rgbOf(p.fgHex)
    local pat, patA = rgbOf(p.pHex)
    local line, lineA = rgbOf(p.bgHex)
    local imgData = ompBake.makeTexturedCanvas(outline, bakedSource('textures/' .. p.fgURL),
        fill, fillA, bakedSource('textures/pat/' .. p.pURL, true), pat, patA,
        0, 1, 1, 0, 0, line, lineA, 1, 1)
    local img = love.graphics.newImage(imgData)
    imgData:release()
    return { img = img, tint = 'ffffff', tx = p.tx, ty = p.ty }
end

-- the same steps as makeCombinedImages in omp-bake, for one part
local tex1
local function bakePart(part, withPatches)
    local main = part.main
    if not main.cached then ompBake.makeCached(main) end
    local c = main.cached
    local patches = nil
    if withPatches and part.torso then
        patches = {}
        for i, p in ipairs(PATCHES) do patches[i] = bakePatch(p) end
    end
    local hasFg = main.fgURL and main.fgURL ~= ''
    local imgData = ompBake.makeTexturedCanvas(
        bakedSource('textures/' .. main.bgURL), hasFg and bakedSource('textures/' .. main.fgURL) or nil,
        c.fgRGB, c.fgA, bakedSource('textures/pat/' .. (main.pURL or ''), true) or tex1, c.pRGB, c.pA,
        main.pr or 0, main.psx or 1, main.psy or 1, main.ptx or 0, main.pty or 0,
        c.bgRGB, c.bgA, main.fx or 1, main.fy or 1, patches)
    local img = love.graphics.newImage(imgData)
    imgData:release()
    if patches then for _, p in ipairs(patches) do p.img:release() end end
    return { img = img, w = part.w, h = part.h }
end

---------------------------------------------------------------- live

-- One pass of what makeTexturedCanvas draws onto its canvas: the fill (mask, coloured, pattern
-- mixed in) over the outline colour at alpha 0, patches into the colour only (the bake's
-- setColorMask), the outline on top. src = the source's uv with the part's flip (mask, pattern
-- and outline are drawn flipped in the bake, patches aren't).
local LIVE_CODE = [[
uniform Image maskTex;
uniform Image patTex;
uniform vec4 fillColor;  // rgb, alpha (fgHex)
uniform vec4 patColor;   // rgb, alpha (pHex)
uniform vec4 lineColor;  // rgb, alpha (bgHex)
uniform mat2 uvTransform;
uniform vec2 uvTranslation;
uniform vec2 flip;       // 1 where the part is flipped on that axis
uniform float hasMask;
#ifdef PATCHES
uniform Image pLine[2];
uniform Image pMask[2];
uniform Image pPat[2];
uniform vec3 pRow1[2];   // the part's uv -> the patch's uv (affine, two rows)
uniform vec3 pRow2[2];
uniform vec4 pFill[2];
uniform vec4 pPatColor[2];
uniform vec4 pLineColor[2];
uniform float patchCount;

vec4 patchColor(Image line, Image mask, Image pat, vec2 puv, vec4 fill, vec4 pc, vec4 lc) {
    if (puv.x < 0.0 || puv.y < 0.0 || puv.x > 1.0 || puv.y > 1.0) return vec4(0.0);
    float m = Texel(mask, puv).r * fill.a;
    float pa = Texel(pat, puv).a * pc.a;
    vec3 rgb = mix(lc.rgb, mix(fill.rgb, pc.rgb, pa), m);
    vec4 lt = Texel(line, puv);
    float la = lt.a * lc.a;
    return vec4(mix(rgb, lc.rgb * lt.rgb, la), la + m * (1.0 - la));
}
#endif

vec4 effect(vec4 vcolor, Image outline, vec2 uv, vec2 fc) {
    vec2 src = mix(uv, 1.0 - uv, flip);
    float m = hasMask * Texel(maskTex, src).r * fillColor.a;
    float pa = Texel(patTex, src * uvTransform + uvTranslation).a * patColor.a;
    vec3 rgb = mix(lineColor.rgb, mix(fillColor.rgb, patColor.rgb, pa), m);
    float a = m;
#ifdef PATCHES
    if (patchCount > 0.5) {
        vec3 u = vec3(uv, 1.0);
        vec4 p = patchColor(pLine[0], pMask[0], pPat[0], vec2(dot(pRow1[0], u), dot(pRow2[0], u)),
            pFill[0], pPatColor[0], pLineColor[0]);
        rgb = mix(rgb, p.rgb, p.a);
        p = patchColor(pLine[1], pMask[1], pPat[1], vec2(dot(pRow1[1], u), dot(pRow2[1], u)),
            pFill[1], pPatColor[1], pLineColor[1]);
        rgb = mix(rgb, p.rgb, p.a);
    }
#endif
    vec4 lt = Texel(outline, src);
    float la = lt.a * lineColor.a;
    rgb = mix(rgb, lineColor.rgb * lt.rgb, la);
    a = la + a * (1.0 - la);
    return vec4(rgb, a) * vcolor;
}
]]
-- The same mix with a part's numbers in one array (packed) or in vertex attributes (mesh).
-- P[0] fill, P[1] pattern colour, P[2] line colour, P[3] the pattern's uv matrix (columns),
-- P[4] = (pattern offset x, y, flip x + 2 flip y, hasMask + 2 patchCount); with patches 5 more
-- per patch: its uv rows (xyz), fill, pattern colour, line colour.
local PACKED_CODE = [[
#ifdef PATCHES
#define NP 15
#else
#define NP 5
#endif
#ifdef MESH
varying vec4 vP0, vP1, vP2, vP3, vP4;
#endif
#ifdef VERTEX
#ifdef MESH
attribute vec4 A0, A1, A2, A3, A4;
#endif
vec4 position(mat4 transform_projection, vec4 vertex_position) {
#ifdef MESH
    vP0 = A0; vP1 = A1; vP2 = A2; vP3 = A3; vP4 = A4;
#endif
    return transform_projection * vertex_position;
}
#endif
#ifdef PIXEL
uniform Image maskTex;
uniform Image patTex;
#ifndef MESH
uniform vec4 P[NP];
#endif
#ifdef PATCHES
uniform Image pLine[2];
uniform Image pMask[2];
uniform Image pPat[2];
vec4 patchColor(Image line, Image mask, Image pat, vec2 puv, vec4 fill, vec4 pc, vec4 lc) {
    if (puv.x < 0.0 || puv.y < 0.0 || puv.x > 1.0 || puv.y > 1.0) return vec4(0.0);
    float m = Texel(mask, puv).r * fill.a;
    float pa = Texel(pat, puv).a * pc.a;
    vec3 rgb = mix(lc.rgb, mix(fill.rgb, pc.rgb, pa), m);
    vec4 lt = Texel(line, puv);
    float la = lt.a * lc.a;
    return vec4(mix(rgb, lc.rgb * lt.rgb, la), la + m * (1.0 - la));
}
#endif
vec4 effect(vec4 vcolor, Image outline, vec2 uv, vec2 fc) {
#ifdef MESH
    vec4 fill = vP0, patC = vP1, lineC = vP2, M = vP3, E = vP4;
#else
    vec4 fill = P[0], patC = P[1], lineC = P[2], M = P[3], E = P[4];
#endif
    vec2 flip = vec2(mod(E.z, 2.0), floor(E.z / 2.0 + 0.25));
    float hasMask = mod(E.w, 2.0);
    vec2 src = mix(uv, 1.0 - uv, flip);
#ifdef COMBINED
    vec4 c = Texel(outline, src);
    float m = c.g * fill.a;
    vec4 lt = vec4(1.0, 1.0, 1.0, c.r);
#else
    float m = hasMask * Texel(maskTex, src).r * fill.a;
    vec4 lt = Texel(outline, src);
#endif
    float pa = Texel(patTex, src * mat2(M.x, M.y, M.z, M.w) + E.xy).a * patC.a;
    vec3 rgb = mix(lineC.rgb, mix(fill.rgb, patC.rgb, pa), m);
    float a = m;
#ifdef PATCHES
    if (E.w > 1.5) {
        vec3 u = vec3(uv, 1.0);
        vec4 p = patchColor(pLine[0], pMask[0], pPat[0], vec2(dot(P[5].xyz, u), dot(P[6].xyz, u)),
            P[7], P[8], P[9]);
        rgb = mix(rgb, p.rgb, p.a);
        p = patchColor(pLine[1], pMask[1], pPat[1], vec2(dot(P[10].xyz, u), dot(P[11].xyz, u)),
            P[12], P[13], P[14]);
        rgb = mix(rgb, p.rgb, p.a);
    }
#endif
    float la = lt.a * lineC.a;
    rgb = mix(rgb, lineC.rgb * lt.rgb, la);
    a = la + a * (1.0 - la);
    return vec4(rgb, a) * vcolor;
}
#endif
]]
local liveShader, livePatchShader
local packedShader, packedPatchShader, meshShader, combinedShader
local blackPixel
local MESH_FORMAT = {
    { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 },
    { 'A0', 'float', 4 }, { 'A1', 'float', 4 }, { 'A2', 'float', 4 }, { 'A3', 'float', 4 }, { 'A4', 'float', 4 },
}

local function vec4Of(hex)
    local r, g, b, a = color.hexToColor(hex)
    return { r, g, b, a }
end

-- the part's uv -> a patch's uv, as makeTexturedCanvas places a patch on the canvas
local function patchRows(lw, lh, pw, ph, p)
    local t = love.math.newTransform()
    t:translate(lw / 2 + (p.tx or 0) * pw, lh / 2 + (p.ty or 0) * ph)
    t:rotate((p.r or 0) * math.pi * 2 / 16)
    t:scale(p.sx or 1, p.sy or 1)
    t:translate(-pw / 2, -ph / 2) -- patch px -> part px
    t = t:inverse()               -- part px -> patch px
    local m = love.math.newTransform():scale(1 / pw, 1 / ph):apply(t):apply(love.math.newTransform():scale(lw, lh))
    local a, b, _, c, d, e, _, f = m:getMatrix()
    return { a, b, c }, { d, e, f }
end

-- What a part sends each draw, worked out once (a colour change would just change these)
local function prepareLive(part, withPatches, send)
    local main = part.main
    local outline = liveSource('textures/' .. main.bgURL)
    local mask = liveSource('textures/' .. (main.fgURL or ''))
    local pattern = liveSource('textures/pat/' .. (main.pURL or ''), true) or liveSource('textures/pat/type0.png', true)
    local t = love.math.newTransform():rotate(main.pr or 0):scale(main.psx or 1, main.psy or 1)
    local m1, m2, _, _, m5, m6 = t:getMatrix()
    local lw, lh = outline:getDimensions()
    local live = {
        outline = outline, w = part.w, h = part.h, lw = lw, lh = lh,
        mask = mask or blackPixel, pattern = pattern, hasMask = mask and 1 or 0,
        fill = vec4Of(main.fgHex), pat = vec4Of(main.pHex), line = vec4Of(main.bgHex),
        uvTransform = { { m1, m2 }, { m5, m6 } }, uvTranslation = { main.ptx or 0, main.pty or 0 },
        flip = { (main.fx or 1) < 0 and 1 or 0, (main.fy or 1) < 0 and 1 or 0 },
    }
    if withPatches and part.torso then
        live.patches = { line = {}, mask = {}, pat = {}, row1 = {}, row2 = {}, fill = {}, patColor = {}, lineColor = {} }
        local ps = live.patches
        for i, p in ipairs(PATCHES) do
            local pl = liveSource('textures/' .. p.bgURL)
            ps.line[i], ps.mask[i] = pl, liveSource('textures/' .. p.fgURL)
            ps.pat[i] = liveSource('textures/pat/' .. p.pURL, true)
            local pw, ph = pl:getDimensions()
            ps.row1[i], ps.row2[i] = patchRows(lw, lh, pw, ph, p)
            ps.fill[i], ps.patColor[i], ps.lineColor[i] = vec4Of(p.fgHex), vec4Of(p.pHex), vec4Of(p.bgHex)
        end
    end
    if send == 'packed' or send == 'mesh' then
        local ps = live.patches
        local packed = {
            live.fill, live.pat, live.line,
            { m1, m5, m2, m6 }, -- the matrix's columns (the naive send gives it as rows)
            { main.ptx or 0, main.pty or 0, live.flip[1] + 2 * live.flip[2], live.hasMask + 2 * (ps and #ps.line or 0) },
        }
        if ps then
            for i = 1, #ps.line do
                local r1, r2 = ps.row1[i], ps.row2[i]
                packed[#packed + 1] = { r1[1], r1[2], r1[3], 0 }
                packed[#packed + 1] = { r2[1], r2[2], r2[3], 0 }
                packed[#packed + 1] = ps.fill[i]
                packed[#packed + 1] = ps.patColor[i]
                packed[#packed + 1] = ps.lineColor[i]
            end
        end
        live.packed = packed
    end
    if send == 'mesh' then
        if withPatches == 'combined' then
            live.combined = combinedSource('textures/' .. main.bgURL, mask and 'textures/' .. main.fgURL)
        end
        local vertices = {}
        for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }) do
            local v = { c[1] * lw, c[2] * lh, c[1], c[2] }
            for k = 1, 5 do
                for j = 1, 4 do v[#v + 1] = live.packed[k][j] end
            end
            vertices[#vertices + 1] = v
        end
        live.mesh = love.graphics.newMesh(MESH_FORMAT, vertices, 'fan', 'static')
        live.mesh:setTexture(live.combined or outline)
    end
    return live
end

-- the pictures a shader has now: only sent when they change (packed, mesh)
local lastSent = setmetatable({}, { __mode = 'k' })
local function sendImage(shader, name, img)
    local sent = lastSent[shader]
    if not sent then
        sent = {}
        lastSent[shader] = sent
    end
    if sent[name] ~= img then
        shader:send(name, img)
        sent[name] = img
    end
end

local function sendPacked(shader, live)
    if not live.combined then sendImage(shader, 'maskTex', live.mask) end
    sendImage(shader, 'patTex', live.pattern)
    if not live.mesh then
        local ps = live.patches
        if ps then
            -- an array of pictures goes in one send; every torso has the same patches here
            local sent = lastSent[shader]
            if sent.patches ~= ps.line[1] then
                shader:send('pLine', unpack(ps.line))
                shader:send('pMask', unpack(ps.mask))
                shader:send('pPat', unpack(ps.pat))
                sent.patches = ps.line[1]
            end
        end
        shader:send('P', unpack(live.packed))
    end
end

local function sendLive(shader, live)
    if live.packed then return sendPacked(shader, live) end
    shader:send('maskTex', live.mask)
    shader:send('patTex', live.pattern)
    shader:send('fillColor', live.fill)
    shader:send('patColor', live.pat)
    shader:send('lineColor', live.line)
    shader:send('uvTransform', live.uvTransform)
    shader:send('uvTranslation', live.uvTranslation)
    shader:send('flip', live.flip)
    shader:send('hasMask', live.hasMask)
    if shader == livePatchShader then
        local ps = live.patches
        if ps then
            shader:send('pLine', unpack(ps.line))
            shader:send('pMask', unpack(ps.mask))
            shader:send('pPat', unpack(ps.pat))
            shader:send('pRow1', unpack(ps.row1))
            shader:send('pRow2', unpack(ps.row2))
            shader:send('pFill', unpack(ps.fill))
            shader:send('pPatColor', unpack(ps.patColor))
            shader:send('pLineColor', unpack(ps.lineColor))
        end
        shader:send('patchCount', ps and #ps.line or 0)
    end
end

---------------------------------------------------------------- drawing

local current = { option = OPTIONS[1], mipos = {} } -- mipos: a list per Mipo of baked or live parts
local view = { scale = CAMERA_SCALE, layout = 'scatter', count = 20 }

local function drawPart(option, p, x, y, scale)
    if p.mesh then
        love.graphics.draw(p.mesh, x, y, 0, p.w * scale / p.lw, p.h * scale / p.lh)
    elseif option.live then
        love.graphics.draw(p.outline, x, y, 0, p.w * scale / p.lw, p.h * scale / p.lh)
    else
        local iw, ih = p.img:getDimensions()
        love.graphics.draw(p.img, x, y, 0, p.w * scale / iw, p.h * scale / ih)
    end
end

local function shaderOf(option)
    if not option.live then return nil end
    if option.combined then return combinedShader end
    if option.send == 'mesh' then return meshShader end
    if option.send == 'packed' then return option.patches and packedPatchShader or packedShader end
    return option.patches and livePatchShader or liveShader
end

-- count Mipos (the scene's, over and over), each part somewhere on screen
local function drawScatter(option, list, count, scale)
    local w, h = love.graphics.getDimensions()
    local rng = love.math.newRandomGenerator(7) -- the same layout every frame and every option
    local shader = shaderOf(option)
    love.graphics.setShader(shader)
    for i = 1, count do
        for _, p in ipairs(list[(i - 1) % #list + 1]) do
            if shader then sendLive(shader, p) end
            drawPart(option, p, rng:random(-50, w - 50), rng:random(-50, h - 50), scale)
        end
    end
    love.graphics.setShader()
end

-- one Mipo's parts side by side, for looking and for the pixel diff
local function drawGrid(option, parts, scale, width)
    local x, y, rowH = 10, 30, 0
    local shader = shaderOf(option)
    love.graphics.setShader(shader)
    for _, p in ipairs(parts) do
        local pw, ph = p.w * scale, p.h * scale
        if x + pw > width - 10 then x, y, rowH = 10, y + rowH + 10, 0 end
        if shader then sendLive(shader, p) end
        drawPart(option, p, x, y, scale)
        x = x + pw + 10
        rowH = math.max(rowH, ph)
    end
    love.graphics.setShader()
end

---------------------------------------------------------------- the --auto run

local sourceMipos = {}
local results = {}
local hud = ''
local timing = { submit = 0, dt = 0 }
local runner

local function percentile(list, p)
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    table.sort(copy)
    return copy[math.max(1, math.min(#copy, math.ceil(#copy * p)))]
end
local function median(list) return percentile(list, 0.5) end

local function settle()
    collectgarbage('collect')
    collectgarbage('collect')
    coroutine.yield()
end

local function frames(n)
    local submit, dt = {}, {}
    for _ = 1, n do
        coroutine.yield()
        submit[#submit + 1] = timing.submit
        dt[#dt + 1] = timing.dt
    end
    return submit, dt
end

local function prepareMipo(option, parts)
    local list = {}
    for i, part in ipairs(parts) do
        local withPatches = option.combined and 'combined' or option.patches
        list[i] = option.live and prepareLive(part, withPatches, option.send) or bakePart(part, option.patches)
    end
    return list
end

local function releaseAll(option, mipos)
    if option.live then return end
    for _, list in ipairs(mipos) do
        for _, p in ipairs(list) do p.img:release() end
    end
end

-- Mipo 1's parts with the torso first, so the close look shows its patches
local function torsoFirst(list)
    local out = {}
    for i, part in ipairs(sourceMipos[1]) do
        if part.torso then table.insert(out, 1, list[i]) else out[#out + 1] = list[i] end
    end
    return out
end

local LOOKS_W, LOOKS_H = 1000, 800
local function renderLooks(option, parts, scale)
    local canvas = love.graphics.newCanvas(LOOKS_W, LOOKS_H, { dpiscale = 1 })
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.85, 0.8, 0.75, 1)
    love.graphics.setColor(1, 1, 1)
    drawGrid(option, parts, scale, LOOKS_W)
    love.graphics.pop()
    local data = canvas:newImageData()
    canvas:release()
    return data
end

-- mean difference per channel (0-255) and the share of pixels that differ visibly
local function compareLooks(a, b)
    local w, h = a:getDimensions()
    local sum, visible = 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1 = a:getPixel(x, y)
            local r2, g2, b2 = b:getPixel(x, y)
            local d = (math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2)) / 3
            sum = sum + d
            if d > 8 / 255 then visible = visible + 1 end
        end
    end
    return sum / (w * h) * 255, visible / (w * h) * 100
end

local looksOf = {}
-- the save folder always (the phone has nowhere else); results/ too where the source folder is writable
local function writeResultFile(name, contents)
    love.filesystem.write(name, contents)
    if IOS then return end
    local file = io.open(love.filesystem.getSource() .. '/results/' .. name, 'wb')
    if file then
        file:write(contents)
        file:close()
    end
end

local function runOption(option)
    local row = { name = option.name }
    current.option, current.mipos = option, {}
    settle()
    local startMB = texMB()

    -- 1. the Mipos appear: a bake per part (baked), uniforms worked out (live)
    local perMipo = {}
    for i, parts in ipairs(sourceMipos) do
        local t0 = love.timer.getTime()
        current.mipos[i] = prepareMipo(option, parts)
        perMipo[#perMipo + 1] = (love.timer.getTime() - t0) * 1000
        hud = option.name .. ': Mipo ' .. i
        coroutine.yield()
    end
    row.prepareMs = median(perMipo)
    settle()
    row.perMipoMB = (texMB() - startMB) / #sourceMipos
    -- a litter: LITTER Mipos in one frame, again (and let go again)
    local t0 = love.timer.getTime()
    local litter = {}
    for i = 1, LITTER do litter[i] = prepareMipo(option, sourceMipos[i]) end
    row.litterMs = (love.timer.getTime() - t0) * 1000
    releaseAll(option, litter)
    settle()

    -- 2. the frame with the 20 on screen at the dollhouse zoom
    view.layout, view.scale, view.count = 'scatter', CAMERA_SCALE, #sourceMipos
    hud = option.name .. ': ' .. #sourceMipos .. ' Mipos'
    frames(10) -- skip the frames after a change (a shader's first use)
    local submit, dt = frames(FRAME_TEST_FRAMES)
    row.submitMs, row.submitP95 = median(submit), percentile(submit, 0.95)
    row.frameMs, row.frameP95 = median(dt), percentile(dt, 0.95)
    row.drawcalls = timing.drawcalls

    -- 3. more Mipos until a frame takes longer than 60 fps allows
    row.fits = '>' .. RAMP_MAX
    for count = #sourceMipos, RAMP_MAX, RAMP_STEP do
        view.count = count
        hud = option.name .. ': ramp ' .. count
        frames(10)
        local _, rampDt = frames(RAMP_FRAMES)
        if median(rampDt) > RAMP_BUDGET_MS then
            row.fits = count == #sourceMipos and ('<' .. count) or (count - RAMP_STEP)
            break
        end
    end

    -- 4. looks: Mipo 1 at the dollhouse zoom and close, live against baked
    view.layout = 'none'
    for _, zoom in ipairs({ { 'game', CAMERA_SCALE }, { 'close', CLOSE_SCALE } }) do
        local data = renderLooks(option, torsoFirst(current.mipos[1]), zoom[2])
        writeResultFile('looks-' .. option.name .. '-' .. zoom[1] .. '.png', data:encode('png'):getString())
        local key = (option.patches and 'p' or '') .. zoom[1]
        if not option.live then
            looksOf[key] = data
        else
            row['diff_' .. zoom[1]], row['changed_' .. zoom[1]] = compareLooks(looksOf[key], data)
            data:release()
        end
    end

    releaseAll(option, current.mipos)
    current.mipos = {}
    settle()
    return row
end

local function fmt(v, digits)
    return type(v) == 'number' and string.format('%.' .. (digits or 1) .. 'f', v) or tostring(v or '')
end

local combinedMB = 0 -- mesh+rg's pictures, measured in autoRun
local function resultsText(sourcesMB, liveSourcesMB)
    local columns = {
        { 'option', 'name' }, { 'MB per Mipo', 'perMipoMB', 2 }, { 'appear ms/Mipo', 'prepareMs', 2 },
        { 'litter of ' .. LITTER .. ' ms', 'litterMs' },
        { 'draw ms', 'submitMs', 2 }, { 'draw p95', 'submitP95', 2 },
        { 'frame ms', 'frameMs', 2 }, { 'frame p95', 'frameP95', 2 }, { 'draw calls', 'drawcalls', 0 },
        { 'Mipos in 60 fps', 'fits', 0 },
        { 'diff game', 'diff_game', 2 }, { '% px game', 'changed_game' },
        { 'diff close', 'diff_close', 2 }, { '% px close', 'changed_close' },
    }
    local header, sep = {}, {}
    for _, col in ipairs(columns) do header[#header + 1] = col[1]; sep[#sep + 1] = '---' end
    local lines = { '| ' .. table.concat(header, ' | ') .. ' |', '|' .. table.concat(sep, '|') .. '|' }
    for _, row in ipairs(results) do
        local cells = {}
        for _, col in ipairs(columns) do cells[#cells + 1] = fmt(row[col[2]], col[3]) end
        lines[#lines + 1] = '| ' .. table.concat(cells, ' | ') .. ' |'
    end
    local parts = 0
    for _, list in ipairs(sourceMipos) do parts = parts + #list end
    local name, version, vendor, device = love.graphics.getRendererInfo()
    local w, h, flags = love.window.getMode()
    local intro = {
        '# OMP bench: baked against live',
        '',
        string.format('Run: %s on %s (%s %s, %s %s), window %dx%d at dpi scale %.0f, msaa %d, vsync %s.',
            os.date('%Y-%m-%d %H:%M'), love.system.getOS(), name, version, vendor, device, w, h,
            love.graphics.getDPIScale(), flags.msaa or 0, tostring(flags.vsync)),
        string.format('Scene: %s, %d Mipos, %d OMP parts (ribbons drawn as quads). JIT off.', SCENE,
            #sourceMipos, parts),
        string.format('Shared source pictures: %.1f MB as the game loads them; %.1f MB more for live\'s mipmapped copies;',
            sourcesMB, liveSourcesMB),
        string.format('mesh+rg\'s outline+mask pictures (rg8, mipmapped) %.1f MB, in place of the outlines and masks.', combinedMB),
        '',
        'MB per Mipo: texture memory the 20 Mipos added, over 20. appear: making one Mipo\'s pictures (baked) or',
        'working out its uniforms (live). litter: ' .. LITTER .. ' Mipos in one frame. draw ms: love.draw\'s CPU time',
        string.format('for the 20 (median of %d frames, sends included); frame ms: the time between frames.',
            FRAME_TEST_FRAMES),
        string.format('Mipos in 60 fps: Mipos added %d at a time until the median frame is over %.1f ms.', RAMP_STEP,
            RAMP_BUDGET_MS),
        'diff: live against baked (each with its own patches or not), mean per channel 0-255; % px: off by more than 8/255.',
        '',
    }
    return table.concat(intro, '\n') .. table.concat(lines, '\n') .. '\n'
end

local finalText
local function autoRun()
    -- the sources each way, loaded once before measuring
    for _, parts in ipairs(sourceMipos) do
        for _, part in ipairs(parts) do
            local m = part.main
            bakedSource('textures/' .. (m.fgURL or ''))
            bakedSource('textures/pat/' .. (m.pURL or ''), true)
        end
    end
    for _, p in ipairs(PATCHES) do
        for _, url in ipairs({ p.bgURL, p.fgURL }) do bakedSource('textures/' .. url) end
    end
    settle()
    local sourcesMB = texMB()
    for i = 1, #sourceMipos do prepareMipo(OPTIONS[4], sourceMipos[i]) end
    settle()
    local liveSourcesMB = texMB() - sourcesMB
    for i = 1, #sourceMipos do prepareMipo(OPTIONS[#OPTIONS], sourceMipos[i]) end
    settle()
    combinedMB = texMB() - sourcesMB - liveSourcesMB
    for _, option in ipairs(OPTIONS) do
        results[#results + 1] = runOption(option)
    end
    finalText = resultsText(sourcesMB, liveSourcesMB)
    love.filesystem.write('omp-live-results.md', finalText)
    writeResultFile('live-' .. love.system.getOS():gsub(' ', '') .. '.md', finalText)
    print(finalText)
    if not IOS then love.event.quit() end
    hud = 'done'
end

---------------------------------------------------------------- LÖVE

local function pickInteractive(index)
    local option = OPTIONS[index]
    if current.mipos[1] then releaseAll(current.option, current.mipos) end
    current.option = option
    current.mipos = { prepareMipo(option, sourceMipos[1]) }
    view.layout = 'grid'
    hud = option.name .. '  (1-8 option, z zoom, esc quit)'
end

function love.load()
    love.filesystem.remove('omp-live-results.md') -- the last run's: an install keeps the save folder
    tex1 = ompBake.getLoveImage('textures/pat/type0.png', PATTERN_WRAP)
    blackPixel = love.graphics.newImage(love.image.newImageData(1, 1))
    liveShader = love.graphics.newShader(LIVE_CODE)
    livePatchShader = love.graphics.newShader('#define PATCHES\n' .. LIVE_CODE)
    packedShader = love.graphics.newShader(PACKED_CODE)
    packedPatchShader = love.graphics.newShader('#define PATCHES\n' .. PACKED_CODE)
    meshShader = love.graphics.newShader('#define MESH\n' .. PACKED_CODE)
    combinedShader = love.graphics.newShader('#define MESH\n#define COMBINED\n' .. PACKED_CODE)
    combineShader = love.graphics.newShader([[
        uniform Image maskTex;
        vec4 effect(vec4 c, Image outline, vec2 uv, vec2 fc) {
            return vec4(Texel(outline, uv).a, Texel(maskTex, uv).r, 0.0, 1.0);
        }
    ]])
    sourceMipos = loadMipos()
    if AUTO then
        runner = coroutine.create(autoRun)
    else
        pickInteractive(1)
    end
end

function love.update(dt)
    timing.dt = dt * 1000
    if runner and coroutine.status(runner) ~= 'dead' then
        local ok, err = coroutine.resume(runner)
        if not ok then error(debug.traceback(runner, err)) end
    end
end

function love.draw()
    love.graphics.clear(0.85, 0.8, 0.75, 1)
    -- on iOS the frame's first graphics call waits for vsync: time from after the clear
    local t0 = love.timer.getTime()
    love.graphics.setColor(1, 1, 1)
    if view.layout == 'grid' then
        drawGrid(current.option, current.mipos[1], view.scale, love.graphics.getWidth())
    elseif view.layout == 'scatter' and current.mipos[1] then
        drawScatter(current.option, current.mipos, view.count, view.scale)
    end
    timing.submit = (love.timer.getTime() - t0) * 1000
    timing.drawcalls = love.graphics.getStats().drawcalls
    if finalText then
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(finalText, 8, 8, love.graphics.getWidth() - 16)
    else
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(string.format('%s   tex %.1f MB   %d fps', hud, texMB(), love.timer.getFPS()), 10, 10)
    end
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
    if runner then return end
    local index = tonumber(key)
    if index and OPTIONS[index] then pickInteractive(index) end
    if key == 'z' then view.scale = view.scale == CAMERA_SCALE and CLOSE_SCALE or CAMERA_SCALE end
end
