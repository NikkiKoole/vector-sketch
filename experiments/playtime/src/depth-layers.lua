-- depth-layers.lua — back / play / front for bodies (docs/DEPTH-LAYERS.md DL1; from the `depth` spike).
-- A toy house needs depth: Mipos walk in front of a wall with a door, stand on its top, behind a porch railing.
-- A body's layer is on its thing (thing.layer: 'back' or 'front'; none is 'play', solid as always), saved with
-- it, set in the body panel. It says what it collides with and where it's drawn:
--   play   solid, at Mipo depth (floors, planks, stairs, toys): as everything was
--   back   drawn behind the Mipos; what moves around (Mipos and loose toys, Nikki 2026-11-15) passes in front,
--          but its top is a one-way floor (thing.layerTop, on unless false): landing on it from above you
--          stand there, from below or from the side you pass. It still stands on static ground and stacks and
--          welds with other back bodies, so a house stays physics.
--   front  drawn over the Mipos, never touches what moves around (a porch railing, a bush)
-- Layered bodies only touch layered bodies of their own layer, and static ground. The rule is a contact filter
-- in preSolve (src/physics/physics-callbacks.lua), not Box2D's categories: simpler, room for rules.
-- Drawing: pictures get lib.zOffset (src/physics/box2d-draw-textured.lua), plain front bodies are drawn after
-- the textured world (src/physics/box2d-draw.lua lib.drawFrontBodies). The joint guard counts a layered body
-- as passable (a limb in front of a wall isn't stuck in it: src/mipo-joint-guard.lua).
local units = require('src.physics-units')

local lib = {}

lib.LAYERS = { 'play', 'back', 'front' }
lib.Z = { back = -1000000, front = 1000000 } -- far below / above every Mipo's z groups and the front grass

local function thingOf(body)
    local ud = body:getUserData()
    return type(ud) == 'table' and ud.thing or nil
end

-- 'play', 'back' or 'front'
function lib.of(body)
    local thing = thingOf(body)
    return thing and thing.layer or 'play'
end

-- added to a body's pictures' z
function lib.zOffset(body)
    local thing = thingOf(body)
    local layer = thing and thing.layer
    return layer and lib.Z[layer] or 0
end

function lib.isLayered(body)
    local thing = thingOf(body)
    return thing ~= nil and thing.layer ~= nil
end

-- the highest point of a fixture's shape at body-local x (y down: the smallest y)
local function topAt(fixture, lx)
    local shape = fixture:getShape()
    local kind = shape:getType()
    if kind == 'circle' then
        local cx, cy = shape:getPoint()
        local r = shape:getRadius()
        local dx = lx - cx
        if math.abs(dx) >= r then return cy end
        return cy - math.sqrt(r * r - dx * dx)
    end
    local v = { shape:getPoints() }
    local n = #v / 2
    local best, lowestY
    for i = 1, n do
        local j = (kind == 'polygon') and (i % n + 1) or (i + 1)
        if j <= n then
            local x1, y1, x2, y2 = v[i * 2 - 1], v[i * 2], v[j * 2 - 1], v[j * 2]
            if (lx >= x1 and lx <= x2) or (lx >= x2 and lx <= x1) then
                local y = (x1 == x2) and math.min(y1, y2) or y1 + (y2 - y1) * (lx - x1) / (x2 - x1)
                if not best or y < best then best = y end
            end
        end
        lowestY = math.min(lowestY or v[i * 2], v[i * 2])
    end
    return best or lowestY or 0
end

-- A one-way top: decided when the pair first touches (is the mover's lowest point above the top there,
-- and not going up?), kept until they part (endContact)
local passing = setmetatable({}, { __mode = 'k' }) -- [back fixture] = { [mover fixture] = solid }
local function oneWaySolid(fBack, fMover)
    local rec = passing[fBack]
    if rec and rec[fMover] ~= nil then return rec[fMover] end
    local body = fBack:getBody()
    local x1, _, x2, y2 = fMover:getBoundingBox()
    local lx, ly = body:getLocalPoint((x1 + x2) / 2, y2)
    local _, vy = fMover:getBody():getLinearVelocity()
    local solid = ly <= topAt(fBack, lx) + 24 and vy > -units.speed(60)
    if not rec then
        rec = setmetatable({}, { __mode = 'k' })
        passing[fBack] = rec
    end
    rec[fMover] = solid
    return solid
end

function lib.onPreSolve(fa, fb, contact)
    local ba, bb = fa:getBody(), fb:getBody()
    local ta, tb = thingOf(ba), thingOf(bb)
    local la, lb = ta and ta.layer, tb and tb.layer
    if not la and not lb then return end -- both play: as always
    if la and lb then
        if la ~= lb then contact:setEnabled(false) end
        return
    end
    local fLayer, fOther, layer, thing = fa, fb, la, ta
    if lb then fLayer, fOther, layer, thing = fb, fa, lb, tb end
    if fOther:getBody():getType() == 'static' then return end -- the ground: a house stands on it
    -- what moves around: never a front body; a back body only on its top
    if layer == 'back' and thing.layerTop ~= false and oneWaySolid(fLayer, fOther) then return end
    contact:setEnabled(false)
end

function lib.onEndContact(fa, fb)
    if passing[fa] then passing[fa][fb] = nil end
    if passing[fb] then passing[fb][fa] = nil end
end

return lib
