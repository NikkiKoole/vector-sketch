-- signals.lua
-- Wiring for contraptions (docs/DOLL-PLAY-MENU.md, contraption kit): triggers send a
-- named signal, receivers listening to that name act on it. Both are behaviors on
-- the body's thing, so they save with the scene and show up in the editor's
-- "add behavior" list:
--   { name = 'SIGNAL_BUTTON', signal = 'gate1' }             tap it -> sends 'gate1'
--   { name = 'SIGNAL_PLATE',  signal = 'gate1', mode = 'hold' } something resting on it
--        sends 'gate1'; 'hold' sends again when it's free (gate closes), 'toggle' only on press
--   { name = 'SIGNAL_SOCKET', signal = 'gate1', mode = 'hold', accepts = 'key' } something
--        snapped onto it (src/physics/snap.lua; not a Mipo hand, label = accepts if set)
--   { name = 'SIGNAL_GATE',   signal = 'gate1', open = false } prismatic gate: toggles
local state = require('src.state')
local units = require('src.physics-units')
local contactTracker = require('src.physics.contact-tracker')
local behaviors = require('src.behaviors')
local mipoRegistry = require('src.mipo-registry')
local snap = require('src.physics.snap')

local lib = {}

lib.gateSpeed = 600      -- how fast a gate moves (world units/s, at any meter: it's how the gate looks)
lib.gateForce = 1e7      -- motor force: enough to hold up a skateboard with a Mipo (at 100 px per
                         -- metre; src/physics-units.lua makes it the same push at any meter)

local triggerNames = { SIGNAL_BUTTON = true, SIGNAL_PLATE = true, SIGNAL_SOCKET = true }

local function prismaticOf(body)
    for _, joint in ipairs(body:getJoints()) do
        if joint:getType() == 'prismatic' then return joint end
    end
    return nil
end

-- Opening moves a gate toward world-down along its prismatic axis, whichever
-- way the axis was drawn (+1: along the axis, -1: against it).
local function openDirection(joint)
    local _, ay = joint:getAxis()
    return ay >= 0 and 1 or -1
end

-- A prismatic joint made with the editor's 'add joint' has limits 0..0 (or
-- none). Give it a usable range: from where the gate stands now (closed) to
-- the gate's own height further down (open).
local function ensureGateLimits(body, joint)
    if joint:areLimitsEnabled() and joint:getUpperLimit() - joint:getLowerLimit() > 1 then return end
    local y1, y2 = math.huge, -math.huge
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            local _, top, _, bottom = fixture:getBoundingBox(1)
            y1, y2 = math.min(y1, top), math.max(y2, bottom)
        end
    end
    local travel = (y2 > y1) and (y2 - y1 + 10) or 200
    local t = joint:getJointTranslation()
    local dir = openDirection(joint)
    joint:setLimits(math.min(t, t + dir * travel), math.max(t, t + dir * travel))
    joint:setLimitsEnabled(true)
end

-- [gate body] = { steps it stays awake, its own sleep setting to put back }. A gate resting
-- half a pixel past the end of its limits (Box2D's slop, which grows with the meter) gets a
-- limit-and-motor solve that
-- pushes it the wrong way; it doesn't move, falls asleep after half a second and stays
-- shut (or open). Awake for the whole trip it gets going. On state: survives a hot reload.
state.gatesTravelling = state.gatesTravelling or setmetatable({}, { __mode = 'k' })
local travelling = state.gatesTravelling

-- The list for the world in play: emptied when it's another world than the one it was filled in
-- (a scene loaded since, or a spec's own world): those bodies are gone, and their objects may be
-- released already, so even isDestroyed() on them fails.
local function travellingNow()
    if state.gatesTravellingWorld ~= state.physicsWorld then
        for body in pairs(travelling) do travelling[body] = nil end
        state.gatesTravellingWorld = state.physicsWorld
    end
    return travelling
end

-- Gate: a body on a prismatic joint; the motor drives it to the closed end or
-- to the open (world-down) end of its limits.
function lib.setGate(body, open)
    local b = behaviors.find(body, 'SIGNAL_GATE')
    local joint = prismaticOf(body)
    if not b or not joint then return end
    ensureGateLimits(body, joint)
    b.open = open
    local dir = openDirection(joint)
    joint:setMotorEnabled(true)
    joint:setMaxMotorForce(units.force(lib.gateForce))
    joint:setMotorSpeed((open and dir or -dir) * lib.gateSpeed)
    body:setAwake(true)
    travellingNow()
    local wasAllowed = travelling[body] and travelling[body].sleepingAllowed or body:isSleepingAllowed()
    body:setSleepingAllowed(false)
    local travel = joint:getUpperLimit() - joint:getLowerLimit()
    -- the trip, and half a second, in physics steps
    local stepsPerSecond = units.stepsPerSecond()
    travelling[body] = { steps = math.ceil((travel / lib.gateSpeed + 0.5) * stepsPerSecond),
        sleepingAllowed = wasAllowed }
end

local receivers = {
    SIGNAL_GATE = function(body, behavior) lib.setGate(body, not behavior.open) end,
}

-- Send a signal: every receiver behavior with that signal name acts on it.
function lib.emit(signal)
    if not signal or not state.physicsWorld then return 0 end
    local count = 0
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        for _, b in ipairs(behaviors.all(body)) do
            local receive = receivers[b.name]
            if receive and b.signal == signal then
                receive(body, b)
                count = count + 1
            end
        end
    end
    return count
end

local clickSource = nil
local function playClick()
    if not (love and love.audio) then return end
    if not clickSource then
        local path = 'assets/sounds/casio-mt70/hat-clave.ogg'
        if not love.filesystem.getInfo(path) then return end
        clickSource = love.audio.newSource(path, 'static')
    end
    local click = clickSource:clone()
    click:setVolume(0.5)
    click:play()
end

-- Called with the bodies under a press (src/input-manager.lua): a SIGNAL_BUTTON
-- among them sends its signal.
function lib.onPressed(bodies)
    for _, body in ipairs(bodies) do
        local b = behaviors.find(body, 'SIGNAL_BUTTON')
        if b then
            playClick()
            lib.emit(b.signal)
            return true
        end
    end
    return false
end

-- Editor overlay (drawn in world space while paused): a line from every trigger
-- to every receiver on the same signal, its name halfway. Wires touching the
-- selected body are drawn thicker.

-- Signal names in use on the stage, skipping the bodies in skip (a set).
function lib.namesInUse(skip)
    local names = {}
    if not state.physicsWorld then return names end
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        if not (skip and skip[body]) then
            for _, b in ipairs(behaviors.all(body)) do
                if behaviors.isSignal(b) then names[b.signal] = true end
            end
        end
    end
    return names
end

-- A copy (library prefab, clone) gets its own name (gate1 -> gate2) for each
-- signal it holds both ends of, a trigger and a receiver, when that name is
-- already in use. A copy with one end only (a second button for the same gate)
-- keeps the name and joins that circuit. Renames the behaviors in place.
function lib.renameForCopy(behaviorLists, inUse)
    local hasTrigger, hasReceiver = {}, {}
    for _, list in ipairs(behaviorLists) do
        for _, b in ipairs(list) do
            if behaviors.isSignal(b) then
                if triggerNames[b.name] then hasTrigger[b.signal] = true else hasReceiver[b.signal] = true end
            end
        end
    end
    local taken, renamed = {}, {}
    for name in pairs(inUse) do taken[name] = true end
    for name in pairs(hasTrigger) do
        if hasReceiver[name] and inUse[name] then
            local base, n = name:gsub('%d+$', ''), 2
            while taken[base .. n] do n = n + 1 end
            renamed[name] = base .. n
            taken[base .. n] = true
        end
    end
    for _, list in ipairs(behaviorLists) do
        for _, b in ipairs(list) do
            if behaviors.isSignal(b) and renamed[b.signal] then b.signal = renamed[b.signal] end
        end
    end
    return renamed
end

-- Every wire: { signal, from = trigger body, to = receiver body }.
function lib.wires()
    local wires = {}
    if not state.physicsWorld then return wires end
    local triggers, listeners = {}, {}
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        for _, b in ipairs(behaviors.all(body)) do
            if behaviors.isSignal(b) then
                local list = triggerNames[b.name] and triggers or listeners
                list[b.signal] = list[b.signal] or {}
                table.insert(list[b.signal], body)
            end
        end
    end
    for signal, from in pairs(triggers) do
        for _, t in ipairs(from) do
            for _, rcv in ipairs(listeners[signal] or {}) do
                table.insert(wires, { signal = signal, from = t, to = rcv })
            end
        end
    end
    table.sort(wires, function(a, b) return a.signal < b.signal end)
    return wires
end

function lib.drawWires(selectedBody)
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()
    for _, wire in ipairs(lib.wires()) do
        local tx, ty = wire.from:getPosition()
        local rx, ry = wire.to:getPosition()
        local selected = selectedBody and (wire.from == selectedBody or wire.to == selectedBody)
        love.graphics.setColor(1, 0.85, 0.2, selected and 1 or 0.5)
        love.graphics.setLineWidth(selected and 8 or 3)
        love.graphics.line(tx, ty, rx, ry)
        love.graphics.circle('fill', rx, ry, selected and 14 or 8)
        love.graphics.print(wire.signal, (tx + rx) / 2, (ty + ry) / 2, 0, 3, 3)
    end
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(r, g, b, a)
end

-- Pressure plates: pressed while anything that isn't fixed (a Mipo, a ball, a
-- board) touches the plate body. Polled every frame from main.lua. A press
-- counts at once, a release only after the plate has been free for
-- plateReleaseFrames (a bouncing ball or a wobbling Mipo made the gate chatter).
lib.plateReleaseFrames = 15 -- 0.25s at 60 fps
-- A toggle plate waits longer: every release-and-press flips its gate, and a ball
-- bouncing on it is in the air 0.25-0.5 s per hop (shorter at a bigger meter); it
-- flipped the gate on every bounce, ending open or closed by how many there were.
lib.toggleReleaseFrames = 60
local plateWasPressed = setmetatable({}, { __mode = 'k' }) -- [body] = bool
local plateFreeFrames = setmetatable({}, { __mode = 'k' }) -- [body] = frames free in a row

local function solidDynamic(own, other, otherBody)
    return otherBody:getType() == 'dynamic' and not own:isSensor() and not other:isSensor()
end

local function plateIsPressed(body)
    return contactTracker.any(body, solidDynamic)
end

-- Sockets: filled while something is snapped onto the body. Mipo hands don't
-- count (grabbing the lock isn't a key); `accepts` limits it to one label.
local socketWasFilled = setmetatable({}, { __mode = 'k' }) -- [body] = bool

local function socketIsFilled(body, socket, snapJoints)
    for _, joint in ipairs(snapJoints) do
        local a, b = joint:getBodies()
        local other = (a == body and b) or (b == body and a) or nil
        if other and not mipoRegistry.getFromBody(other) then
            local oud = other:getUserData()
            local label = oud and oud.thing and oud.thing.label
            if not socket.accepts or socket.accepts == '' or label == socket.accepts then return true end
        end
    end
    return false
end

-- A trigger changed state: on -> click + send; off -> send again unless 'toggle'.
local function edge(store, body, behavior, now)
    local was = store[body]
    if was == nil then
        store[body] = now -- first look after a load: no signal
    elseif now ~= was then
        store[body] = now
        if now or behavior.mode ~= 'toggle' then
            if now then playClick() end
            lib.emit(behavior.signal)
        end
    end
end

-- The plates and sockets, looked up again when the world or its body count changes, else
-- every rescanSteps (a behavior added in the editor): every body every step was 4500
-- behavior lookups a frame with 20 Mipos.
lib.rescanSteps = 60
local triggerScan = { world = nil, bodyCount = -1, steps = 0, list = {} }

local function triggerBodies(world)
    local count = world:getBodyCount()
    triggerScan.steps = triggerScan.steps - 1
    if triggerScan.world ~= world or triggerScan.bodyCount ~= count or triggerScan.steps <= 0 then
        local list = {}
        for _, body in ipairs(world:getBodies()) do
            local socket, plate = behaviors.find(body, 'SIGNAL_SOCKET'), behaviors.find(body, 'SIGNAL_PLATE')
            if socket or plate then list[#list + 1] = body end
        end
        triggerScan.world, triggerScan.bodyCount = world, count
        triggerScan.steps, triggerScan.list = lib.rescanSteps, list
    end
    return triggerScan.list
end

function lib.update()
    if not state.physicsWorld then return end
    for body, trip in pairs(travellingNow()) do
        if body:isDestroyed() or type(trip) ~= 'table' then
            travelling[body] = nil
        elseif trip.steps <= 1 then
            body:setSleepingAllowed(trip.sleepingAllowed)
            travelling[body] = nil
        else
            trip.steps = trip.steps - 1
        end
    end
    local snapJoints = nil
    for _, body in ipairs(triggerBodies(state.physicsWorld)) do
        local socket = not body:isDestroyed() and behaviors.find(body, 'SIGNAL_SOCKET')
        if socket then
            snapJoints = snapJoints or snap.joints()
            edge(socketWasFilled, body, socket, socketIsFilled(body, socket, snapJoints))
        end
        local plate = not body:isDestroyed() and behaviors.find(body, 'SIGNAL_PLATE')
        if plate then
            local touching = plateIsPressed(body)
            plateFreeFrames[body] = touching and 0 or (plateFreeFrames[body] or 0) + 1
            local was = plateWasPressed[body]
            local release = plate.mode == 'toggle' and lib.toggleReleaseFrames or lib.plateReleaseFrames
            local pressed = touching or (was and plateFreeFrames[body] < release) or false
            edge(plateWasPressed, body, plate, was == nil and touching or pressed)
        end
    end
end

-- After a scene loads, drive every gate to its saved state.
function lib.applySavedStates()
    if not state.physicsWorld then return end
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        local b = behaviors.find(body, 'SIGNAL_GATE')
        if b then lib.setGate(body, b.open or false) end
    end
end

return lib
