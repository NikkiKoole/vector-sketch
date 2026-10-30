-- ear-bend.lua
-- A Mipo ear's picture bends instead of turning as one piece. The ear body turns on its
-- spring around its root; a wide ear turned whole lifts one corner of its base out of the
-- head (a seam) and pushes the other in. Here the bottom of the picture stays where the ear
-- is at rest (on the head, at the joint's reference angle) and the top follows the ear
-- body, blended up the picture. Drawn with spineSkin.drawGrid: points in the ear's local
-- space at rest, bent, and back in the ear's local space.
local mipoRegistry = require('src.mipo-registry')

local lib = {}

lib.enabled = true
lib.bendLength = 0.2 -- part of the ear (root to tip) over which it goes from head to ear body
                     -- (0.7 bent the whole ear like a banana; this only closes the seam)

local ears = { lear = true, rear = true }

local function smoothstep(t)
    if t <= 0 then return 0 elseif t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

-- The joint that holds an ear to its parent (the ear is its second body).
local function earJoint(body)
    for _, joint in ipairs(body:getJoints()) do
        local _, bodyB = joint:getBodies()
        local jointType = joint:getType()
        if bodyB == body and (jointType == 'weld' or jointType == 'revolute') then return joint end
    end
    return nil
end

-- Bend a flat list of ear-local rest points over the bones; writes into `out`.
function lib.deform(points, bones, out)
    out = out or {}
    local ear, parent = bones.ear, bones.parent
    local cos, sin = math.cos(bones.restAngle), math.sin(bones.restAngle)
    local ax, ay = bones.anchorX, bones.anchorY
    local rx, ry = bones.rootX, bones.rootY
    local dx, dy, length = bones.axisX, bones.axisY, bones.length
    for k = 1, #points - 1, 2 do
        local x, y = points[k], points[k + 1]
        -- where it is on the ear body, and where it would be with the ear at rest
        local ex, ey = ear:getWorldPoint(x, y)
        local lx, ly = x - rx, y - ry
        local hx, hy = parent:getWorldPoint(ax + lx * cos - ly * sin, ay + lx * sin + ly * cos)
        -- 1 at the root (and below it), 0 from bendLength up
        local t = (lx * dx + ly * dy) / length
        local w = 1 - smoothstep(t / lib.bendLength)
        out[k], out[k + 1] = ear:getLocalPoint(ex + (hx - ex) * w, ey + (hy - ey) * w)
    end
    return out
end

-- The bones of a Mipo ear when `body` is one, for spineSkin.drawGrid; nil for anything else.
-- corners: the picture's rectangle (ear-local), to know which way is up the ear.
function lib.bonesOf(body, corners)
    if not lib.enabled then return nil end
    local _, partName = mipoRegistry.getFromBody(body)
    if not ears[partName] then return nil end
    local joint = earJoint(body)
    if not joint or joint:isDestroyed() then return nil end
    local parent = joint:getBodies()
    local x1, y1, x2, y2 = joint:getAnchors()
    local rootX, rootY = body:getLocalPoint(x2, y2)
    local anchorX, anchorY = parent:getLocalPoint(x1, y1)
    -- up the ear: from the root to the middle of the picture, as far as its farthest corner
    local cx, cy = 0, 0
    for k = 1, 7, 2 do cx, cy = cx + corners[k] / 4, cy + corners[k + 1] / 4 end
    local dx, dy = cx - rootX, cy - rootY
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1e-6 then return nil end
    dx, dy = dx / d, dy / d
    local length = 0
    for k = 1, 7, 2 do
        length = math.max(length, (corners[k] - rootX) * dx + (corners[k + 1] - rootY) * dy)
    end
    if length <= 0 then return nil end
    return {
        deform = lib.deform, ear = body, parent = parent,
        -- the ear's angle against its parent at rest
        restAngle = joint:getReferenceAngle(),
        anchorX = anchorX, anchorY = anchorY, rootX = rootX, rootY = rootY,
        axisX = dx, axisY = dy, length = length,
    }
end

return lib
