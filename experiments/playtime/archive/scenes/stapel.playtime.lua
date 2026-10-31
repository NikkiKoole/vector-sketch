-- Stone-balancing scene script.
-- Press SPACE to spawn a random-sized stone at the mouse cursor.
-- Press C to clear all spawned stones.

local s = {}

-- Mark stones with this label so we can find/clear them later.
local STONE_LABEL = 'stone'

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
            stones[i].body:destroy()
        end
    end
end

function s.onStart()
    worldState.paused = false
    print('[stapel] SPACE = spawn stone at cursor, C = clear stones')
end

function s.onKeyPress(key)
    if key == 'space' then
        local mx, my = mouseWorldPos()
        spawnStone(mx, my)
    elseif key == 'c' then
        clearStones()
    end
end

-- Expose so other scripts / the bridge can call it.
s.spawnStone = spawnStone
s.clearStones = clearStones

return s
