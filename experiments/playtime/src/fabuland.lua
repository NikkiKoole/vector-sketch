-- fabuland.lua — chunky building parts (docs/FABULAND.md): window blocks, door blocks, roofs,
-- stairs, posts, planks, railings, stacked into houses the way Fabuland's were.
--
-- One table, PARTS, is the whole catalogue: a part is a size, a shape, the edges that snap, its
-- colour sets and what's drawn on it. Everything else follows from the entry:
--   * the body (objectManager, so it saves with the scene like anything else); its label is
--     'fab:<part>:<colour set>', which is how the look is found again after a load
--   * stiff snap points (src/physics/snap.lua) at the centres of the 250 grid cells along each
--     snapping edge, counted from the part's left/top edge: two parts whose edges sit on the grid
--     have points on the same spots, and they weld there, square
--   * the look: fill, a darker outline, and its details (windows, doors, shingles, studs)
--   * a button in the fabuland scene's panel (scripts/fabuland.playtime.lua)
-- A spike, parked (docs/FABULAND.md): drawing only runs while a scene sets state.fabuland.on
-- (the fabuland scene does), so elsewhere it costs nothing.
-- To add a part: add an entry to PARTS (and a detail drawer to DETAILS if it needs a new one).
local lib = {}

local objectManager = require('src.object-manager')
local snap = require('src.physics.snap')
local utils = require('src.utils')
local mathutils = require('src.math-utils')
local state = require('src.state')

lib.GRID = 250

local function rgb(r, g, b) return { r / 255, g / 255, b / 255 } end
-- Fabuland's colours, a little warm so they sit with the crayon line
lib.COLORS = {
    yellow = rgb(247, 205, 52), red = rgb(206, 58, 42), blue = rgb(38, 102, 178),
    green = rgb(62, 140, 78), brown = rgb(132, 84, 50), white = rgb(240, 234, 216),
    glass = rgb(200, 226, 232), dark = rgb(48, 34, 28),
}
-- colour sets: body colour and its trim (window frames, doors)
lib.SETS = {
    yellow = { 'yellow', 'blue' }, red = { 'red', 'yellow' }, blue = { 'blue', 'yellow' },
    green = { 'green', 'red' }, brown = { 'brown', 'yellow' }, white = { 'white', 'red' },
}

local B, H = 750, 1000 -- a block: 3 grid cells wide, 4 high; a Mipo (median 658) fits under 1000

-- shape: 'rect' or vertices around the box's centre (flat, x, y, ...). snaps: edges of the
-- box that snap ('top', 'bottom', 'left', 'right'); a shape that doesn't fill its box only
-- lists the edges it does have. details: drawers from DETAILS, in order.
lib.PARTS = {
    { name = 'window block', w = B, h = H, shape = 'rect', snaps = { 'top', 'bottom', 'left', 'right' },
      sets = { 'yellow', 'red', 'blue' }, details = { 'roundWindow', 'studs' } },
    { name = 'wheel window block', w = B, h = H, shape = 'rect', snaps = { 'top', 'bottom', 'left', 'right' },
      sets = { 'yellow', 'red', 'blue' }, details = { 'wheelWindow', 'studs' } },
    { name = 'arch window block', w = B, h = H, shape = 'rect', snaps = { 'top', 'bottom', 'left', 'right' },
      sets = { 'yellow', 'red', 'blue' }, details = { 'archWindow', 'studs' } },
    { name = 'door block', w = B, h = H, shape = 'rect', snaps = { 'top', 'bottom', 'left', 'right' },
      sets = { 'yellow', 'red', 'blue' }, details = { 'door', 'studs' } },
    { name = 'block', w = B, h = H, shape = 'rect', snaps = { 'top', 'bottom', 'left', 'right' },
      sets = { 'yellow', 'red', 'blue', 'white' }, details = { 'studs' } },
    { name = 'half block', w = B, h = H / 2, shape = 'rect', snaps = { 'top', 'bottom', 'left', 'right' },
      sets = { 'yellow', 'red', 'blue', 'white' }, details = { 'studs' } },
    { name = 'roof left', w = B, h = 500, shape = { -B / 2, 250, B / 2, 250, B / 2, -250 },
      snaps = { 'bottom', 'right' }, sets = { 'green', 'red' }, details = { 'shingles' } },
    { name = 'roof right', w = B, h = 500, shape = { -B / 2, 250, B / 2, 250, -B / 2, -250 },
      snaps = { 'bottom', 'left' }, sets = { 'green', 'red' }, details = { 'shingles' } },
    { name = 'stairs', w = B, h = H, shape = { -375, 500, 375, 500, 375, -500, 188, -500, 188, -250, 0, -250,
      0, 0, -188, 0, -188, 250, -375, 250 }, snaps = { 'bottom', 'right' }, sets = { 'red', 'yellow', 'blue' },
      details = {} },
    { name = 'post', w = 125, h = 500, shape = 'rect', snaps = { 'top', 'bottom' },
      sets = { 'brown', 'white', 'red' }, details = {} },
    { name = 'plank', w = 1000, h = 125, shape = 'rect', snaps = { 'top', 'bottom', 'left', 'right' },
      sets = { 'brown', 'yellow', 'red' }, details = {} },
    { name = 'railing', w = B, h = 250, shape = 'rect', snaps = { 'bottom' },
      sets = { 'red', 'white', 'yellow' }, details = { 'railing' } },
}
local byName = {}
for _, part in ipairs(lib.PARTS) do byName[part.name] = part end

-- Grid cell centres along a length, from its start edge (a part shorter than a cell: its middle).
local function cells(length)
    local n = math.floor(length / lib.GRID + 0.5)
    local out = {}
    if n < 1 then return { 0 } end
    for k = 1, n do out[k] = -length / 2 + (k - 0.5) * lib.GRID end
    return out
end

-- Body-space snap point positions for a part (the box's centre is the body's origin).
function lib.snapPoints(part)
    local out = {}
    for _, edge in ipairs(part.snaps) do
        if edge == 'top' or edge == 'bottom' then
            local y = edge == 'top' and -part.h / 2 or part.h / 2
            for _, x in ipairs(cells(part.w)) do out[#out + 1] = { x, y } end
        else
            local x = edge == 'left' and -part.w / 2 or part.w / 2
            for _, y in ipairs(cells(part.h)) do out[#out + 1] = { x, y } end
        end
    end
    return out
end

-- The part and colour set a body is ('fab:<part>:<set>' label), or nil.
function lib.partOf(body)
    local thing = utils.thingOf(body)
    local label = thing and thing.label
    if not label or label:sub(1, 4) ~= 'fab:' then return nil end
    local name, set = label:match('^fab:([^:]+):([^:]+)$')
    return byName[name], set, thing
end

-- Make a part at (x, y) (its box's centre); `set` a colour set name, else one of the part's.
function lib.make(name, x, y, set)
    local part = byName[name]
    if not part then return nil end
    set = set or part.sets[love.math.random(#part.sets)]
    local label = 'fab:' .. name .. ':' .. set
    local thing
    if part.shape == 'rect' then
        thing = objectManager.addThing('rectangle', { x = x, y = y, width = part.w, height = part.h, label = label })
    else
        local vertices = {}
        for i = 1, #part.shape, 2 do
            vertices[i], vertices[i + 1] = x + part.shape[i], y + part.shape[i + 1]
        end
        thing = objectManager.addThing('custom', { x = x, y = y, vertices = vertices, label = label })
    end
    if not thing then return nil end
    -- a custom shape's body sits on its centroid: the box's centre is (x, y), wherever that is
    -- in body space
    local ox, oy = thing.body:getLocalPoint(x, y)
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:isSensor() then fixture:setFriction(0.9) end
    end
    for _, p in ipairs(lib.snapPoints(part)) do snap.addPoint(thing.body, ox + p[1], oy + p[2], 10, true) end
    return thing
end

-- The part's outline in body space. A rectangle's thing.vertices are; a custom shape's are the
-- world points it was made from, and its body sits on their centroid (as box2d-draw's
-- drawCustomBodyFill reads them).
local function localOutline(thing, part)
    if part.shape == 'rect' then return thing.vertices end
    if not thing.fabOutline then
        local v = thing.vertices
        thing.fabOutline = mathutils.makePolygonRelativeToCenter(v, mathutils.computeCentroid(v))
    end
    return thing.fabOutline
end

-- Where the box's centre is in body space: the middle of the outline's bounding box.
local function boxCentre(outline)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #outline, 2 do
        minX, maxX = math.min(minX, outline[i]), math.max(maxX, outline[i])
        minY, maxY = math.min(minY, outline[i + 1]), math.max(maxY, outline[i + 1])
    end
    return (minX + maxX) / 2, (minY + maxY) / 2
end

local LINE = 7
local function setColor(c, k) k = k or 1; love.graphics.setColor(c[1] * k, c[2] * k, c[3] * k, 1) end
local function outlined(mode, fill, ...)
    setColor(fill)
    love.graphics[mode]('fill', ...)
    setColor(lib.COLORS.dark)
    love.graphics[mode]('line', ...)
end

-- Details, drawn in the box's space (centre 0, 0; w, h the box), with the body and trim colours.
local DETAILS = {}
function DETAILS.studs(w, h, body)
    -- the row of round bumps along a Fabuland block's foot
    local r, n = 22, math.floor(w / 110)
    for k = 1, n do
        local x = -w / 2 + (k - 0.5) * w / n
        outlined('circle', body, x, h / 2 - 50, r)
    end
end
function DETAILS.roundWindow(w, h, _, trim)
    local r = w * 0.3
    outlined('circle', trim, 0, -h * 0.1, r)
    outlined('circle', lib.COLORS.glass, 0, -h * 0.1, r * 0.72)
    setColor(trim)
    love.graphics.setLineWidth(r * 0.16)
    love.graphics.line(-r * 0.72, -h * 0.1, r * 0.72, -h * 0.1)
    love.graphics.line(0, -h * 0.1 - r * 0.72, 0, -h * 0.1 + r * 0.72)
    love.graphics.setLineWidth(LINE)
end
function DETAILS.wheelWindow(w, h, _, trim)
    local r, cy = w * 0.3, -h * 0.1
    outlined('circle', trim, 0, cy, r)
    outlined('circle', lib.COLORS.glass, 0, cy, r * 0.72)
    setColor(trim)
    love.graphics.setLineWidth(r * 0.1)
    for k = 0, 5 do
        local a = k * math.pi / 3
        love.graphics.line(0, cy, math.cos(a) * r * 0.72, cy + math.sin(a) * r * 0.72)
    end
    outlined('circle', trim, 0, cy, r * 0.18)
    love.graphics.setLineWidth(LINE)
end
local function archPoints(cx, top, bw, bh, r)
    -- a rectangle bw x bh with its top a half circle, as a polygon
    local pts = {}
    local hw = bw / 2
    for k = 0, 12 do
        local a = math.pi + k * math.pi / 12
        pts[#pts + 1], pts[#pts + 2] = cx + math.cos(a) * hw, top + hw + math.sin(a) * r
    end
    pts[#pts + 1], pts[#pts + 2] = cx + hw, top + bh
    pts[#pts + 1], pts[#pts + 2] = cx - hw, top + bh
    return pts
end
function DETAILS.archWindow(w, h, _, trim)
    local bw, bh = w * 0.6, h * 0.5
    local top = -h * 0.36
    outlined('polygon', trim, unpack(archPoints(0, top, bw, bh, bw / 2)))
    outlined('polygon', lib.COLORS.glass, unpack(archPoints(0, top + bw * 0.12, bw * 0.76, bh - bw * 0.24, bw * 0.38)))
    setColor(trim)
    love.graphics.setLineWidth(bw * 0.08)
    love.graphics.line(0, top + bw * 0.12, 0, top + bh - bw * 0.12)
    love.graphics.line(-bw * 0.38, top + bh * 0.5, bw * 0.38, top + bh * 0.5)
    love.graphics.setLineWidth(LINE)
end
function DETAILS.door(w, h, _, trim)
    local bw, bh = w * 0.62, h * 0.72
    local top = h / 2 - 90 - bh
    outlined('polygon', lib.COLORS.dark, unpack(archPoints(0, top, bw, bh, bw / 2)))
    -- the door, standing open to one side
    outlined('polygon', trim, bw * 0.05, top + bw * 0.2, bw * 0.5, top + bw * 0.05, bw * 0.5, top + bh,
        bw * 0.05, top + bh)
    outlined('circle', lib.COLORS.yellow, bw * 0.15, top + bh * 0.55, 14)
end
function DETAILS.shingles(w, h, body)
    -- rows of scallops across the slope: drawn under the outline, clipped to the shape
    local rows = 5
    setColor(body, 0.75)
    love.graphics.setLineWidth(5)
    for row = 1, rows - 1 do
        local y = -h / 2 + row * h / rows
        local r = w / 12
        for x = -w / 2, w / 2, r * 2 do
            love.graphics.arc('line', 'open', x + r, y - r * 0.2, r, 0.15, math.pi - 0.15)
        end
    end
    love.graphics.setLineWidth(LINE)
end
function DETAILS.railing(w, h, _, trim)
    setColor(trim)
    local n = 6
    for k = 0, n do
        local x = -w / 2 + 40 + k * (w - 80) / n
        outlined('rectangle', trim, x - 14, -h / 2 + 40, 28, h - 40)
    end
end
lib.DETAILS = DETAILS

-- Draw every part: fill, details, outline. Called between the bodies and the textured world
-- (main.lua), so Mipos are in front.
function lib.draw()
    local world = state.physicsWorld
    if not (world and state.fabuland and state.fabuland.on) then return end
    love.graphics.setLineWidth(LINE)
    love.graphics.setLineJoin('bevel')
    for _, body in ipairs(world:getBodies()) do
        local part, setName, thing = lib.partOf(body)
        if part then
            local set = lib.SETS[setName] or lib.SETS.yellow
            local bodyColor, trim = lib.COLORS[set[1]], lib.COLORS[set[2]]
            local outline = localOutline(thing, part)
            local points = { body:getWorldPoints(unpack(outline)) }
            setColor(bodyColor)
            for _, fixture in ipairs(body:getFixtures()) do
                local shape = fixture:getShape()
                if not fixture:isSensor() and shape.getPoints then
                    love.graphics.polygon('fill', body:getWorldPoints(shape:getPoints()))
                end
            end
            local cx, cy = boxCentre(outline)
            -- details stay inside the part's outline (a roof's shingles in its triangle)
            love.graphics.stencil(function() love.graphics.polygon('fill', points) end, 'replace', 1)
            love.graphics.setStencilTest('greater', 0)
            love.graphics.push()
            love.graphics.translate(body:getWorldPoint(cx, cy))
            love.graphics.rotate(body:getAngle())
            for _, detail in ipairs(part.details) do DETAILS[detail](part.w, part.h, bodyColor, trim) end
            love.graphics.pop()
            love.graphics.setStencilTest()
            setColor(lib.COLORS.dark)
            love.graphics.polygon('line', points)
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return lib
