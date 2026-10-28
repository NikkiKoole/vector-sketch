-- doors.lua — rooms linked by doors (docs/WORLDS-AND-DOORS.md, slice W1).
-- A door is a body with a DOOR behavior: { door = 'bakery', to = 'bakery',
-- arrive = 'front' } (usually a static sensor, so Mipos walk past it).
-- Tap a door: it opens. Drop a Mipo on it and tap it again: you go in. The room
-- you leave is kept in memory (state.rooms.saved, as JSON), the Mipo comes along
-- and steps out of the arrival door. Tap an open door with no Mipo on it to close it.
-- W1: the Mipo travels alone (joints to anything else are let go), rooms live in
-- memory only, a room's scene script runs on its first visit, not on a return.
local lib = {}

local state = require('src.state')
local json = require('vendor.dkjson')
local sceneIO = require('src.io')
local mipoRegistry = require('src.mipo-registry')
local camera = require('src.camera')
local logger = require('src.logger')

-- On state so a hot reload keeps the rooms you've been in.
state.rooms = state.rooms or { saved = {}, openDoor = nil, pending = nil, fade = 0 }
local R = state.rooms

local FADE_SECONDS = 0.5
local DOOR_MARGIN = 40 -- a Mipo's torso this close to the door's box counts as on it
local ARRIVE_CLEARANCE = 80 -- the lowest part's centre this far above the door's bottom

local function doorOf(body)
    if body:isDestroyed() then return nil end
    local ud = body:getUserData()
    for _, b in ipairs(ud and ud.thing and ud.thing.behaviors or {}) do
        if b.name == 'DOOR' then return b end
    end
    return nil
end

-- Every door body in the world.
function lib.doors()
    local found = {}
    if not state.physicsWorld then return found end
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        local b = doorOf(body)
        if b then table.insert(found, { body = body, door = b }) end
    end
    return found
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

local function torsoBody(instance)
    local part = instance.parts and (instance.parts['torso1'] or instance.parts['head'])
    if part and part.body and not part.body:isDestroyed() then return part.body end
    return nil
end

-- The id of a Mipo standing on the door (its torso in the door's box), or nil.
function lib.mipoOn(body)
    local x1, y1, x2, y2 = lib.box(body)
    for id, instance in pairs(mipoRegistry.getAll()) do
        local torso = torsoBody(instance)
        if torso then
            local x, y = torso:getPosition()
            if x > x1 - DOOR_MARGIN and x < x2 + DOOR_MARGIN and y > y1 - DOOR_MARGIN and y < y2 + DOOR_MARGIN then
                return id
            end
        end
    end
    return nil
end

local function bodyId(body)
    local ud = body:getUserData()
    return ud and ud.thing and ud.thing.id
end

-- Called with the bodies under a press while playing (src/input-manager.lua).
-- Returns true when a door took the tap.
function lib.onPressed(bodies)
    for _, body in ipairs(bodies) do
        local b = doorOf(body)
        if b then
            local id = bodyId(body)
            if R.openDoor ~= id then
                R.openDoor = id
            else
                local mipoId = lib.mipoOn(body)
                if mipoId and b.to and b.to ~= '' then
                    -- go next frame, outside the input callback
                    R.pending = { to = b.to, arrive = b.arrive, mipoId = mipoId }
                else
                    R.openDoor = nil
                end
            end
            return true
        end
    end
    return false
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
        if bodyData.mipoId == mipoId then
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

local function enterRoom(to, arrive, traveler)
    local sceneLoader = require('src.scene-loader')
    local pointerJoints = require('src.physics.box2d-pointerjoints')
    local cam = camera.getInstance()

    if R.saved[to] then
        sceneLoader.loadSceneData(R.saved[to], to)
        state.scene.id = to
    else
        sceneLoader.loadScriptAndScene(to)
    end
    pointerJoints.resetPointerJoints()
    state.interaction.draggingObj = nil
    state.selection.selectedBodies = nil

    -- the Mipo steps out of the arrival door: centred on it, its lowest part just
    -- above the door's bottom (the torso at the door's centre put the legs in the floor)
    local doorBody = lib.findDoor(arrive)
    local ax, ay = 0, 0
    local bottom
    if doorBody then
        local x1, _, x2, y2 = lib.box(doorBody)
        ax, ay, bottom = (x1 + x2) / 2, doorBody:getY(), y2
    else
        logger:info('doors: no door "' .. tostring(arrive) .. '" in ' .. to)
    end
    if #traveler.bodies > 0 then
        local tx, ty = torsoPosition(traveler)
        if bottom then
            local lowest = ty
            for _, bodyData in ipairs(traveler.bodies) do lowest = math.max(lowest, bodyData.position[2]) end
            ay = bottom - ARRIVE_CLEARANCE - (lowest - ty)
        end
        require('src.library').move(traveler, ax - tx, ay - ty)
        local data = json.decode(json.encode(traveler))
        sceneIO.prepareLoaded(data)
        sceneIO.buildWorld(data, state.physicsWorld, cam, { additive = true })
        require('src.physics.snap').onSceneLoaded()
    end
    cam:setTranslation(ax, ay)
end

local function goThrough(pending)
    local from = state.scene.id
    local data = sceneIO.gatherSaveData(state.physicsWorld, camera.getInstance())
    local room, traveler = lib.split(data, pending.mipoId)
    if from then R.saved[from] = json.encode(room) end
    R.openDoor = nil
    enterRoom(pending.to, pending.arrive, traveler)
    R.fade = 1
end

function lib.update(dt)
    if R.pending then
        local pending = R.pending
        R.pending = nil
        goThrough(pending)
    end
    if R.fade > 0 then R.fade = math.max(0, R.fade - dt / FADE_SECONDS) end
end

-- World space: an open door shows a dark inside and what to do next; a closed
-- one a small label. In the editor (paused) every door shows where it leads.
function lib.draw()
    local lg = love.graphics
    for _, d in ipairs(lib.doors()) do
        local x1, y1, x2, y2 = lib.box(d.body)
        local open = R.openDoor == bodyId(d.body)
        if open then
            lg.setColor(0.08, 0.06, 0.1, 0.92)
            lg.rectangle('fill', x1, y1, x2 - x1, y2 - y1)
            local onIt = lib.mipoOn(d.body)
            lg.setColor(onIt and { 1, 0.8, 0.3 } or { 1, 1, 1, 0.7 })
            lg.setLineWidth(6)
            lg.rectangle('line', x1, y1, x2 - x1, y2 - y1)
            lg.printf(onIt and 'tap to go in' or ('put a Mipo here\n(' .. tostring(d.door.to) .. ')'),
                x1, (y1 + y2) / 2 - 20, x2 - x1, 'center')
        elseif state.world.paused then
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
