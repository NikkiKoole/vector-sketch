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
local spineSkin = require('src.spine-skin')
local earBend = require('src.ear-bend')
-- face parts drawn on their body around extra.ox/oy: on a spine torso they ride the bend
local faceDrawables = { decal = true, brow = true, ['mouth-backdrop'] = true, ['mouth-lower'] = true,
    ['mouth-upper'] = true, ['mouth-teeth'] = true }

local gazeRadius = 1000 -- world units; cursor within this distance → track, outside → look ahead
local mipoFace = require('src.mipo-face')
local utils = require('src.utils')
local mipoRegistry = require('src.mipo-registry')
local view = require('src.render.view')
local ompBake = require('src.render.omp-bake')
local shaders = require('src.render.shaders')
local ribbon = require('src.render.ribbon')
local mouth = require('src.render.mouth')
local skinning = require('src.render.skinning')

local getLoveImage = ompBake.getLoveImage
local setSurfaceShader = shaders.setSurfaceShader
local ownStrip, growLine = ribbon.ownStrip, ribbon.growLine
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
    local bones = #vertices == 16 and spineSkin.bonesOf(texfixture:getBody()) -- a spine's bodyhair bends with it
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
        local bones = #vertices == 8 and (spineSkin.bonesOf(body) or earBend.bonesOf(body, vertices))
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

        drawSquishableHairOver(img, body:getX(), body:getY(), body:getAngle(), sx, sy, 1, vertices, extra, 'omp')
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
        if type(ud) ~= 'table' then -- only table userData is an sfixture
            ud = nil
        end
        local body = ud and fixture:getBody()
        local before = #drawables
        -- each Mipo draws in its own z-range: zGroupOffset * 1000 + the part's zOffset
        local composedZ = ud and ud.extra and ((ud.extra.zGroupOffset or 0) * 1000 + (ud.extra.zOffset or 0))
        if ud and subtypes.is(ud, subtypes.TRACE_VERTICES) then

            table.insert(drawables, {
                type = 'trace-vertices',
                z = composedZ,
                extra = ud.extra,
                thing = utils.thingOf(body)
            })
        end

        if ud and subtypes.is(ud, subtypes.TILE_REPEAT) then

            table.insert(drawables, {
                type = 'tile-repeat',
                z = composedZ,
                extra = ud.extra,
                thing = utils.thingOf(body)
            })
        end

        if ud and subtypes.is(ud, subtypes.GRASS) then
            -- two layers: behind the Mipos at its own z, in front of all of them (src/grass.lua)
            local thing = utils.thingOf(body)
            table.insert(drawables, { type = 'grass', layer = 'back', z = composedZ,
                extra = ud.extra, thing = thing, body = body })
            table.insert(drawables, { type = 'grass', layer = 'front', z = grass.FRONT_Z + (ud.extra.zOffset or 0),
                extra = ud.extra, thing = thing, body = body })
        end

        if ud and subtypes.is(ud, subtypes.LIQUID) then
            -- water in a container (src/liquid.lua); 'front' puts it in front of the Mipos (a bath)
            if ud.extra.front then composedZ = liquid.FRONT_Z + (ud.extra.zOffset or 0) end
            table.insert(drawables, { type = subtypes.LIQUID, z = composedZ, extra = ud.extra, body = body })
        end

        if ud and subtypes.is(ud, subtypes.SOFTBODY) then
            table.insert(drawables, { type = subtypes.SOFTBODY, z = composedZ, fixture = fixture })
        end

        if ud and subtypes.is(ud, subtypes.TEXFIXTURE) then
            table.insert(drawables,
                {
                    type = 'texfixture',
                    z = composedZ,
                    texfixture = fixture,
                    extra = ud.extra,
                    body = body,
                    thing = utils.thingOf(body)
                })
        end
        if ud and subtypes.is(ud, subtypes.MESHUSERT) then
            table.insert(drawables,
                {
                    type = 'meshusert',
                    z = composedZ,
                    texfixture = fixture,
                    label = ud.label,
                    extra = ud.extra,
                    body = body,
                    thing = utils.thingOf(body)
                })
        end
        if ud and subtypes.is(ud, subtypes.UVUSERT) then
            table.insert(drawables,
                {
                    type = 'uvusert',
                    z = composedZ,
                    texfixture = fixture,
                    label = ud.label,
                    extra = ud.extra,
                    body = body,
                    thing = utils.thingOf(body)
                })
        end
        if ud and subtypes.is(ud, subtypes.DECAL) then
            if ud.extra.browCurve then
                table.insert(drawables, {
                    type = 'brow',
                    z = composedZ,
                    extra = ud.extra,
                    body = body,
                })
            elseif ud.extra.mouthCurve then
                if ud.extra.mouthCurve == 'teeth' then
                    -- Teeth: positioned image, optionally clipped to mouth polygon
                    table.insert(drawables, {
                        type = 'mouth-teeth',
                        z = composedZ,
                        extra = ud.extra,
                        body = body,
                    })
                else
                    -- Mouth bezier curve decal (upper or lower lip); its curve comes from
                    -- extra.curvePoints when drawn (src/render/mouth.lua)
                    local pts = ud.extra.curvePoints
                    if pts and #pts == 16 then
                        table.insert(drawables, {
                            type = 'mouth-' .. ud.extra.mouthCurve,
                            z = composedZ,
                            extra = ud.extra,
                            body = body,
                        })
                        if ud.extra.mouthCurve == 'lower' then
                            -- Dark interior fill renders below teeth so teeth always
                            -- sit on top of the void. zOffset 250 < non-stickOut teeth 251.
                            table.insert(drawables, {
                                type = 'mouth-backdrop',
                                z = composedZ - 2,
                                extra = ud.extra,
                                body = body,
                            })
                        end
                    end
                end
            else
                table.insert(drawables, {
                    type = 'decal',
                    z = composedZ,
                    extra = ud.extra,
                    body = body,
                })
            end
        end

        if ud and subtypes.is(ud, subtypes.CONNECTED_TEXTURE) and ud.extra.nodes then
            -- its curve follows the joints: laid in drawConnectedTexture (ribbonPoints)
            table.insert(drawables, { z = composedZ, type = 'connected-texture', extra = ud.extra, body = body })
        end
        local thing = body and utils.thingOf(body)
        for k = before + 1, #drawables do
            drawables[k].key, drawables[k].sub = ud.id, k - before
            drawables[k].mipoThing = thing and thing.mipoId and thing -- for culling (L0)
        end
        if ud then listState.entries[#listState.entries + 1] = sfixtureLooks({}, fixture, ud) end
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
local function drawTexfixture(d)
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
                local b = f:getBody()
                local centerX, centerY = mathutils.getCenterOfPoints({ b:getWorldPoints(f:getShape()
                    :getPoints()) })
                table.insert(points, centerX)
                table.insert(points, centerY)
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

local function shapeRibbon(points, extra)
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
    points[1], points[2] = growLine({ points[1], points[2] }, { points[3], points[4] }, growLength)
    points[5], points[6] = growLine({ points[5], points[6] }, { points[3], points[4] }, growLength)

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
local function ribbonPoints(extra)
    local raw = nodePositions(extra, rawScratch)
    local grow, bend = extra.growExtra or 20, (extra.main and extra.main.bendiness) or 2
    local c = ribbonCache[extra]
    if c and c.nodes == extra.nodes and c.grow == grow and c.bend == bend and #c.raw == #raw then
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
    c.nodes, c.grow, c.bend, c.points = extra.nodes, grow, bend, shapeRibbon(copy, extra)
    return c.points
end

local function drawConnectedTexture(d)
    local extra = d.extra
    local points = ribbonPoints(extra)
    if not points then return end
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
    local shaded = setSurfaceShader(extra, nil)
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

    local img = getLoveImage('textures/' .. d.extra.main.bgURL)
    if img then
        if not d.extra._mesh then
            img:setWrap("repeat", "repeat")
            local texW, texH = img:getWidth(), img:getHeight()
            local centroidX, centroidY = mathutils.computeCentroid(vertices)
            local meshVertices = {}

            local twm = d.extra.tileWidthM
            local thm = d.extra.tileHeightM
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
    local m = traceVerticesMesh(d.extra,
        hairBones and hairBones.outline or d.thing.vertices)
    if m then
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
                img = getLoveImage('textures/' .. 'hair7.png')
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

local function drawDecal(d)
    local extra = d.extra
    local body = d.body
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
                local angle = math.atan2(dy, dx)
                local localAngle = angle - body:getAngle()
                local dw = extra.w or 0
                local dh = extra.h or 0
                local maxX = math.max(0, (extra.eyeW - dw) / 2) * 0.8
                local maxY = math.max(0, (extra.eyeH - dh) / 2) * 0.8
                ox = ox + math.cos(localAngle) * maxX * t
                oy = oy + math.sin(localAngle) * maxY * t
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

        if extra.OMP and extra.ompImage then
            -- Pre-composited OMP image (has proper alpha)
            local img = extra.ompImage
            local imgw, imgh = img:getDimensions()
            local sx = dw / imgw * mirrorX
            local sy = dh / imgh
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
        elseif extra.bgURL and extra.bgURL ~= '' then
            -- Simple single-color tinted image (no mask)
            local img, imgw, imgh = getLoveImage('textures/' .. extra.bgURL)
            if img then
                local sx = dw / imgw * mirrorX
                local sy = dh / imgh
                local r, g, b, a = color.hexToColor(extra.bgHex or 'ffffffff')
                love.graphics.setColor(r, g, b, a)
                love.graphics.draw(img, wx, wy, angle, sx, sy, imgw / 2, imgh / 2)
            end
        end
    end
end

    -- Brow: bezier curve with bend pattern
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
            love.graphics.draw(mesh, ox, oy, 0, mirrorSx, 1)
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
for kind, draw in pairs(mouth.drawers) do drawers[kind] = draw end -- backdrop, lips, teeth

function lib.drawTexturedWorld(_world) -- draws what's registered (createDrawables)

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

    for i = 1, #drawables do
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

return lib
