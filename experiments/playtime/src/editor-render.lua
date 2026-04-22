-- here we just have small functions that render things for the editor
-- (not ui but active state, selection boxes that sort of thing)
--
local logger = require 'src.logger'
local registry = require 'src.registry'
local state = require 'src.state'
local modes = require 'src.modes'
local fixtures = require 'src.fixtures'
local box2dDraw = require 'src.physics.box2d-draw'
local shapes = require 'src.shapes'
local mathutils = require 'src.math-utils'
local camera = require 'src.camera'
local cam = camera.getInstance()
local utils = require 'src.utils'
local inputmanager = require 'src.input-manager'
local subtypes = require 'src.subtypes'
local ST = require 'src.shape-types'
local NT = require('src.node-types')
local cdt = require 'src.cdt'
local lib = {}


-- drawGrid renders in WORLD space so it must be called inside cam:push().
-- Line width is divided by the camera scale so grid lines stay visually 1px
-- regardless of zoom.
function lib.drawGrid(color)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1 / cam:getScale())
    love.graphics.setColor(color[1], color[2], color[3], color[4])

    local w, h = love.graphics.getDimensions()
    local tlx, tly = cam:getWorldCoordinates(0, 0)
    local brx, bry = cam:getWorldCoordinates(w, h)
    local step = state.world.meter
    local startX = math.floor(tlx / step) * step
    local endX = math.ceil(brx / step) * step
    local startY = math.floor(tly / step) * step
    local endY = math.ceil(bry / step) * step

    for i = startX, endX, step do
        love.graphics.line(i, tly, i, bry)
    end
    for i = startY, endY, step do
        love.graphics.line(tlx, i, brx, i)
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)
end

function lib.renderActiveEditorThings()
    if state.selection.selectedSFixture and not state.selection.selectedSFixture:isDestroyed() then
        local body = state.selection.selectedSFixture:getBody()
        local centroid = fixtures.getCentroidOfFixture(body, state.selection.selectedSFixture)
        local x2, y2 = body:getWorldPoint(centroid[1], centroid[2])
        love.graphics.circle('line', x2, y2, 3)
    end

    if state.selection.selectedSFixture and not state.selection.selectedSFixture:isDestroyed() then
        local ud = state.selection.selectedSFixture:getUserData()
        if false and ud.subtype == 'resource' then
            local bod = state.selection.selectedSFixture:getBody()
            local bodyData = bod:getUserData()
            love.graphics.polygon('line', bodyData.thing.vertices)
            local b = state.backdrops[ud.extra.selectedBGIndex]
            local x1l, y1l = bod:getLocalPoint(b.x, b.y)
            local x2l, y2l = bod:getLocalPoint(b.x + b.w, b.y + b.h)
            love.graphics.rectangle('line', x1l, y1l, x2l - x1l, y2l - y1l)
        end

        -- Render bone-segment influence capsules for MESHUSERT so the user can
        -- see what `bindRadius` actually covers in world space. A capsule is
        -- the set of points within `radius` of the bone segment — the
        -- influence zone used by applySegmentWeights.
        if ud.subtype == 'meshusert' and ud.extra.nodes and #ud.extra.nodes >= 2 then
            local radius = tonumber(ud.extra.bindRadius) or 80
            local function endpointsOnSharedBody(nA, nB)
                local function resolve(n)
                    if n.type == NT.JOINT then
                        local j = registry.getJointByID(n.id)
                        if not j then return {} end
                        local x1, y1, x2, y2 = j:getAnchors()
                        local bA, bB = j:getBodies()
                        return { { body = bA, wx = x1, wy = y1 }, { body = bB, wx = x2, wy = y2 } }
                    end
                    local f = registry.getSFixtureByID(n.id)
                    if not f then return {} end
                    local bp = f:getBody()
                    local pts = { bp:getWorldPoints(f:getShape():getPoints()) }
                    local cx, cy = mathutils.getCenterOfPoints(pts)
                    return { { body = bp, wx = cx, wy = cy } }
                end
                local a, b = resolve(nA), resolve(nB)
                for _, ai in ipairs(a) do
                    for _, bi in ipairs(b) do
                        if ai.body == bi.body then return ai, bi end
                    end
                end
                return nil, nil
            end

            local lw = love.graphics.getLineWidth()
            love.graphics.setLineWidth(1 / cam:getScale())
            love.graphics.setColor(1.0, 0.7, 0.2, 0.7)

            local nodes = ud.extra.nodes
            for i = 1, #nodes - 1 do
                local a, b = endpointsOnSharedBody(nodes[i], nodes[i + 1])
                if a and b then
                    local dx, dy = b.wx - a.wx, b.wy - a.wy
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 1e-4 then
                        -- Perpendicular offset, normalized.
                        local nxp, nyp = -dy / len * radius, dx / len * radius
                        -- Two parallel lines forming the "tube" part.
                        love.graphics.line(a.wx + nxp, a.wy + nyp, b.wx + nxp, b.wy + nyp)
                        love.graphics.line(a.wx - nxp, a.wy - nyp, b.wx - nxp, b.wy - nyp)
                    end
                    -- Rounded caps: full circles at each endpoint (simpler
                    -- than arcs, slight overlap with tube lines is fine).
                    love.graphics.circle('line', a.wx, a.wy, radius)
                    love.graphics.circle('line', b.wx, b.wy, radius)
                    -- Centerline for orientation reference.
                    love.graphics.setColor(1.0, 0.7, 0.2, 0.35)
                    love.graphics.line(a.wx, a.wy, b.wx, b.wy)
                    love.graphics.setColor(1.0, 0.7, 0.2, 0.7)
                end
            end

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(lw)
        end
    end



    if state.selection.selectedJoint and not state.selection.selectedJoint:isDestroyed() then
        box2dDraw.drawJointAnchors(state.selection.selectedJoint)
    end

    local lw = love.graphics.getLineWidth()
    for i, v in ipairs(state.world.softbodies) do
        if (tostring(v) == "softbody") then
            love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255, .8)
            --v:draw("fill", false)
            love.graphics.setColor(50 * i / 255, 255 / 255, 200 * i / 255, .8)
        else
            love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255, .8)
        end

        if v.centerBody and not v.centerBody:isDestroyed() then
            local polygon = v:getPoly()

            local tris = shapes.makeTrianglesFromPolygon(polygon)
            for ti = 1, #tris do
                love.graphics.polygon('fill', tris[ti])
            end
        end
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)

    -- draw to be drawn polygon
    if modes.is(modes.DRAW_CLICK)
        or modes.is(modes.DRAW_FREE_POLY)
        or modes.is(modes.DRAW_FREE_PATH) then
        if (#state.interaction.polyVerts >= 6) then
            love.graphics.polygon('line', state.interaction.polyVerts)
        end
    end


    -- draw mousehandlers for dragging vertices
    local rightShape = state.selection.selectedObj and
        (state.selection.selectedObj.shapeType == ST.CUSTOM or state.selection.selectedObj.shapeType == ST.RIBBON)
    if state.polyEdit.tempVerts and rightShape and state.polyEdit.lockedVerts == false then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)


        local mx, my = love.mouse:getPosition()
        local cx, cy = cam:getWorldCoordinates(mx, my)
        -- Scale marker sizes by camera zoom so they stay visually constant
        -- (precise when zoomed in, not giant when zoomed out).
        local invZoom = 1 / cam:getScale()
        local hitR = 10 * invZoom

        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < hitR then
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('fill', vx, vy, 13 * invZoom)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', vx, vy, 11 * invZoom)
            else
                love.graphics.setColor(0, 0, 0)
                love.graphics.setLineWidth(invZoom)
                love.graphics.circle('line', vx, vy, 12 * invZoom)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', vx, vy, 10 * invZoom)
            end

            love.graphics.setColor(0, 0, 0)
            love.graphics.print(math.ceil(i / 2), vx, vy, 0, invZoom, invZoom)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(math.ceil(i / 2), vx - 2 * invZoom, vy - 2 * invZoom, 0, invZoom, invZoom)
        end
    end


    if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture
        and state.texFixtureEdit.lockedVerts == false then
        local thing     = state.selection.selectedSFixture:getBody():getUserData().thing

        local fixtureUD = state.selection.selectedSFixture:getUserData()
        local isMeta8   = fixtureUD.label == 'meta8'
        local verts     = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
            thing, 0, 0)

        local mx, my    = love.mouse:getPosition()
        local cx, cy    = cam:getWorldCoordinates(mx, my)
        local invZoom   = 1 / cam:getScale()
        local hitR      = 10 * invZoom
        -- logger:inspect(fixtureUD)
        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < hitR then
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('fill', vx, vy, 13 * invZoom)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', vx, vy, 11 * invZoom)
            else
                love.graphics.setColor(0, 0, 0)
                love.graphics.setLineWidth(invZoom)
                love.graphics.circle('line', vx, vy, 12 * invZoom)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', vx, vy, 10 * invZoom)

                if (isMeta8) then
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print(math.ceil(i / 2), vx, vy, 0, invZoom, invZoom)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(math.ceil(i / 2), vx - 2 * invZoom, vy - 2 * invZoom, 0, invZoom, invZoom)
                end
            end
        end

        if (isMeta8) then
            -- index 1 -> 5
            love.graphics.line(verts[1 * 2 - 1], verts[1 * 2 - 0], verts[5 * 2 - 1], verts[5 * 2 - 0])
            -- index 2 -> 8
            love.graphics.line(verts[2 * 2 - 1], verts[2 * 2 - 0], verts[8 * 2 - 1], verts[8 * 2 - 0])
            -- index 3 -> 7
            love.graphics.line(verts[3 * 2 - 1], verts[3 * 2 - 0], verts[7 * 2 - 1], verts[7 * 2 - 0])
            -- index 4 -> 6
            love.graphics.line(verts[4 * 2 - 1], verts[4 * 2 - 0], verts[6 * 2 - 1], verts[6 * 2 - 0])

            local function roundArray(values)
                local result = {}
                for i, v in ipairs(values) do
                    result[i] = math.floor(v + 0.5)
                end
                return result
            end

            logger:info(isMeta8)
            logger:inspect(roundArray(state.texFixtureEdit.tempVerts))
        end
    end

    -- Highlight selected bodies
    if state.selection.selectedBodies then
        local bodies = utils.map(state.selection.selectedBodies, function(thing)
            return thing.body
        end)
        box2dDraw.drawBodies(bodies)
    end

    if modes.is(modes.ADD_NODE_CONNECTED_TEX) or modes.is(modes.ADD_NODE_MESHUSERT) then
        -- maybe show all possible connections on screen

        local node = inputmanager.showCloseNode()

        if node then
            --  logger:info(node[1] - 5, node[2] - 5)
            love.graphics.rectangle('line', node[1] - 5, node[2] - 5, 10, 10)
        end
    end

    -- draw temp poly when changing vertices
    if state.polyEdit.tempVerts and state.selection.selectedObj then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
        love.graphics.setColor(1, 0, 0)
        love.graphics.polygon('line', verts)
        love.graphics.setColor(1, 1, 1) -- Rese
    end

    -- TRIANGLE SELECTION VISUALIZATION
    if modes.is(modes.EDIT_MESH_TRIS) and state.selection.selectedSFixture then
        local ud = state.selection.selectedSFixture:getUserData()
        if ud and subtypes.is(ud, subtypes.MESHUSERT) and ud.label then
            local mappert = nil
            for _, v in pairs(registry.sfixtures) do
                if not v:isDestroyed() then
                    local vud = v:getUserData()
                    if #vud.label > 0 and vud.label == ud.label and subtypes.is(vud, subtypes.RESOURCE) then
                        mappert = v
                        break
                    end
                end
            end

            if mappert then
                local mextra = mappert:getUserData().extra
                local triIdx = mextra and mextra.triangles
                local mb = mappert:getBody()
                local meshData = mb:getUserData()
                local baseVerts = (mextra and mextra.meshVertices) or meshData.thing.vertices

                local body = state.selection.selectedSFixture:getBody()
                local polyCx, polyCy = mathutils.computeCentroid(baseVerts)
                local centeredVerts = mathutils.makePolygonRelativeToCenter(baseVerts, polyCx, polyCy)

                local mx = ud.extra.meshX or 0
                local my = ud.extra.meshY or 0
                local sx = ud.extra.scaleX or 1
                local sy = ud.extra.scaleY or 1
                local mr = ud.extra.meshRot or 0
                local cosR, sinR = math.cos(mr), math.sin(mr)

                local function worldAt(vertIndex)
                    local lx = centeredVerts[(vertIndex - 1) * 2 + 1]
                    local ly = centeredVerts[(vertIndex - 1) * 2 + 2]
                    lx = (lx + mx) * sx
                    ly = (ly + my) * sy
                    if mr ~= 0 then
                        lx, ly = lx * cosR - ly * sinR, lx * sinR + ly * cosR
                    end
                    return body:getWorldPoint(lx, ly)
                end

                if triIdx and #triIdx >= 3 then
                    local selSet = {}
                    for _, t in ipairs(state.triangleEditor.selectedTriangles) do selSet[t] = true end
                    local groups = mextra.triangleGroups
                    local numTris = math.floor(#triIdx / 3)

                    -- Same hash as the group buttons in sfixture-editor.lua
                    local function groupColor(g)
                        return ((g * 73) % 256) / 255,
                               ((g * 151) % 256) / 255,
                               ((g * 211) % 256) / 255
                    end
                    local paintMode = state.triangleEditor.paintMode or 'bones'

                    local function boneColor(b)
                        return ((b * 97)  % 256) / 255,
                               ((b * 163) % 256) / 255,
                               ((b * 211) % 256) / 255
                    end

                    local targetBone     = state.triangleEditor.selectedBone or 1
                    local triangleBones  = ud.extra.triangleBones
                    local targetGroup    = state.triangleEditor.selectedGroup or 1
                    local hoveredGroup   = state.triangleEditor.hoveredGroup
                    -- triangleGroups lives on the RESOURCE fixture
                    local triangleGroups = groups  -- already read above

                    for t = 1, numTris do
                        local i1 = triIdx[(t - 1) * 3 + 1]
                        local i2 = triIdx[(t - 1) * 3 + 2]
                        local i3 = triIdx[(t - 1) * 3 + 3]
                        if i1 and i2 and i3 then
                            local x1, y1 = worldAt(i1)
                            local x2, y2 = worldAt(i2)
                            local x3, y3 = worldAt(i3)

                            if paintMode == 'groups' then
                                local assignedGroup = triangleGroups and triangleGroups[t]
                                if assignedGroup then
                                    local isHovered = (assignedGroup == hoveredGroup)
                                    local r, gn, bl = groupColor(assignedGroup)
                                    love.graphics.setColor(r, gn, bl, isHovered and 0.85 or 0.6)
                                    love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
                                    love.graphics.setColor(r, gn, bl, isHovered and 1.0 or 0.9)
                                    love.graphics.setLineWidth(isHovered and 3 or 1)
                                    love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
                                end
                                if selSet[t] then
                                    local r, gn, bl = groupColor(targetGroup)
                                    love.graphics.setColor(r, gn, bl, 0.85)
                                    love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
                                end
                                if not assignedGroup then
                                    love.graphics.setColor(0.2, 1.0, 0.4, 0.4)
                                    love.graphics.setLineWidth(1)
                                    love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
                                end
                            else -- bones
                                local assignedBone = triangleBones and triangleBones[t]
                                if assignedBone then
                                    local r, gn, bl = boneColor(assignedBone)
                                    love.graphics.setColor(r, gn, bl, 0.6)
                                    love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
                                    love.graphics.setColor(r, gn, bl, 0.9)
                                    love.graphics.setLineWidth(1)
                                    love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
                                end
                                if selSet[t] then
                                    local r, gn, bl = boneColor(targetBone)
                                    love.graphics.setColor(r, gn, bl, 0.85)
                                    love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
                                end
                                if not assignedBone then
                                    love.graphics.setColor(0.2, 1.0, 0.4, 0.4)
                                    love.graphics.setLineWidth(1)
                                    love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
                                end
                            end
                        end
                    end
                    love.graphics.setColor(1, 1, 1, 1)
                end

                -- Brush radius at mouse cursor
                local msx, msy = love.mouse.getPosition()
                local bcx, bcy = cam:getWorldCoordinates(msx, msy)
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.circle('line', bcx, bcy, tonumber(state.triangleEditor.brushSize) or 20)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end

    love.graphics.setColor(1, 1, 1)  -- Reset color
end

-- Steiner-point authoring overlay. When the selected body has
-- `thing.extraSteiner` populated, draws each point as an orange dot
-- and the would-be triangulation in green. This is the authoring
-- feedback for PLACE_STEINER mode. Steiners flow through MESHUSERT's
-- triangulation on the paired RESOURCE — they affect textured-mesh
-- detail, not body collision (by design).
function lib.renderSteinerOverlay()
    local thing = state.selection.selectedObj
    if not thing or not thing.body or thing.body:isDestroyed() then return end
    if not thing.vertices or #thing.vertices < 6 then return end
    if not thing.extraSteiner or #thing.extraSteiner < 2 then return end

    local body = thing.body

    -- Polygon verts are stored in authoring-world coords; the rendered body
    -- uses `vert - centroid(thing.vertices)` as its body-local frame. Match
    -- that frame so the overlay tracks the body when it moves.
    local cenX, cenY = mathutils.computeCentroid(thing.vertices)
    local localPoly = {}
    for i = 1, #thing.vertices, 2 do
        localPoly[i] = thing.vertices[i] - cenX
        localPoly[i + 1] = thing.vertices[i + 1] - cenY
    end

    local meshVerts, triIdx = cdt.triangulatePolyWithSteiner(localPoly, thing.extraSteiner)

    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1 / cam:getScale())

    if meshVerts and triIdx and #triIdx >= 3 then
        love.graphics.setColor(0.2, 0.85, 0.35, 0.85)
        for t = 1, #triIdx - 2, 3 do
            local i1, i2, i3 = triIdx[t], triIdx[t + 1], triIdx[t + 2]
            local x1, y1 = body:getWorldPoint(meshVerts[(i1 - 1) * 2 + 1], meshVerts[(i1 - 1) * 2 + 2])
            local x2, y2 = body:getWorldPoint(meshVerts[(i2 - 1) * 2 + 1], meshVerts[(i2 - 1) * 2 + 2])
            local x3, y3 = body:getWorldPoint(meshVerts[(i3 - 1) * 2 + 1], meshVerts[(i3 - 1) * 2 + 2])
            love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
        end
    end

    -- Steiner points themselves — solid orange dot with a dark border so
    -- they pop against any body color.
    local dotR = 5 / cam:getScale()
    for i = 1, #thing.extraSteiner, 2 do
        local wx, wy = body:getWorldPoint(thing.extraSteiner[i], thing.extraSteiner[i + 1])
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle('fill', wx, wy, dotR * 1.4)
        love.graphics.setColor(1, 0.55, 0.1, 1)
        love.graphics.circle('fill', wx, wy, dotR)
    end

    -- Brush cursor in PLACE_STEINER mode so the user knows they're hot.
    if modes.is(modes.PLACE_STEINER) then
        local mx, my = love.mouse.getPosition()
        local wx, wy = cam:getWorldCoordinates(mx, my)
        love.graphics.setColor(1, 0.55, 0.1, 0.4)
        love.graphics.circle('line', wx, wy, dotR * 1.6)
    end

    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1, 1)
end

return lib
