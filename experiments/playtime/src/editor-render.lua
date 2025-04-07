-- here we just have snall functions that render thigns for the editor (not ui but active state, selction boxes that sot of thing)
--
local state = require 'src.state'
local fixtures = require 'src.fixtures'
local box2dDraw = require 'src.box2d-draw'
local shapes = require 'src.shapes'
local mathutils = require 'src.math-utils'
local camera = require 'src.camera'
local cam = camera.getInstance()
local utils = require 'src.utils'

local lib = {}


function lib.drawGrid()
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, .1)

    local w, h = love.graphics.getDimensions()
    local tlx, tly = cam:getWorldCoordinates(0, 0)
    local brx, bry = cam:getWorldCoordinates(w, h)
    local step = state.world.meter
    local startX = math.floor(tlx / step) * step
    local endX = math.ceil(brx / step) * step
    local startY = math.floor(tly / step) * step
    local endY = math.ceil(bry / step) * step

    for i = startX, endX, step do
        local x, _ = cam:getScreenCoordinates(i, 0)
        love.graphics.line(x, 0, x, h)
    end
    for i = startY, endY, step do
        local _, y = cam:getScreenCoordinates(0, i)
        love.graphics.line(0, y, w, y)
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

    if state.selection.selectedJoint and not state.selection.selectedJoint:isDestroyed() then
        box2dDraw.drawJointAnchors(state.selection.selectedJoint)
    end

    local lw = love.graphics.getLineWidth()
    for i, v in ipairs(state.world.softbodies) do
        love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255, .8)
        if (tostring(v) == "softbody") then
            love.graphics.setColor(50 * i / 255, 100 / 255, 200 * i / 255, .8)
            --v:draw("fill", false)
            love.graphics.setColor(50 * i / 255, 255 / 255, 200 * i / 255, .8)
            local polygon = v:getPoly()
            local tris = shapes.makeTrianglesFromPolygon(polygon)
            for i = 1, #tris do
                love.graphics.polygon('fill', tris[i])
            end
        else
            --v:draw(false)
            local polygon = v:getPoly()
            local tris = shapes.makeTrianglesFromPolygon(polygon)
            for i = 1, #tris do
                love.graphics.polygon('fill', tris[i])
            end
        end
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)

    -- draw to be drawn polygon
    if state.currentMode == 'drawClickMode' or state.currentMode == 'drawFreePoly' then
        if (#state.interaction.polyVerts >= 6) then
            love.graphics.polygon('line', state.interaction.polyVerts)
        end
    end

    -- draw mousehandlers for dragging vertices
    if state.polyEdit.tempVerts and state.selection.selectedObj and state.selection.selectedObj.shapeType == 'custom' and state.polyEdit.lockedVerts == false then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)

        local mx, my = love.mouse:getPosition()
        local cx, cy = cam:getWorldCoordinates(mx, my)

        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < 10 then
                love.graphics.circle('fill', vx, vy, 10)
            else
                love.graphics.circle('line', vx, vy, 10)
            end
        end
    end


    if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture and state.texFixtureEdit.lockedVerts == false then
        local thing = state.selection.selectedSFixture:getBody():getUserData().thing
        local verts = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
            thing, 0, 0)
        --print(inspect(verts))
        local mx, my = love.mouse:getPosition()
        local cx, cy = cam:getWorldCoordinates(mx, my)

        for i = 1, #verts, 2 do
            local vx = verts[i]
            local vy = verts[i + 1]
            local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
            if dist < 10 then
                love.graphics.circle('fill', vx, vy, 10)
            else
                love.graphics.circle('line', vx, vy, 10)
            end
        end
    end

    -- Highlight selected bodies
    if state.selection.selectedBodies then
        local bodies = utils.map(state.selection.selectedBodies, function(thing)
            return thing.body
        end)
        box2dDraw.drawBodies(bodies)
    end

    -- draw temp poly when changing vertices
    if state.polyEdit.tempVerts and state.selection.selectedObj then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
        love.graphics.setColor(1, 0, 0)
        love.graphics.polygon('line', verts)
        love.graphics.setColor(1, 1, 1) -- Rese
    end
end

return lib
