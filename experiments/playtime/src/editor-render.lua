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

        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < 10 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('fill', vx, vy, 13)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', vx, vy, 11)
            else
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('line', vx, vy, 12)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', vx, vy, 10)
            end

            love.graphics.setColor(0, 0, 0)
            love.graphics.print(math.ceil(i / 2), vx, vy)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(math.ceil(i / 2), vx - 2, vy - 2)
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
        -- logger:inspect(fixtureUD)
        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < 10 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('fill', vx, vy, 13)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', vx, vy, 11)
            else
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle('line', vx, vy, 12)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', vx, vy, 10)

                if (isMeta8) then
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print(math.ceil(i / 2), vx, vy)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(math.ceil(i / 2), vx - 2, vy - 2)
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

    -- VERTEX SELECTION VISUALIZATION
    if modes.is(modes.EDIT_MESH_VERTS) and state.selection.selectedSFixture then
        local ud = state.selection.selectedSFixture:getUserData()
        if ud and subtypes.is(ud, subtypes.MESHUSERT) and ud.label then
            -- Find the resource fixture with matching label
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
                local mb = mappert:getBody()
                local meshData = mb:getUserData()
                local verts = meshData.thing.vertices

                -- Get vertices in world space
                local body = state.selection.selectedSFixture:getBody()

                -- IMPORTANT: Must match the logic in playtime-ui.lua bind pose!
                -- 1. Center the vertices
                local polyCx, polyCy = mathutils.getCenterOfPoints(verts)
                local centeredVerts = mathutils.makePolygonRelativeToCenter(verts, polyCx, polyCy)
                --logger:inspect(state.vertexEditor)
                --
                --
                --

                if state.vertexEditor.selectedBone > 0 then
                    for i =1, #ud.extra.nodes do
                        local node = ud.extra.nodes[i]
                        if i == state.vertexEditor.selectedBone then

                            if node.type == NT.JOINT then
                                local j = registry.getJointByID(node.id)
                                local x1, y1 = j:getAnchors( )

                                love.graphics.circle('line', x1, y1, 10)

                            end
                            if node.type == NT.ANCHOR then
                                local a = registry.getSFixtureByID(node.id)
                                local anchorBody = a:getBody()
                                local nx, ny = mathutils.getCenterOfPoints(
                                    { anchorBody:getWorldPoints(a:getShape():getPoints()) })
                                love.graphics.circle('line', nx, ny, 10)
                            end
                        end
                    end
                end


                for i = 1, #centeredVerts / 2 do
                    local lx, ly = centeredVerts[i * 2 - 1], centeredVerts[i * 2]

                    -- Apply mesh transforms
                    if ud.extra.meshX or ud.extra.meshY then
                        lx = lx + (ud.extra.meshX or 0)
                        ly = ly + (ud.extra.meshY or 0)
                    end
                    if ud.extra.scaleX or ud.extra.scaleY then
                        lx = lx * (ud.extra.scaleX or 1)
                        ly = ly * (ud.extra.scaleY or 1)
                    end

                    local wx, wy = body:getWorldPoint(lx, ly)



                    -- for i = 1, #ud.extra.nodes do
                    --     local node = ud.extra.nodes[i]
                    --     local isSelected = (state.vertexEditor.selectedBone == i)
                    --     local nodeLabel = 'Node ' .. i .. ' (' .. (node.type or '?') .. ')'
                    --     local nodeColor = isSelected and { 0.3, 0.6, 1.0 } or nil

                    --     if ui.button(x, y, ROW_WIDTH + 50, nodeLabel, BUTTON_HEIGHT, nodeColor) then
                    --         state.vertexEditor.selectedBone = i



                    -- i owuld like to render lines from the vertex to the nodes where it got it weight from

              --

                   --if state.vertexEditor.selectedVertices then
                   local lineweight = love.graphics.getLineWidth()
                   love.graphics.setColor(1,1,1,0.5)
                   love.graphics.setLineWidth(1)
                        for _, node in ipairs(ud.extra.nodes) do

                            if node.type == NT.JOINT then
                                local j = registry.getJointByID(node.id)
                                local x1, y1 = j:getAnchors( )

                                love.graphics.line(wx, wy, x1, y1)

                            end
                            if node.type == NT.ANCHOR then
                                 local a = registry.getSFixtureByID(node.id)
                                 local anchorBody = a:getBody()
                                  local nx, ny = mathutils.getCenterOfPoints(
                                      { anchorBody:getWorldPoints(a:getShape():getPoints()) })
                                 love.graphics.line(wx, wy, nx, ny)
                            end
                        end
                         love.graphics.setLineWidth(lineweight)
                           love.graphics.setColor(1,1,1,1)
                        --end
                    -- Check if this vertex is selected
                    local isSelected = false
                    for _, idx in ipairs(state.vertexEditor.selectedVertices) do
                        if idx == i then
                            isSelected = true
                            break
                        end
                    end

                    -- Draw vertex
                    if isSelected then
                        love.graphics.setColor(1, 0.8, 0)  -- Orange for selected
                        love.graphics.circle('fill', wx, wy, 6)
                        love.graphics.setColor(0, 0, 0)
                        love.graphics.circle('line', wx, wy, 7)
                    else
                        love.graphics.setColor(0.5, 0.5, 1)  -- Blue for unselected
                        love.graphics.circle('fill', wx, wy, 4)
                        love.graphics.setColor(0, 0, 0)
                        love.graphics.circle('line', wx, wy, 5)
                    end

                    -- Draw vertex index
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(tostring(i), wx + 8, wy - 6)
                end

                -- Draw brush radius at mouse cursor
                local mx, my = love.mouse.getPosition()
                local cx, cy = cam:getWorldCoordinates(mx, my)
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.circle('line', cx, cy, tonumber(state.vertexEditor.brushSize) or 20)
            end
        end
    end

    love.graphics.setColor(1, 1, 1)  -- Reset color
end

return lib
