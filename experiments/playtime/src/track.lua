-- track.lua — coaster tracks (docs/COASTER.md): a line drawn in the editor becomes a static body whose
-- one fixture is a Box2D chain along it (shape type 'track'). thing.vertices is the centre line,
-- thing.track = { closed, flips } the rest (saved with the body).
--
-- Depth is draw order and who touches what, never size: every point of the line has a lane, front or
-- back. Where the line crosses itself the stretch drawn later goes over (front), unless that crossing is
-- flipped (thing.track.flips[key]). Near a crossing a chain edge is solid only for its own lane (a
-- contact with a mover of the other lane is switched off in preSolve, by the edge's child index); away
-- from crossings an edge is solid for both. Between two crossings that want different lanes the lane
-- changes halfway. A mover takes the lane of the nearest point of the track it rides (state.trackMovers).
local state = require('src.state')
local polygon = require('src.polygon')

local lib = {}

lib.SHAPE_TYPE = 'track'
lib.FRONT, lib.BACK = 1, 2
local BOTH = 3 -- an edge's mask: bit 1 front, bit 2 back

lib.SPACING = 20        -- world units between the centre line's points
lib.CLOSE_DIST = 90     -- a stroke ending this near its start closes into a loop
lib.CROSS_MARGIN = 110  -- along the track, edges this near a crossing are solid for their own lane only
lib.TRANSITION = 160    -- the drawn depth eases over this much either side of a lane change
lib.AWAY_DIST = 160     -- a mover this far from its track's line ...
lib.AWAY_TIME = 0.6     -- ... for this long lets go of its lane
lib.PICK_DIST = 24      -- clicking this near the line picks the track
lib.RAIL_GAP = 7        -- the two drawn rails sit this far either side of the line
lib.RAIL_W = 4.5
lib.SLEEPER_W = 4
lib.SLEEPER_EVERY = 2   -- a sleeper every n points

local RAIL_FRONT = { 0.30, 0.31, 0.36 }
local SLEEPER_FRONT = { 0.46, 0.34, 0.24 }
local HAZE = { 0.66, 0.70, 0.76 }
local HAZE_BACK = 0.55 -- how far a back stretch goes toward the haze

---------------------------------------------------------------- the stroke -> the centre line

local function lengthOf(pts)
    local total = 0
    for i = 2, #pts do
        total = total + math.sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2)
    end
    return total
end

-- Chaikin corner cutting, the ends kept
local function smooth(pts, rounds)
    for _ = 1, rounds do
        if #pts < 3 then return pts end
        local out = { pts[1] }
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            out[#out + 1] = { a[1] * 0.75 + b[1] * 0.25, a[2] * 0.75 + b[2] * 0.25 }
            out[#out + 1] = { a[1] * 0.25 + b[1] * 0.75, a[2] * 0.25 + b[2] * 0.75 }
        end
        out[#out + 1] = pts[#pts]
        pts = out
    end
    return pts
end

-- a point every `spacing` along the polyline (the last point kept)
local function resample(pts, spacing)
    local out = { { pts[1][1], pts[1][2] } }
    local carry = 0
    for i = 2, #pts do
        local ax, ay, bx, by = pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2]
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local d = spacing - carry
        while d <= len do
            local t = d / len
            out[#out + 1] = { ax + (bx - ax) * t, ay + (by - ay) * t }
            d = d + spacing
        end
        carry = len - (d - spacing)
    end
    local last = pts[#pts]
    local tail = out[#out]
    if (last[1] - tail[1]) ^ 2 + (last[2] - tail[2]) ^ 2 > (spacing * 0.3) ^ 2 then
        out[#out + 1] = { last[1], last[2] }
    end
    return out
end

-- A drawn stroke (flat world x, y, ...) -> the centre line (flat) and whether it closes, or nil.
function lib.fromStroke(flat)
    local pts = {}
    for i = 1, #flat - 1, 2 do pts[#pts + 1] = { flat[i], flat[i + 1] } end
    if #pts < 2 or lengthOf(pts) < lib.SPACING * 3 then return nil end
    local first, last = pts[1], pts[#pts]
    local closed = #pts > 8 and lengthOf(pts) > lib.CLOSE_DIST * 4
        and (first[1] - last[1]) ^ 2 + (first[2] - last[2]) ^ 2 < lib.CLOSE_DIST ^ 2
    if closed then pts[#pts + 1] = { first[1], first[2] } end -- smooth and resample through the join
    pts = resample(smooth(pts, 3), lib.SPACING)
    if closed then
        -- the join: drop the tail points that came back onto the start
        while #pts > 3 do
            local p = pts[#pts]
            if (p[1] - first[1]) ^ 2 + (p[2] - first[2]) ^ 2 < (lib.SPACING * 0.6) ^ 2 then
                table.remove(pts)
            else
                break
            end
        end
    end
    local out = {}
    for _, p in ipairs(pts) do
        out[#out + 1] = p[1]
        out[#out + 1] = p[2]
    end
    return out, closed
end

---------------------------------------------------------------- the chain

-- the points without near-duplicates (Box2D asserts on chain points closer than its slop)
local function cleaned(flat, closed)
    local out = {}
    for i = 1, #flat - 1, 2 do
        local x, y = flat[i], flat[i + 1]
        local n = #out
        if n == 0 or (x - out[n - 1]) ^ 2 + (y - out[n]) ^ 2 > 4 then
            out[n + 1], out[n + 2] = x, y
        end
    end
    if closed then
        while #out > 6 and (out[#out - 1] - out[1]) ^ 2 + (out[#out] - out[2]) ^ 2 <= 4 do
            out[#out], out[#out - 1] = nil, nil
        end
    end
    return out
end

-- shapes.createShape's 'track' branch: the chain around the line's centre, and the line as given.
-- settings.optionalVertices: the line (world or local, the body goes to its centre), settings.track.closed
function lib.createShapes(settings)
    local vertices = settings.optionalVertices
    if not vertices or #vertices < 4 then return {}, vertices end
    local closed = settings.track and settings.track.closed or false
    local cx, cy = polygon.getCenterOfPoints(vertices)
    local centred = {}
    for i = 1, #vertices - 1, 2 do
        centred[#centred + 1] = vertices[i] - cx
        centred[#centred + 1] = vertices[i + 1] - cy
    end
    local points = cleaned(centred, closed)
    if #points < (closed and 6 or 4) then return {}, vertices end
    local ok, shape = pcall(love.physics.newChainShape, closed, points)
    if not ok then return {}, vertices end
    return { shape }, vertices
end

---------------------------------------------------------------- the layout: arcs, crossings, lanes

local function segIntersect(ax, ay, bx, by, cx, cy, dx, dy)
    local rx, ry, sx, sy = bx - ax, by - ay, dx - cx, dy - cy
    local den = rx * sy - ry * sx
    if den == 0 then return nil end
    local qx, qy = cx - ax, cy - ay
    local t = (qx * sy - qy * sx) / den
    local u = (qx * ry - qy * rx) / den
    if t >= 0 and t < 1 and u >= 0 and u < 1 then return t, u end
    return nil
end

-- shortest arc distance between two arc positions (around a loop when closed)
local function arcGap(a, b, total, closed)
    local d = math.abs(a - b)
    if closed then d = math.min(d, total - d) end
    return d
end

local function smootherstep(t)
    t = math.max(0, math.min(1, t))
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- the line's points around the centre (as the chain has them), their arc positions, the edge count
local function linePoints(thing, closed)
    local cx, cy = polygon.getCenterOfPoints(thing.vertices)
    local xs, ys = {}, {}
    local v = cleaned(thing.vertices, closed)
    for i = 1, #v - 1, 2 do
        xs[#xs + 1] = v[i] - cx
        ys[#ys + 1] = v[i + 1] - cy
    end
    local n = #xs
    local L = { n = n, edges = closed and n or n - 1, closed = closed, xs = xs, ys = ys, arc = {}, total = 0 }
    for i = 1, n do
        L.arc[i] = L.total
        if i <= L.edges then
            local j = i % n + 1
            L.total = L.total + math.sqrt((xs[j] - xs[i]) ^ 2 + (ys[j] - ys[i]) ^ 2)
        end
    end
    return L
end

local function edgeLen(L, e)
    local j = e % L.n + 1
    return math.sqrt((L.xs[j] - L.xs[e]) ^ 2 + (L.ys[j] - L.ys[e]) ^ 2)
end

-- do edges a and b's bounding boxes miss each other
local function boxesMiss(xs, ys, a1, a2, b1, b2)
    return math.max(xs[b1], xs[b2]) < math.min(xs[a1], xs[a2]) or math.min(xs[b1], xs[b2]) > math.max(xs[a1], xs[a2])
        or math.max(ys[b1], ys[b2]) < math.min(ys[a1], ys[a2]) or math.min(ys[b1], ys[b2]) > math.max(ys[a1], ys[a2])
end

-- every pair of non-neighbouring edges that cross; the later stretch goes over unless flipped
local function findCrossings(L, flips)
    local xs, ys, n = L.xs, L.ys, L.n
    local crossings = {}
    for e1 = 1, L.edges - 2 do
        local a2 = e1 % n + 1
        for e2 = e1 + 2, L.edges do
            local b2 = e2 % n + 1
            local neighbours = L.closed and e1 == 1 and e2 == L.edges
            if not neighbours and not boxesMiss(xs, ys, e1, a2, e2, b2) then
                local t, u = segIntersect(xs[e1], ys[e1], xs[a2], ys[a2], xs[e2], ys[e2], xs[b2], ys[b2])
                if t then
                    local key = e1 .. ':' .. e2
                    local flipped = flips and flips[key] or false
                    crossings[#crossings + 1] = {
                        key = key, e1 = e1, e2 = e2, flipped = flipped,
                        x = xs[e1] + (xs[a2] - xs[e1]) * t, y = ys[e1] + (ys[a2] - ys[e1]) * t,
                        s1 = L.arc[e1] + t * edgeLen(L, e1), s2 = L.arc[e2] + u * edgeLen(L, e2),
                        lane1 = flipped and lib.FRONT or lib.BACK,
                        lane2 = flipped and lib.BACK or lib.FRONT,
                    }
                end
            end
        end
    end
    return crossings
end

-- what each crossing asks of the stretch at its arc position, in arc order
local function wishesOf(crossings)
    local wants = {}
    for _, c in ipairs(crossings) do
        wants[#wants + 1] = { s = c.s1, lane = c.lane1 }
        wants[#wants + 1] = { s = c.s2, lane = c.lane2 }
    end
    table.sort(wants, function(a, b) return a.s < b.s end)
    return wants
end

-- the arc span from a to b (forward, around a loop)
local function spanOf(a, b, total)
    local span = b - a
    if span < 0 then span = span + total end
    return span
end

-- where the lane changes: halfway between neighbouring wishes for different lanes
local function laneChanges(L, wants)
    local changes = {}
    local m = #wants
    local last = L.closed and m or m - 1
    for k = 1, last do
        local a, b = wants[k], wants[k % m + 1]
        if a.lane ~= b.lane then
            local mid = a.s + spanOf(a.s, b.s, L.total) / 2
            if mid >= L.total then mid = mid - L.total end
            changes[#changes + 1] = mid
        end
    end
    return changes
end

-- the nearest wish at or before s and the next after it (around a loop; at the ends of an open line the one there is)
local function wishesAround(L, wants, s)
    local before, after = nil, nil
    for k = 1, #wants do
        if wants[k].s <= s then before = wants[k] elseif not after then after = wants[k] end
    end
    if L.closed then return before or wants[#wants], after or wants[1] end
    return before or after, after or before
end

-- each point's lane: as its wishes around it ask; between two that differ, the change is halfway
local function assignLanes(L, wants)
    local lane = {}
    for i = 1, L.n do
        if #wants == 0 then
            lane[i] = lib.FRONT
        else
            local s = L.arc[i]
            local before, after = wishesAround(L, wants, s)
            if before.lane == after.lane then
                lane[i] = before.lane
            else
                local into = spanOf(before.s, s, L.total)
                lane[i] = (into < spanOf(before.s, after.s, L.total) / 2) and before.lane or after.lane
            end
        end
    end
    return lane
end

-- the drawn depth per point (0 front .. 1 back): its lane, eased across each change
local function easeDepth(L, lane, changes)
    local depth = {}
    for i = 1, L.n do
        local d = lane[i] == lib.BACK and 1 or 0
        for _, mid in ipairs(changes) do
            local gap = arcGap(L.arc[i], mid, L.total, L.closed)
            if gap < lib.TRANSITION then
                local eased = smootherstep(0.5 + 0.5 * gap / lib.TRANSITION) -- 0.5 at the change, 1 at TRANSITION
                d = (lane[i] == lib.BACK) and eased or (1 - eased)
            end
        end
        depth[i] = d
    end
    return depth
end

-- each edge: solid for its own lane only near a crossing on it, for both lanes elsewhere
local function edgeMasks(L, crossings, lane)
    local mask = {}
    for e = 1, L.edges do
        local mid = L.arc[e] + edgeLen(L, e) / 2
        local near = false
        for _, c in ipairs(crossings) do
            if arcGap(mid, c.s1, L.total, L.closed) < lib.CROSS_MARGIN
                or arcGap(mid, c.s2, L.total, L.closed) < lib.CROSS_MARGIN then
                near = true
                break
            end
        end
        mask[e] = near and lane[e] or BOTH
    end
    return mask
end

-- The layout of a track, in body-local coordinates: xs, ys, arc (per point), total, edges, crossings,
-- lane (per point), depth (per point, 0 front .. 1 back, eased), mask (per edge), changes (arc positions).
local function computeLayout(thing)
    local track = thing.track or {}
    local L = linePoints(thing, track.closed or false)
    L.crossings = findCrossings(L, track.flips)
    local wants = wishesOf(L.crossings)
    L.changes = laneChanges(L, wants)
    L.lane = assignLanes(L, wants)
    L.depth = easeDepth(L, L.lane, L.changes)
    L.mask = edgeMasks(L, L.crossings, L.lane)
    return L
end

local layoutCache = setmetatable({}, { __mode = 'k' })

local function flipsKey(track)
    local keys = {}
    for k, on in pairs(track and track.flips or {}) do if on then keys[#keys + 1] = k end end
    table.sort(keys)
    return table.concat(keys, ',')
end

-- the layout of a track thing, made again when its line, closedness or flips change
function lib.layout(thing)
    local cached = layoutCache[thing]
    local fk = flipsKey(thing.track)
    local closed = thing.track and thing.track.closed or false
    if cached and cached.vertices == thing.vertices and cached.flips == fk and cached.closed == closed then
        return cached.layout
    end
    local layout = computeLayout(thing)
    layoutCache[thing] = { vertices = thing.vertices, flips = fk, closed = closed, layout = layout }
    return layout
end

function lib.isTrack(thing) return thing ~= nil and thing.shapeType == lib.SHAPE_TYPE and thing.vertices ~= nil end

---------------------------------------------------------------- movers and their lanes

-- the track thing a fixture belongs to (its chain), or false; looked up once per fixture
local trackOfFixture = setmetatable({}, { __mode = 'k' })
local function trackOf(fixture)
    local known = trackOfFixture[fixture]
    if known ~= nil then return known end
    local found = false
    if fixture:getType() == 'chain' then
        local ud = fixture:getBody():getUserData()
        local thing = ud and ud.thing
        if lib.isTrack(thing) then found = thing end
    end
    trackOfFixture[fixture] = found
    return found
end
lib.trackOf = trackOf

local function movers()
    state.trackMovers = state.trackMovers or setmetatable({}, { __mode = 'k' })
    return state.trackMovers
end

-- the nearest point to body-local x, y, walking from `from` while it gets nearer (both ways)
local function nearestFrom(layout, from, x, y)
    local n, xs, ys, closed = layout.n, layout.xs, layout.ys, layout.closed
    local function d2(i) return (xs[i] - x) ^ 2 + (ys[i] - y) ^ 2 end
    local best, bestD = from, d2(from)
    for _, step in ipairs({ 1, -1 }) do
        local i = from
        while true do
            local j = i + step
            if closed then
                j = (j - 1) % n + 1
            elseif j < 1 or j > n then
                break
            end
            if j == from then break end
            local dj = d2(j)
            if dj < bestD then
                best, bestD, i = j, dj, j
            elseif dj > d2(i) then
                break
            else
                i = j
            end
        end
    end
    return best, math.sqrt(bestD)
end

local function nearestAll(layout, x, y)
    local best, bestD = 1, math.huge
    for i = 1, layout.n do
        local d = (layout.xs[i] - x) ^ 2 + (layout.ys[i] - y) ^ 2
        if d < bestD then best, bestD = i, d end
    end
    return best, math.sqrt(bestD)
end

-- preSolve: a mover touching a track edge of the other lane doesn't touch it
function lib.onPreSolve(fix1, fix2, contact)
    local thing, other, edge
    local t1, t2 = trackOf(fix1), trackOf(fix2)
    if t1 and not t2 then
        thing, other = t1, fix2
        edge = (contact:getChildren())
    elseif t2 and not t1 then
        thing, other = t2, fix1
        edge = select(2, contact:getChildren())
    else
        return
    end
    local body = other:getBody()
    if body:getType() == 'static' then return end
    local layout = lib.layout(thing)
    local mask = layout.mask[edge]
    if not mask then return end
    local list = movers()
    local m = list[body]
    if not m or m.thing ~= thing then
        -- first touch: the lane of the edge it touched
        local lane = (mask == BOTH) and layout.lane[edge] or mask
        m = { thing = thing, idx = edge, lane = lane, away = 0 }
        list[body] = m
    end
    m.away = 0
    if mask ~= BOTH and mask ~= m.lane then contact:setEnabled(false) end -- no `bit`: the web build is PUC Lua
end

-- after the physics step: each mover's lane is its nearest point's; one far from its track lets go
function lib.update(dt)
    local list = state.trackMovers
    if not list then return end
    for body, m in pairs(list) do
        local thing = m.thing
        if body:isDestroyed() or not thing.body or thing.body:isDestroyed() then
            list[body] = nil
        else
            local layout = lib.layout(thing)
            if layout.n < 2 then
                list[body] = nil
            else
                local lx, ly = thing.body:getLocalPoint(body:getPosition())
                if m.idx > layout.n then m.idx = nearestAll(layout, lx, ly) end
                local idx, dist = nearestFrom(layout, m.idx, lx, ly)
                m.idx = idx
                m.lane = layout.lane[idx]
                if dist > lib.AWAY_DIST then
                    m.away = m.away + (dt or 0)
                    if m.away > lib.AWAY_TIME then list[body] = nil end
                end
            end
        end
    end
end

-- the lane a body rides in now (nil: not on a track), for draw order and tests
function lib.laneOf(body)
    local m = state.trackMovers and state.trackMovers[body]
    return m and m.lane
end

---------------------------------------------------------------- picking

-- is world x, y within PICK_DIST of this fixture's track line (clicking picks a track: a chain has no inside)
function lib.hits(fixture, wx, wy, tolerance)
    local thing = trackOf(fixture)
    if not thing then return false end
    local layout = lib.layout(thing)
    local lx, ly = thing.body:getLocalPoint(wx, wy)
    local tol2 = (tolerance or lib.PICK_DIST) ^ 2
    local xs, ys, n = layout.xs, layout.ys, layout.n
    for e = 1, layout.edges do
        local j = e % n + 1
        local ax, ay, bx, by = xs[e], ys[e], xs[j], ys[j]
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local t = len2 > 0 and math.max(0, math.min(1, ((lx - ax) * dx + (ly - ay) * dy) / len2)) or 0
        local px, py = ax + dx * t - lx, ay + dy * t - ly
        if px * px + py * py <= tol2 then return true end
    end
    return false
end

---------------------------------------------------------------- drawing

local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end

-- per point: the unit normal (averaged over its two edges)
local function normals(layout)
    local n, xs, ys, closed = layout.n, layout.xs, layout.ys, layout.closed
    local nx, ny = {}, {}
    for i = 1, n do
        local p = (i > 1) and i - 1 or (closed and n or i)
        local q = (i < n) and i + 1 or (closed and 1 or i)
        local dx, dy = xs[q] - xs[p], ys[q] - ys[p]
        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then len = 1 end
        nx[i], ny[i] = -dy / len, dx / len
    end
    return nx, ny
end

-- the track's mesh for one lane: both rails and the sleepers of the edges in that lane, coloured by
-- depth per vertex (so a lane change eases, no step). Body-local.
local function buildMesh(layout, lane)
    local verts = {}
    local nx, ny = normals(layout)
    local xs, ys, n, depth = layout.xs, layout.ys, layout.n, layout.depth
    local function colourAt(i, base)
        local c = mix(base, HAZE, depth[i] * HAZE_BACK)
        return c[1], c[2], c[3]
    end
    local function quad(ax, ay, bx, by, cx, cy, dx, dy, r1, g1, b1, r2, g2, b2)
        -- a-b on the first end, c-d on the second
        verts[#verts + 1] = { ax, ay, 0, 0, r1, g1, b1, 1 }
        verts[#verts + 1] = { bx, by, 0, 0, r1, g1, b1, 1 }
        verts[#verts + 1] = { cx, cy, 0, 0, r2, g2, b2, 1 }
        verts[#verts + 1] = { bx, by, 0, 0, r1, g1, b1, 1 }
        verts[#verts + 1] = { dx, dy, 0, 0, r2, g2, b2, 1 }
        verts[#verts + 1] = { cx, cy, 0, 0, r2, g2, b2, 1 }
    end
    local hw = lib.RAIL_W / 2
    -- sleepers first (under the rails)
    for e = 1, layout.edges do
        if layout.lane[e] == lane and (e - 1) % lib.SLEEPER_EVERY == 0 then
            local j = e % n + 1
            local tx, ty = xs[j] - xs[e], ys[j] - ys[e]
            local tl = math.sqrt(tx * tx + ty * ty)
            if tl > 0 then
                tx, ty = tx / tl * lib.SLEEPER_W / 2, ty / tl * lib.SLEEPER_W / 2
                local reach = lib.RAIL_GAP + lib.RAIL_W
                local x, y = xs[e], ys[e]
                local r, g, b = colourAt(e, SLEEPER_FRONT)
                quad(x - tx + nx[e] * reach, y - ty + ny[e] * reach, x + tx + nx[e] * reach, y + ty + ny[e] * reach,
                    x - tx - nx[e] * reach, y - ty - ny[e] * reach, x + tx - nx[e] * reach, y + ty - ny[e] * reach,
                    r, g, b, r, g, b)
            end
        end
    end
    -- the rails: a strip each side, one quad per edge
    for _, side in ipairs({ -1, 1 }) do
        for e = 1, layout.edges do
            if layout.lane[e] == lane then
                local j = e % n + 1
                local o1 = side * lib.RAIL_GAP
                local ax, ay = xs[e] + nx[e] * o1, ys[e] + ny[e] * o1
                local bx, by = xs[j] + nx[j] * o1, ys[j] + ny[j] * o1
                local r1, g1, b1 = colourAt(e, RAIL_FRONT)
                local r2, g2, b2 = colourAt(j, RAIL_FRONT)
                quad(ax + nx[e] * hw, ay + ny[e] * hw, ax - nx[e] * hw, ay - ny[e] * hw,
                    bx + nx[j] * hw, by + ny[j] * hw, bx - nx[j] * hw, by - ny[j] * hw,
                    r1, g1, b1, r2, g2, b2)
            end
        end
    end
    if #verts == 0 then return false end
    return love.graphics.newMesh(verts, 'triangles', 'static')
end

local meshCache = setmetatable({}, { __mode = 'k' }) -- layout -> { [lane] = mesh or false }

local function meshFor(layout, lane)
    local m = meshCache[layout]
    if not m then
        m = {}
        meshCache[layout] = m
    end
    if m[lane] == nil then m[lane] = buildMesh(layout, lane) end
    return m[lane]
end

-- every track in the world (live)
function lib.list()
    local out = {}
    local world = state.physicsWorld
    if not world then return out end
    for _, body in ipairs(world:getBodies()) do
        local ud = body:getUserData()
        local thing = ud and ud.thing
        if lib.isTrack(thing) then out[#out + 1] = thing end
    end
    return out
end

local function drawLane(lane)
    for _, thing in ipairs(lib.list()) do
        local layout = lib.layout(thing)
        if layout.n >= 2 then
            local mesh = meshFor(layout, lane)
            if mesh then
                local body = thing.body
                love.graphics.push()
                love.graphics.translate(body:getX(), body:getY())
                love.graphics.rotate(body:getAngle())
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(mesh)
                love.graphics.pop()
            end
        end
    end
end

-- an engine system (src/systems.lua): the back lane behind the bodies, the front lane over them
function lib.drawBelow() drawLane(lib.BACK) end
function lib.draw() drawLane(lib.FRONT) end

return lib
