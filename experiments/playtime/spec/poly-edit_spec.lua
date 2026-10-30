-- spec/poly-edit_spec.lua
-- The polygon tools (src/poly-edit.lua, moved out of object-manager in CL22): draw a
-- polygon, then add and remove vertices the way the editor does.
-- Run with: love . --specs spec/poly-edit_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mathutils = require('src.math-utils')
local utils = require('src.utils')
local polyEdit = require('src.poly-edit')

describe('poly-edit', function()
    local thing

    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        registry.reset()
        state.interaction.polyVerts = { 0, 0, 100, 0, 100, 100, 0, 100 }
        thing = polyEdit.finalizePolygon()
        -- what the body panel does when you start editing vertices
        state.selection.selectedObj = thing
        state.polyEdit.tempVerts = utils.shallowCopy(thing.vertices)
        local cx, cy = mathutils.computeCentroid(thing.vertices)
        state.polyEdit.centroid = { x = cx, y = cy }
    end)

    after_each(function()
        state.selection.selectedObj = nil
        state.polyEdit.tempVerts = nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    -- world point of polygon vertex i
    local function vertexWorld(i)
        local v = state.polyEdit.tempVerts
        local c = state.polyEdit.centroid
        return thing.body:getWorldPoint(v[(i - 1) * 2 + 1] - c.x, v[(i - 1) * 2 + 2] - c.y)
    end

    it('draws a custom polygon from the clicked points', function()
        assert.is_not_nil(thing)
        assert.are.equal('custom', thing.shapeType)
        assert.are.equal(8, #thing.vertices)
        assert.are.same({}, state.interaction.polyVerts)
    end)

    it('adds a vertex on the nearest edge, removes one clicked on', function()
        local ax, ay = vertexWorld(1)
        local bx, by = vertexWorld(2)
        polyEdit.insertCustomPolygonVertex((ax + bx) / 2, (ay + by) / 2)
        polyEdit.maybeUpdateCustomPolygonVertices()
        thing = state.selection.selectedObj
        assert.are.equal(10, #thing.vertices)

        -- the editor takes the nearest edge and checks the vertex it starts at: click
        -- just past vertex 2, on its own edge
        local x2, y2 = vertexWorld(2)
        local x3, y3 = vertexWorld(3)
        local len = math.sqrt((x3 - x2) ^ 2 + (y3 - y2) ^ 2)
        polyEdit.removeCustomPolygonVertex(x2 + (x3 - x2) / len, y2 + (y3 - y2) / len)
        thing = state.selection.selectedObj
        assert.are.equal(8, #thing.vertices)
    end)

    it('keeps a vertex when the click is too far from it, and never goes under three', function()
        local x, y = vertexWorld(1)
        polyEdit.removeCustomPolygonVertex(x + 40, y + 40)
        assert.are.equal(8, #state.polyEdit.tempVerts)

        state.polyEdit.tempVerts = { 0, 0, 50, 0, 0, 50 }
        x, y = vertexWorld(1)
        polyEdit.removeCustomPolygonVertex(x, y)
        assert.are.equal(6, #state.polyEdit.tempVerts)
    end)
end)
