--[[
TODO Recreating meshes every frame in drawSquishableHairOver and
createTexturedTriangleStrip (within drawTexturedWorld) is definitely
inefficient. We should absolutely cache these.
]] --

local lib = {}
local registry = require('src.registry')
local state = require('src.state')
local mathutils = require('src.math-utils')
local shapes = require('src.shapes')
local subtypes = require('src.subtypes')
local grass = require('src.grass')
local blobs = require('src.blob')
local liquid = require('src.liquid')
local resourceLink = require('src.resource-link')
local color = require('src.color')
local NT = require('src.node-types')
local spineMesh = require('src.spine-mesh')
local cam = require('src.camera').getInstance()
local smallFlat = require('src.render.small-flat')
local spineSkin = require('src.spine-skin')
local earBend = require('src.ear-bend')
-- face parts drawn on their body around extra.ox/oy: on a spine torso they ride the bend
local faceDrawables = { decal = true, brow = true, ['mouth-backdrop'] = true, ['mouth-lower'] = true,
    ['mouth-upper'] = true, ['mouth-teeth'] = true,
    ['mouth-tongue'] = true }

local gazeRadius = 1000 -- world units; cursor within this distance → track, outside → look ahead
-- how far a pupil moves toward the eye's edge: 1 = its edge at the eye picture's edge. The white sits
-- inside the outline, and the pupil is clipped to the white, so below 1 keeps most of it in view
local pupilRange = 0.6
local mipoFace = require('src.mipo-face')
local utils = require('src.utils')
local mipoRegistry = require('src.mipo-registry')
local facing = require('src.mipo-facing')
local view = require('src.render.view')
local ompBake = require('src.render.omp-bake')
local shaders = require('src.render.shaders')
local ribbon = require('src.render.ribbon')
local mouth = require('src.render.mouth')
local skinning = require('src.render.skinning')

local getLoveImage = ompBake.getLoveImage
local setSurfaceShader = shaders.setSurfaceShader
local ownStrip, growLine = ribbon.ownStrip, ribbon.growLine
local hairBounce = require('src.hair-bounce')
local systems = require('src.systems')
local drawSquishableHairOver, traceVerticesMesh = ribbon.drawSquishableHairOver, ribbon.traceVerticesMesh
local lookupUV, buildPolyVertexIndex = skinning.lookupUV, skinning.buildPolyVertexIndex

-- What other modules use from here (the rest moved to src/render/, SPLIT1)
-- (calls passed on, so a hot reload of those modules reaches everyone)
function lib.makeCached(...) return ompBake.makeCached(...) end
function lib.makeCombinedImages(...) return ompBake.makeCombinedImages(...) end
function lib.lipEdgeU(...) return mouth.lipEdgeU(...) end

lib.drawMeshOutline = false -- debug: draw wireframe over deformed MESHUSERT meshes
local function transformUV(x, y, cx, cy, opts)
    -- Translate point to origin (centroid or top-left)
    local dx = x - cx + opts.offsetX
    local dy = y - cy + opts.offsetY

    -- Rotate
    local cosA = math.cos(opts.rotate or 0)
    local sinA = math.sin(opts.rotate or 0)
    local rx = dx * cosA - dy * sinA
    local ry = dx * sinA + dy * cosA

    -- Scale to UV space
    local tileW = opts.tileWidth or 64
    local tileH = opts.tileHeight or 64
    local u = rx / tileW
    local v = ry / tileH

    return u * (opts.scaleX or 1), v * (opts.scaleY or 1)
end

-- ─── hoisted drawTexturedWorld helpers ─────────────────────────────
-- These were closures re-created inside drawTexturedWorld every frame
-- (the deform/anchor ones per DRAWABLE per frame). None of them capture
-- per-call state, so they live at module scope now — pure GC churn win.

-- z first; equal z by the sfixture's id (then which of its entries), so it can't flicker
-- or differ between sessions
local function sorter(a, b)
    if a.z ~= b.z then return a.z < b.z end
    if a.key ~= b.key then return a.key < b.key end
    return a.sub < b.sub
end

local function drawImageLayerSquishRGBA(url, r, g, b, a, extra, texfixture)
    local img = getLoveImage('textures/' .. url)
    local vertices = extra.vertices or { texfixture:getShape():getPoints() }
    local bones = #vertices == 16 and spineSkin.torsoBones(texfixture:getBody()) -- a spine's bodyhair bends with it
    if bones and img then
        love.graphics.setColor(r, g, b, a)
        spineSkin.drawFan(img, vertices, bones, texfixture:getBody(), extra)
        return
    end

    if (vertices and img) then
        local body = texfixture:getBody()
        local sx = 1 --ww / imgw
        local sy = 1 --hh / imgh
        love.graphics.setColor(r, g, b, a)
        drawSquishableHairOver(img, body:getX(), body:getY(), body:getAngle(), sx, sy, 1, vertices, extra, url)
    end
end

local function drawCombinedImageVanilla(ompImage, extra, texfixture, _thing)
    local vertices = extra.vertices or { texfixture:getShape():getPoints() }
    local img = ompImage
    if vertices and img then
        local body = texfixture:getBody()
        -- a spine's torso picture bends, and a Mipo ear's
        local bones = #vertices == 8 and (spineSkin.torsoBones(body) or earBend.bonesOf(body, vertices))
        if bones then
            love.graphics.setColor(1, 1, 1, 1)
            if extra.main.tint then love.graphics.setColor(color.hexToColor(extra.main.tint)) end
            spineSkin.drawGrid(img, vertices, bones, body, extra)
            return
        end
        local sx = 1 --ww / imgw
        local sy = 1 --hh / imgh

        love.graphics.setColor(1, 1, 1, 1)

        if (extra.main.tint) then
            local r, g, b, a = color.hexToColor(extra.main.tint)
            love.graphics.setColor(r, g, b, a)
        end

        local bx, by, angle = body:getX(), body:getY(), body:getAngle()
        if extra.leanAngle and extra.leanAngle ~= 0 then
            -- the picture turned about a point of the body (a Mipo foot leaning round as it
            -- turns, scripts/spikes/facing); the body itself stays where it is
            local px, py = body:getWorldPoint(extra.leanPivotX or 0, extra.leanPivotY or 0)
            local cs, sn = math.cos(extra.leanAngle), math.sin(extra.leanAngle)
            local rx, ry = bx - px, by - py
            bx, by, angle = px + rx * cs - ry * sn, py + rx * sn + ry * cs, angle + extra.leanAngle
        end
        drawSquishableHairOver(img, bx, by, angle, sx, sy, 1, vertices, extra, 'omp')
    end
end

-- The draw list, kept between frames (docs/MIPO-DRAWING.md L1): built again (and sorted) only when
-- an sfixture comes or goes (registry.sfixtureVersion) or one of them changed what it draws: its
-- fixture, userData, subtype, z, or the extra fields createDrawables reads. Each frame only that is
-- checked. What moves every frame (ribbon curves, lip curves) is read by the drawers.
local drawablesList = {}
local listState = { version = nil, entries = {} }
local reachOf = setmetatable({}, { __mode = 'k' }) -- [Mipo] = how far its pictures reach (culling)

local function fullMouth(extra) return extra.curvePoints ~= nil and #extra.curvePoints == 16 end

-- what createDrawables made this sfixture's drawables from
local function sfixtureLooks(e, fixture, ud)
    local extra = ud.extra
    e.fixture, e.ud, e.extra, e.subtype = fixture, ud, extra, ud.subtype
    if extra then
        e.z = (extra.zGroupOffset or 0) * 1000 + (extra.zOffset or 0)
        e.brow, e.mouth, e.points = extra.browCurve, extra.mouthCurve, fullMouth(extra)
        e.front, e.nodes = extra.front, extra.nodes ~= nil
    end
    return e
end

local function looksTheSame(e)
    local fixture = e.fixture
    if fixture:isDestroyed() then return false end
    local ud = fixture:getUserData()
    if ud ~= e.ud or ud.extra ~= e.extra or ud.subtype ~= e.subtype then return false end
    local extra = e.extra
    if not extra then return true end
    return e.z == (extra.zGroupOffset or 0) * 1000 + (extra.zOffset or 0)
        and e.brow == extra.browCurve and e.mouth == extra.mouthCurve and e.points == fullMouth(extra)
        and e.front == extra.front and e.nodes == (extra.nodes ~= nil)
end

local function listStillHolds()
    if listState.version ~= registry.sfixtureVersion then return false end
    local entries = listState.entries
    for i = 1, #entries do
        if not looksTheSame(entries[i]) then return false end
    end
    return true
end

-- A mouth decal (upper or lower lip, or the teeth). A lip's curve comes from extra.curvePoints
-- when drawn (src/render/mouth.lua); without its 16 numbers it draws nothing.
local function addMouth(out, extra, body, z)
    if extra.mouthCurve == 'teeth' then
        -- positioned image, optionally clipped to the mouth polygon
        out[#out + 1] = { type = 'mouth-teeth', z = z, extra = extra, body = body }
        return
    end
    if not fullMouth(extra) then return end
    out[#out + 1] = { type = 'mouth-' .. extra.mouthCurve, z = z, extra = extra, body = body }
    if extra.mouthCurve == 'lower' then
        -- Dark interior fill renders below teeth so teeth always
        -- sit on top of the void. zOffset 250 < non-stickOut teeth 251.
        out[#out + 1] = { type = 'mouth-backdrop', z = z - 2, extra = extra, body = body }
        -- the tongue, out only during a raspberry (src/mipo-raspberry.lua):
        -- over the lower lip, under the upper one (253)
        out[#out + 1] = { type = 'mouth-tongue', z = z + 0.6, extra = extra, body = body }
    end
end

local function addDecal(out, ud, _, body, z)
    local extra = ud.extra
    if extra.browCurve then
        out[#out + 1] = { type = 'brow', z = z, extra = extra, body = body }
    elseif extra.mouthCurve then
        addMouth(out, extra, body, z)
    else
        out[#out + 1] = { type = 'decal', z = z, extra = extra, body = body, nose = ud.label == 'nose' }
    end
end

-- a picture laid over a fixture's shape (texfixture) or a skinned / uv-mapped mesh
local function texturedMaker(kind, withLabel)
    return function(out, ud, fixture, body, z)
        out[#out + 1] = { type = kind, z = z, texfixture = fixture, label = withLabel and ud.label or nil,
            extra = ud.extra, body = body, thing = utils.thingOf(body) }
    end
end

-- A foot's picture is drawn twice (Nikki 2026-11-10: "the feet and leg connection a bit more depth
-- correct"): whole, just behind its leg (its ribbons' lowest z), and its lower part again at its own z,
-- in front, cut across its leg FOOT_CUT of the way from the ankle (where the lower leg joins it) to the
-- foot's middle: the leg shows over the top of the foot and goes into it, as into a shoe. Before, the whole foot
-- lay over the leg's end. state.feetFlat = true: as before.
local FOOT_CUT = 0.9 -- of the way from the ankle to the foot's middle
-- Each side in a depth range of its own (foot behind, leg, foot in front), the right one over the left:
-- with both feet's pieces at the same two depths, the front of one lay over the back of the other where
-- they overlapped and they cut into each other (Nikki: "z fighting"). The right leg's ribbons go up by
-- RIGHT_SIDE_UP (nothing is drawn between the legs and the feet).
local RIGHT_SIDE_UP = 2
local function legSideUp(body)
    local instance, partName = mipoRegistry.getFromBody(body)
    if instance and (partName == 'ruleg' or partName == 'rlleg') then return RIGHT_SIDE_UP end
    return 0
end
-- The z to draw a foot texfixture behind its leg at and the z of its front piece, or nil when it isn't a
-- Mipo's foot (or has no leg).
local function footBackZ(_, body)
    local instance, partName = mipoRegistry.getFromBody(body)
    if not (instance and (partName == 'lfoot' or partName == 'rfoot')) then return nil end
    -- both sides' legs: a foot lies behind every leg, so the legs always show (Nikki 2026-11-10: "legs
    -- go under and over the feet, we should just see them always"). Facing a side, its own leg only:
    -- the far leg is drawn behind the torso (mipo-facing FAR_Z), and with all four legs the far foot's
    -- front piece came over the near leg and the near foot's back piece went behind the torso (Nikki
    -- 2026-11-10: "the right foot when facing left should be closest to us").
    local side = partName:sub(1, 1)
    local legs = facing.facingOf(instance, partName) == 'front' and { 'luleg', 'llleg', 'ruleg', 'rlleg' }
        or { side .. 'uleg', side .. 'lleg' }
    local low, high
    for _, leg in ipairs(legs) do
        local part = instance.parts[leg]
        if part and part.body and not part.body:isDestroyed() then
            for _, f in ipairs(part.body:getFixtures()) do
                local lud = f:getUserData()
                if type(lud) == 'table' and lud.subtype == subtypes.CONNECTED_TEXTURE and lud.extra then
                    local lz = (lud.extra.zGroupOffset or 0) * 1000 + (lud.extra.zOffset or 0) + legSideUp(part.body)
                    low, high = low and math.min(low, lz) or lz, high and math.max(high, lz) or lz
                end
            end
        end
    end
    if not low then return nil end
    return low - (partName == 'rfoot' and 0.25 or 0.5), high + 0.5 -- the right foot over the left
end

-- Where a foot is cut, in the world: across its leg (the way from the knee to the ankle), FOOT_CUT of the
-- way from the ankle toward the foot's middle (a foot's own frame runs along it, so not its y). Returns
-- the cut's point, the leg's way (unit) and the distance from the ankle; nil without a leg.
local function footCut(instance, side)
    local foot, upper, lower = instance.parts[side .. 'foot'], instance.parts[side .. 'uleg'],
        instance.parts[side .. 'lleg']
    if not (foot and lower and upper and foot.body and lower.body and upper.body) then return nil end
    if foot.body:isDestroyed() or lower.body:isDestroyed() or upper.body:isDestroyed() then return nil end
    local function anchorBetween(a, b)
        for _, joint in ipairs(a:getJoints()) do
            local j1, j2 = joint:getBodies()
            if (j1 == a and j2 == b) or (j1 == b and j2 == a) then return joint:getAnchors() end
        end
    end
    local ax, ay = anchorBetween(foot.body, lower.body)
    local kx, ky = anchorBetween(upper.body, lower.body)
    if not (ax and kx) then return nil end
    local dx, dy = ax - kx, ay - ky
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return nil end
    dx, dy = dx / len, dy / len
    local fx, fy = foot.body:getPosition()
    local toMiddle = (fx - ax) * dx + (fy - ay) * dy
    if toMiddle <= 1 then return nil end
    local dist = toMiddle * FOOT_CUT
    return ax + dx * dist, ay + dy * dist, dx, dy, dist, ax, ay
end

-- A leg ribbon (on an upper leg) reaches past the ankle into its foot, past the cut, so it goes into
-- the foot instead of ending at its top edge; the foot's front pass hides the rest. A function of
-- nothing giving the extra length (px), or nil when the body is no Mipo's upper leg.
local function legFootReach(body)
    local instance, partName = mipoRegistry.getFromBody(body)
    if not (instance and (partName == 'luleg' or partName == 'ruleg')) then return nil end
    local side = partName:sub(1, 1)
    return function()
        if state.feetFlat then return 0 end
        local _, _, _, _, dist = footCut(instance, side)
        -- small on screen: the leg ends at the ankle over its foot, unclipped (src/render/small-flat.lua)
        if not dist or smallFlat.tooSmall(dist / FOOT_CUT * 2) then return 0 end
        return dist * 1.3 -- past the cut, so its end is under the foot
    end, instance, side
end

-- Below its ankle a leg shows only inside its own foot: what reaches past the ankle lay over the other
-- foot where the feet overlap, and its tip out of the foot (Nikki's screenshot, 2026-11-10). A stencil:
-- everything on the knee's side of the ankle, and the foot's own shape (its pictures' alpha). Returns
-- the stencil test to put back, or nil (no clip: feet flat, no foot, a canvas without a stencil).
local legCutShader
local legClipState = {}
local drawTexfixture -- (below)
local function clipLegToFoot(instance, side)
    if state.feetFlat then return nil end
    local _, _, dx, dy, dist, ax, ay = footCut(instance, side)
    local foot = instance.parts[side .. 'foot']
    if not (ax and foot and foot.body) or smallFlat.tooSmall(dist / FOOT_CUT * 2) then return nil end
    local fixture
    for _, f in ipairs(foot.body:getFixtures()) do
        local ud = f:getUserData()
        if type(ud) == 'table' and ud.subtype == subtypes.TEXFIXTURE then fixture = f end
    end
    if not fixture then return nil end
    legCutShader = legCutShader or love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
            if (Texel(tex, uv).a < 0.5) discard;
            return vec4(1.0);
        }
    ]])
    local footD = { body = foot.body, extra = fixture:getUserData().extra, texfixture = fixture,
        thing = utils.thingOf(foot.body) }
    local shader = love.graphics.getShader()
    local wasOutlines = state.drawingOutlines
    local ok = pcall(love.graphics.stencil, function()
        love.graphics.setShader()
        love.graphics.push()
        love.graphics.translate(ax, ay)
        love.graphics.rotate(math.atan2(dy, dx) - math.pi / 2) -- +y along the leg, into the foot
        love.graphics.rectangle('fill', -1e4, -2e4, 2e4, 2e4)  -- the knee's side of the ankle
        love.graphics.pop()
        state.drawingOutlines = true -- (no light shaders: only the foot's alpha)
        love.graphics.setShader(legCutShader)
        drawTexfixture(footD)
    end, 'replace', 1)
    state.drawingOutlines = wasOutlines
    love.graphics.setShader(shader)
    if not ok then return nil end
    legClipState.compare, legClipState.value = love.graphics.getStencilTest()
    love.graphics.setStencilTest('greater', 0)
    return legClipState
end

-- [subtype] = function(out, ud, fixture, body, z): adds that sfixture's drawables to out, in
-- draw order for equal z. A subtype not here draws nothing of its own.
local makers = {
    [subtypes.TRACE_VERTICES] = function(out, ud, _, body, z)
        out[#out + 1] = { type = 'trace-vertices', z = z, extra = ud.extra, thing = utils.thingOf(body) }
    end,
    [subtypes.TILE_REPEAT] = function(out, ud, _, body, z)
        out[#out + 1] = { type = 'tile-repeat', z = z, extra = ud.extra, thing = utils.thingOf(body) }
    end,
    [subtypes.GRASS] = function(out, ud, _, body, z)
        -- two layers: behind the Mipos at its own z, in front of all of them (src/grass.lua)
        local thing = utils.thingOf(body)
        out[#out + 1] = { type = 'grass', layer = 'back', z = z, extra = ud.extra, thing = thing, body = body }
        out[#out + 1] = { type = 'grass', layer = 'front', z = grass.FRONT_Z + (ud.extra.zOffset or 0),
            extra = ud.extra, thing = thing, body = body }
    end,
    [subtypes.LIQUID] = function(out, ud, _, body, z)
        -- water in a container (src/liquid.lua); 'front' puts it in front of the Mipos (a bath)
        if ud.extra.front then z = liquid.FRONT_Z + (ud.extra.zOffset or 0) end
        out[#out + 1] = { type = subtypes.LIQUID, z = z, extra = ud.extra, body = body }
    end,
    [subtypes.SOFTBODY] = function(out, _, fixture, _, z)
        out[#out + 1] = { type = subtypes.SOFTBODY, z = z, fixture = fixture }
    end,
    [subtypes.TEXFIXTURE] = function(out, ud, fixture, body, z)
        local footBack, footFront = footBackZ(ud, body)
        if footBack then -- a foot: behind its leg, and its lower part again over it (drawFootBack / Front)
            local d = { type = 'foot-back', z = footBack, texfixture = fixture, extra = ud.extra, body = body,
                thing = utils.thingOf(body) }
            out[#out + 1] = d
            out[#out + 1] = { type = 'foot-front', z = footFront, texfixture = fixture, extra = ud.extra,
                body = body, thing = d.thing }
            return
        end
        out[#out + 1] = { type = 'texfixture', z = z, texfixture = fixture, extra = ud.extra, body = body,
            thing = utils.thingOf(body) }
    end,
    [subtypes.MESHUSERT] = texturedMaker('meshusert', true),
    [subtypes.UVUSERT] = texturedMaker('uvusert', true),
    [subtypes.DECAL] = addDecal,
    [subtypes.CONNECTED_TEXTURE] = function(out, ud, _, body, z)
        -- its curve follows the joints: laid in drawConnectedTexture (ribbonPoints)
        if ud.extra.nodes then
            local reach, instance, side = legFootReach(body)
            out[#out + 1] = { z = z + legSideUp(body), type = 'connected-texture', extra = ud.extra, body = body,
                footReach = reach, legInstance = instance, legSide = side }
        end
    end,
}

-- Everything drawn here hangs off an sfixture, so the list is built from the registry's
-- sfixtures, not by walking every fixture of every body (1500 fixtures, 650 of them
-- sfixtures, with 20 Mipos). Each entry gets a `key` (its sfixture's id) and `sub` so
-- equal z sorts the same way every frame and every session.
local function createDrawables()
    local drawables = drawablesList
    for i = #drawables, 1, -1 do drawables[i] = nil end
    listState.entries = {}
    reachOf = setmetatable({}, { __mode = 'k' }) -- parts may have been rebuilt or resized
    for _, fixture in pairs(registry.sfixtures) do
        local ud = not fixture:isDestroyed() and fixture:getUserData()
        if type(ud) == 'table' then -- only table userData is an sfixture
            local body = fixture:getBody()
            local before = #drawables
            local make = makers[ud.subtype]
            if make then
                -- each Mipo draws in its own z-range: zGroupOffset * 1000 + the part's zOffset
                local z = ud.extra and ((ud.extra.zGroupOffset or 0) * 1000 + (ud.extra.zOffset or 0))
                make(drawables, ud, fixture, body, z)
            end
            local thing = utils.thingOf(body)
            for k = before + 1, #drawables do
                drawables[k].key, drawables[k].sub = ud.id, k - before
                drawables[k].mipoThing = thing and thing.mipoId and thing -- for culling (L0)
            end
            listState.entries[#listState.entries + 1] = sfixtureLooks({}, fixture, ud)
        end
    end
    return drawables
end


-- todo: these3 function look very much alike, we wnat to combine them all in otne,
-- another issue here is that i dont really understand how to set the ox and oy correctly, (for the combined Image)
-- and there is an issue with the center of the 'fan' mesh, it
-- shouldnt always be 0,0 you can see this when you position the
-- texfxture with the
-- onscreen 'd' button quite a distnace out of the actual physics body center.
--
-- local function drawImageLayerSquish(url, hex, extra, texfixture)
function drawTexfixture(d)
    local thing = d.thing
    local texfixture = d.texfixture
    local extra = d.extra
    local shaded = setSurfaceShader(extra, texfixture and texfixture:getBody() or nil)
    if not extra.OMP then -- this is the BG and FG routine
        local main = extra.main
        if main then
            if not main.cached then
                ompBake.makeCached(main)
                print('Cached not found')
                local cached = main.cached
                print(cached.bgR, cached.bgG, cached.bgB, cached.bgA)
            end
            local cached = main.cached

            if main and main.bgURL then
                love.graphics.setColor(1, 0, 0)
                drawImageLayerSquishRGBA(extra.main.bgURL,
                    cached.bgR, cached.bgG, cached.bgB, cached.bgA,
                    extra, texfixture)
            end
            if extra.main and extra.main.fgURL then
                drawImageLayerSquishRGBA(extra.main.fgURL,
                    cached.fgR, cached.fgG, cached.fgB, cached.fgA,
                    extra, texfixture)
            end
        end
    end

    if extra.OMP then
        if (texfixture and extra.ompImage) then
            drawCombinedImageVanilla(extra.ompImage, extra, texfixture, thing)
        end
    end
    if shaded then
        love.graphics.setShader()
    end
end

    -- this is all wrong, the code works but this shouldbnt  be a responnsible in the drawloop, do this outside!
    -- really we want to do this on load or something.
local function drawMeshusert(d)
    -- now we need to find a mapping file..

    local mappert = resourceLink.find(d.texfixture:getUserData())

    local data = mappert and mappert:getUserData().extra
    if data then
        local mapperBody = mappert:getBody()
        local bodyUD = mapperBody:getUserData()
        -- Prefer `meshVertices` (CDT mode — includes Steiner points)
        -- over the polygon's raw verts. UVs + triangle indices are
        -- stored aligned with whichever vertex source is in use.
        local verts = data.meshVertices or bodyUD.thing.vertices

        local vertexFormat, meshVertices, triIdx, tris
        vertexFormat, meshVertices, verts, triIdx, tris = skinning.meshusertVertices(d.extra, d.body, data, verts,
            state.selection.selectedSFixture == d.texfixture)
        local mesh = love.graphics.newMesh(vertexFormat, meshVertices, 'triangles')
        if data and data.uvs then
            local url = resourceLink.imageURL(mappert:getUserData())
            local img = url and getLoveImage(url)
            if img then mesh:setTexture(img) end
        end
        local bx, by = d.body:getPosition()
        local ba = d.body:getAngle()
        -- Reset global color: previous TEXFIXTURE drawables leave
        -- their bg/fg/tint in love.graphics state, which multiplies
        -- into mesh vertex colors and tints the textured mesh
        -- (brown/tan cast from whichever OMP character drew last).
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mesh, bx, by, ba)

        -- Debug outline: draw triangle edges so the deformed mesh is
        -- visible even when untextured / backdrop missing. Toggle with
        -- lib.drawMeshOutline.
        if lib.drawMeshOutline then
            love.graphics.push()
            love.graphics.translate(bx, by)
            love.graphics.rotate(ba)
            love.graphics.setColor(0.2, 1.0, 0.4, 0.5)
            love.graphics.setLineWidth(1)
            if triIdx then
                -- Guard against stale indices pointing past the
                -- current vert count (e.g. during the single frame
                -- after a polygon-vert edit before invalidation
                -- has fully propagated).
                local wireVertCount = math.floor(#verts / 2)
                for j = 1, #triIdx, 3 do
                    local i1, i2, i3 = triIdx[j], triIdx[j + 1], triIdx[j + 2]
                    if i1 and i2 and i3
                        and i1 <= wireVertCount and i2 <= wireVertCount and i3 <= wireVertCount then
                        love.graphics.polygon('line',
                            verts[(i1 - 1) * 2 + 1], verts[(i1 - 1) * 2 + 2],
                            verts[(i2 - 1) * 2 + 1], verts[(i2 - 1) * 2 + 2],
                            verts[(i3 - 1) * 2 + 1], verts[(i3 - 1) * 2 + 2])
                    end
                end
            else
                for j = 1, #tris do
                    love.graphics.polygon('line', tris[j])
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.pop()
        end

    end
end

local function drawUvusert(d)
    -- now we need to find a mapping file..

    local mappert = resourceLink.find(d.texfixture:getUserData())
    local data = mappert and mappert:getUserData().extra
    if data and data.uvs then

        local bx, by = d.body:getPosition()
        local ba = d.body:getAngle()
        local b = d.body:getUserData()

        local centerX, centerY = mathutils.getCenterOfPoints(b.thing.vertices)
        local verts = {}

        for vi = 1, #b.thing.vertices, 2 do
            verts[vi] = b.thing.vertices[vi] - centerX
            verts[vi + 1] = b.thing.vertices[vi + 1] - centerY
        end

        local p = {}
        for vi = 1, #verts, 2 do
            table.insert(p, { verts[vi], verts[vi + 1] })
        end

        local vertexFormat = {
            { "VertexPosition", "float", 2 },
            { "VertexTexCoord", "float", 2 },
            { "VertexColor",    "byte",  4 },
        }
        local meshVertices = {}
        local tris = shapes.makeTrianglesFromPolygon(verts)

        local vertexIndex = buildPolyVertexIndex(verts)
        for j = 1, #tris do
            local tri = tris[j]
            for k = 0, 2 do
                local x = tri[k * 2 + 1]
                local y = tri[k * 2 + 2]
                local u, v = lookupUV(x, y, vertexIndex, data.uvs)
                table.insert(meshVertices, {
                    x, y,
                    u or 0, v or 0,
                    255, 255, 255
                })
            end
        end

        local mesh = love.graphics.newMesh(vertexFormat, meshVertices, 'triangles')
        local url = resourceLink.imageURL(mappert:getUserData())
        local img = url and getLoveImage(url)
        if img then mesh:setTexture(img) end

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(mesh, bx, by, ba)
        love.graphics.setColor(1, 1, 1)
    end
end

-- An anchor sfixture's centre in its body's frame: it never changes for that fixture (moving
-- or resizing one makes a new fixture), so it's worked out once. Every frame it was the
-- shape's points and their world points as new tables, for every anchor of every ribbon.
local anchorCentres = setmetatable({}, { __mode = 'k' }) -- [fixture] = { x, y }
local function anchorCentre(f)
    local c = anchorCentres[f]
    if not c then
        local x, y = mathutils.getCenterOfPoints({ f:getShape():getPoints() })
        c = { x, y }
        anchorCentres[f] = c
    end
    return c[1], c[2]
end

-- Where an anchor sfixture is in the world (a ribbon passes through it)
function lib.anchorPoint(f)
    return f:getBody():getWorldPoint(anchorCentre(f))
end

-- A connected texture's control points this frame: through its nodes (anchors, joint anchors), a
-- midpoint added for two, the ends grown, the inner points doubled by bendiness; nil when it has
-- fewer than three.
local function nodePositions(extra, points)
    for i = #points, 1, -1 do points[i] = nil end
    for j = 1, #extra.nodes do
        local it = extra.nodes[j]
        if it.type == NT.ANCHOR then
            local f = registry.getSFixtureByID(it.id)
            if f then
                local centerX, centerY = lib.anchorPoint(f)
                points[#points + 1] = centerX
                points[#points + 1] = centerY
            else
                print('issue with finding achor, id:', it.id)
            end
        end
        if it.type == NT.JOINT then
            local jnt = registry.getJointByID(it.id)
            if jnt and not jnt:isDestroyed() then
                local x1, y1, _, _ = jnt:getAnchors()
                table.insert(points, x1)
                table.insert(points, y1)
            end
        end
    end
    return points
end

local function shapeRibbon(points, extra, endGrow)
    if #points == 4 then
        -- here we will just introduce a little midle thingie
        -- -- becaue i cannot draw a curve of 2 points
        local function addMidpoint(pts)
            if #pts ~= 4 then
                error("Expected array of exactly 2 points (4 numbers)")
            end

            local x1, y1, x2, y2 = pts[1], pts[2], pts[3], pts[4]
            local midX = (x1 + x2) / 2
            local midY = (y1 + y2) / 2

            return { x1, y1, midX, midY, x2, y2 }
        end

        points = addMidpoint(points)
    end

    if #points < 6 then return nil end

    -- todo here we might want to grow the curve... so it will stick a little bit from the sides

    -- todo parameterize this
    local growLength = extra.growExtra or 20
    -- both ends stick out a little: the first point away from the second, the last away
    -- from the one before it (this grew the third point until 2026-10-31: the same with
    -- three anchors, a bend in the middle of a ribbon with more)
    local n = #points
    points[1], points[2] = growLine({ points[1], points[2] }, { points[3], points[4] }, growLength)
    points[n - 1], points[n] = growLine({ points[n - 1], points[n] }, { points[n - 3], points[n - 2] },
        growLength + (endGrow or 0))

    -- bendiness controls control-point duplication for the bezier through
    -- joint anchors. 0 = soft/rubbery (curve smooths across the elbow),
    -- 6 = crisp (curve hugs each joint tightly). Default 2 matches the
    -- pre-knob behaviour. See doubleControlPoints in src/spine-mesh.lua.
    local bendiness = (extra.main and extra.main.bendiness) or 2
    points = spineMesh.doubleControlPoints(points, bendiness)
    return points
end

-- Worked out again only when its nodes moved, or its node list, grow length or bendiness changed:
-- recomputed every frame it was 40% of the Lua time with 100 Mipos standing still.
local ribbonCache = setmetatable({}, { __mode = 'k' }) -- [extra] = { raw, nodes, grow, bend, points }
local rawScratch = {}
local function ribbonPoints(extra, endGrow)
    local raw = nodePositions(extra, rawScratch)
    local grow, bend = extra.growExtra or 20, (extra.main and extra.main.bendiness) or 2
    endGrow = endGrow or 0
    local c = ribbonCache[extra]
    if c and c.nodes == extra.nodes and c.grow == grow and c.bend == bend and c.endGrow == endGrow
        and #c.raw == #raw then
        local same = true
        for i = 1, #raw do
            if c.raw[i] ~= raw[i] then same = false; break end
        end
        if same then return c.points end
    end
    local copy = {}
    for i = 1, #raw do copy[i] = raw[i] end
    if not c then c = { raw = {} }; ribbonCache[extra] = c end
    for i = 1, #raw do c.raw[i] = raw[i] end
    for i = #raw + 1, #c.raw do c.raw[i] = nil end
    c.nodes, c.grow, c.bend, c.endGrow = extra.nodes, grow, bend, endGrow
    c.points = shapeRibbon(copy, extra, endGrow)
    return c.points
end

local ribbonMiddle = { 0, 0 }
local function drawConnectedTexture(d)
    local extra = d.extra
    local points = ribbonPoints(extra, d.footReach and d.footReach() or nil)
    if not points then return end
    local legClip = d.legInstance and clipLegToFoot(d.legInstance, d.legSide)
    local main = extra.main
    local wmul, dir = main.wmul or 1, main.dir or 1
    local bezier, derivative -- one curve for the layers, made when the first needs laying
    local function curve()
        if not bezier then
            bezier = love.math.newBezierCurve(points)
            derivative = bezier:getDerivative()
        end
        return bezier, derivative
    end
    -- a ribbon has no body: its lights are picked by its middle, in the world (LIGHT-AND-SHADOW LS27)
    local n = #points
    ribbonMiddle[1], ribbonMiddle[2] = (points[1] + points[n - 1]) / 2, (points[2] + points[n]) / 2
    local shaded = setSurfaceShader(extra, nil, ribbonMiddle)
    if not extra.OMP then -- this is the BG and FG routine
        if not main.cached then
            ompBake.makeCached(main)
        end
        local cached = main.cached

        if main.bgURL then
            local img = getLoveImage('textures/' .. main.bgURL)
            if img then
                local mesh = ownStrip(extra, 'bg', img, wmul, points, dir, nil, curve)
                love.graphics.setColor(cached.bgR, cached.bgG, cached.bgB, cached.bgA)
                love.graphics.draw(mesh)
            end
        end
        if main.fgURL then
            local img = getLoveImage('textures/' .. main.fgURL)
            if img then
                local mesh = ownStrip(extra, 'fg', img, wmul, points, dir, nil, curve)
                love.graphics.setColor(cached.fgR, cached.fgG, cached.fgB, cached.fgA)
                love.graphics.draw(mesh)
            end
        end
    end
    if extra.OMP then
        local img = extra.ompImage
        if img then
            local mesh = ownStrip(extra, 'omp', img, wmul, points, dir, nil, curve)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(mesh)
        end
    end
    if shaded then
        love.graphics.setShader()
    end
    if legClip then
        if legClip.compare then love.graphics.setStencilTest(legClip.compare, legClip.value)
        else love.graphics.setStencilTest() end
    end
end

local function drawGrass(d)
    grass.draw(d.extra, d.thing, d.body, d.layer)
end

local function drawSoftbody(d)
    blobs.draw(d.fixture)
end

local function drawLiquid(d)
    liquid.draw(d.extra, d.body)
end

local function drawTileRepeat(d)
    local vertices = d.thing.vertices
    -- todo CACHE THIS!!
    local tris = d.thing._tris or shapes.makeTrianglesFromPolygon(vertices)
    d.thing._tris = tris

    -- a new one from the tool rail has no texture until the panel picks one
    local main = d.extra.main
    local img = main and main.bgURL and main.bgURL ~= '' and getLoveImage('textures/' .. main.bgURL)
    if img then
        if not d.extra._mesh then
            img:setWrap("repeat", "repeat")
            local texW, texH = img:getWidth(), img:getHeight()
            local centroidX, centroidY = mathutils.computeCentroid(vertices)
            local meshVertices = {}

            -- the panel's defaults (src/sfixture-params.lua): one from the tool rail has none set
            local twm = d.extra.tileWidthM or 1
            local thm = d.extra.tileHeightM or 1
            local tr = d.extra.tileRotation
            local uvParams = {
                tileWidth = texW * twm,  --bb.width,    -- world units per tile horizontally
                tileHeight = texH * thm, --bb.height,  -- world units per tile vertically
                rotate = tr,             -- radians
                offsetX = 0,             -- offset in world units
                offsetY = 0,
                scaleX = 1,              -- scale texture space (can be 1 / repeatX)
                scaleY = 1,
                anchor = "center",       -- or "top-left"
                keepAspect = false       -- optional flag to preserve aspect ratio
            }

            for j = 1, #tris do
                local tri = tris[j]
                for k = 0, 2 do
                    local x = tri[k * 2 + 1]
                    local y = tri[k * 2 + 2]
                    local u, v = transformUV(x, y, centroidX, centroidY, uvParams)
                    table.insert(meshVertices, {
                        x - centroidX, y - centroidY,
                        u, v,
                        255, 255, 255, 140
                    })
                end
            end

            local vertexFormat = {
                { "VertexPosition", "float", 2 },
                { "VertexTexCoord", "float", 2 },
                { "VertexColor",    "byte",  4 },
            }

            local mesh = love.graphics.newMesh(vertexFormat, meshVertices, "triangles")
            mesh:setTexture(img)
            d.extra._mesh = mesh
        end

        local r, g, b, a = color.hexToColor(d.extra.main.tint or 'ffffffff')
        love.graphics.setColor(r, g, b, a)

        local body = d.thing.body
        love.graphics.draw(d.extra._mesh, body:getX(), body:getY(), body:getAngle())
    end
end

local function drawTraceVertices(d)
    -- a spine torso's haircut runs along the whole torso's top, not its lowest band's
    local hairBones = spineSkin.bonesOf(d.thing.body)
    local m, rest = traceVerticesMesh(d.extra,
        hairBones and hairBones.outline or d.thing.vertices)
    if m then
        hairBounce.apply(d.extra, d.thing.body, m, rest, love.timer.getDelta())
        --if d.extra.main.bgURL
        local extra = d.extra
        local useOMP = extra.OMP and extra.ompImage
        local img
        if useOMP then
            img = extra.ompImage
        else
            -- Haircut/limb-hair can be deliberately cleared (Mipo editor "null"
            -- thumbnail). nil/empty bgURL means "no hair" — skip drawing rather
            -- than crash on the textures/ concat or fall through to a default.
            local bg = extra.main.bgURL
            if not bg or bg == '' then
                return
            end
            img = getLoveImage('textures/' .. bg)
            if not img then
                img = getLoveImage('textures/' .. 'mipo/hair/hair-07.png')
            end
        end

        m:setTexture(img)
        local body = d.thing.body
        if useOMP then
            love.graphics.setColor(1, 1, 1, 1)
        else
            local main = extra.main
            if main then
                if not main.cached then ompBake.makeCached(main) end
                local c = main.cached
                love.graphics.setColor(c.bgR, c.bgG, c.bgB, c.bgA)
            end
        end
        local shaded = setSurfaceShader(extra, body)
        if hairBones then
            -- the mesh is around the whole outline's centre: put that where the torso
            -- shape's centre is on torso1, then bend with the spine at the top
            local outline = hairBones.outline
            local cx, cy = mathutils.getCenterOfPoints(outline)
            local topY = math.huge
            for k = 2, #outline, 2 do topY = math.min(topY, outline[k]) end
            local bend = spineSkin.transformAt(body, 0, topY + hairBones.originY)
            love.graphics.push()
            love.graphics.applyTransform(bend)
            local wx, wy = body:getWorldPoint(cx, cy + hairBones.originY)
            love.graphics.draw(m, wx, wy, body:getAngle())
            love.graphics.pop()
        else
            love.graphics.draw(m, body:getX(), body:getY(), body:getAngle())
        end
        if shaded then
            love.graphics.setShader()
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- A face decal (an eye, a pupil, the nose) in a material (extra.material, src/render/materials.lua;
-- docs/MATERIALS.md MT6c): drawn as a quad in the head's own frame, as the head's picture is, so the
-- lights reach it the same way (an image draw hands the shader the picture's own pixels). Only when
-- a material is set; a quad kept per decal.
-- The quad is only uploaded when it changed (an eye's white changes only while blinking): ~0.15 ms
-- with 20 Mipos on the phone (LIGHT-AND-SHADOW LS30; the eyes' cost is the shader, not the upload).
local decalQuads = setmetatable({}, { __mode = 'k' }) -- [extra] = { mesh, img, ox, oy, dw, dh, mirrorX, rot }
local quadVerts = { { 0, 0, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 1, 1 }, { 0, 0, 0, 1 } }
local quadCorners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
local function drawDecalLit(extra, body, img, ox, oy, dw, dh, mirrorX)
    local rot = extra.rot or 0
    local q = decalQuads[extra]
    if not q then
        q = { mesh = love.graphics.newMesh(4, 'fan', 'dynamic') }
        decalQuads[extra] = q
    end
    local mesh = q.mesh
    if q.ox ~= ox or q.oy ~= oy or q.dw ~= dw or q.dh ~= dh or q.mirrorX ~= mirrorX or q.rot ~= rot then
        local c, s = math.cos(rot), math.sin(rot)
        local hw, hh = dw / 2, dh / 2
        for i = 1, 4 do
            local px, py = quadCorners[i][1] * hw * mirrorX, quadCorners[i][2] * hh
            quadVerts[i][1] = ox + c * px - s * py
            quadVerts[i][2] = oy + s * px + c * py
        end
        mesh:setVertices(quadVerts)
        q.ox, q.oy, q.dw, q.dh, q.mirrorX, q.rot = ox, oy, dw, dh, mirrorX, rot
    end
    if q.img ~= img then mesh:setTexture(img); q.img = img end
    local shaded = setSurfaceShader(extra, body)
    local bx, by = body:getPosition()
    love.graphics.draw(mesh, bx, by, body:getAngle())
    if shaded then love.graphics.setShader() end
end

-- A stencil of a picture's inside: where its mask is white, less where its outline is drawn
-- (drawMask / drawLine draw them, in place, with the shader they're handed). Returns the stencil
-- test to put back after, or nil when it couldn't (a canvas without a stencil, e.g. a depth picture).
local maskCut, lineCut
local clipState = {}
local function stencilInside(drawMask, drawLine)
    maskCut = maskCut or love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
            vec4 c = Texel(tex, uv);
            if (c.r * c.a < 0.5) discard;
            return c;
        }
    ]])
    lineCut = lineCut or love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
            if (Texel(tex, uv).a < 0.5) discard;
            return vec4(1.0);
        }
    ]])
    local shader = love.graphics.getShader()
    local ok = pcall(love.graphics.stencil, function()
        love.graphics.setShader(maskCut)
        drawMask()
    end, 'replace', 1)
    if ok and drawLine then
        pcall(love.graphics.stencil, function()
            love.graphics.setShader(lineCut)
            drawLine()
        end, 'replace', 0, true)
    end
    love.graphics.setShader(shader)
    if not ok then return nil end
    clipState.compare, clipState.value = love.graphics.getStencilTest()
    love.graphics.setStencilTest('greater', 0)
    return clipState
end

local function endClip(clip)
    if not clip then return end
    if clip.compare then love.graphics.setStencilTest(clip.compare, clip.value)
    else love.graphics.setStencilTest() end
end

-- A pupil drawn only inside its eye's white: clipped to the eye's mask (white where the white is),
-- placed as the eye is drawn (its turn, tilt, mirror and blink); then the eye's outline is drawn
-- again over it (redrawEyeLine), so the line's soft inner edge lies over the pupil. Cutting the
-- outline out of the stencil instead left a hole where the eye's white showed through the line's
-- see-through edge: a white glare along the pupil's cut edge (2026-11-08).
-- nil: no clip (no eye white, a mask picture missing, no stencil).
local eyeLine = {}
local function clipToEye(extra, body)
    local mask, mw, mh = getLoveImage('textures/' .. extra.eyeMaskURL)
    if not mask then return nil end
    local thing = utils.thingOf(body)
    local eyesOpen = (thing and thing.eyesOpen) or 1
    local wx, wy = body:getWorldPoint(extra.ox or 0, extra.oy or 0) -- the eye's centre (before the gaze)
    local angle = body:getAngle() + (extra.eyeRot or 0)
    local w, h = extra.eyeW * (extra.eyeMirror and -1 or 1), extra.eyeH * eyesOpen
    eyeLine.x, eyeLine.y, eyeLine.angle, eyeLine.w, eyeLine.h = wx, wy, angle, w, h
    return stencilInside(
        function() love.graphics.draw(mask, wx, wy, angle, w / mw, h / mh, mw / 2, mh / 2) end)
end

-- The eye's outline over its pupil, where clipToEye last placed the eye.
local function redrawEyeLine(extra)
    local line, lw, lh = getLoveImage('textures/' .. (extra.eyeMaskURL:gsub('%-mask%.png$', '.png')))
    if not line then return end
    love.graphics.setColor(color.hexToColor(extra.eyeLineHex or '000000ff'))
    love.graphics.draw(line, eyeLine.x, eyeLine.y, eyeLine.angle, eyeLine.w / lw, eyeLine.h / lh, lw / 2, lh / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

-- The skin's picture is drawn on a fan over its corners (ribbon drawSquishableHairOver): the same fan
-- with the skin's mask and outline, for a stencil of the skin's inside. Its UVs follow the bake's
-- flips (omp-bake getDrawParams mirrors the outline and mask in the picture). Kept per skin.
local RING_UV = {
    [4] = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } },
    [8] = { { 0, 0 }, { .5, 0 }, { 1, 0 }, { 1, .5 }, { 1, 1 }, { .5, 1 }, { 0, 1 }, { 0, .5 } },
}
local skinFans = setmetatable({}, { __mode = 'k' })
local function skinFan(skin)
    local vertices = skin.vertices
    local n = vertices and #vertices / 2
    local uvs = n and RING_UV[n]
    if not uvs then return nil end
    local fx, fy = skin.main.fx == -1, skin.main.fy == -1
    local rec = skinFans[skin]
    if rec and rec.vertices == vertices and rec.fx == fx and rec.fy == fy then return rec.mesh end
    local cx, cy = mathutils.getCenterOfPoints(vertices)
    local verts = { { cx, cy, 0.5, 0.5 } }
    for i = 1, n + 1 do
        local k = (i - 1) % n + 1
        local u, v = uvs[k][1], uvs[k][2]
        verts[i + 1] = { vertices[k * 2 - 1], vertices[k * 2], fx and 1 - u or u, fy and 1 - v or v }
    end
    if rec then rec.mesh:release() end
    local mesh = love.graphics.newMesh(verts, 'fan', 'static')
    skinFans[skin] = { mesh = mesh, vertices = vertices, fx = fx, fy = fy }
    return mesh
end

local function clipToSkin(skin, body)
    local mask = skin.main.fgURL and skin.main.fgURL ~= '' and getLoveImage('textures/' .. skin.main.fgURL)
    local mesh = mask and skinFan(skin)
    if not mesh then return nil end
    local line = getLoveImage('textures/' .. skin.main.bgURL)
    local bx, by = body:getPosition()
    local angle = body:getAngle()
    return stencilInside(
        function() mesh:setTexture(mask) love.graphics.draw(mesh, bx, by, angle) end,
        line and function() mesh:setTexture(line) love.graphics.draw(mesh, bx, by, angle) end)
end

-- Face patches (eye hollows, cheeks, a snout): skin colouring under the hair, the eyes on top. One
-- decal per face holds them all (extra.facePatches: { ox, oy, w, h, mirror, url, tint }, turned
-- with the face by mipo-facing applyFace), drawn inside the skin and off its outline with one
-- stencil. Each picture is a mask (white where the patch is), its red as the alpha.
local patchShader
local function drawFacePatches(extra, body)
    local skinFixture = extra.skinFixture
    if not skinFixture or skinFixture:isDestroyed() then return end
    local skin = skinFixture:getUserData().extra
    patchShader = patchShader or love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
            vec4 t = Texel(tex, uv);
            return vec4(color.rgb, color.a * t.r * t.a);
        }
    ]])
    local clip = clipToSkin(skin, body)
    local shader = love.graphics.getShader()
    love.graphics.setShader(patchShader)
    local angle = body:getAngle()
    for _, patch in ipairs(extra.facePatches) do
        local img, iw, ih = getLoveImage('textures/' .. patch.url)
        if patch.image then -- baked with its outline / pattern (face-patches bakePending): drawn as it is
            local bw, bh = patch.image:getDimensions()
            local wx, wy = body:getWorldPoint(patch.ox, patch.oy)
            love.graphics.setShader(shader)
            love.graphics.setColor(1, 1, 1, patch.tint[4] or 1)
            love.graphics.draw(patch.image, wx, wy, angle, patch.w / bw * (patch.mirror and -1 or 1), patch.h / bh,
                bw / 2, bh / 2)
            love.graphics.setShader(patchShader)
        elseif img then
            local wx, wy = body:getWorldPoint(patch.ox, patch.oy)
            love.graphics.setColor(patch.tint)
            local sx = patch.w / iw * (patch.mirror and -1 or 1)
            love.graphics.draw(img, wx, wy, angle, sx, patch.h / ih, iw / 2, ih / 2)
        end
    end
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    endClip(clip)
end

-- A nose with volume (when no material lights it already): drawn through the clay shader rounded like a
-- dome (its form baked from its mask; without a mask, rounded at its edge), so the light catches one
-- side and the other falls into shade, and a soft shadow of it on the face, a little away from the
-- strongest light. state.noseFlat = true: flat as before. Nikki 2026-11-10: "a bit with a volume".
local noseLits = setmetatable({}, { __mode = 'k' })
local function noseLit(extra)
    local lit = noseLits[extra]
    if not lit then
        -- matte: the clay's tight shine (0.2, 25) read as metal (Nikki 2026-11-10: "less metallic")
        lit = setmetatable({ plasticine = true, plasticineForm = true, plasticineFormBaked = true,
            plasticineMottleStrength = 0, plasticineSpecStrength = 0.04, plasticineSpecPow = 6,
            plasticineBump = 1 }, { __index = extra })
        noseLits[extra] = lit
    end
    return lit
end
local NOSE_SHADOW = 0.12 -- of the nose's size, away from the light
local function drawNoseShadow(body, img, ox, oy, dw, dh, mirrorX, rot)
    local count, dirs = shaders.gatherLightsForBody(body)
    local lx, ly = -0.7, -0.7 -- the shaders' own light without the scene's: from the upper left
    if count > 0 and dirs[1] then lx, ly = dirs[1][1], dirs[1][2] end
    local len = math.sqrt(lx * lx + ly * ly)
    if len < 1e-6 then return end
    local size = math.max(dw, dh) * NOSE_SHADOW
    local sx, sy = ox - lx / len * size, oy - ly / len * size
    local wx, wy = body:getWorldPoint(sx, sy)
    local imgw, imgh = img:getDimensions()
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 0.22 * a)
    love.graphics.draw(img, wx, wy, body:getAngle() + (rot or 0), dw / imgw * mirrorX * 1.05, dh / imgh * 1.05,
        imgw / 2, imgh / 2)
    love.graphics.setColor(r, g, b, a)
end

-- Eyes (Nikki 2026-11-10): the white lit as glaze rounded like a ball (its form baked from its mask),
-- and inside the eye, after the pupil: the lid's soft shadow along its top (following the blink).
-- (tried 2026-11-10: a catchlight, a small glint toward the strongest light: "just remove it", it read
-- as a white dot beside the pupil.) state.eyesFlat = true: flat as before.
local eyeLits = setmetatable({}, { __mode = 'k' })
local function eyeLit(extra)
    local lit = eyeLits[extra]
    if not lit then
        lit = setmetatable({ material = 'glaze', plasticineFormBaked = true }, { __index = extra })
        eyeLits[extra] = lit
    end
    return lit
end
lib.eyeLidShadow, lib.eyeLidDepth = 0.35, 0.5 -- darkest at the top, fading over this much of its height
lib.eyeWhite = 0.5 -- the flat white laid back over the lit one: whites stay bright (lit alone, a warm
-- lamp near them made them tan)
local lidMesh
local LID_ROWS = 6
local function eyeDepth()
    local x, y, angle, w, h = eyeLine.x, eyeLine.y, eyeLine.angle, eyeLine.w, eyeLine.h
    if not x or h <= 0 then return end
    -- the lid's shadow: a strip over the eye, dark at its top
    local verts = {}
    for r = 0, LID_ROWS - 1 do
        local v = r / (LID_ROWS - 1)
        local a = v < lib.eyeLidDepth and lib.eyeLidShadow * (1 - v / lib.eyeLidDepth) ^ 2 or 0
        verts[#verts + 1] = { -0.5, v - 0.5, 0, 0, 0, 0, 0, a }
        verts[#verts + 1] = { 0.5, v - 0.5, 0, 0, 0, 0, 0, a }
    end
    if not lidMesh then lidMesh = love.graphics.newMesh(#verts, 'strip', 'stream') end
    lidMesh:setVertices(verts)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(lidMesh, x, y, angle, math.abs(w), h)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawDecal(d)
    local extra = d.extra
    local body = d.body
    if extra.facePatches then
        if body and not body:isDestroyed() then drawFacePatches(extra, body) end
        return
    end
    if body and not body:isDestroyed() then
        local ox, oy = extra.ox or 0, extra.oy or 0
        if extra.lookAtMouse and extra.eyeW then
            -- per-Mipo gaze (src/mipo-actions.lua) looks fully that way;
            -- without one, follow the mouse with a distance falloff
            local gazeThing = utils.thingOf(body)
            local ecx, ecy = body:getPosition()
            local dx, dy, t
            if gazeThing and gazeThing.gazeX then
                dx, dy = gazeThing.gazeX - ecx, gazeThing.gazeY - ecy
                local dist = math.sqrt(dx * dx + dy * dy)
                t = math.min(1, dist / 40)
            else
                local mx, my = love.mouse.getPosition()
                local wmx, wmy = cam:getWorldCoordinates(mx, my)
                dx, dy = wmx - ecx, wmy - ecy
                local dist = math.sqrt(dx * dx + dy * dy)
                t = math.max(0, 1 - dist / gazeRadius)
            end
            if t > 0 then
                -- the offset is worked out in the eye's own frame (it's drawn turned by eyeRot), so a
                -- tilted eye's pupil moves along the eye; a blink squashes the eye toward its centre,
                -- so the pupil's offset across the eye shrinks with it
                local eyeRot = extra.eyeRot or 0
                local eyeAngle = math.atan2(dy, dx) - body:getAngle() - eyeRot
                local dw = extra.w or 0
                local dh = extra.h or 0
                local maxX = math.max(0, (extra.eyeW - dw) / 2) * pupilRange
                local maxY = math.max(0, (extra.eyeH - dh) / 2) * pupilRange
                local eyesOpen = (gazeThing and gazeThing.eyesOpen) or 1
                local ex = math.cos(eyeAngle) * maxX * t
                local ey = math.sin(eyeAngle) * maxY * t * eyesOpen
                local c, s = math.cos(eyeRot), math.sin(eyeRot)
                ox = ox + ex * c - ey * s
                oy = oy + ex * s + ey * c
            end
        end
        local wx, wy = body:getWorldPoint(ox, oy)
        local angle = body:getAngle() + (extra.rot or 0)
        local dw = extra.w or 50
        local dh = extra.h or 50
        local mirrorX = extra.mirror and -1 or 1
        if extra.isEye then
            local bodyThing = utils.thingOf(body)
            local eyesOpen = (bodyThing and bodyThing.eyesOpen) or 1
            dh = dh * eyesOpen
        end
        local clip = extra.eyeMaskURL and extra.eyeW and clipToEye(extra, body)
        -- small on screen: drawn flat (src/render/small-flat.lua); a pupil goes by its eye's size
        local tiny = smallFlat.tooSmall(extra.eyeW or math.max(extra.w or 50, extra.h or 50))
        local eyeLitNow = extra.isEye and not extra.material and not state.eyesFlat and not state.drawingOutlines
            and not tiny

        if extra.OMP and extra.ompImage then
            -- Pre-composited OMP image (has proper alpha)
            local img = extra.ompImage
            local imgw, imgh = img:getDimensions()
            local sx = dw / imgw * mirrorX
            local sy = dh / imgh
            love.graphics.setColor(1, 1, 1, 1)
            if d.nose and not extra.material and not state.noseFlat and not state.drawingOutlines and not tiny then
                drawNoseShadow(body, img, ox, oy, dw, dh, mirrorX, extra.rot)
                drawDecalLit(noseLit(extra), body, img, ox, oy, dw, dh, mirrorX)
            elseif eyeLitNow then
                drawDecalLit(eyeLit(extra), body, img, ox, oy, dw, dh, mirrorX)
                love.graphics.setColor(1, 1, 1, lib.eyeWhite)
                love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
                love.graphics.setColor(1, 1, 1, 1)
            elseif extra.material then
                drawDecalLit(extra, body, img, ox, oy, dw, dh, mirrorX)
            else
                love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
            end
        elseif extra.bgURL and extra.bgURL ~= '' then
            -- Simple single-color tinted image (no mask)
            local img, imgw, imgh = getLoveImage('textures/' .. extra.bgURL)
            if img then
                local sx = dw / imgw * mirrorX
                local sy = dh / imgh
                local r, g, b, a = color.hexToColor(extra.bgHex or 'ffffffff')
                love.graphics.setColor(r, g, b, a)
                if d.nose and not extra.material and not state.noseFlat and not state.drawingOutlines and not tiny then
                    drawNoseShadow(body, img, ox, oy, dw, dh, mirrorX, extra.rot)
                    drawDecalLit(noseLit(extra), body, img, ox, oy, dw, dh, mirrorX)
                elseif eyeLitNow then
                    drawDecalLit(eyeLit(extra), body, img, ox, oy, dw, dh, mirrorX)
                    love.graphics.setColor(r, g, b, a * lib.eyeWhite)
                    love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
                    love.graphics.setColor(r, g, b, a)
                elseif extra.material then
                    drawDecalLit(extra, body, img, ox, oy, dw, dh, mirrorX)
                else
                    love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
                end
            end
        end
        if clip and not state.eyesFlat and not state.drawingOutlines and not tiny then eyeDepth() end
        endClip(clip)
        if clip then redrawEyeLine(extra) end
    end
end

    -- Brow: bezier curve with bend pattern
local browLit = setmetatable({}, { __mode = 'k' }) -- a brow's settings with its mirror, for the lights
local function drawBrow(d)
    local extra = d.extra
    local body = d.body
    if body and not body:isDestroyed() and extra.bgURL then
        local browBends = mipoFace.browBendVecs

        local angle = body:getAngle()
        local bx, by = body:getPosition()

        love.graphics.push()
        love.graphics.translate(bx, by)
        love.graphics.rotate(angle)

        local browImg = getLoveImage('textures/' .. extra.bgURL)
        if browImg then
            local w = extra.w or 20
            local h = extra.h or 10
            local bodyThing = utils.thingOf(body)
            local vecKey = extra.browMirror and 'rbrowVec' or 'lbrowVec'
            local bend = (bodyThing and bodyThing[vecKey]) or browBends[extra.browBend or 1] or browBends[1]
            local bendMul = w / 5

            -- Build curve at origin, same for both sides
            local ox = extra.ox or 0
            local oy = extra.oy or 0
            local yKey = extra.browMirror and 'rbrowYOffset' or 'lbrowYOffset'
            oy = oy + (bodyThing and bodyThing[yKey] or 0)

            local p1x = -w / 2
            local p1y = bend[1] * bendMul
            local p2x = 0
            local p2y = bend[2] * bendMul
            local p3x = w / 2
            local p3y = bend[3] * bendMul

            -- Double control points to create a proper bezier
            local curveData = {
                p1x, p1y,
                (p1x + p2x) / 2, (p1y + p2y) / 2,
                (p2x + p3x) / 2, (p2y + p3y) / 2,
                p3x, p3y,
            }

            local lipScale = h / (browImg:getHeight() * 2)
            local mesh = ownStrip(extra, 'brow', browImg, lipScale, curveData, -1)
            local r, g, b, a = color.hexToColor(extra.bgHex or '000000ff')
            love.graphics.setColor(r, g, b, a)
            -- Mirror right brow via sx=-1, matching puppet-maker2 approach
            local mirrorSx = extra.browMirror and -1 or 1
            -- in a material (MT6c): lit like the head; the mirrored brow tells the lights it's flipped
            local shaded = false
            if extra.material then
                local lit = browLit[extra]
                if not lit then
                    lit = setmetatable({ main = { fx = 1, fy = 1 } }, { __index = extra })
                    browLit[extra] = lit
                end
                lit.main.fx = mirrorSx
                shaded = setSurfaceShader(lit, body)
            end
            love.graphics.draw(mesh, ox, oy, 0, mirrorSx, 1)
            if shaded then love.graphics.setShader() end
        end

        love.graphics.pop()
    end
end





-- Skip Mipos that are off screen (docs/MIPO-DRAWING.md L0): their part bodies' box, grown by how far
-- their pictures reach, against the screen corners in world space (whatever transform the camera or
-- a canvas set). lib.cull = false draws everything.
lib.cull = true
local hiddenMipos = {}
local cullStats = { culled = 0 }

-- How far a Mipo's pictures reach past its part bodies' centres: the furthest corner of any fixture
-- from its body's centre (texfixtures are the pictures' quads; a Mipo's `scale` says little, its parts
-- are sized on their own: heads stuck out 318 at scale 0.3), plus CULL_PAD for what's drawn past
-- the fixtures (ribbon and hair width). Measured when the draw list is built, not every frame.
local CULL_PAD = 200
local function mipoReach(instance)
    local reach = reachOf[instance]
    if reach then return reach end
    reach = 0
    for _, part in pairs(instance.parts) do
        local body = part.body
        if body and not body:isDestroyed() then
            for _, fixture in ipairs(body:getFixtures()) do
                local shape = fixture:getShape()
                if shape:getType() == 'circle' then
                    local px, py = shape:getPoint()
                    reach = math.max(reach, math.sqrt(px * px + py * py) + shape:getRadius())
                else
                    local points = { shape:getPoints() }
                    for i = 1, #points, 2 do
                        reach = math.max(reach, math.sqrt(points[i] * points[i] + points[i + 1] * points[i + 1]))
                    end
                end
            end
        end
    end
    reach = reach + CULL_PAD
    reachOf[instance] = reach
    return reach
end
-- This frame's splits: the scene's own (state.drawSplits, with the contact shadows') and the engine
-- systems' (src/systems.lua: the hair in its Mipo's layers), sorted by z, equal z in the order added.
-- Pooled: one entry table per split, kept between frames.
local splitList, splitPool, splitCount = {}, {}, 0
local function addSplit(z, fn, arg, mipoId)
    splitCount = splitCount + 1
    local e = splitPool[splitCount]
    if not e then
        e = {}
        splitPool[splitCount] = e
    end
    e.z, e.fn, e.arg, e.mipoId, e.order = z, fn, arg, mipoId, splitCount
    splitList[splitCount] = e
end
local function splitSorter(a, b)
    if a.z ~= b.z then return a.z < b.z end
    return a.order < b.order
end
local function frameSplits()
    splitCount = 0
    local scene = state.drawSplits
    if scene then
        for i = 1, #scene do addSplit(scene[i].z, scene[i].fn, scene[i].arg, scene[i].mipoId) end
    end
    systems.splits(addSplit)
    for i = splitCount + 1, #splitList do splitList[i] = nil end
    if splitCount == 0 then return nil end
    table.sort(splitList, splitSorter)
    return splitList
end
local function drawSplit(split)
    if not (split.mipoId and hiddenMipos[split.mipoId]) then split.fn(split.arg) end
end

local function hideOffscreenMipos()
    for id in pairs(hiddenMipos) do hiddenMipos[id] = nil end
    if not lib.cull then return end
    local vx1, vy1, vx2, vy2 = view.worldRect()
    for id, instance in pairs(mipoRegistry.getAll()) do
        local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
        for _, part in pairs(instance.parts) do
            local body = part.body
            if body and not body:isDestroyed() then
                local x, y = body:getPosition()
                if x < x1 then x1 = x end
                if x > x2 then x2 = x end
                if y < y1 then y1 = y end
                if y > y2 then y2 = y end
            end
        end
        local margin = mipoReach(instance)
        if x1 - margin > vx2 or x2 + margin < vx1 or y1 - margin > vy2 or y2 + margin < vy1 then
            hiddenMipos[id] = true
        end
    end
end

-- One function per drawable type: drawers[d.type](d). `d` is a drawable from createDrawables.
-- Named, so a profiler (POST /profile/frames) reports them by name.
local drawers = {
    [subtypes.TEXFIXTURE] = drawTexfixture,
    ['foot-back'] = function(d)
        if not state.feetFlat then drawTexfixture(d) end
    end,
    ['foot-front'] = function(d)
        local instance, partName = mipoRegistry.getFromBody(d.body)
        -- Not drawn over the leg any more (the legs always show; tried 2026-11-10: the foot's lower part
        -- cut across the leg and drawn in front, the leg went under and over the feet). Flat: the whole foot.
        if not state.feetFlat then return end
        local cx, cy, dx, dy
        if instance and not state.feetFlat then cx, cy, dx, dy = footCut(instance, partName:sub(1, 1)) end
        if not cx then return drawTexfixture(d) end
        local ok = pcall(love.graphics.stencil, function()
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(math.atan2(dy, dx) - math.pi / 2) -- +y along the leg, into the foot
            love.graphics.rectangle('fill', -1e4, 0, 2e4, 2e4)
            love.graphics.pop()
        end, 'replace', 1)
        if not ok then return drawTexfixture(d) end -- a canvas without a stencil: the whole foot
        local compare, value = love.graphics.getStencilTest()
        love.graphics.setStencilTest('greater', 0)
        drawTexfixture(d)
        if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
    end,
    [subtypes.MESHUSERT] = drawMeshusert,
    [subtypes.UVUSERT] = drawUvusert,
    [subtypes.CONNECTED_TEXTURE] = drawConnectedTexture,
    [subtypes.GRASS] = drawGrass,
    [subtypes.SOFTBODY] = drawSoftbody,
    [subtypes.LIQUID] = drawLiquid,
    [subtypes.TILE_REPEAT] = drawTileRepeat,
    [subtypes.TRACE_VERTICES] = drawTraceVertices,
    ['decal'] = drawDecal,
    ['brow'] = drawBrow,
}
-- backdrop, lips, teeth: looked up in mouth.drawers each time, so a hot reload of
-- src/render/mouth.lua reaches them (a copy kept drawing the old ones)
for kind in pairs(mouth.drawers) do drawers[kind] = function(d) return mouth.drawers[kind](d) end end

-- draws what's registered (createDrawables). `only` (optional): a function of a drawable's body (and the
-- drawable itself: its type), false skips it; the scene's splits aren't drawn then (the 3D shadows draw
-- each depth on its own and leave out what doesn't show in a shadow, src/shadow-silhouettes.lua)
function lib.drawTexturedWorld(_world, only)

    -- state.drawTimes = { frames = 0, ms = {}, count = {} } (from the bridge) adds up the time
    -- per drawable kind; nil (the default) costs nothing. On state: a hot swap gives this
    -- code a fresh lib, so a flag set on the old one from outside is never seen
    local times, counts = state.drawTimes and state.drawTimes.ms, state.drawTimes and state.drawTimes.count
    local tStart = times and love.timer.getTime()
    local drawables = drawablesList
    local rebuilt = not listStillHolds()
    if rebuilt then
        listState.version = registry.sfixtureVersion
        drawables = createDrawables()
    end
    local tBuilt = times and love.timer.getTime()
    if rebuilt then table.sort(drawables, sorter) end
    hideOffscreenMipos()
    local culled = 0
    local tCreate = times and tBuilt - tStart
    local tSort = times and love.timer.getTime() - tBuilt

    -- state.drawSplits = { { z = n, fn = f }, ... }: a scene draws its own layer between the
    -- drawables, f called before the first one at z or higher (the depth spike draws its house
    -- between the back lane's Mipos and the front lane's). Set per frame by the scene. Merged with
    -- the engine systems' splits (frameSplits), so the hair goes in its Mipo's layers too.
    local splits, nextSplit = (not only) and frameSplits() or nil, 1
    -- state.sceneDrawnMipos = { [instance.id] = true }: Mipos a scene draws itself (with `only`, in
    -- its own transform: the tracks spike's riders, at their cart's depth); the world pass skips them
    local sceneDrawn = (not only) and state.sceneDrawnMipos or nil
    for i = 1, #drawables do repeat -- break = the next drawable
        if only and not only(drawables[i].body, drawables[i]) then break end
        if sceneDrawn and drawables[i].mipoThing and sceneDrawn[drawables[i].mipoThing.mipoId] then break end
        if splits then
            local z = drawables[i].z
            while splits[nextSplit] and splits[nextSplit].z <= z do
                drawSplit(splits[nextSplit])
                nextSplit = nextSplit + 1
            end
        end
        local t0 = times and love.timer.getTime()
        local mipoThing = drawables[i].mipoThing
        if mipoThing and mipoThing.mipoId and hiddenMipos[mipoThing.mipoId] then
            culled = culled + 1
        else
            -- a face on a spine torso (a potato head) moves and turns with the bend where it sits
            local faceBend = faceDrawables[drawables[i].type] and drawables[i].body and drawables[i].extra
                and spineSkin.transformAt(drawables[i].body, drawables[i].extra.ox or 0, drawables[i].extra.oy or 0)
            if faceBend then
                love.graphics.push()
                love.graphics.applyTransform(faceBend)
            end
            local draw = drawers[drawables[i].type]
            if draw then draw(drawables[i]) end
            if faceBend then love.graphics.pop() end
            if times then
                local kind = drawables[i].type
                times[kind] = (times[kind] or 0) + love.timer.getTime() - t0
                counts[kind] = (counts[kind] or 0) + 1
            end
        end
    until true end
    if splits then
        for k = nextSplit, #splits do drawSplit(splits[k]) end
    end
    cullStats.culled = culled
    if times then
        times['(createDrawables)'] = (times['(createDrawables)'] or 0) + tCreate
        times['(sort)'] = (times['(sort)'] or 0) + tSort
        state.drawTimes.frames = state.drawTimes.frames + 1
    end

end

-- for specs, not part of the API
lib._test = {
    setSurfaceShader = shaders.setSurfaceShader,
    -- forget the kept list and the owned strips and fans: the next frame is drawn from scratch
    clearCaches = function()
        listState.version = nil
        ribbonCache = setmetatable({}, { __mode = 'k' })
        ribbon.clearOwned()
    end,
    -- how many drawables the last frame skipped as off screen
    culled = function() return cullStats.culled end,
    -- the kept list's order: one 'type key sub z' line per drawable
    order = function()
        local out = {}
        for i, d in ipairs(drawablesList) do out[i] = d.type .. ' ' .. tostring(d.key) .. ' ' .. d.sub .. ' ' .. d.z end
        return table.concat(out, '\n')
    end,
}

-- A pictured sfixture's picture as the world draws it (an OMP texfixture's combined image), no shader:
-- for a stencil of what's drawn (src/contact-shadows.lua). Returns false when it has none to draw.
function lib.drawPictureOf(fixture)
    local ud = fixture:getUserData()
    local extra = type(ud) == 'table' and ud.subtype == subtypes.TEXFIXTURE and ud.extra
    if not (extra and extra.OMP and extra.ompImage) then return false end
    drawCombinedImageVanilla(extra.ompImage, extra, fixture, utils.thingOf(fixture:getBody()))
    return true
end

return lib
