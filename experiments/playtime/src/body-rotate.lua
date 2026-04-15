-- Editor-time helpers for FK-style body rotation. Used for pre-bind
-- alignment: rotate a bone (and its connected child chain) so the rig
-- matches a drawn character before binding a MESHUSERT.
--
-- Convention: joints are constructed "parent → child" (main.lua top TODO).
-- So `joint:getBodies()` returns (parent, child). A subtree rooted at body X
-- contains X plus everything reachable via joints where X is the parent side.

local lib = {}

-- Return the first body whose fixture contains (wx, wy). Skips sensor
-- fixtures so sfixtures don't block body picking.
function lib.findBodyAt(world, wx, wy)
    for _, body in ipairs(world:getBodies()) do
        for _, fixture in ipairs(body:getFixtures()) do
            if not fixture:isSensor() and fixture:testPoint(wx, wy) then
                return body
            end
        end
    end
    return nil
end

-- Return a set (keys=body) of bodies in the subtree rooted at `root`,
-- following joints where root is on the parent side. Includes root itself.
function lib.collectDescendants(root)
    local seen = { [root] = true }
    local stack = { root }
    while #stack > 0 do
        local b = table.remove(stack)
        for _, j in ipairs(b:getJoints()) do
            local ba, bb = j:getBodies()
            -- Follow only parent → child.
            if ba == b and not seen[bb] then
                seen[bb] = true
                stack[#stack + 1] = bb
            end
        end
    end
    return seen
end

-- If `body` has a parent joint (it's on the child side of some joint),
-- return that joint's anchor on the body's side (the natural pivot). If
-- there's no parent, return the body's own center (rotate in place).
function lib.findParentPivot(body)
    for _, j in ipairs(body:getJoints()) do
        local ba, bb = j:getBodies()
        if bb == body then
            local _, _, x2, y2 = j:getAnchors()
            return x2, y2
        end
    end
    return body:getX(), body:getY()
end

-- Rotate `root` and every descendant body by `dtheta` radians around the
-- pivot derived from `findParentPivot(root)`. Zeros velocities so editor
-- manipulation doesn't leave the sim with stale motion.
function lib.rotateSubtree(root, dtheta)
    local px, py = lib.findParentPivot(root)
    local cosD, sinD = math.cos(dtheta), math.sin(dtheta)
    local subtree = lib.collectDescendants(root)
    for body, _ in pairs(subtree) do
        local bx, by = body:getPosition()
        local dx, dy = bx - px, by - py
        local nx = px + cosD * dx - sinD * dy
        local ny = py + sinD * dx + cosD * dy
        body:setPosition(nx, ny)
        body:setAngle(body:getAngle() + dtheta)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0, 0)
        body:setAwake(true)
    end
    return px, py
end

return lib
