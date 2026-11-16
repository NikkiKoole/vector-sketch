-- book-flaps: a flap, as in a lift-the-flap book (Spot, Usborne Peep Inside). Shared by the belly spike (the
-- whale's skin, the pouch) and the book spike (doors, windows, a bush, the page turn). Loaded with
-- love.filesystem.load('scripts/spikes/book-flaps.lua')(), so it runs in the plain globals.
--
-- A flap is a polygon hinged along a line that folds toward you, squashed across the hinge by the cosine of its
-- angle: past flat it turns over and shows its darker back, and what was under it. It can curl: the far end of the
-- hinge opens later than the near end.
--   def = { hingeY = y (a horizontal hinge) or hingeX = x (a vertical one: doors, a page turn),
--           from, to   the curl runs along the hinge from `from` to `to` (x for a horizontal hinge, y for a vertical)
--           angle      open (past pi/2 it lies foreshortened; pi folds it flat onto the other side)
--           spread     the curl: how much later the `to` end opens
--           drag       world units of drag for a full open
--           pull       { dx, dy }: the way a drag opens it (default {0, 1}: down)
--           height     how far it reaches from the hinge (to find it when it's open)
--           stiffness, damping   its spring when let go (default 90, 11: quick, a little overshoot)
--           outside, inside, edge, edgeWidth   colours
--           decorate = function(def, st)   drawn after the faces (check flap.fold's c to draw on the outside only)
--           grab = function(def, st, x, y)  where a press takes it (default: inside the polygon, or on it open) }
--   st  = flap.state(store, key): { open, v, target, drag } — keep the store on state, so a reload keeps it
-- flap.press / release / update follow a finger (let go past halfway and it finishes, a tap toggles), else a
-- spring with a little overshoot. flap.draw(def, st, polygon). flap.contains(def, st, polygon, x, y).
local flap = {}

local function insidePoly(pts, x, y)
    local inPoly, n = false, #pts / 2
    local j = n
    for i = 1, n do
        local xi, yi, xj, yj = pts[2 * i - 1], pts[2 * i], pts[2 * j - 1], pts[2 * j]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inPoly = not inPoly end
        j = i
    end
    return inPoly
end
flap.insidePoly = insidePoly

function flap.state(store, key)
    store[key] = store[key] or { open = 0, v = 0, target = 0 }
    return store[key]
end

-- the angle of the flap at a point along its hinge (a = x for a horizontal hinge, y for a vertical one)
function flap.angleAt(def, st, a)
    local u = (a - def.from) / (def.to - def.from)
    local k = math.max(0, math.min(1.08, st.open * (1 + def.spread) - u * def.spread))
    local e = k <= 1 and k * k * (3 - 2 * k) or k -- eased, the overshoot kept
    return def.angle * e
end

-- a point of the flap folded about the hinge; c > 0 while that part shows its outside
function flap.fold(def, st, x, y)
    if def.hingeX then
        local c = math.cos(flap.angleAt(def, st, y))
        return def.hingeX + (x - def.hingeX) * c, y, c
    end
    local c = math.cos(flap.angleAt(def, st, x))
    return x, def.hingeY + (y - def.hingeY) * c, c
end

function flap.foldLine(def, st, pts)
    local out = {}
    for i = 1, #pts, 2 do
        local x, y = flap.fold(def, st, pts[i], pts[i + 1])
        out[#out + 1], out[#out + 2] = x, y
    end
    return out
end

-- on the flap: inside its polygon (closed), or on it folded over beyond the hinge (open)
function flap.contains(def, st, poly, x, y)
    if def.grab then return def.grab(def, st, x, y) end
    if st.open < 0.5 and insidePoly(poly, x, y) then return true end
    if st.open <= 0.3 then return false end
    local over = math.max(0, -math.cos(def.angle * math.min(1, st.open))) * (def.height or 0)
    local pull = def.pull or { 0, 1 }
    if def.hingeX then
        local d = (x - def.hingeX) * (pull[1] >= 0 and 1 or -1)
        local lo, hi = math.min(def.from, def.to), math.max(def.from, def.to)
        return y > lo and y < hi and d > -100 and d < over + 150
    end
    local d = (y - def.hingeY) * (pull[2] >= 0 and 1 or -1)
    local lo, hi = math.min(def.from, def.to), math.max(def.from, def.to)
    return x > lo and x < hi and d > -100 and d < over + 150
end

function flap.press(st, x, y, now) st.drag = { x = x, y = y, open = st.open, t = now, moved = 0 } end

function flap.release(st, now)
    local d = st.drag
    if not d then return end
    if d.moved < 80 and now - d.t < 0.4 then
        st.target = d.open > 0.5 and 0 or 1 -- a tap: open or close
    else
        st.target = st.open > 0.5 and 1 or 0 -- let go: past halfway it finishes
    end
    st.drag = nil
end

function flap.toggle(st) st.target = st.target > 0.5 and 0 or 1 end

-- returns true the frame it starts to open
function flap.update(def, st, dt, mx, my)
    local was = st.open
    local d = st.drag
    if d then
        d.moved = math.max(d.moved, math.abs(my - d.y) + math.abs(mx - d.x))
        local pull = def.pull or { 0, 1 }
        local along = (mx - d.x) * pull[1] + (my - d.y) * pull[2]
        st.open = math.max(0, math.min(1, d.open + along / def.drag))
        st.v = 0
    else
        local a = (def.stiffness or 90) * (st.target - st.open) - (def.damping or 11) * st.v
        st.v = st.v + a * dt
        st.open = math.max(-0.05, math.min(1.08, st.open + st.v * dt))
    end
    return was < 0.05 and st.open >= 0.05
end

function flap.draw(def, st, poly)
    local ok, tris = pcall(love.math.triangulate, poly)
    if not ok then return end
    for _, t in ipairs(tris) do
        local x1, y1, c1 = flap.fold(def, st, t[1], t[2])
        local x2, y2, c2 = flap.fold(def, st, t[3], t[4])
        local x3, y3, c3 = flap.fold(def, st, t[5], t[6])
        local c = (c1 + c2 + c3) / 3
        local col, sh = def.outside, 0.72 + 0.28 * c
        if c < 0 then col, sh = def.inside, 0.65 + 0.35 * -c end
        love.graphics.setColor(col[1] * sh, col[2] * sh, col[3] * sh)
        love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
    end
    if def.decorate then def.decorate(def, st) end
    local edge = flap.foldLine(def, st, poly)
    edge[#edge + 1], edge[#edge + 2] = edge[1], edge[2]
    love.graphics.setColor(def.edge)
    love.graphics.setLineWidth(def.edgeWidth or 12)
    love.graphics.line(edge)
    love.graphics.setLineWidth(1)
end

return flap
