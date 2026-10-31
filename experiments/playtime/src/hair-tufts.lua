-- Hair tufts: a few short tufts on top of the head as real Box2D bodies, a spike
-- (scripts/tufts.playtime.lua). Like the ears: each tuft is a short chain of small bodies, the
-- first soft-welded to the head, each next one soft-welded to the one before (a weld with a
-- frequency is a spring that keeps the rest angle), so a tuft stands, sways and bounces with
-- the head. They collide with nothing (category 16, masked against all): no contacts, so they
-- can't snag, push things, or call contact callbacks. Light, so they hardly pull on the head.
-- Drawn as a ribbon through the chain: with the Mipo's own ear picture (baked, its colours and
-- pattern: a fuzzy ear already reads as a tuft of hair), else a hair picture.
local lib = {}

local state = require('src.state')
local utils = require('src.utils')
local units = require('src.physics-units')
local ribbon = require('src.render.ribbon')
local color = require('src.color')

lib.defaults = {
    count = 3,          -- tufts
    segments = 2,       -- bodies per tuft
    length = 70,        -- px, a whole tuft
    width = 26,         -- px, a body's width (the drawn tuft is `drawWidth` of the picture)
    spread = 1.0,       -- radians of the head's top the roots cover
    lean = 0.35,        -- radians the outer tufts lean outward from straight out of the head
    frequency = 3,      -- Hz at 100 px/m, the ears' 3: lower is floppier
    dampingRatio = 0.25, -- the ears' 0.25: higher settles sooner
    density = 0.2,      -- of the head's: light
    drawWidth = 0.25,   -- ribbon half-width as a share of the picture's width
    texture = 7,        -- hairN.png (and hairN-mask.png when there is one), when not `ear`
    ear = 1,            -- 1: draw with the Mipo's own ear picture, 0: with hairN
    style = 1,          -- lib.haircuts[style]; 0: `count` tufts spread evenly (spread, lean)
}

-- Haircuts: where each tuft sits and which way it points; the welds keep pulling it back there.
-- at: on the head's outline, -1 the left side, 0 the top, 1 the right side. angle: degrees from
-- straight up (head space), + leans right, 180 hangs down. len/width: times the sliders.
local function T(at, angle, len, width) return { at = at, angle = angle, len = len or 1, width = width or 1 } end
lib.haircuts = {
    { name = 'spiky', T(-0.6, -35), T(-0.3, -15), T(0, 0, 1.1), T(0.3, 15), T(0.6, 35) },
    { name = 'mohawk', T(-0.15, -5, 1.2), T(0, 0, 1.4), T(0.15, 5, 1.2) },
    { name = 'swept', T(-0.6, 70, 1.1), T(-0.3, 60, 1.2), T(0, 55, 1.2), T(0.3, 50, 1) },
    { name = 'pigtails', T(-0.95, -120, 1.4, 1.2), T(0.95, 120, 1.4, 1.2) },
    { name = 'cowlick', T(0.15, -25, 1.3, 0.8) },
    { name = 'fringe', T(-0.4, 160, 0.8), T(-0.15, 175, 0.9), T(0.15, 185, 0.9), T(0.4, 200, 0.8) },
}

local images = {}
local function image(path)
    if images[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path)
        images[path] = ok and img or false
    end
    return images[path] or nil
end

-- Where a ray from the body's origin at `angle` leaves the polygon `vertices` (flat, local).
local function outlinePoint(vertices, angle)
    local dx, dy = math.cos(angle), math.sin(angle)
    local best = nil
    local n = #vertices / 2
    for i = 1, n do
        local ax, ay = vertices[2 * i - 1], vertices[2 * i]
        local j = i % n + 1
        local bx, by = vertices[2 * j - 1], vertices[2 * j]
        local ex, ey = bx - ax, by - ay
        local denom = dx * ey - dy * ex
        if math.abs(denom) > 1e-9 then
            local t = (ax * ey - ay * ex) / denom
            local u = (ax * dy - ay * dx) / denom
            if t > 0 and u >= 0 and u <= 1 and (not best or t < best) then best = t end
        end
    end
    best = best or 50
    return dx * best, dy * best
end

local function headOf(instance)
    local part = instance.parts and (instance.parts.head or instance.parts.torso1)
    return part and part.body
end

local function headDensity(body)
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then return fixture:getDensity() end
    end
    return 1
end

-- Take `instance`'s tufts away (their joints go with the bodies).
function lib.remove(instance)
    local t = instance.hairTufts
    if not t then return end
    for _, tuft in ipairs(t.tufts) do
        for _, body in ipairs(tuft.bodies) do
            if not body:isDestroyed() then body:destroy() end
        end
    end
    instance.hairTufts = nil
end

local function weld(a, b, x, y, o)
    local joint = love.physics.newWeldJoint(a, b, x, y, false)
    joint:setFrequency(units.rate(o.frequency))
    joint:setDampingRatio(o.dampingRatio)
    return joint
end

-- Give `instance` tufts (opts over lib.defaults); again to change them.
function lib.attach(instance, opts)
    lib.remove(instance)
    local o = {}
    for k, v in pairs(lib.defaults) do o[k] = (opts and opts[k] ~= nil) and opts[k] or v end
    local head = headOf(instance)
    if not head or head:isDestroyed() then return end
    local thing = utils.thingOf(head)
    local vertices = thing and thing.vertices
    if not vertices or #vertices < 6 then return end
    local world = head:getWorld()
    local density = headDensity(head) * o.density
    local a = head:getAngle()
    local tufts = {}
    -- where the tufts go: (root angle on the outline, direction, length, width), head space
    local placements = {}
    local haircut = lib.haircuts[o.style]
    if haircut then
        for _, t in ipairs(haircut) do
            placements[#placements + 1] = { root = -math.pi / 2 + t.at * math.pi / 2 * 0.95,
                dir = -math.pi / 2 + math.rad(t.angle), len = t.len, width = t.width }
        end
    else
        for k = 1, o.count do
            local f = o.count > 1 and (k - 1) / (o.count - 1) or 0.5
            local root = -math.pi / 2 + (f - 0.5) * o.spread
            placements[k] = { root = root, dir = root + (f - 0.5) * 2 * o.lean, len = 1, width = 1 }
        end
    end
    for k, place in ipairs(placements) do
        local lx, ly = outlinePoint(vertices, place.root)
        lx, ly = lx * 0.9, ly * 0.9 -- a little inside the head
        local dir = place.dir + a
        local dx, dy = math.cos(dir), math.sin(dir)
        local rootX, rootY = head:getWorldPoint(lx, ly)
        local segLen = o.length * place.len / o.segments
        local tuft = { rootX = lx, rootY = ly, bodies = {}, segLen = segLen, drawWidth = o.drawWidth * place.width }
        local prev, jx, jy = head, rootX, rootY
        for i = 1, o.segments do
            local cx, cy = jx + dx * segLen / 2, jy + dy * segLen / 2
            local body = love.physics.newBody(world, cx, cy, 'dynamic')
            body:setAngle(dir + math.pi / 2) -- local -y along the tuft, outward
            local shape = love.physics.newRectangleShape(o.width * place.width, segLen)
            local fixture = love.physics.newFixture(body, shape, density)
            fixture:setCategory(16)
            fixture:setMask(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
            local vx, vy = head:getLinearVelocityFromWorldPoint(cx, cy)
            body:setLinearVelocity(vx, vy)
            weld(prev, body, jx, jy, o)
            tuft.bodies[i] = body
            prev, jx, jy = body, jx + dx * segLen, jy + dy * segLen
        end
        tufts[k] = tuft
    end
    instance.hairTufts = { opts = o, tufts = tufts, head = head }
end

-- The Mipo's baked ear picture (nil without ears).
local function earImage(instance)
    for _, name in ipairs({ 'lear', 'rear' }) do
        local part = instance.parts and instance.parts[name]
        if part and part.body and not part.body:isDestroyed() then
            for _, fixture in ipairs(part.body:getFixtures()) do
                local ud = fixture:getUserData()
                if ud and ud.extra and ud.extra.ompImage then return ud.extra.ompImage end
            end
        end
    end
end

local scratch = {}
-- The tufts of every Mipo that has them, in the colours of its haircut.
function lib.draw()
    for _, instance in pairs(state.mipoInstances) do
        local t = instance.hairTufts
        if t and not t.head:isDestroyed() then
            local o = t.opts
            local line = image('textures/hair' .. o.texture .. '.png')
            local mask = image('textures/hair' .. o.texture .. '-mask.png')
            local cut = instance.dna and instance.dna.parts and instance.dna.parts.head
                and instance.dna.parts.head.appearance and instance.dna.parts.head.appearance.haircut
            local main = cut and cut.main or {}
            local fr, fg, fb = color.hexToColor(main.fgHex or 'bf1a2dff')
            local lr, lg, lb = color.hexToColor(main.bgHex or '000000ff')
            local ear = o.ear == 1 and earImage(instance)
            if ear then mask, line = nil, nil end
            for _, tuft in ipairs(t.tufts) do
                -- the root on the head, then each body's tip
                local points = tuft.points or {}
                tuft.points = points
                points[1], points[2] = t.head:getWorldPoint(tuft.rootX, tuft.rootY)
                for i, body in ipairs(tuft.bodies) do
                    points[2 * i + 1], points[2 * i + 2] = body:getWorldPoint(0, -tuft.segLen / 2)
                end
                if #tuft.bodies == 1 then -- a Bezier needs 3 points: the body's middle between
                    local b = tuft.bodies[1]
                    scratch[1], scratch[2] = points[1], points[2]
                    scratch[3], scratch[4] = b:getPosition()
                    scratch[5], scratch[6] = points[3], points[4]
                    points = scratch
                end
                if ear then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(ribbon.ownStrip(tuft, 'ear', ear, tuft.drawWidth, points, 1, 0, nil, true))
                end
                if mask then
                    love.graphics.setColor(fr, fg, fb, 1)
                    love.graphics.draw(ribbon.ownStrip(tuft, 'fill', mask, tuft.drawWidth, points, 1, 0, nil, true))
                end
                if line then
                    love.graphics.setColor(lr, lg, lb, 1)
                    love.graphics.draw(ribbon.ownStrip(tuft, 'line', line, tuft.drawWidth, points, 1, 0, nil, true))
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return lib
