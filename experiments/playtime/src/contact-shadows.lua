-- contact-shadows.lua — a soft dark patch on what a thing stands on (docs/LIGHT-AND-SHADOW.md LS6).
-- Each caster (a body standing on something; of a Mipo only its feet, hands and torso, so it casts as
-- one figure, not twenty parts) looks straight down with three short rays for the surface under it: the
-- first up-facing, non-sensor fixture of another body (not its own Mipo). The shadow is a soft oval on
-- that surface's top line, darker and tighter the closer the caster is, fading out by `reach`. It's cut
-- with a stencil to what's drawn of the receiver (its pictures, else its collision shapes), so only the
-- part on the surface shows: past a shelf's edge, above its top, or over the see-through corners of a
-- square body wearing a rounded picture, nothing (no shadow over nothing).
-- Depth: on a receiver without pictures, drawn before all the textured drawables (beforeTextured); on
-- one with pictures, just above its highest one (a split in the textured list, state.drawSplits, merged
-- with a scene's own), so it lies on the shelf's picture and under what stands on it.
-- Off unless state.contactShadows is set: { strength = 0..1 (0.45), reach = how far a caster's shadow
-- reaches, in its widths (1.5) }.
local lib = {}

local state = require('src.state')
local utils = require('src.utils')

local MIPO_CASTERS = { lfoot = true, rfoot = true, lhand = true, rhand = true, torso1 = true }
local MAX_CASTER_WIDTH = 1500 -- the ground and walls don't cast
local MIN_DEPTH = 28 -- how far down the surface a shadow reaches at least, world units

local blob -- the soft oval: a radial falloff, made once
local function blobImage()
    if blob then return blob end
    local size = 64
    local data = love.image.newImageData(size, size)
    data:mapPixel(function(x, y)
        local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
        local r2 = dx * dx + dy * dy
        local a = r2 < 1 and (1 - r2) ^ 1.6 or 0
        return 1, 1, 1, a
    end)
    blob = love.graphics.newImage(data)
    blob:setFilter('linear', 'linear')
    return blob
end

local function solidFixtures(body)
    local list = {}
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then list[#list + 1] = fixture end
    end
    return list
end

-- the caster's extent (left, right, top, bottom) from its solid fixtures; nil if it has none. (The
-- bounding boxes carry Box2D's skin: a box resting on a shelf reaches a little into it.)
local function extent(body)
    local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            local ax, ay, bx, by = fixture:getBoundingBox(1)
            x0, x1, y0, y1 = math.min(x0, ax), math.max(x1, bx), math.min(y0, ay), math.max(y1, by)
        end
    end
    if x0 == math.huge then return nil end
    return x0, x1, y0, y1
end

local function casts(body)
    local thing = utils.thingOf(body)
    if not thing then return false end
    if thing.mipoId then return MIPO_CASTERS[thing.mipoPartName] == true end
    return true
end

-- the nearest up-facing surface straight under (x, y) within reach: its fixture, the y, and the
-- surface's normal there (a sloped floor: the shadow lies along it). One callback for every ray, its
-- state in upvalues: a closure per ray was most of compute's ~190 KB of garbage a frame (M12).
local rayBody, rayMipoId, best, bestFixture, bestY, bestNx, bestNy
local function onRayHit(fixture, _, hy, nx, ny, fraction)
    if fixture:isSensor() or ny > -0.3 then return -1 end
    local other = fixture:getBody()
    if other == rayBody then return -1 end
    if rayMipoId then
        local otherThing = utils.thingOf(other)
        if otherThing and otherThing.mipoId == rayMipoId then return -1 end
    end
    if fraction < best then best, bestFixture, bestY, bestNx, bestNy = fraction, fixture, hy, nx, ny end
    return fraction
end
local function surfaceUnder(world, body, mipoId, x, y, reach)
    rayBody, rayMipoId = body, mipoId
    best, bestFixture, bestY, bestNx, bestNy = math.huge, nil, nil, 0, -1
    world:rayCast(x, y, x, y + reach, onRayHit)
    rayBody = nil
    return bestFixture, bestY, bestNx, bestNy
end

-- the depth just above a body's own pictures, nil if it has none
local function pictureDepth(body)
    local z
    for _, fixture in ipairs(body:getFixtures()) do
        local ud = fixture:getUserData()
        if type(ud) == 'table' and ud.extra then
            local fz = (ud.extra.zGroupOffset or 0) * 1000 + (ud.extra.zOffset or 0)
            if not z or fz > z then z = fz end
        end
    end
    return z
end

-- The casters, kept between frames for the C++ path (found again when the world's body count changes,
-- one is destroyed, or every 30 frames): the bodies, and each one's own Mipo's collision group (a Mipo's
-- parts share a negative group of their own; 0: not a Mipo), so the rays skip its own Mipo.
local casterCache = { bodies = {}, groups = {}, count = -1, frames = 0 }
local function casterList(world)
    local c = casterCache
    c.frames = c.frames + 1
    local stale = c.world ~= world or world:getBodyCount() ~= c.count or c.frames >= 30
    if not stale then
        for _, body in ipairs(c.bodies) do
            if body:isDestroyed() then stale = true; break end
        end
    end
    if stale then
        local bodies, groups = {}, {}
        for _, body in ipairs(world:getBodies()) do
            if casts(body) then
                local group = 0
                if (utils.thingOf(body) or {}).mipoId then
                    for _, fixture in ipairs(body:getFixtures()) do
                        if not fixture:isSensor() then
                            local g = fixture:getGroupIndex()
                            if g < 0 then group = g end
                            break
                        end
                    end
                end
                bodies[#bodies + 1], groups[#groups + 1] = body, group
            end
        end
        c.bodies, c.groups, c.world, c.count, c.frames = bodies, groups, world, world:getBodyCount(), 0
    end
    return c.bodies, c.groups
end

-- every shadow this frame: { receiver, x, y, hw, hh, alpha, z }
-- In C++ where LÖVE has World:playtimeContactShadows (the iOS build: native/ios/patch-love-physics.py,
-- the same rays and ovals; docs/MEASURING.md M12); state.contactShadowsLua = true: the Lua path anyway.
local RAY_OFFSETS = { 0, -0.35, 0.35 }
local nativeOut = {}
function lib.compute(world)
    local settings = state.contactShadows
    local list = {}
    if not settings or not world then return list end
    local strength, reachWidths = settings.strength or 0.45, settings.reach or 1.5
    local depths = {} -- a receiver's picture depth, once a frame (false: none)
    if world.playtimeContactShadows and not state.contactShadowsLua then
        local bodies, groups = casterList(world)
        local n = world:playtimeContactShadows(bodies, groups, nativeOut, strength, reachWidths,
            MAX_CASTER_WIDTH, MIN_DEPTH, 60)
        for i = 0, n - 1 do
            local o = i * 7
            local receiver = nativeOut[o + 1]
            local z = depths[receiver]
            if z == nil then z = pictureDepth(receiver) or false; depths[receiver] = z end
            list[#list + 1] = { receiver = receiver, x = nativeOut[o + 2], y = nativeOut[o + 3],
                hw = nativeOut[o + 4], hh = nativeOut[o + 5], alpha = nativeOut[o + 6], angle = nativeOut[o + 7],
                z = z or nil }
        end
        return list
    end
    for _, body in ipairs(world:getBodies()) do
        if casts(body) then
            local x0, x1, top, bottom = extent(body)
            local width = x0 and (x1 - x0)
            if width and width > 0 and width < MAX_CASTER_WIDTH then
                local reach = math.max(width * reachWidths, 60)
                local cx = (x0 + x1) / 2
                local fixture, surfaceY, nx, ny, hitX
                -- from a little up inside the caster (skipped by the rays): a ray starting inside the
                -- surface wouldn't see it
                local from = bottom - math.min((bottom - top) * 0.5, 20)
                local mipoId = (utils.thingOf(body) or {}).mipoId
                for _, k in ipairs(RAY_OFFSETS) do
                    hitX = cx + k * width
                    fixture, surfaceY, nx, ny = surfaceUnder(world, body, mipoId, hitX, from, reach + bottom - from)
                    if fixture then break end
                end
                if fixture then
                    local t = math.min(1, math.max(0, (surfaceY - bottom) / reach))
                    local alpha = strength * (1 - t) ^ 2
                    if alpha > 0.005 then
                        local hw = width * 0.5 * (1.05 + t * 0.6)
                        -- deep enough to reach past a drawn outline onto the picture (a stone's black
                        -- line is ~15 thick: a small foot's shadow lay all on it, unseen)
                        local hh = math.max(hw * 0.28, MIN_DEPTH)
                        -- along the surface (its tangent from the normal); on a slope the middle's height
                        -- is where the surface is under the caster's middle, not under the ray that hit
                        local angle = math.atan2(nx, -ny)
                        local y = surfaceY + (cx - hitX) * math.tan(angle)
                        local receiver = fixture:getBody()
                        local z = depths[receiver]
                        if z == nil then z = pictureDepth(receiver) or false; depths[receiver] = z end
                        list[#list + 1] = { receiver = receiver, x = cx, y = y, hw = hw,
                            hh = hh, alpha = alpha, angle = angle, z = z or nil }
                    end
                end
            end
        end
    end
    return list
end

-- what's drawn of the receiver, for the stencil: its pictures (their see-through parts cut away), else
-- its collision shapes. A square body wearing a rounded stone: the shadow only on the stone.
local alphaCut
local function cutShader()
    alphaCut = alphaCut or love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 fc) {
            vec4 c = Texel(tex, uv) * color;
            if (c.a < 0.5) discard;
            return c;
        }
    ]])
    return alphaCut
end

local function stencilPictures(body)
    local drawn = false
    local textured = require('src.physics.box2d-draw-textured')
    love.graphics.setShader(cutShader())
    for _, fixture in ipairs(body:getFixtures()) do
        if textured.drawPictureOf(fixture) then drawn = true end
    end
    love.graphics.setShader()
    return drawn
end

local function stencilBody(body)
    if stencilPictures(body) then return end
    for _, fixture in ipairs(solidFixtures(body)) do
        local shape = fixture:getShape()
        local kind = shape:getType()
        if kind == 'polygon' then
            love.graphics.polygon('fill', body:getWorldPoints(shape:getPoints()))
        elseif kind == 'circle' then
            local x, y = body:getWorldPoint(shape:getPoint())
            love.graphics.circle('fill', x, y, shape:getRadius())
        end
    end
end

-- The shadows on one receiver: its stencil drawn once, then every oval on it. (One stencil per shadow
-- drew the floor ~85 times a frame with 20 Mipos: ~3 ms on an iPhone SE 2, LIGHT-AND-SHADOW LS13.)
local function drawOn(receiver, shadows)
    local image = blobImage()
    local compare, value = love.graphics.getStencilTest()
    love.graphics.stencil(function() stencilBody(receiver) end, 'replace', 1)
    love.graphics.setStencilTest('greater', 0)
    local iw, ih = image:getDimensions()
    for _, s in ipairs(shadows) do
        love.graphics.setColor(0, 0, 0, s.alpha)
        love.graphics.draw(image, s.x, s.y, s.angle or 0, s.hw * 2 / iw, s.hh * 2 / ih, iw / 2, ih / 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
    if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
end

function lib.drawShadow(s) drawOn(s.receiver, { s }) end

-- the shadows grouped by what they land on, in the order the receivers first come
local function byReceiver(list)
    local groups, order = {}, {}
    for _, s in ipairs(list) do
        local g = groups[s.receiver]
        if not g then
            g = { receiver = s.receiver, z = s.z, shadows = {} }
            groups[s.receiver] = g
            order[#order + 1] = g
        end
        g.shadows[#g.shadows + 1] = s
    end
    return order
end

-- every shadow now, whatever its depth (specs, a scene without pictures)
function lib.drawAll(world)
    for _, g in ipairs(byReceiver(lib.compute(world))) do drawOn(g.receiver, g.shadows) end
end

-- Before the textured world: the shadows on surfaces without pictures drawn now, the others handed to
-- the textured drawing as splits at their receiver's depth (with a scene's own splits). afterTextured
-- puts the scene's splits back.
local sceneSplits
function lib.beforeTextured(world)
    if not state.contactShadows then return end
    local splits = {}
    for _, g in ipairs(byReceiver(lib.compute(world))) do
        if g.z then
            splits[#splits + 1] = { z = g.z + 0.0005, fn = function() drawOn(g.receiver, g.shadows) end }
        else
            drawOn(g.receiver, g.shadows)
        end
    end
    if #splits == 0 then return end
    sceneSplits = state.drawSplits
    for _, split in ipairs(sceneSplits or {}) do splits[#splits + 1] = split end
    table.sort(splits, function(a, b) return a.z < b.z end)
    state.drawSplits = splits
    lib.active = true
end

function lib.afterTextured()
    if not lib.active then return end
    state.drawSplits, sceneSplits, lib.active = sceneSplits, nil, false
end

return lib
