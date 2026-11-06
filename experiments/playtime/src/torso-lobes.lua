-- torso-lobes.lua
-- Lobes (creation.torsoLobes): soft round bodies at the ends of any torso, found from its
-- outline. Each end gets two at its corners when it's wide (a heart's bumps, a box's
-- corners) or one in its middle when it's narrow (a heart's tip, an egg's top): a heart
-- has three, a box four, an egg two. Each hangs from torso1 on two springy distance joints
-- in a V and a rope that stops it going too far, so it gives in every direction and pushes
-- back on the torso: it bounces on a landing, spreads when sat on, sways when walked or
-- dragged. torso1's own collision stops at the cuts, the lobes are what touch beyond them;
-- legs, arms and ears still hang from the whole outline. The torso picture is drawn as a
-- grid (spineSkin.drawGrid) whose points near a lobe move with it. With a spine each lobe
-- hangs from the band it sits in, and the picture bends with the spine first.
local mipoRegistry = require('src.mipo-registry')
local shape8Dict = require('src.shape8-dict')
local units = require('src.physics-units')
local ST = require('src.shape-types')
local JT = require('src.joint-types')
local topology = require('src.character-topology')

local lib = {}

lib.columns = 8        -- the torso picture's grid with lobes: finer across than a spine's
lib.rows = 12
lib.inner = 1.0        -- grid points within this many lobe radii follow the lobe fully
lib.outer = 2.2        -- ... and from here on not at all
lib.slack = 0.5        -- the rope: how far (lobe radii) a lobe can go from its rest place
lib.springLength = 1.5 -- the V's springs, in lobe radii
lib.splitAt = 0.45     -- an end is wide (two lobes) when its corners are this much of the width apart
lib.cornerOff = 0.15   -- a corner is at least this much of the width off the middle
lib.cornerNear = 0.5   -- ... and within this much of the depth from the end
lib.MAX = 4

function lib.enabled(creation)
    return (creation and creation.torsoLobes) and true or false
end

-- The number of spine bands (1 without a spine).
local function bandCount(creation)
    return creation.torsoSpine and (creation.torsoSegments or 1) > 1 and creation.torsoSegments or 1
end

function lib.isLobe(partName)
    return partName:match('^lobe%d$') ~= nil
end

-- Smallest and largest x where the closed outline (flat list) crosses the line at y.
local function crossings(points, y)
    local lo, hi = math.huge, -math.huge
    local n = #points / 2
    for i = 1, n do
        local j = i % n + 1
        local x1, y1, x2, y2 = points[i * 2 - 1], points[i * 2], points[j * 2 - 1], points[j * 2]
        if y >= math.min(y1, y2) and y <= math.max(y1, y2) then
            local x = (y1 == y2) and x1 or x1 + (x2 - x1) * (y - y1) / (y2 - y1)
            lo, hi = math.min(lo, x), math.max(hi, x)
        end
    end
    return lo, hi
end

-- The lobes of one end (e = 1 the bottom, -1 the top), added to `lobes`; returns the cut.
local function endLobes(points, box, e, depth, main, lobes)
    local endY = e > 0 and box.bottom or box.top
    local midX = box.midX
    -- the corner on each side: of the outline points off the middle and near this end, the
    -- one furthest toward it (a shape's own middle point at an end is no corner)
    local corners = {}
    for k = 1, #points, 2 do
        local x, y = points[k], points[k + 1]
        local off, near = math.abs(x - midX) > lib.cornerOff * box.width, e * (endY - y) <= lib.cornerNear * depth
        if off and near then
            local side = x < midX and 1 or 2
            if not corners[side] or e * y > e * corners[side][2] then corners[side] = { x, y } end
        end
    end
    local wide = corners[1] and corners[2] and (corners[2][1] - corners[1][1]) > lib.splitAt * box.width
    if wide then
        for side = 1, 2 do
            local c = corners[side]
            local sign = side == 1 and -1 or 1
            local r = math.max(1, math.min(depth / 2, 0.6 * math.abs(c[1] - midX)))
            lobes[#lobes + 1] = { x = c[1] - sign * r * 0.6, y = c[2] - e * r, r = r, inward = -e, main = main }
        end
        return endY - e * depth
    end
    local lo, hi = crossings(points, endY - e * depth / 2)
    if lo > hi then lo, hi = midX, midX end
    local r = math.max(1, math.min((hi - lo) / 2 * 0.8, depth / 2 * 1.2))
    lobes[#lobes + 1] = { x = (lo + hi) / 2, y = endY - e * r, r = r, inward = -e, main = main }
    return endY - e * r
end

-- Where the lobes go on a torso part (its DNA) at `scale`, in torso1's local space:
-- { lobes = { { x, y, r, inward, main }, ... }, cuts = { { e, y }, { e, y } }, top, bottom,
-- midX, width }. The wider end comes first (main = true: what the drawn jiggle swings most).
-- inward: the y direction toward the torso's middle, where a lobe's springs hang from.
function lib.layout(partData, creation, scale)
    local entry = partData.shape8URL and shape8Dict[partData.shape8URL]
    if not entry then return nil end
    local sx = (partData.dims.sx or 1) * scale
    local sy = (partData.dims.sy or 1) * scale
    local points = {}
    local box = { top = math.huge, bottom = -math.huge, left = math.huge, right = -math.huge }
    for k = 1, #entry.vertices, 2 do
        local x, y = entry.vertices[k] * sx, entry.vertices[k + 1] * sy
        points[k], points[k + 1] = x, y
        box.top, box.bottom = math.min(box.top, y), math.max(box.bottom, y)
        box.left, box.right = math.min(box.left, x), math.max(box.right, x)
    end
    box.midX, box.width = (box.left + box.right) / 2, box.right - box.left
    local h = box.bottom - box.top
    local loT, hiT = crossings(points, box.top + 0.2 * h)
    local loB, hiB = crossings(points, box.bottom - 0.2 * h)
    local first = (hiB - loB) >= (hiT - loT) and 1 or -1
    -- with a spine, an end's lobes take at most about one band
    local depth = math.min((creation.lobeDepth or 0.35) * h, 0.9 * h / bandCount(creation))
    local lobes, cuts = {}, {}
    for _, e in ipairs({ first, -first }) do
        cuts[#cuts + 1] = { e = e, y = endLobes(points, box, e, depth, e == first, lobes) }
    end
    box.lobes, box.cuts = lobes, cuts
    return box
end

-- Each band's middle y in the whole torso's drawn space (unscaled): 0 without a spine.
local function bandMiddles(torso, creation)
    local count = bandCount(creation)
    local middles = {}
    if count == 1 then return { 0 } end
    local raw = shape8Dict[torso.shape8URL].vertices
    local sy = torso.dims.sy or 1
    for i = 1, count do
        local _, middle = topology.spineBand(raw, i, count, sy < 0)
        middles[i] = middle * sy
    end
    return middles
end

-- The lobes a Mipo gets (unscaled), nil without: { { name, parent, at (in the parent band's
-- space), rest (in torso1's), r, inward, main }, ... }, the layout's order.
function lib.plan(instance)
    local creation = instance.dna.creation
    if not lib.enabled(creation) then return nil end
    local torso = instance.dna.parts.torso1
    local layout = torso and torso.shape8URL and lib.layout(torso, creation, 1)
    if not layout then return nil end
    local middles = bandMiddles(torso, creation)
    local list = {}
    for i = 1, math.min(#layout.lobes, lib.MAX) do
        local lobe = layout.lobes[i]
        local band, best = 1, math.huge
        for b, m in ipairs(middles) do
            if math.abs(lobe.y - m) < best then band, best = b, math.abs(lobe.y - m) end
        end
        list[i] = { name = 'lobe' .. i, parent = 'torso' .. band, at = { lobe.x, lobe.y - middles[band] },
            rest = { lobe.x, lobe.y - middles[1] }, r = lobe.r, inward = lobe.inward, main = lobe.main }
    end
    return list
end

-- { { name, parent } } for the topology, nil without lobes.
function lib.names(instance)
    return lib.plan(instance)
end

-- Keep the part of a flat polygon on the torso's side of each cut (Sutherland-Hodgman).
local function clipOnce(vertices, e, cut)
    local out = {}
    local n = #vertices / 2
    local function inside(y) return e * y <= e * cut end
    for i = 1, n do
        local j = i % n + 1
        local ax, ay = vertices[i * 2 - 1], vertices[i * 2]
        local bx, by = vertices[j * 2 - 1], vertices[j * 2]
        local aIn, bIn = inside(ay), inside(by)
        if aIn then out[#out + 1], out[#out + 2] = ax, ay end
        if aIn ~= bIn then
            local t = (cut - ay) / (by - ay)
            out[#out + 1], out[#out + 2] = ax + (bx - ax) * t, cut
        end
    end
    if #out < 6 then return vertices end
    return out
end

function lib.clip(vertices, layout, shift)
    for _, cut in ipairs(layout.cuts) do vertices = clipOnce(vertices, cut.e, cut.y - (shift or 0)) end
    return vertices
end

-- A torso band's collision (`vertices`, its own space at `scale`) with the lobe ends cut off.
function lib.collision(instance, partName, vertices, scale)
    local creation = instance.dna.creation
    local index = tonumber(partName:match('^torso(%d+)$'))
    if not (index and lib.enabled(creation)) then return vertices end
    local torso = instance.dna.parts.torso1
    local layout = torso and lib.layout(torso, creation, scale)
    if not layout then return vertices end
    local middles = bandMiddles(torso, creation)
    if not middles[index] then return vertices end
    return lib.clip(vertices, layout, middles[index] * scale)
end

-- The lobes' DNA parts, from torso1's shape (called wherever the spine is applied: a new
-- torso shape or size moves them). Stored unscaled, like the other parts' dims.
function lib.apply(instance)
    for i = 1, lib.MAX do instance.dna.parts['lobe' .. i] = nil end
    for _, lobe in ipairs(lib.plan(instance) or {}) do
        instance.dna.parts[lobe.name] = {
            shape = ST.CIRCLE,
            dims = { r = lobe.r },
            parent = lobe.parent,
            at = lobe.at,
            rest = lobe.rest,
            inward = lobe.inward,
            main = lobe.main,
            density = 1,
            j = { type = JT.ROPE, maxLength = lib.slack * lobe.r },
        }
    end
end

-- The V of springs from torso1 to a just-made lobe (after makePart's rope).
function lib.makeSprings(instance, partName, torsoBody, lobeBody)
    local joints = require('src.joints') -- here: joints requires the registry, no loop on load
    local part = instance.dna.parts[partName]
    local creation = instance.dna.creation
    local scale = instance.scale or 1
    local x, y, r = part.at[1] * scale, part.at[2] * scale, part.dims.r * scale
    local length = lib.springLength * r
    for _, sign in ipairs({ -1, 1 }) do
        joints.createJoint({
            body1 = torsoBody,
            body2 = lobeBody,
            jointType = JT.DISTANCE,
            collideConnected = false,
            offsetA = { x = x + sign * 0.6 * length, y = y + (part.inward or -1) * 0.8 * length },
            offsetB = { x = 0, y = 0 },
            frequency = units.rate(creation.lobeSpring or 2.5),
            dampingRatio = creation.lobeDamping or 0.2,
            label = 'lobe-spring',
        })
    end
end

-- The springs' frequency and damping from the DNA, live (editor sliders).
function lib.setSprings(instance)
    local creation = instance.dna.creation
    for i = 1, lib.MAX do
        local part = instance.parts['lobe' .. i]
        if part and part.body and not part.body:isDestroyed() then
            for _, joint in ipairs(part.body:getJoints()) do
                if joint:getType() == 'distance' then
                    joint:setFrequency(units.rate(creation.lobeSpring or 2.5))
                    joint:setDampingRatio(creation.lobeDamping or 0.2)
                end
            end
        end
    end
end

local function smoothstep(t)
    if t <= 0 then return 0 elseif t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

-- Push a flat list of torso1-local rest points by soft points' offsets ({ x, y, r, ox, oy }
-- in torso1's frame), each weighted by how near the rest point is to it; added to `base`
-- (the points already bent by a spine) when given. Shared with the drawn jiggle.
function lib.pushPoints(points, soft, out, base)
    out = out or {}
    base = base or points
    local inner, span = lib.inner, lib.outer - lib.inner
    for k = 1, #points - 1, 2 do
        local x, y = points[k], points[k + 1]
        local sum, ox, oy = 0, 0, 0
        for i = 1, #soft do
            local p = soft[i]
            local d = math.sqrt((x - p.x) ^ 2 + (y - p.y) ^ 2) / p.r
            local w = 1 - smoothstep((d - inner) / span)
            sum, ox, oy = sum + w, ox + w * p.ox, oy + w * p.oy
        end
        if sum > 1 then ox, oy = ox / sum, oy / sum end
        out[k], out[k + 1] = base[k] + ox, base[k + 1] + oy
    end
    return out
end

-- Each lobe's offset from where its band carries its rest place, in torso1's frame.
function lib.measure(bones)
    local torso = bones.torso
    for i = 1, #bones.lobes do
        local lobe = bones.lobes[i]
        local lx, ly = lobe.body:getPosition()
        local rx, ry = lobe.parent:getWorldPoint(lobe.ax, lobe.ay)
        lobe.ox, lobe.oy = torso:getLocalVector(lx - rx, ly - ry)
    end
end

local function deform(points, bones, out)
    lib.measure(bones)
    return lib.pushPoints(points, bones.lobes, out)
end

-- The bones for spineSkin.drawGrid / drawFan / transformAt when `body` is a lobed torso1
-- (spineSkin.torsoBones puts a spine's bend under them).
local bonesCache = setmetatable({}, { __mode = 'k' })
function lib.bonesOf(body)
    local instance, partName = mipoRegistry.getFromBody(body)
    if partName ~= 'torso1' or not lib.enabled(instance.dna and instance.dna.creation) then return nil end
    local scale = instance.scale or 1
    local bones = bonesCache[instance] or { deform = deform, cols = lib.columns, rows = lib.rows, lobes = {} }
    bonesCache[instance] = bones
    bones.torso = body
    local count = 0
    for i = 1, lib.MAX do
        local part, dnaPart = instance.parts['lobe' .. i], instance.dna.parts['lobe' .. i]
        local parent = dnaPart and instance.parts[dnaPart.parent or 'torso1']
        if part and part.body and not part.body:isDestroyed() and dnaPart and dnaPart.at and dnaPart.rest
            and parent and parent.body and not parent.body:isDestroyed() then
            count = count + 1
            local lobe = bones.lobes[count] or {}
            bones.lobes[count] = lobe
            lobe.body, lobe.parent = part.body, parent.body
            lobe.ax, lobe.ay = dnaPart.at[1] * scale, dnaPart.at[2] * scale
            lobe.x, lobe.y, lobe.r = dnaPart.rest[1] * scale, dnaPart.rest[2] * scale, dnaPart.dims.r * scale
        end
    end
    for i = count + 1, #bones.lobes do bones.lobes[i] = nil end
    if count == 0 then return nil end
    return bones
end

return lib
