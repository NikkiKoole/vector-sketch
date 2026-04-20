--box2d-draw.lua

local lib = {}

local state = require 'src.state'
local JT = require 'src.joint-types'
local BT = require('src.body-types')
local cdt = require 'src.cdt'
local mathutils = require 'src.math-utils'
local shapes = require 'src.shapes'
local pal = {
    ['orange']  = { 242 / 255, 133 / 255, 0 },         --#F28500  tangerine orange
    ['sun']     = { 253 / 255, 215 / 255, 4 / 255 },   --#FFD700  sunshine yellow
    ['rust']    = { 183 / 255, 64 / 255, 13 / 255 },   --#b7410e  rust otange
    ['avocado'] = { 106 / 255, 144 / 255, 32 / 255 },  --#568203  avocado graan
    ['gold']    = { 219 / 255, 145 / 255, 0 },         --#da9100  harvest gold
    ['lime']    = { 69 / 255, 205 / 255, 50 / 255 },   --#32CD32  lime green
    ['creamy']  = { 245 / 255, 245 / 255, 220 / 255 }, --#F5F5DC Creamy White:
    ['dark']    = { 50 / 255, 30 / 255, 30 / 255 },    -- dark
    ['choco']   = { 123 / 255, 64 / 255, 0 },          --#7B3F00 Chocolate Brown:
    ['beige']   = { 244 / 255, 164 / 255, 97 / 255 },  --#F4A460 Sand Beige:
    ['red']     = { 217 / 255, 73 / 255, 56 / 255 },   --#D94A38 Adobe Red:
}

local function getBodyColor(body)
    if body:getType() == BT.KINEMATIC then
        return pal.red
    end
    if body:getType() == BT.DYNAMIC then
        return pal.lime
    end
    if body:getType() == BT.STATIC then
        return pal.sun
    end
end

local function getEndpoint(x, y, angle, length)
    local endX = x + length * math.cos(angle)
    local endY = y + length * math.sin(angle)
    return endX, endY
end

-- Custom-body fill-draw that respects thing.extraSteiner. Replaces the
-- per-Box2D-fixture polygon fill for CUSTOM bodies. Two wins:
--   1. Fan artifact gone — one polygon outline instead of per-triangle outlines.
--   2. Authored Steiners actually show up in the mesh (if any).
-- Caches the triangulation on thing._fillCache, keyed by counts so
-- polygon-edit or Steiner-add invalidates naturally. Love2D polygon('fill')
-- is used per triangle (same pattern as fixtures today); seam anti-aliasing
-- is usually invisible when all triangles share the fill color.
local function drawCustomBodyFill(body, thing, fillColor, alpha, drawOutline)
    local verts = thing and thing.vertices
    if not verts or #verts < 6 then return false end

    local extraSteiner = thing.extraSteiner
    local cacheKey = tostring(#verts) .. ':' .. tostring(extraSteiner and #extraSteiner or 0)
    local cache = thing._fillCache
    if not cache or cache.key ~= cacheKey then
        local cenX, cenY = mathutils.computeCentroid(verts)
        local localPoly = {}
        for i = 1, #verts, 2 do
            localPoly[i] = verts[i] - cenX
            localPoly[i + 1] = verts[i + 1] - cenY
        end
        local meshVerts, triIdx
        if extraSteiner and #extraSteiner >= 2 then
            meshVerts, triIdx = cdt.triangulatePolyWithSteiner(localPoly, nil, extraSteiner)
        end
        if not triIdx or #triIdx == 0 then
            -- No Steiners, or CDT declined: fall back to ear-clip
            -- indexed triangulation (same output as makeTrianglesFromPolygon
            -- uses, just as indices we can iterate).
            meshVerts = localPoly
            triIdx = mathutils.triangulateToIndices and
                mathutils.triangulateToIndices(localPoly) or nil
        end
        cache = { key = cacheKey, verts = meshVerts, tris = triIdx, cenX = cenX, cenY = cenY }
        thing._fillCache = cache
    end

    if not cache.tris or #cache.tris < 3 then return false end

    -- Fill
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], alpha)
    local mv = cache.verts
    for t = 1, #cache.tris - 2, 3 do
        local i1, i2, i3 = cache.tris[t], cache.tris[t + 1], cache.tris[t + 2]
        local x1, y1 = body:getWorldPoint(mv[(i1 - 1) * 2 + 1], mv[(i1 - 1) * 2 + 2])
        local x2, y2 = body:getWorldPoint(mv[(i2 - 1) * 2 + 1], mv[(i2 - 1) * 2 + 2])
        local x3, y3 = body:getWorldPoint(mv[(i3 - 1) * 2 + 1], mv[(i3 - 1) * 2 + 2])
        love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
    end

    -- Single outline from thing.vertices (not per triangle) — the fan-killer.
    if drawOutline then
        local outlineColor = state.world.darkMode and pal.creamy or pal.dark
        love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], alpha)
        local worldOutline = {}
        for i = 1, #verts, 2 do
            local wx, wy = body:getWorldPoint(verts[i] - cache.cenX, verts[i + 1] - cache.cenY)
            worldOutline[#worldOutline + 1] = wx
            worldOutline[#worldOutline + 1] = wy
        end
        love.graphics.polygon('line', worldOutline)
    end

    return true
end



function lib.drawWorld(world, drawOutline)
    local debugIds = {}
    if drawOutline == nil then drawOutline = true end
    if drawOutline == true then
        if state.world.drawOutline == false then
            drawOutline = false
        end
    end
    local r, g, b, a = love.graphics.getColor()
    local alpha = .8 * state.world.debugAlpha
    love.graphics.setLineJoin("none")
    love.graphics.setColor(0, 0, 0, alpha)
    local bodies = world:getBodies()
    local DRAW_BODIES = state.world.debugDrawBodies


    if DRAW_BODIES then
        for _, body in ipairs(bodies) do
            local bodyUD = body:getUserData()
            local bodyThing = bodyUD and bodyUD.thing
            -- CUSTOM bodies get a single unified fill+outline pass that honors
            -- thing.extraSteiner (Phase 3 of STEINER-OWNERSHIP-PLAN.md). Kills
            -- the fan outline artifact from the per-fixture draw below.
            local customHandled = false
            if bodyThing and bodyThing.shapeType == 'custom' then
                customHandled = drawCustomBodyFill(body, bodyThing, getBodyColor(body), alpha, drawOutline)
            end

            local fixtures = body:getFixtures()

            for _, fixture in ipairs(fixtures) do
                --if fixture:getUserData() then
                --     print(inspect(fixture:getUserData()))
                --end
                if fixture:getShape():type() == 'PolygonShape' then
                    local fillColor = getBodyColor(body)
                    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], alpha)
                    local hasSpecialFixtureData = fixture:getUserData() and
                        (fixture:getUserData().bodyType == "connector" or fixture:getUserData().type)
                    -- Skip default per-fixture polygon fill/outline when the CUSTOM
                    -- override already drew the body. Special fixtures (connector /
                    -- typed) keep their per-fixture pass so their distinct color
                    -- overlays the body fill as before.
                    if customHandled and not hasSpecialFixtureData then
                        goto polyEnd
                    end
                    if (fixture:getUserData()) then
                        if fixture:getUserData().bodyType == "connector" then
                            love.graphics.setColor(1, 0, 0, alpha)
                        end
                        if fixture:getUserData().type then
                            local typeColor = pal.orange
                            love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha)
                        end
                        --else
                        if state.world.drawFixtures then
                            love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                        end
                    else
                        love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
                    end


                    local outlineColor = state.world.darkMode and pal.creamy or pal.dark
                    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], alpha)
                    if (fixture:getUserData()) then
                        if fixture:getUserData().bodyType == "connector" then
                            love.graphics.setColor(1, 0, 0, alpha)
                        end
                        --  print(inspect(fixture:getUserData() ))
                    end
                    if drawOutline then
                        love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints()))
                    end
                    ::polyEnd::
                elseif fixture:getShape():type() == 'EdgeShape' or fixture:getShape():type() == 'ChainShape' then
                    love.graphics.setColor(0, 1, 1, alpha)
                    local points = { body:getWorldPoints(fixture:getShape():getPoints()) }
                    for i = 1, #points, 2 do
                        if i < #points - 2 then
                            love.graphics.line(points[i], points[i + 1], points[i + 2], points
                                [i + 3])
                        end
                    end
                elseif fixture:getShape():type() == 'CircleShape' then
                    local body_x, body_y = body:getPosition()
                    local shape_x, shape_y = fixture:getShape():getPoint()
                    local radius = fixture:getShape():getRadius()
                    local circleFillColor = getBodyColor(body)
                    local segments = 180
                    love.graphics.setColor(circleFillColor[1], circleFillColor[2], circleFillColor[3], alpha)
                    love.graphics.circle('fill', body_x + shape_x, body_y + shape_y, radius, segments)

                    local circleOutlineColor = pal.creamy
                    love.graphics.setColor(circleOutlineColor[1], circleOutlineColor[2], circleOutlineColor[3], alpha)
                    if drawOutline then
                        love.graphics.circle('line', body_x + shape_x, body_y + shape_y, radius, segments)
                    end
                end
                if state.world.showDebugIds then
                    local ud = fixture:getUserData()
                    if ud and ud.id then
                        local x1, y1 = body:getPosition()
                        if debugIds[ud.id] == true then
                            print('id already drawn in this loop', ud.id)
                        end
                        debugIds[ud.id] = true
                        love.graphics.print(ud.id, x1, y1)
                    end
                end
            end
        end
    end
    love.graphics.setColor(255, 255, 255, alpha)
    -- Joint debug

    local joints = world:getJoints()
    local DRAW_JOINTS = state.world.debugDrawJoints
    if DRAW_JOINTS then
        for _, joint in ipairs(joints) do
            local x1, y1, x2, y2 = joint:getAnchors()

            if (x1 and y1 and x2 and y2) then
                local color = pal.creamy
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.line(x1, y1, x2, y2)
            end
            local color = pal.orange
            love.graphics.setColor(color[1], color[2], color[3], alpha)

            love.graphics.setLineJoin("miter")
            if x1 and y1 then love.graphics.circle('line', x1, y1, 4) end
            if x2 and y2 then love.graphics.circle('line', x2, y2, 4) end
            love.graphics.setLineJoin("none")

            local jointType = joint:getType()
            if jointType == JT.PULLEY then
                local gx1, gy1, gx2, gy2 = joint:getGroundAnchors()
                love.graphics.setColor(1, 1, 0, alpha)
                love.graphics.line(x1, y1, gx1, gy1)
                love.graphics.line(x2, y2, gx2, gy2)
                love.graphics.line(gx1, gy1, gx2, gy2)
            end
            if jointType == JT.PRISMATIC then
                local x, y = joint:getAnchors()
                local ax, ay = joint:getAxis()
                local length = 50
                love.graphics.setColor(1, 0.5, 0) -- Orange
                love.graphics.line(x, y, x + ax * length, y + ay * length)
                if joint:areLimitsEnabled() then
                    local lower, upper = joint:getLimits()
                    love.graphics.setColor(1, 1, 0) -- Yellow
                    love.graphics.line(x + ax * lower, y + ay * lower,
                        x + ax * lower + ax * 10, y + ay * lower + ay * 10)
                    love.graphics.line(x + ax * upper, y + ay * upper,
                        x + ax * upper + ax * 10, y + ay * upper + ay * 10)
                end
                love.graphics.setColor(1, 1, 1) -- Reset
            end
            if jointType == JT.REVOLUTE and joint:areLimitsEnabled() then
                local lower = joint:getLowerLimit()
                local upper = joint:getUpperLimit()
                local referenceAngle = joint:getReferenceAngle()

                local bodyA, bodyB = joint:getBodies()
                local angleA = bodyA:getAngle()
                local angleB = bodyB:getAngle()

                -- Use the joint's reference frame to compute world-space zero angle
                local zeroAngle = angleA + referenceAngle

                local startAngle = zeroAngle + lower
                local endAngle = zeroAngle + upper
                if endAngle < startAngle then
                    endAngle = endAngle + 2 * math.pi
                end

                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.setLineJoin("miter")
                love.graphics.arc('line', x1, y1, 15, startAngle, endAngle)
                love.graphics.setLineJoin("none")

                -- draw current angle of bodyB relative to bodyA (via reference frame)
                local currentRelative = angleB - zeroAngle
                local dirAngle = zeroAngle + currentRelative
                local endX, endY = getEndpoint(x1, y1, dirAngle, 15)
                love.graphics.setColor(0.5, 0.5, 0.5, alpha)
                love.graphics.line(x1, y1, endX, endY)
            end
            if jointType == JT.WHEEL then
                -- Draw wheel joint axis
                local axisX, axisY = joint:getAxis()
                if x1 and y1 and axisX and axisY then
                    local axisLength = 50                   -- Scale factor for visualizing the axis
                    love.graphics.setColor(0, .5, 0, alpha) -- Green for axis
                    love.graphics.line(x1, y1, x1 + axisX * axisLength, y1 + axisY * axisLength)
                    love.graphics.setColor(1, 1, 1, alpha)
                end
            end
            if state.world.showDebugIds then
                local ud = joint:getUserData()

                if ud and ud.id then
                    love.graphics.print(ud.id, x1, y1)
                    if debugIds[ud.id] == true then
                        print('id already drawn in this loop', ud.id)
                    end
                    debugIds[ud.id] = true
                end
            end
        end
    end
    love.graphics.setLineJoin("miter")
    love.graphics.setColor(r, g, b, a)
    --   love.graphics.setLineWidth(1)
end

function lib.drawJointAnchors(joint)
    local color = pal.creamy
    love.graphics.setColor(color[1], color[2], color[3], 1)
    local x1, y1, x2, y2 = joint:getAnchors()
    love.graphics.circle('line', x1, y1, 10)
    love.graphics.line(x2 - 10, y2, x2 + 10, y2)
    love.graphics.line(x2, y2 - 10, x2, y2 + 10)
end

function lib.drawBodies(bodies)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(6)
    love.graphics.setColor(1, 0, 1) -- Red outline for selection
    for i = 1, #bodies do
        --for _, thing in ipairs(state.selection.selectedBodies) do
        --local fixtures = body:getFixtures()
        local body = bodies[i]
        for _, fixture in ipairs(body:getFixtures()) do
            --for fixture in pairs(fixtures) do
            local shape = fixture:getShape()
            love.graphics.push()
            love.graphics.translate(body:getX(), body:getY())
            love.graphics.rotate(body:getAngle())
            if shape:typeOf("CircleShape") then
                love.graphics.circle("line", 0, 0, shape:getRadius())
            elseif shape:typeOf("PolygonShape") then
                local points = { shape:getPoints() }
                love.graphics.polygon("line", points)
            elseif shape:typeOf("EdgeShape") then
                local x1, y1, x2, y2 = shape:getPoints()
                love.graphics.line(x1, y1, x2, y2)
            end
            love.graphics.pop()
        end
    end
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1) -- Reset color
end

return lib
