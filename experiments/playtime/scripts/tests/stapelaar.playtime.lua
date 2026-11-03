-- Stone-balancing scene script.
-- Press SPACE to spawn a random-sized stone at the mouse cursor.
-- Press B to spawn a stone at the stack's base anchor (always same x,y).
-- Press C to clear all spawned stones.

local s = {}

-- Mark stones with this label so we can find/clear them later.
local STONE_LABEL = 'stone'

-- Cached anchor for "press B to spawn at base". Computed in onStart from
-- whichever body is labelled 'anchor', else from the first static body found.
local stackAnchorX, stackAnchorY = 0, 0

-- Cached ref to the "ground" static (the one the anchor sits on). Used so
-- beginContact can tell the ground apart from the side walls — only wall
-- collisions remove a stone.
local groundBody = nil

-- The most-recently-spawned "base" stone. Used as the seed for liftStack so
-- we only lift stones that are physically part of the active column (via the
-- contact graph), not every random stone that happens to be near the anchor X.
local currentBase = nil

-- Spawn a rectangle "stone" body at world coords (x, y).
-- w / h optional; defaults to a random size in the stone range.
local function spawnStone(x, y, w, h)
    w = w or random(40, 90)
    h = h or random(20, 50)

    local thing = objectManager.addThing('rectangle', {
        x = x,
        y = y,
        bodyType = 'dynamic',
        width = w,
        height = h,
        label = STONE_LABEL,
    })

    if not thing then return nil end

    -- Tune fixtures for stone-like behavior: high friction so they grip when
    -- stacked, low restitution so they don't bounce off each other.
    for _, fixture in ipairs(thing.body:getFixtures()) do
        if not fixture:getUserData() then -- only the collision fixture, not sfixtures
            fixture:setFriction(0.9)
            fixture:setRestitution(0.05)
            fixture:setDensity(2)
        end
    end
    thing.body:resetMassData()
    thing.body:setAngularDamping(0.2)

    return thing
end

local function clearStones()
    local stones = getObjectsByLabel(STONE_LABEL)
    for i = 1, #stones do
        if stones[i].body and not stones[i].body:isDestroyed() then
            -- Must go through objectManager so the registry is cleaned up too;
            -- raw body:destroy() leaves a stale entry that crashes keep-angle.
            objectManager.destroyBody(stones[i].body)
        end
    end
end

-- Resolve the spawn anchor for press-B. Priority:
--   1. Any body labelled 'anchor' (user-positioned in editor)
--   2. The first static body found (likely the ground)
-- The anchor sits a bit ABOVE the chosen body so spawned stones land on top
-- without overlapping the existing collider.
local function computeAnchor()
    local labelled = getObjectsByLabel('anchor')[1]
    if labelled and labelled.body then
        groundBody = labelled.body
        local x, y = labelled.body:getPosition()
        local h = labelled.height or 0
        return x, y - h * 0.5 - 30
    end
    for _, body in pairs(world:getBodies()) do
        if body:getType() == 'static' then
            local ud = body:getUserData()
            if ud and ud.thing then
                groundBody = body
                local x, y = body:getPosition()
                local h = ud.thing.height or 0
                return x, y - h * 0.5 - 30
            end
        end
    end
    return 0, 0
end

function s.onStart()
    worldState.paused = false
    stackAnchorX, stackAnchorY = computeAnchor()
    print(string.format('[stapel] anchor=(%.0f,%.0f)  SPACE=spawn at cursor  B=spawn at anchor  C=clear',
        stackAnchorX, stackAnchorY))
end

-- How far (in X) a stone can drift from the anchor before the reset trigger
-- considers it "outside the column". Also used as a fallback seed radius
-- when there's no currentBase yet.
local STACK_X_TOLERANCE = 60

-- Shift everything physically connected to the current base stone up by
-- `dy` so a new stone can slot in at the bottom. Three-pass flood from the
-- base:
--   1. Seed with `currentBase` (last spawned). Falls back to any in-column
--      stone if the base is gone.
--   2. Flood via active CONTACTS — this catches stones stacked on top of
--      the base and the person resting on the top stone, but NOT fallen
--      stones elsewhere (they're not in contact with the chain). Statics
--      are skipped so the chain can't escape via the ground.
--   3. Flood via JOINTS — once any body part of the person is reached, all
--      his other parts come along.
-- Velocities are zeroed so the teleport doesn't fling anything.
local function liftStack(dy)
    local toLift = {}
    local queue = {}

    local function enqueue(body)
        if body and not body:isDestroyed()
            and body:getType() == 'dynamic' and not toLift[body] then
            toLift[body] = true
            table.insert(queue, body)
        end
    end

    -- Seed: prefer the most recent base stone, else any near-column stone.
    if currentBase and not currentBase:isDestroyed() then
        enqueue(currentBase)
    else
        local stones = getObjectsByLabel(STONE_LABEL)
        for i = 1, #stones do
            local body = stones[i].body
            if body and not body:isDestroyed() then
                local x, _ = body:getPosition()
                if math.abs(x - stackAnchorX) <= STACK_X_TOLERANCE then
                    enqueue(body)
                end
            end
        end
    end

    -- Flood via contacts + joints
    -- Contact rule: only follow contacts to bodies that are ABOVE the current
    -- one (smaller Y in screen-space). This prevents a fallen stone resting
    -- beside the base — which is at the same Y — from being pulled into
    -- the stack. Vertical stacking is the only valid direction.
    -- Joints are flooded unconditionally so Knut's arms etc. still come along
    -- once any of his body parts has been reached.
    local CONTACT_Y_MARGIN = 4 -- ignore jitter
    while #queue > 0 do
        local b = table.remove(queue)
        local _, by = b:getPosition()

        for _, contact in ipairs(b:getContacts()) do
            if contact:isTouching() then
                local f1, f2 = contact:getFixtures()
                local other = (f1:getBody() == b) and f2:getBody() or f1:getBody()
                if other and other:getType() == 'dynamic' then
                    local _, oy = other:getPosition()
                    if oy < by - CONTACT_Y_MARGIN then
                        enqueue(other)
                    end
                end
            end
        end

        for _, joint in ipairs(b:getJoints()) do
            local b1, b2 = joint:getBodies()
            enqueue((b1 == b) and b2 or b1)
        end
    end

    for body, _ in pairs(toLift) do
        local x, y = body:getPosition()
        body:setPosition(x, y - dy)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

function s.onKeyPress(key)
    if key == 'space' then
        local mx, my = mouseWorldPos()
        spawnStone(mx, my)
    elseif key == 'b' then
        local newH = random(20, 50)
        liftStack(newH)
        local stone = spawnStone(stackAnchorX, stackAnchorY, nil, newH)
        -- New stone becomes the base for the next lift's contact flood.
        currentBase = stone and stone.body or nil
    elseif key == 'c' then
        clearStones()
        currentBase = nil
    end
end

-- If a stone hits any static body that ISN'T the main ground (i.e. the side
-- walls), remove just that stone. The rest of the pile and the ground
-- contact are left alone.
local function isStone(body)
    local ud = body:getUserData()
    return ud and ud.thing and ud.thing.label == STONE_LABEL
end

-- Box2D contact callbacks fire mid-solver; destroying a body right now would
-- invalidate pointers the solver is using. Defer destruction to the next
-- frame via the update hook.
local pendingDestroy = {}

function s.beginContact(fix1, fix2, contact)
    local b1 = fix1:getBody()
    local b2 = fix2:getBody()
    local stone, static
    if isStone(b1) and b2:getType() == 'static' then
        stone, static = b1, b2
    elseif isStone(b2) and b1:getType() == 'static' then
        stone, static = b2, b1
    end
    if not stone then return end

    if static ~= groundBody then
        pendingDestroy[stone] = true
    end
end

function s.update(dt)
    for body, _ in pairs(pendingDestroy) do
        if body and not body:isDestroyed() then
            objectManager.destroyBody(body)
        end
        pendingDestroy[body] = nil
    end
end

-- Expose so other scripts / the bridge can call it.
s.spawnStone = spawnStone
s.clearStones = clearStones

return s
