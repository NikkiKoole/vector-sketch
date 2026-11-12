--box2d-draw.lua

local lib = {}

local state = require('src.state')
local JT = require('src.joint-types')
local BT = require('src.body-types')
local cdt = require('src.cdt')
local mathutils = require('src.math-utils')
local subtypes = require('src.subtypes')
local NT = require('src.node-types')
local registry = require('src.registry')
local walls = require('src.walls')
local view = require('src.render.view')
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

-- in play mode a body without a picture is a plain grey shape: no type colours, outlines or sfixtures
-- (Nikki 2026-11-12: "when playing ... grey boxes without outlines")
local PLAY_GREY = { 0.62, 0.62, 0.6 }

local function getBodyColor(body)
    if state.playMode == true then return PLAY_GREY end
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
-- per-Box2D-fixture polygon fill for CUSTOM bodies. Wins:
--   1. Fan artifact gone — one polygon outline instead of per-triangle outlines.
--   2. Authored Steiners actually show up in the mesh (if any).
--   3. Inner triangulation edges drawn faintly when the body is selected,
--      so the author can see what they're shaping.
-- No cross-frame cache. Detecting "did the polygon actually change" cheaply
-- is fiddly (count-based keys miss vertex-drags); per-frame compute is
-- cheap enough for typical bodies. Revisit if profiling disagrees.
local function drawCustomBodyFill(body, thing, fillColor, alpha, drawOutline)
    local verts = thing and thing.vertices
    if not verts or #verts < 6 then return false end

    local extraSteiner = thing.extraSteiner
    local localPoly, cenX, cenY = mathutils.makePolygonRelativeToCenter(verts, mathutils.computeCentroid(verts))

    -- Match the MESHUSERT's triangulation so body fill and deformed render
    -- agree. With Steiners → outline + user points; without → ear-clip.
    local hasSteiner = extraSteiner and #extraSteiner >= 2
    local meshVerts, triIdx
    if hasSteiner then
        meshVerts, triIdx = cdt.triangulatePolyWithSteiner(localPoly, extraSteiner)
    end
    if not triIdx or #triIdx == 0 then
        meshVerts = localPoly
        triIdx = mathutils.triangulateToIndices and
            mathutils.triangulateToIndices(localPoly) or nil
    end
    if not triIdx or #triIdx < 3 then return false end

    -- Fill pass.
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], alpha)
    for t = 1, #triIdx - 2, 3 do
        local i1, i2, i3 = triIdx[t], triIdx[t + 1], triIdx[t + 2]
        local x1, y1 = body:getWorldPoint(meshVerts[(i1 - 1) * 2 + 1], meshVerts[(i1 - 1) * 2 + 2])
        local x2, y2 = body:getWorldPoint(meshVerts[(i2 - 1) * 2 + 1], meshVerts[(i2 - 1) * 2 + 2])
        local x3, y3 = body:getWorldPoint(meshVerts[(i3 - 1) * 2 + 1], meshVerts[(i3 - 1) * 2 + 2])
        love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
    end

    -- Inner triangulation edges when body is selected — same stroke style
    -- as the outer outline so the whole mesh reads as one coherent shape.
    local isSelected = state.selection.selectedObj == thing
    local outlineColor = state.world.darkMode and pal.creamy or pal.dark
    if isSelected then
        love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], alpha)
        for t = 1, #triIdx - 2, 3 do
            local i1, i2, i3 = triIdx[t], triIdx[t + 1], triIdx[t + 2]
            local x1, y1 = body:getWorldPoint(meshVerts[(i1 - 1) * 2 + 1], meshVerts[(i1 - 1) * 2 + 2])
            local x2, y2 = body:getWorldPoint(meshVerts[(i2 - 1) * 2 + 1], meshVerts[(i2 - 1) * 2 + 2])
            local x3, y3 = body:getWorldPoint(meshVerts[(i3 - 1) * 2 + 1], meshVerts[(i3 - 1) * 2 + 2])
            love.graphics.polygon('line', x1, y1, x2, y2, x3, y3)
        end
    end

    -- Outer polygon outline — single stroke, replaces the per-fixture outlines.
    if drawOutline then
        love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], alpha)
        local worldOutline = {}
        for i = 1, #verts, 2 do
            local wx, wy = body:getWorldPoint(verts[i] - cenX, verts[i + 1] - cenY)
            worldOutline[#worldOutline + 1] = wx
            worldOutline[#worldOutline + 1] = wy
        end
        love.graphics.polygon('line', worldOutline)
    end

    return true
end

-- sfixture kinds that draw a texture over their own body (src/physics/box2d-draw-textured.lua);
-- a connected-texture is a ribbon between joints, so it doesn't count
local texturedKinds = {}
for _, kind in ipairs({ subtypes.TEXFIXTURE, subtypes.MESHUSERT, subtypes.UVUSERT, subtypes.TILE_REPEAT,
    subtypes.DECAL, subtypes.TRACE_VERTICES, subtypes.WALL }) do -- a wall: src/walls.lua draws it
    texturedKinds[kind] = true
end

-- lib.cull = false draws every body (spec/draw-cache_spec.lua compares); OUTLINE_PAD: the outline's
-- width and the debug ids printed next to a body
lib.cull = true
local OUTLINE_PAD = 100

-- Remembered per body until an sfixture comes or goes (it depends only on which sfixtures a
-- body has): asked for every body every frame, getFixtures made a new table and a userdata per
-- fixture each time; drawWorld was 0.83 ms a frame with 20 Mipos on an iPhone SE 2 drawing
-- nearly nothing (2026-10-31).
local texturedCache = { version = nil, of = nil }
function lib.hasTexture(body)
    if texturedCache.version ~= registry.sfixtureVersion then
        texturedCache.version, texturedCache.of = registry.sfixtureVersion, setmetatable({}, { __mode = 'k' })
    end
    local known = texturedCache.of[body]
    if known ~= nil then return known end
    known = false
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        if type(ud) == 'table' and texturedKinds[ud.subtype] then known = true; break end
    end
    texturedCache.of[body] = known
    return known
end

local function hasURL(extra)
    return extra and extra.main and extra.main.bgURL and extra.main.bgURL ~= ''
end

-- Bodies covered by a picture that isn't their own texfixture: a limb's segments under
-- a textured connected-texture (the bodies two joints in a row share, so not the torso
-- the first joint hangs off) and a textured blob's body and rim circles. Kept until an sfixture
-- comes or goes (registry.sfixtureVersion), and at most 30 calls (a picture cleared in the editor
-- changes no sfixture): built every frame it was a walk over all sfixtures.
local coveredCache = { version = nil, covered = nil, calls = 0 }
function lib.coveredBodies()
    coveredCache.calls = coveredCache.calls + 1
    if coveredCache.version == registry.sfixtureVersion and coveredCache.calls < 30 then
        local covered = coveredCache.covered
        for rim, rt in pairs(state.blobRims or {}) do -- rims are rebuilt as the blob goes
            if covered[rt.body] then covered[rim] = true end
        end
        return covered
    end
    local covered = setmetatable({}, { __mode = 'k' })
    coveredCache.version, coveredCache.covered, coveredCache.calls = registry.sfixtureVersion, covered, 0
    for _, f in pairs(registry.sfixtures) do
        local ud = not f:isDestroyed() and f:getUserData()
        if ud and subtypes.is(ud, subtypes.CONNECTED_TEXTURE) and hasURL(ud.extra) and ud.extra.nodes then
            local prev
            for _, node in ipairs(ud.extra.nodes) do
                local bodies = {}
                if node.type == NT.JOINT then
                    local joint = registry.getJointByID(node.id)
                    if joint and not joint:isDestroyed() then
                        local a, b = joint:getBodies()
                        bodies[a], bodies[b] = true, true
                    end
                elseif node.type == NT.ANCHOR then
                    local anchor = registry.getSFixtureByID(node.id)
                    if anchor and not anchor:isDestroyed() then bodies[anchor:getBody()] = true end
                end
                for b in pairs(bodies) do
                    if prev and prev[b] then covered[b] = true end
                end
                prev = bodies
            end
        elseif ud and subtypes.is(ud, subtypes.SOFTBODY) and hasURL(ud.extra) then
            covered[f:getBody()] = true
        end
    end
    for rim, rt in pairs(state.blobRims or {}) do
        if covered[rt.body] then covered[rim] = true end
    end
    return covered
end

-- In the 'tex/body' view: does this body still draw as a body? Untextured ones
-- do; textured (or covered, see coveredBodies) ones don't, except Mipo parts while
-- 'mipo body' is on.
-- A Mipo's torso lobes (src/torso-lobes.lua) have no picture of their own: the torso's covers them.
local function isLobe(body)
    local ud = body:getUserData()
    local name = ud and ud.thing and ud.thing.mipoPartName
    return name ~= nil and name:match('^lobe%d$') ~= nil
end

function lib.showsBody(body, covered)
    if not lib.hasTexture(body) and not (covered and covered[body]) and not isLobe(body) then return true end
    if state.world.mipoBodies ~= true then return false end
    local ud = body:getUserData()
    return state.world.mipoBodies == true and ud ~= nil and ud.thing ~= nil and ud.thing.mipoId ~= nil
end

-- a fixture's id next to its body (showDebugIds); an id drawn twice in a frame is a broken scene
local function drawDebugId(debugIds, id, x, y)
    if debugIds[id] == true then print('id already drawn in this loop', id) end
    debugIds[id] = true
    love.graphics.print(id, x, y)
end

-- A polygon fixture: its fill (a connector red, a typed sfixture orange; an sfixture's only with the
-- 'sfixtures' setting, state.world.showSfixtures, off unless turned on; never in play mode) and its
-- outline. A CUSTOM body's fill already drew the plain ones (drawCustomBodyFill).
local function drawPolygonFixture(body, shape, ud, alpha, drawOutline, customHandled)
    local fillColor = getBodyColor(body)
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], alpha)
    local hasSpecialFixtureData = ud and (ud.bodyType == "connector" or ud.type)
    -- Skip default per-fixture polygon fill/outline when the CUSTOM override already drew the body.
    -- Special fixtures (connector / typed) keep their per-fixture pass so their distinct color overlays
    -- the body fill as before.
    if customHandled and not hasSpecialFixtureData then return end
    if ud and state.playMode == true then return end -- no sfixture or connector overlays in play
    if ud then
        if ud.bodyType == "connector" then love.graphics.setColor(1, 0, 0, alpha) end
        if ud.type then
            local typeColor = pal.orange
            love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], alpha)
        end
        if state.world.showSfixtures then
            love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
        end
    else
        love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
    end
    local outlineColor = state.world.darkMode and pal.creamy or pal.dark
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], alpha)
    if ud and ud.bodyType == "connector" then love.graphics.setColor(1, 0, 0, alpha) end
    -- an sfixture's outline only with the 'sfixture lines' setting (state.world.showSfixtureLines)
    if ud and ud.type and not state.world.showSfixtureLines then return end
    if drawOutline then love.graphics.polygon('line', body:getWorldPoints(shape:getPoints())) end
end

-- an edge or chain: its segments in cyan, as one line (a coaster track's chain has ~1000: a line call
-- each was 25 ms a frame, 2026-11-12)
local function drawEdgeFixture(body, shape, alpha)
    love.graphics.setColor(0, 1, 1, alpha)
    local points = { body:getWorldPoints(shape:getPoints()) }
    if #points >= 4 then love.graphics.line(points) end
end

local function drawCircleFixture(body, shape, alpha, drawOutline)
    local cx, cy = body:getWorldPoint(shape:getPoint()) -- an offset circle turns with its body
    local radius = shape:getRadius()
    local circleFillColor = getBodyColor(body)
    local segments = 180
    love.graphics.setColor(circleFillColor[1], circleFillColor[2], circleFillColor[3], alpha)
    love.graphics.circle('fill', cx, cy, radius, segments)
    local circleOutlineColor = pal.creamy
    love.graphics.setColor(circleOutlineColor[1], circleOutlineColor[2], circleOutlineColor[3], alpha)
    if drawOutline then love.graphics.circle('line', cx, cy, radius, segments) end
end

-- One body: CUSTOM bodies get a single unified fill+outline pass that honors thing.extraSteiner (Phase 3
-- of STEINER-OWNERSHIP-PLAN.md; it kills the fan outline artifact of the per-fixture draw), then each
-- fixture by its shape, with its id when showDebugIds.
local function drawBody(body, alpha, drawOutline, debugIds)
    local bodyUD = body:getUserData()
    local bodyThing = bodyUD and bodyUD.thing
    local customHandled = false
    if bodyThing and bodyThing.shapeType == 'custom' then
        customHandled = drawCustomBodyFill(body, bodyThing, getBodyColor(body), alpha, drawOutline)
    end
    for _, fixture in ipairs(body:getFixtures()) do
        -- hot loop: cache the FFI-crossing getters once per fixture
        local ud = fixture:getUserData()
        local shape = fixture:getShape()
        local shapeType = shape:type()
        if shapeType == 'PolygonShape' then
            drawPolygonFixture(body, shape, ud, alpha, drawOutline, customHandled)
        elseif shapeType == 'EdgeShape' or shapeType == 'ChainShape' then
            drawEdgeFixture(body, shape, alpha)
        elseif shapeType == 'CircleShape' then
            drawCircleFixture(body, shape, alpha, drawOutline)
        end
        if state.world.showDebugIds and ud and ud.id then
            local x1, y1 = body:getPosition()
            drawDebugId(debugIds, ud.id, x1, y1)
        end
    end
end

-- a pulley's ropes to its ground anchors, in yellow
local function drawPulley(joint, x1, y1, x2, y2, alpha)
    local gx1, gy1, gx2, gy2 = joint:getGroundAnchors()
    love.graphics.setColor(1, 1, 0, alpha)
    love.graphics.line(x1, y1, gx1, gy1)
    love.graphics.line(x2, y2, gx2, gy2)
    love.graphics.line(gx1, gy1, gx2, gy2)
end

-- a prismatic joint's axis (orange) and its limits (yellow ticks)
local function drawPrismatic(joint)
    local x, y = joint:getAnchors()
    local ax, ay = joint:getAxis()
    local length = 50
    love.graphics.setColor(1, 0.5, 0) -- Orange
    love.graphics.line(x, y, x + ax * length, y + ay * length)
    if joint:areLimitsEnabled() then
        local lower, upper = joint:getLimits()
        love.graphics.setColor(1, 1, 0) -- Yellow
        love.graphics.line(x + ax * lower, y + ay * lower, x + ax * lower + ax * 10, y + ay * lower + ay * 10)
        love.graphics.line(x + ax * upper, y + ay * upper, x + ax * upper + ax * 10, y + ay * upper + ay * 10)
    end
    love.graphics.setColor(1, 1, 1) -- Reset
end

-- a revolute joint's limits as an arc, and the angle bodyB is at now (in the joint's reference frame)
local function drawRevoluteLimits(joint, x1, y1, alpha)
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
    if endAngle < startAngle then endAngle = endAngle + 2 * math.pi end
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

-- a wheel joint's axis, in green
local function drawWheelAxis(joint, x1, y1, alpha)
    local axisX, axisY = joint:getAxis()
    if x1 and y1 and axisX and axisY then
        local axisLength = 50                   -- Scale factor for visualizing the axis
        love.graphics.setColor(0, .5, 0, alpha) -- Green for axis
        love.graphics.line(x1, y1, x1 + axisX * axisLength, y1 + axisY * axisLength)
        love.graphics.setColor(1, 1, 1, alpha)
    end
end

-- One joint: the line between its anchors, a circle at each, then what its type shows, and its id
local function drawJoint(joint, alpha, debugIds)
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
    if jointType == JT.PULLEY then drawPulley(joint, x1, y1, x2, y2, alpha) end
    if jointType == JT.PRISMATIC then drawPrismatic(joint) end
    if jointType == JT.REVOLUTE and joint:areLimitsEnabled() then drawRevoluteLimits(joint, x1, y1, alpha) end
    if jointType == JT.WHEEL then drawWheelAxis(joint, x1, y1, alpha) end
    if state.world.showDebugIds then
        local ud = joint:getUserData()
        if ud and ud.id then drawDebugId(debugIds, ud.id, x1, y1) end
    end
end

-- The editor's view of the world: the bodies (their fixtures filled and outlined) and the joints, as the
-- world settings say (debugDrawBodies / debugDrawJoints, drawOutline, debugAlpha, showDebugIds; in the
-- 'tex/body' view and in play mode a body under its picture is left out: see showsBody).
function lib.drawWorld(world, drawOutline)
    local debugIds = {} -- ids drawn this frame (showDebugIds): bodies and joints both use it
    if drawOutline == nil then drawOutline = true end
    if drawOutline == true and state.world.drawOutline == false then drawOutline = false end
    local r, g, b, a = love.graphics.getColor()
    local alpha = .8 * state.world.debugAlpha
    if state.playMode == true then drawOutline, alpha = false, 1 end -- plain grey shapes (getBodyColor)
    love.graphics.setLineJoin("none")
    love.graphics.setColor(0, 0, 0, alpha)
    -- 'tex/body' view: a body with a texture shows only the texture (see showsBody)
    -- (play mode always: the scene as it ships has no body shapes under its pictures, and
    -- drawing all of them under 20 Mipos was ~2 ms a frame)
    local skipTextured = state.world.showTextures and (state.world.textureOrBody or state.playMode == true)
    local DRAW_BODIES = state.world.debugDrawBodies
    local covered = skipTextured and DRAW_BODIES and lib.coveredBodies()
    -- skip bodies off screen (docs/MIPO-DRAWING.md L1b): their centre plus how far their fixtures reach,
    -- against what the screen shows, before anything else is asked of them
    local vx1, vy1, vx2, vy2 = view.worldRect()
    local cull = lib.cull
    if DRAW_BODIES then
        -- inline, not a function per body: it runs for every body every frame, the skipped ones too
        for _, body in ipairs(world:getBodies()) do repeat -- break = next body (no goto in the web's Lua 5.1)
            -- a body under its picture first: in play mode that's nearly all of them, and this is a table
            -- lookup (hasTexture remembers) where the cull asks the body twice
            if skipTextured and not lib.showsBody(body, covered) then break end
            if walls.isWallBody(body) then break end -- drawn by src/walls.lua, behind everything
            if cull then
                local x, y = body:getPosition()
                local reach = view.bodyReach(body) + OUTLINE_PAD
                if x + reach < vx1 or x - reach > vx2 or y + reach < vy1 or y - reach > vy2 then break end
            end
            drawBody(body, alpha, drawOutline, debugIds)
        until true end
    end
    love.graphics.setColor(1, 1, 1, alpha)
    -- only when drawn: getJoints makes a table and a userdata per joint (305 with 20 Mipos), every frame,
    -- for nothing in play mode
    if state.world.debugDrawJoints then
        for _, joint in ipairs(world:getJoints()) do drawJoint(joint, alpha, debugIds) end
    end
    love.graphics.setLineJoin("miter")
    love.graphics.setColor(r, g, b, a)
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
        local body = bodies[i]
        for _, fixture in ipairs(body:getFixtures()) do
            local shape = fixture:getShape()
            love.graphics.push()
            love.graphics.translate(body:getX(), body:getY())
            love.graphics.rotate(body:getAngle())
            if shape:typeOf("CircleShape") then
                local sx, sy = shape:getPoint()
                love.graphics.circle("line", sx, sy, shape:getRadius())
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
