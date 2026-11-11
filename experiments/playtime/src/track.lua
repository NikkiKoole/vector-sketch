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

-- the stretches a track can be painted with (COASTER CO4, after achtbaan's hoist / accelerate / decelerate
-- / flip); what they do to a cart is src/rail-cart.lua's. thing.track.marks: a character per point.
lib.ZONES = {
    lift  = { char = 'l', colour = { 0.95, 0.80, 0.20 } }, -- a chain: pulls a slower cart up to a steady speed
    boost = { char = 'b', colour = { 0.35, 0.80, 0.35 } }, -- tyres: push it on the way it's going
    brake = { char = 'k', colour = { 0.85, 0.30, 0.25 } }, -- fins: slow it to a crawl
    roll  = { char = 'r', colour = { 0.90, 0.45, 0.80 } }, -- a corkscrew: it rolls round the rail to its other side
}
lib.ZONE_ORDER = { 'lift', 'boost', 'brake', 'roll' }
local ZONE_OF_CHAR = {}
for name, zone in pairs(lib.ZONES) do ZONE_OF_CHAR[zone.char] = name end
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

---------------------------------------------------------------- painting while drawing (keys held)

-- the zone the held keys paint while drawing a track, as in dreamengine's coaster: h hoist (lift),
-- b boost, s slow (brake), f flip (roll); nil: plain
lib.STROKE_KEYS = { { 'h', 'lift' }, { 'b', 'boost' }, { 's', 'brake' }, { 'f', 'roll' } }
function lib.heldBrush()
    for _, pair in ipairs(lib.STROKE_KEYS) do
        if love.keyboard.isDown(pair[1]) then return pair[2] end
    end
    return nil
end

-- the zones recorded for a stroke's points (one per point of polyVerts, false: plain), kept with that
-- very table so a new stroke starts clean
function lib.strokeBrushes(polyVerts)
    local rec = state.trackStroke
    if not rec or rec.verts ~= polyVerts then
        rec = { verts = polyVerts, list = {} }
        state.trackStroke = rec
    end
    return rec.list
end

-- the stroke just got a point: note the zone the held keys paint there
function lib.recordStrokePoint(polyVerts)
    lib.strokeBrushes(polyVerts)[#polyVerts / 2] = lib.heldBrush() or false
end

-- the stroke being drawn, each piece in the colour of the zone painted on it
function lib.drawStroke(polyVerts)
    local list = lib.strokeBrushes(polyVerts)
    local lineWidth = love.graphics.getLineWidth()
    for i = 1, #polyVerts / 2 - 1 do
        local zone = list[i] and lib.ZONES[list[i]]
        if zone then
            love.graphics.setColor(zone.colour[1], zone.colour[2], zone.colour[3], 1)
            love.graphics.setLineWidth(lineWidth * 4)
        else
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(lineWidth)
        end
        love.graphics.line(polyVerts[i * 2 - 1], polyVerts[i * 2], polyVerts[i * 2 + 1], polyVerts[i * 2 + 2])
    end
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(1, 1, 1, 1)
end

-- the marks for the centre line: each of its points takes the zone of the stroke at the same share of the
-- way along (smoothing and resampling change the points, not where along it a zone is)
local function marksAlong(pts, brushes, out)
    local rawArc, rawTotal = { 0 }, 0
    for i = 2, #pts do
        rawTotal = rawTotal + math.sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2)
        rawArc[i] = rawTotal
    end
    local outTotal = lengthOf(out)
    local chars, any, acc, k = {}, false, 0, 1
    for j = 1, #out do
        if j > 1 then acc = acc + math.sqrt((out[j][1] - out[j - 1][1]) ^ 2 + (out[j][2] - out[j - 1][2]) ^ 2) end
        local target = outTotal > 0 and acc / outTotal * rawTotal or 0
        while k < #pts - 1 and rawArc[k + 1] <= target do k = k + 1 end
        local zone = brushes[k] and lib.ZONES[brushes[k]]
        chars[j] = zone and zone.char or '.'
        any = any or zone ~= nil
    end
    if not any then return nil end
    return (table.concat(chars):gsub('%.+$', ''))
end

-- A drawn stroke (flat world x, y, ...) -> the centre line (flat), whether it closes, and the marks for
-- its points (from `brushes`, a zone or false per stroke point, as held while drawing), or nil.
function lib.fromStroke(flat, brushes)
    local pts = {}
    for i = 1, #flat - 1, 2 do pts[#pts + 1] = { flat[i], flat[i + 1] } end
    if #pts < 2 or lengthOf(pts) < lib.SPACING * 3 then return nil end
    local raw = pts
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
    local marks = brushes and marksAlong(raw, brushes, pts) or nil
    return out, closed, marks
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

-- each point's zone (nil: plain track), from thing.track.marks
local function zonesOf(L, marks)
    local zone = {}
    marks = marks or ''
    for i = 1, L.n do zone[i] = ZONE_OF_CHAR[marks:sub(i, i)] end
    return zone
end

-- the roll stretches: each run of roll points as an arc range { s0, s1 }, in arc order
local function rollRuns(L)
    local runs = {}
    local i = 1
    while i <= L.n do
        if L.zone[i] == 'roll' then
            local j = i
            while j < L.n and L.zone[j + 1] == 'roll' do j = j + 1 end
            local s1 = (j < L.n or L.closed) and L.arc[j] + edgeLen(L, j) or L.arc[j] -- up to the next point
            if s1 - L.arc[i] >= 1 then runs[#runs + 1] = { s0 = L.arc[i], s1 = s1 } end
            i = j + 1
        else
            i = i + 1
        end
    end
    return runs
end

-- The layout of a track, in body-local coordinates: xs, ys, arc (per point), total, edges, crossings,
-- lane (per point), depth (per point, 0 front .. 1 back, eased), mask (per edge), changes (arc positions),
-- zone (per point), rolls (arc ranges).
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

-- the layout with its painted zones: the base shared (painting doesn't search the crossings again, which
-- is every edge against every edge), a table of its own so the meshes are made again
local function withZones(base, marks)
    local L = setmetatable({}, { __index = base })
    for k, v in pairs(base) do L[k] = v end
    L.zone = zonesOf(L, marks)
    L.rolls = rollRuns(L)
    return L
end

local layoutCache = setmetatable({}, { __mode = 'k' })

local function flipsKey(track)
    local keys = {}
    for k, on in pairs(track and track.flips or {}) do if on then keys[#keys + 1] = k end end
    table.sort(keys)
    return table.concat(keys, ',')
end

-- the layout of a track thing, made again when its line, closedness, flips or painted zones change
function lib.layout(thing)
    local cached = layoutCache[thing]
    local fk = flipsKey(thing.track)
    local closed = thing.track and thing.track.closed or false
    local marks = thing.track and thing.track.marks or ''
    local sameBase = cached and cached.vertices == thing.vertices and cached.flips == fk and cached.closed == closed
    if sameBase and cached.marks == marks then return cached.layout end
    local base = sameBase and cached.base or computeLayout(thing)
    local layout = withZones(base, marks)
    layoutCache[thing] = { vertices = thing.vertices, flips = fk, closed = closed, marks = marks, base = base,
        layout = layout }
    return layout
end

-- how far round its rail a cart at s has rolled (radians): pi for every roll stretch passed (each lap
-- round a loop counts them all again), part of pi inside one
function lib.rollAt(layout, s)
    local runs = layout.rolls
    if not runs or #runs == 0 then return 0 end
    local within, done = s, 0
    if layout.closed then
        local laps = math.floor(s / layout.total)
        within, done = s - laps * layout.total, laps * #runs
    end
    local partial = 0
    for _, run in ipairs(runs) do
        if within >= run.s1 then
            done = done + 1
        elseif within > run.s0 then
            partial = (within - run.s0) / (run.s1 - run.s0)
        end
    end
    return (done + partial) * math.pi
end

-- paint the points within radius of world x, y with a zone ('lift', 'boost', 'brake', 'roll') or 'clear';
-- true when something changed
function lib.paint(thing, wx, wy, radius, brush)
    if not lib.isTrack(thing) then return false end
    local layout = lib.layout(thing)
    thing.track = thing.track or { closed = false }
    local ch = (brush == 'clear') and '.' or (lib.ZONES[brush] and lib.ZONES[brush].char)
    if not ch then return false end
    local marks = thing.track.marks or ''
    local chars = {}
    for i = 1, layout.n do
        local c = marks:sub(i, i)
        chars[i] = (c == '') and '.' or c
    end
    local lx, ly = thing.body:getLocalPoint(wx, wy)
    local r2, changed = radius * radius, false
    for i = 1, layout.n do
        if (layout.xs[i] - lx) ^ 2 + (layout.ys[i] - ly) ^ 2 <= r2 and chars[i] ~= ch then
            chars[i], changed = ch, true
        end
    end
    if changed then
        local joined = table.concat(chars):gsub('%.+$', '') -- trailing plain points: nothing kept
        thing.track.marks = (joined ~= '') and joined or nil
    end
    return changed
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
    if state.railCarts and state.railCarts[body] then -- a cart on its rail: held by the lock, touches no rail
        contact:setEnabled(false)
        return
    end
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

---------------------------------------------------------------- along the line (for carts, src/rail-cart.lua)

-- the point and unit direction at arc position s (body-local), and its edge; s wraps on a loop and is
-- clamped on an open line (inside reports whether s was on it)
function lib.pointAt(layout, s)
    local total = layout.total
    local inside = true
    if layout.closed then
        s = s % total
    elseif s < 0 or s > total then
        inside = false
        s = math.max(0, math.min(total, s))
    end
    local arc, xs, ys, n = layout.arc, layout.xs, layout.ys, layout.n
    local lo, hi = 1, layout.edges -- the last edge whose start is at or before s
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if arc[mid] <= s then lo = mid else hi = mid - 1 end
    end
    local e = lo
    local j = e % n + 1
    local dx, dy = xs[j] - xs[e], ys[j] - ys[e]
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return xs[e], ys[e], 1, 0, e, inside end
    local t = math.max(0, math.min(1, (s - arc[e]) / len))
    return xs[e] + dx * t, ys[e] + dy * t, dx / len, dy / len, e, inside
end

-- how fast the direction turns at s (radians per unit of arc, + turning clockwise on screen)
function lib.curvatureAt(layout, s, h)
    h = h or lib.SPACING
    local _, _, ax, ay = lib.pointAt(layout, s - h)
    local _, _, bx, by = lib.pointAt(layout, s + h)
    local d = math.atan2(by, bx) - math.atan2(ay, ax)
    if d > math.pi then d = d - 2 * math.pi elseif d < -math.pi then d = d + 2 * math.pi end
    return d / (2 * h)
end

-- the arc position nearest body-local x, y, and how far it is (looks at every edge)
function lib.nearestArc(layout, lx, ly)
    local xs, ys, n = layout.xs, layout.ys, layout.n
    local bestS, bestD = 0, math.huge
    for e = 1, layout.edges do
        local j = e % n + 1
        local dx, dy = xs[j] - xs[e], ys[j] - ys[e]
        local len2 = dx * dx + dy * dy
        local t = len2 > 0 and math.max(0, math.min(1, ((lx - xs[e]) * dx + (ly - ys[e]) * dy) / len2)) or 0
        local px, py = xs[e] + dx * t - lx, ys[e] + dy * t - ly
        local d = px * px + py * py
        if d < bestD then bestS, bestD = layout.arc[e] + t * math.sqrt(len2), d end
    end
    return bestS, math.sqrt(bestD)
end

---------------------------------------------------------------- editing the points (the inspector's 'verts unlocked')
-- `verts` is the edited copy of thing.vertices (state.polyEdit.tempVerts, the same space); the body is
-- made again from it when the drag ends (src/poly-edit.lua maybeUpdateCustomPolygonVertices).

lib.DRAG_REACH = 160 -- dragging a point moves its neighbours this far along the track, less with distance

-- point i's neighbours follow its move (dx, dy, already applied to i), eased off by distance along the line
-- (measured where the points were before the move)
function lib.dragNeighbours(verts, i, dx, dy, closed, reach)
    reach = reach or lib.DRAG_REACH
    local n = #verts / 2
    local function at(k) -- where point k was before this move
        if k == i then return verts[k * 2 - 1] - dx, verts[k * 2] - dy end
        return verts[k * 2 - 1], verts[k * 2]
    end
    for _, step in ipairs({ 1, -1 }) do
        local moves, prev, along = {}, i, 0
        for _ = 1, n - 1 do
            local j = prev + step
            if closed then
                j = (j - 1) % n + 1
            elseif j < 1 or j > n then
                break
            end
            if j == i then break end
            local px, py = at(prev)
            local jx, jy = at(j)
            along = along + math.sqrt((jx - px) ^ 2 + (jy - py) ^ 2)
            if along >= reach then break end
            moves[#moves + 1] = { j, 0.5 * (1 + math.cos(math.pi * along / reach)) }
            prev = j
        end
        for _, m in ipairs(moves) do
            verts[m[1] * 2 - 1] = verts[m[1] * 2 - 1] + dx * m[2]
            verts[m[1] * 2] = verts[m[1] * 2] + dy * m[2]
        end
    end
end

-- the painted marks follow an inserted (+1) or removed (-1) point at i
local function shiftMarks(thing, i, change)
    local marks = thing.track and thing.track.marks
    if not marks or i > #marks + 1 then return end
    if change > 0 then
        local copy = marks:sub(i - 1, i - 1) -- a new point takes the zone of the one before it
        marks = marks:sub(1, i - 1) .. ((copy ~= '') and copy or '.') .. marks:sub(i)
    else
        marks = marks:sub(1, i - 1) .. marks:sub(i + 1)
    end
    marks = marks:gsub('%.+$', '')
    thing.track.marks = (marks ~= '') and marks or nil
end

-- the point of verts nearest x, y (verts' space) and how far
local function nearestPoint(verts, x, y)
    local best, bestD = nil, math.huge
    for i = 1, #verts / 2 do
        local d = (verts[i * 2 - 1] - x) ^ 2 + (verts[i * 2] - y) ^ 2
        if d < bestD then best, bestD = i, d end
    end
    return best, math.sqrt(bestD)
end

-- a point on the edge nearest x, y (an open track has no edge from its end back to its start); true if made
function lib.insertPoint(thing, verts, x, y)
    local n = #verts / 2
    local closed = thing.track and thing.track.closed
    local edges = closed and n or n - 1
    local bestE, bestD, bestX, bestY = nil, math.huge, 0, 0
    for e = 1, edges do
        local j = e % n + 1
        local ax, ay, bx, by = verts[e * 2 - 1], verts[e * 2], verts[j * 2 - 1], verts[j * 2]
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local t = len2 > 0 and math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy) / len2)) or 0
        local px, py = ax + dx * t, ay + dy * t
        local d = (px - x) ^ 2 + (py - y) ^ 2
        if d < bestD then bestE, bestD, bestX, bestY = e, d, px, py end
    end
    if not bestE then return false end
    table.insert(verts, bestE * 2 + 1, bestX)
    table.insert(verts, bestE * 2 + 2, bestY)
    shiftMarks(thing, bestE + 1, 1)
    return true
end

-- remove the point nearest x, y if it's within maxDist (a track keeps at least 3); true if removed
function lib.removePoint(thing, verts, x, y, maxDist)
    if #verts / 2 <= 3 then return false end
    local i, d = nearestPoint(verts, x, y)
    if not i or d > maxDist then return false end
    table.remove(verts, i * 2)
    table.remove(verts, i * 2 - 1)
    shiftMarks(thing, i, -1)
    return true
end

-- close a track into a loop (a bridge of points from its end back to its start) or open it; the new
-- points, for the body to be made again from
function lib.setClosed(thing, closed)
    thing.track = thing.track or {}
    local verts = {}
    for i = 1, #thing.vertices do verts[i] = thing.vertices[i] end
    if closed then
        local n = #verts / 2
        local ax, ay, bx, by = verts[n * 2 - 1], verts[n * 2], verts[1], verts[2]
        local gap = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local steps = math.floor(gap / lib.SPACING)
        for k = 1, steps - 1 do
            verts[#verts + 1] = ax + (bx - ax) * k / steps
            verts[#verts + 1] = ay + (by - ay) * k / steps
        end
    end
    thing.track.closed = closed
    return verts
end

---------------------------------------------------------------- crossings in the editor (COASTER CO2)

lib.MARKER_PX = 13 -- a crossing's marker, in screen pixels (clicking within it swaps over and under)

-- the crossing of this track whose marker is at world x, y (radius in world units), or nil
function lib.crossingAt(thing, wx, wy, radius)
    if not lib.isTrack(thing) or thing.body:isDestroyed() then return nil end
    local lx, ly = thing.body:getLocalPoint(wx, wy)
    local best, bestD = nil, radius * radius
    for _, c in ipairs(lib.layout(thing).crossings) do
        local d = (c.x - lx) ^ 2 + (c.y - ly) ^ 2
        if d <= bestD then best, bestD = c, d end
    end
    return best
end

-- swap which stretch goes over at this crossing (kept in thing.track.flips, saved with the body); the
-- layout and the meshes are made again from it, movers take their new lanes next update
function lib.flipCrossing(thing, crossing)
    thing.track = thing.track or { closed = false }
    thing.track.flips = thing.track.flips or {}
    local now = not thing.track.flips[crossing.key]
    thing.track.flips[crossing.key] = now or nil
end

-- the selected track's crossings: a ring each, the stretch in front drawn through it whole and the one
-- behind broken (a knot drawing). invZoom: world units per screen pixel.
function lib.drawCrossings(thing, invZoom)
    if not lib.isTrack(thing) or thing.body:isDestroyed() then return end
    local layout = lib.layout(thing)
    if #layout.crossings == 0 then return end
    local xs, ys, n = layout.xs, layout.ys, layout.n
    local r = lib.MARKER_PX * invZoom
    local function dir(e)
        local j = e % n + 1
        local dx, dy = xs[j] - xs[e], ys[j] - ys[e]
        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then return 1, 0 end
        return dx / len, dy / len
    end
    local lineWidth = love.graphics.getLineWidth()
    love.graphics.push()
    love.graphics.translate(thing.body:getX(), thing.body:getY())
    love.graphics.rotate(thing.body:getAngle())
    for _, c in ipairs(layout.crossings) do
        local frontE = (layout.lane[c.e2] == lib.FRONT) and c.e2 or c.e1
        local backE = (frontE == c.e2) and c.e1 or c.e2
        love.graphics.setColor(0.1, 0.1, 0.12, 0.85)
        love.graphics.circle('fill', c.x, c.y, r)
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.setLineWidth(2 * invZoom)
        love.graphics.circle('line', c.x, c.y, r)
        -- behind: two stubs with a gap where the front one passes
        local bx, by = dir(backE)
        love.graphics.setColor(0.65, 0.68, 0.74, 1)
        love.graphics.setLineWidth(2.5 * invZoom)
        love.graphics.line(c.x - bx * r * 0.8, c.y - by * r * 0.8, c.x - bx * r * 0.35, c.y - by * r * 0.35)
        love.graphics.line(c.x + bx * r * 0.35, c.y + by * r * 0.35, c.x + bx * r * 0.8, c.y + by * r * 0.8)
        -- in front: whole
        local fx, fy = dir(frontE)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(3.5 * invZoom)
        love.graphics.line(c.x - fx * r * 0.8, c.y - fy * r * 0.8, c.x + fx * r * 0.8, c.y + fy * r * 0.8)
    end
    love.graphics.pop()
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(1, 1, 1, 1)
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
    -- sleepers first (under the rails); in a painted zone every point gets one, wider, in its colour
    for e = 1, layout.edges do
        local zone = layout.zone[e] and lib.ZONES[layout.zone[e]]
        if layout.lane[e] == lane and (zone or (e - 1) % lib.SLEEPER_EVERY == 0) then
            local j = e % n + 1
            local tx, ty = xs[j] - xs[e], ys[j] - ys[e]
            local tl = math.sqrt(tx * tx + ty * ty)
            if tl > 0 then
                local w = zone and lib.SLEEPER_W * 2 or lib.SLEEPER_W
                tx, ty = tx / tl * w / 2, ty / tl * w / 2
                local reach = lib.RAIL_GAP + lib.RAIL_W + (zone and 2 or 0)
                local x, y = xs[e], ys[e]
                local r, g, b = colourAt(e, zone and zone.colour or SLEEPER_FRONT)
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
