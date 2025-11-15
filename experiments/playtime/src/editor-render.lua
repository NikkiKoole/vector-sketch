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


function lib.drawGrid(color)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1)
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

    if state.selection.selectedSFixture then
        local ud = state.selection.selectedSFixture:getUserData()
        if false and ud.subtype == 'uvmappert' then
            -- print('jojo!')
            local bod = state.selection.selectedSFixture:getBody()
            local bud = bod:getUserData()
            --print(bud.thing.body, bod)
            love.graphics.polygon('line', bud.thing.vertices)
            local b = state.backdrops[ud.extra.selectedBGIndex]
            local x1l, y1l = bod:getLocalPoint(b.x, b.y)
            local x2l, y2l = bod:getLocalPoint(b.x + b.w, b.y + b.h)
            love.graphics.rectangle('line', x1l, y1l, x2l - x1l, y2l - y1l)
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
        -- print(inspect(v))
        if v.centerBody and not v.centerBody:isDestroyed() then
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
    if state.currentMode == 'drawClickMode' or state.currentMode == 'drawFreePoly' or state.currentMode == 'drawFreePath' then
        --print(#state.interaction.polyVerts)
        if (#state.interaction.polyVerts >= 6) then
            love.graphics.polygon('line', state.interaction.polyVerts)
        end
    end


    -- draw mousehandlers for dragging vertices
    local rightShape = state.selection.selectedObj and
        (state.selection.selectedObj.shapeType == 'custom' or state.selection.selectedObj.shapeType == 'ribbon')
    if state.polyEdit.tempVerts and rightShape and state.polyEdit.lockedVerts == false then
        --print(state.polyEdit.centroid.x)
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


    if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture and state.texFixtureEdit.lockedVerts == false then
        local thing     = state.selection.selectedSFixture:getBody():getUserData().thing

        local fixtureUD = state.selection.selectedSFixture:getUserData()
        local isMeta8   = fixtureUD.label == 'meta8'
        local verts     = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
            thing, 0, 0)
        --print(inspect(verts))
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

            function roundArray(values)
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
