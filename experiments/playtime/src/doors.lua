-- doors.lua — rooms linked by doors (docs/WORLDS-AND-DOORS.md).
-- A door is a body with a DOOR behavior: { door = 'bakery', to = 'bakery',
-- arrive = 'front' } (usually a static sensor, so Mipos walk past it).
--   Tap a door: it swings open, you go in, as a spectator, and on the other side the
--     arrival door swings shut behind you. The room you leave is kept in memory
--     (state.rooms.saved, as JSON); the camera comes out of the arrival door.
--   Drop a Mipo on a door: the door swings open, and once it's open the Mipo goes through
--     (picked up again or off the door by then: it stays) and you follow it (Nikki,
--     2026-10-30: tapping takes you alone, so gathering Mipos still works). It steps out of
--     the arrival door on the other side (state.rooms.arrivals). Several step out close
--     together and pass through each other while they drift apart, so they don't knot or
--     end up outside the room (mipoJointGuard.passThrough).
--   No opening or closing by hand (Nikki, 2026-10-30): the door swings open on its own when
--     something goes through, and shut again (lib.swing).
-- A Mipo goes alone for now: joints to anything else are let go (W3 carries what's
-- connected). Rooms live in memory only (W2), a room's scene script runs on its first
-- visit, not on a return.
local lib = {}

local state = require('src.state')
local utils = require('src.utils')
local json = require('vendor.dkjson')
local sceneIO = require('src.io')
local mipoRegistry = require('src.mipo-registry')
local camera = require('src.camera')
local logger = require('src.logger')
local behaviors = require('src.behaviors')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local library = require('src.library')
local sceneLoader = require('src.scene-loader')
local snap = require('src.physics.snap')
local objectManager = require('src.object-manager')
local mipoJointGuard = require('src.mipo-joint-guard')
local mipoActions = require('src.mipo-actions')

-- On state so a hot reload keeps the rooms you've been in and the Mipos on their way.
--   saved[room]     the room as you left it (JSON)
--   arrivals[room]  { { traveler = save data of one Mipo, arrive = door name }, ... }
--   swing[doorId]   seconds into a door's swing open and shut (see lib.swing)
state.rooms = state.rooms or {}
local R = state.rooms
R.saved, R.arrivals, R.swing = R.saved or {}, R.arrivals or {}, R.swing or {}
R.fade = R.fade or 0

local FADE_SECONDS = 0.5
-- A door's swing: seconds to swing open, to stay open, to swing shut, and how far it opens.
-- Going in waits for `opening`, so you go through an open door.
-- (80 degrees: the leaf ends as a narrow panel on the hinge side, inside the doorway, so it
-- never draws over a wall next to the door.)
lib.swing = { opening = 0.22, open = 0.45, closing = 0.3, angle = math.rad(80) }
local SWING_DEPTH = 25 -- how much the leaf's free edge shrinks top and bottom when turned side-on
local DOOR_MARGIN = 40 -- a Mipo's torso this close to the door's box counts as on it
local ARRIVE_CLEARANCE = 80 -- the lowest part's centre this far above the door's bottom
local ARRIVE_STEP = 70 -- Mipos stepping out together start this far apart, then drift apart

-- The doors are looked for again when the world or its body count changes, and every
-- RESCAN_CALLS calls (a DOOR behavior added in the editor changes no count). Scanning every
-- body on every call was 1.1-1.4 ms a frame with 100 Mipos (the draws call it each frame).
local RESCAN_CALLS = 60
local doorScan = { world = nil, bodyCount = -1, calls = 0, list = {} }

-- Every door body in the world: { { body, door = its DOOR behavior }, ... }.
function lib.doors()
    local world = state.physicsWorld
    if not world then return {} end
    local count = world:getBodyCount()
    doorScan.calls = doorScan.calls - 1
    local stale = doorScan.world ~= world or doorScan.bodyCount ~= count or doorScan.calls <= 0
    for _, d in ipairs(doorScan.list) do
        -- a room load can bring the same body count back with other bodies
        if stale or d.body:isDestroyed() then
            stale = true
            break
        end
    end
    if stale then
        local found = {}
        for _, body in ipairs(world:getBodies()) do
            local b = behaviors.find(body, 'DOOR')
            if b then table.insert(found, { body = body, door = b }) end
        end
        doorScan.world, doorScan.bodyCount, doorScan.calls, doorScan.list = world, count, RESCAN_CALLS, found
    end
    return doorScan.list
end

function lib.findDoor(name)
    for _, d in ipairs(lib.doors()) do
        if d.door.door == name then return d.body, d.door end
    end
    return nil
end

-- The door's box in world space: its collision fixtures (sfixtures left out).
function lib.box(body)
    local x1, y1, x2, y2
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:getUserData() then
            local ax, ay, bx, by = fixture:getBoundingBox()
            x1, y1 = math.min(x1 or ax, ax), math.min(y1 or ay, ay)
            x2, y2 = math.max(x2 or bx, bx), math.max(y2 or by, by)
        end
    end
    if not x1 then
        local x, y = body:getPosition()
        return x - 50, y - 100, x + 50, y + 100
    end
    return x1, y1, x2, y2
end

local function inside(x, y, x1, y1, x2, y2, margin)
    margin = margin or 0
    return x > x1 - margin and x < x2 + margin and y > y1 - margin and y < y2 + margin
end

local function torsoBody(instance)
    local part = instance.parts and (instance.parts['torso1'] or instance.parts['head'])
    if part and part.body and not part.body:isDestroyed() then return part.body end
    return nil
end

local function bodyId(body)
    local thing = utils.thingOf(body)
    return thing and thing.id
end

-- The door a Mipo's torso is on, or nil.
local function doorUnder(instance)
    local torso = torsoBody(instance)
    if not torso then return nil end
    local x, y = torso:getPosition()
    for _, d in ipairs(lib.doors()) do
        local x1, y1, x2, y2 = lib.box(d.body)
        if inside(x, y, x1, y1, x2, y2, DOOR_MARGIN) then return d.body, d.door end
    end
    return nil
end

-- The id of a Mipo standing on the door (its torso in the door's box), or nil.
function lib.mipoOn(body)
    for id, instance in pairs(mipoRegistry.getAll()) do
        if doorUnder(instance) == body then return id end
    end
    return nil
end

-- A press while playing (src/input-manager.lua), at world x, y, on these bodies: a tap on a
-- door takes you in. Grabbing a Mipo or something loose in front of a door wins over the
-- door. Returns true when a door took the tap.
function lib.onPressed(bodies, x, y)
    for _, body in ipairs(bodies) do
        if mipoRegistry.getFromBody(body) or (body:getType() == 'dynamic' and not behaviors.find(body, 'DOOR')) then
            return false
        end
    end
    for _, d in ipairs(lib.doors()) do
        if inside(x, y, lib.box(d.body)) and d.door.to and d.door.to ~= '' then
            -- go next frame, outside the input callback
            R.pending = { to = d.door.to, arrive = d.door.arrive, wait = lib.swing.opening }
            R.swing[bodyId(d.body)] = 0
            return true
        end
    end
    return false
end

-- Letting go of bodies while playing: a Mipo dropped on a door goes through (next frame).
function lib.onReleased(bodies)
    for _, body in ipairs(bodies) do
        local instance = not body:isDestroyed() and mipoRegistry.getFromBody(body)
        if instance then
            local doorBody, door = doorUnder(instance)
            if doorBody and door.to and door.to ~= '' then
                -- the door swings open first; the Mipo goes once it's open (lib.update)
                R.sends = R.sends or {}
                table.insert(R.sends, { mipoId = instance.id, door = bodyId(doorBody), to = door.to,
                    arrive = door.arrive, wait = lib.swing.opening })
                R.swing[bodyId(doorBody)] = R.swing[bodyId(doorBody)] or 0
            end
        end
    end
end

-- Split save data in two: the Mipo (its bodies, the joints between them, its
-- character entry) and the rest of the room. Joints from the Mipo to anything
-- else are dropped (W3 carries what's connected).
function lib.split(data, mipoId)
    local room = {}
    for k, v in pairs(data) do room[k] = v end
    room.bodies, room.joints, room.characters = {}, {}, {}
    local traveler = { version = data.version, bodies = {}, joints = {}, characters = {} }
    local isTraveler = {}
    for _, bodyData in ipairs(data.bodies or {}) do
        if mipoId and bodyData.mipoId == mipoId then
            table.insert(traveler.bodies, bodyData)
            isTraveler[bodyData.id] = true
        else
            table.insert(room.bodies, bodyData)
        end
    end
    for _, jointData in ipairs(data.joints or {}) do
        local a, b = isTraveler[jointData.bodyA], isTraveler[jointData.bodyB]
        if a and b then
            table.insert(traveler.joints, jointData)
        elseif not a and not b then
            table.insert(room.joints, jointData)
        end
    end
    for _, character in ipairs(data.characters or {}) do
        table.insert(character.id == mipoId and traveler.characters or room.characters, character)
    end
    return room, traveler
end

local function torsoPosition(traveler)
    local fallback
    for _, bodyData in ipairs(traveler.bodies) do
        if bodyData.mipoPartName == 'torso1' then return bodyData.position[1], bodyData.position[2] end
        fallback = fallback or bodyData.position
    end
    if fallback then return fallback[1], fallback[2] end
    return 0, 0
end

-- The arrival door's centre and bottom in the room now loaded (0, 0 and no bottom without one).
local function arrivalPoint(arrive, room)
    local doorBody = lib.findDoor(arrive)
    if not doorBody then
        logger:info('doors: no door "' .. tostring(arrive) .. '" in ' .. tostring(room))
        return 0, 0, nil
    end
    local x1, _, x2, y2 = lib.box(doorBody)
    return (x1 + x2) / 2, doorBody:getY(), y2
end

-- One Mipo steps out of the arrival door: centred on it (shifted by `offset` when several come at
-- once), its lowest part just above the door's bottom (the torso at the door's centre put the legs
-- in the floor).
local function placeTraveler(traveler, ax, ay, bottom, offset)
    if #traveler.bodies == 0 then return end
    local tx, ty = torsoPosition(traveler)
    if bottom then
        local lowest = ty
        for _, bodyData in ipairs(traveler.bodies) do lowest = math.max(lowest, bodyData.position[2]) end
        ay = bottom - ARRIVE_CLEARANCE - (lowest - ty)
    end
    library.move(traveler, ax + offset - tx, ay - ty)
    local data = json.decode(json.encode(traveler))
    sceneIO.prepareLoaded(data)
    sceneIO.buildWorld(data, state.physicsWorld, camera.getInstance(), { additive = true })
end

-- Where travelers stepping out together start, around the door: a little apart (so
-- each knows which way to drift), overlapping; they pass through each other until apart.
local function closeTogether(n)
    local offsets = {}
    for i = 1, n do offsets[i] = (i - (n + 1) / 2) * ARRIVE_STEP end
    return offsets
end

local function enterRoom(to, arrive)
    if R.saved[to] then
        sceneLoader.loadSceneData(R.saved[to], to)
        state.scene.id = to
    else
        sceneLoader.loadScriptAndScene(to)
    end
    box2dPointerJoints.resetPointerJoints()
    state.interaction.draggingObj = nil
    state.selection.selectedBodies = nil

    local ax, ay, bottom = arrivalPoint(arrive, to)
    -- Mipos sent ahead step out of the door they were sent to arrive at, side by side
    local byDoor, order = {}, {}
    for _, arrival in ipairs(R.arrivals[to] or {}) do
        if not byDoor[arrival.arrive] then
            byDoor[arrival.arrive] = {}
            order[#order + 1] = arrival.arrive
        end
        table.insert(byDoor[arrival.arrive], arrival.traveler)
    end
    local arrived = {}
    for _, doorName in ipairs(order) do
        local travelers = byDoor[doorName]
        local offsets = closeTogether(#travelers)
        local x, y, b = ax, ay, bottom
        if doorName ~= arrive then x, y, b = arrivalPoint(doorName, to) end
        for i, traveler in ipairs(travelers) do
            placeTraveler(traveler, x, y, b, offsets[i])
            for _, character in ipairs(traveler.characters or {}) do arrived[#arrived + 1] = character.id end
        end
    end
    if #arrived > 0 then
        -- upright: a Mipo dazed (limp) when it was sent kept its limp KEEP_ANGLEs in the save
        -- data, but not the timer that wakes it
        for _, id in ipairs(arrived) do
            local instance = mipoRegistry.getAll()[id]
            if instance then mipoActions.wake(instance) end
        end
        mipoJointGuard.passThrough(arrived)
    end
    R.arrivals[to] = nil
    snap.onSceneLoaded()
    camera.getInstance():setTranslation(ax, ay)
    -- the door you came through stands open behind you and swings shut as the fade clears
    -- (the other room's swings are left behind)
    R.swing = {}
    local arrivalDoor = lib.findDoor(arrive)
    if arrivalDoor then R.swing[bodyId(arrivalDoor)] = lib.swing.opening end
end

-- You go through the open door; the room you leave is kept as it is.
local function goThrough(pending)
    local from = state.scene.id
    if from then
        R.saved[from] = json.encode(sceneIO.gatherSaveData(state.physicsWorld, camera.getInstance()))
    end
    enterRoom(pending.to, pending.arrive)
    R.fade = 1
end

-- A dropped Mipo goes through by itself: out of this room, onto the next room's arrivals.
local function heldByPointer(instance)
    for _, pointerJoint in ipairs(box2dPointerJoints.getPointerJoints()) do
        local body = pointerJoint.jointBody
        if body and not body:isDestroyed() and mipoRegistry.getFromBody(body) == instance then return true end
    end
    return false
end

local function send(s)
    local instance = mipoRegistry.getAll()[s.mipoId]
    if not instance then return end
    -- picked up again, or tumbled off the door while it opened: it stays, the door just closes
    local doorBody = doorUnder(instance)
    if heldByPointer(instance) or not doorBody or bodyId(doorBody) ~= s.door then return end
    if mipoActions.isDazed(instance) then mipoActions.wake(instance) end -- goes in awake
    local data = sceneIO.gatherSaveData(state.physicsWorld, camera.getInstance())
    local _, traveler = lib.split(data, s.mipoId)
    if #traveler.bodies == 0 then return end
    box2dPointerJoints.resetPointerJoints() -- no finger left holding a part that's going
    state.interaction.draggingObj = nil
    for _, part in pairs(instance.parts or {}) do
        if part.body and not part.body:isDestroyed() then
            snap.destroySnapJointAboutBody(part.body)
            objectManager.destroyBody(part.body)
        end
    end
    mipoRegistry.unregister(s.mipoId)
    R.arrivals[s.to] = R.arrivals[s.to] or {}
    table.insert(R.arrivals[s.to], { traveler = traveler, arrive = s.arrive })
    logger:info('doors: a Mipo went into ' .. s.to)
    -- and you follow it (tapping a door takes you alone, so you can still gather Mipos)
    R.pending = R.pending or { to = s.to, arrive = s.arrive, wait = 0 }
end

function lib.update(dt)
    if R.sends then
        local waiting = {}
        for _, s in ipairs(R.sends) do
            s.wait = (s.wait or 0) - dt
            if s.wait > 0 then waiting[#waiting + 1] = s end
        end
        local due = {}
        for _, s in ipairs(R.sends) do if s.wait <= 0 then due[#due + 1] = s end end
        R.sends = #waiting > 0 and waiting or nil
        for _, s in ipairs(due) do send(s) end
    end
    if R.pending then
        R.pending.wait = (R.pending.wait or 0) - dt
        if R.pending.wait <= 0 then
            local pending = R.pending
            R.pending = nil
            goThrough(pending)
        end
    end
    local total = lib.swing.opening + lib.swing.open + lib.swing.closing
    for id, t in pairs(R.swing) do
        R.swing[id] = t + dt < total and t + dt or nil
    end
    if R.fade > 0 then R.fade = math.max(0, R.fade - dt / FADE_SECONDS) end
end

-- How far a door has turned, 0 (shut) to 1 (open), t seconds into its swing.
function lib.openness(t)
    local w = lib.swing
    local function ease(x) return x * x * (3 - 2 * x) end
    if t < w.opening then return ease(t / w.opening) end
    t = t - w.opening
    if t < w.open then return 1 end
    t = t - w.open
    return 1 - ease(math.min(1, t / w.closing))
end

-- The door leaf turned on its hinge (the doorway's left edge): the dark doorway shows behind
-- it, the free edge comes across and past the hinge, foreshortened as it turns side-on.
local function drawSwing(x1, y1, x2, y2, openness)
    local lg = love.graphics
    local angle = openness * lib.swing.angle
    local freeX = x1 + (x2 - x1) * math.cos(angle)
    local shrink = SWING_DEPTH * math.sin(angle)
    lg.setColor(0.08, 0.06, 0.1, 0.92 * math.min(1, openness * 3))
    lg.rectangle('fill', x1, y1, x2 - x1, y2 - y1)
    lg.setColor(0.55, 0.4, 0.28, 0.97)
    lg.polygon('fill', x1, y1, freeX, y1 + shrink, freeX, y2 - shrink, x1, y2)
    lg.setColor(0.35, 0.25, 0.17, 1)
    lg.setLineWidth(3)
    lg.polygon('line', x1, y1, freeX, y1 + shrink, freeX, y2 - shrink, x1, y2)
end

-- How many Mipos are on their way into a room (waiting for you to go in).
function lib.waiting(room)
    return #(R.arrivals[room] or {})
end

-- World space, between the plain shapes and the textured ones (main.lua): a door swinging open
-- and shut, over the door's own shape and behind whoever stands in the doorway.
function lib.drawBehind()
    for _, d in ipairs(lib.doors()) do
        local t = R.swing[bodyId(d.body)]
        if t then
            local x1, y1, x2, y2 = lib.box(d.body)
            drawSwing(x1, y1, x2, y2, lib.openness(t))
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- World space, over the bodies: a door with Mipos waiting behind it says so; in the editor
-- (paused) every door shows where it leads.
function lib.draw()
    local lg = love.graphics
    for _, d in ipairs(lib.doors()) do
        local x1, y1, x2, y2 = lib.box(d.body)
        local waiting = lib.waiting(d.door.to)
        if waiting > 0 then
            lg.setColor(1, 1, 1, 0.85)
            lg.printf(waiting .. (waiting == 1 and ' Mipo' or ' Mipos') .. ' inside', x1 - 100, y1 - 40,
                x2 - x1 + 200, 'center')
        end
        if state.world.paused then
            lg.setColor(1, 1, 1, 0.6)
            lg.setLineWidth(2)
            lg.rectangle('line', x1, y1, x2 - x1, y2 - y1)
            lg.print(tostring(d.door.door) .. ' -> ' .. tostring(d.door.to) .. ' / ' .. tostring(d.door.arrive),
                x1, y1 - 30)
        end
    end
    lg.setColor(1, 1, 1)
end

-- Screen space, on top of the world: the fade after going through a door.
function lib.drawFade()
    if R.fade <= 0 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, R.fade)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(1, 1, 1)
end

return lib
