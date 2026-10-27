-- signals.lua
-- Wiring for contraptions (docs/DOLL-PLAY.md, contraption kit): triggers send a
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

local lib = {}

lib.gateSpeed = 600      -- how fast a gate moves (world units/s)
lib.gateForce = 1e7      -- motor force: enough to hold up a skateboard with a Mipo

local function behaviorsOf(body)
    local ud = body:getUserData()
    return ud and ud.thing and ud.thing.behaviors or nil
end

local function findBehavior(body, name)
    for _, b in ipairs(behaviorsOf(body) or {}) do
        if b.name == name then return b end
    end
    return nil
end

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

-- Gate: a body on a prismatic joint; the motor drives it to the closed end or
-- to the open (world-down) end of its limits.
function lib.setGate(body, open)
    local b = findBehavior(body, 'SIGNAL_GATE')
    local joint = prismaticOf(body)
    if not b or not joint then return end
    ensureGateLimits(body, joint)
    b.open = open
    local dir = openDirection(joint)
    joint:setMotorEnabled(true)
    joint:setMaxMotorForce(lib.gateForce)
    joint:setMotorSpeed((open and dir or -dir) * lib.gateSpeed)
    body:setAwake(true)
end

local receivers = {
    SIGNAL_GATE = function(body, behavior) lib.setGate(body, not behavior.open) end,
}

-- Send a signal: every receiver behavior with that signal name acts on it.
function lib.emit(signal)
    if not signal or not state.physicsWorld then return 0 end
    local count = 0
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        for _, b in ipairs(behaviorsOf(body) or {}) do
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
        local b = findBehavior(body, 'SIGNAL_BUTTON')
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
local triggerNames = { SIGNAL_BUTTON = true, SIGNAL_PLATE = true, SIGNAL_SOCKET = true }

function lib.drawWires(selectedBody)
    if not state.physicsWorld then return end
    local triggers, receivers2 = {}, {}
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        for _, b in ipairs(behaviorsOf(body) or {}) do
            if b.signal and b.name:find('^SIGNAL_') then
                local list = triggerNames[b.name] and triggers or receivers2
                list[b.signal] = list[b.signal] or {}
                table.insert(list[b.signal], body)
            end
        end
    end
    local r, g, b, a = love.graphics.getColor()
    local lineWidth = love.graphics.getLineWidth()
    for signal, from in pairs(triggers) do
        for _, t in ipairs(from) do
            local tx, ty = t:getPosition()
            for _, rcv in ipairs(receivers2[signal] or {}) do
                local rx, ry = rcv:getPosition()
                local selected = selectedBody and (t == selectedBody or rcv == selectedBody)
                love.graphics.setColor(1, 0.85, 0.2, selected and 1 or 0.5)
                love.graphics.setLineWidth(selected and 8 or 3)
                love.graphics.line(tx, ty, rx, ry)
                love.graphics.circle('fill', rx, ry, selected and 14 or 8)
                love.graphics.print(signal, (tx + rx) / 2, (ty + ry) / 2, 0, 3, 3)
            end
        end
    end
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(r, g, b, a)
end

-- Pressure plates: pressed while anything that isn't fixed (a Mipo, a ball, a
-- board) touches the plate body. Polled every frame from main.lua. A press
-- counts at once, a release only after the plate has been free for
-- plateReleaseFrames (a bouncing ball or a wobbling Mipo made the gate chatter).
lib.plateReleaseFrames = 15 -- 0.25s at 60 fps
local plateWasPressed = setmetatable({}, { __mode = 'k' }) -- [body] = bool
local plateFreeFrames = setmetatable({}, { __mode = 'k' }) -- [body] = frames free in a row

local function plateIsPressed(body)
    for _, contact in ipairs(body:getContacts()) do
        if contact:isTouching() then
            local a, b = contact:getFixtures()
            local other = a:getBody() == body and b:getBody() or a:getBody()
            if other:getType() == 'dynamic' and not a:isSensor() and not b:isSensor() then return true end
        end
    end
    return false
end

-- Sockets: filled while something is snapped onto the body. Mipo hands don't
-- count (grabbing the lock isn't a key); `accepts` limits it to one label.
local socketWasFilled = setmetatable({}, { __mode = 'k' }) -- [body] = bool

local function socketIsFilled(body, socket, snapJoints)
    local mipoRegistry = require('src.mipo-registry')
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

function lib.update()
    if not state.physicsWorld then return end
    local snapJoints = nil
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        local socket = findBehavior(body, 'SIGNAL_SOCKET')
        if socket then
            snapJoints = snapJoints or require('src.physics.snap').joints()
            edge(socketWasFilled, body, socket, socketIsFilled(body, socket, snapJoints))
        end
        local plate = findBehavior(body, 'SIGNAL_PLATE')
        if plate then
            local touching = plateIsPressed(body)
            plateFreeFrames[body] = touching and 0 or (plateFreeFrames[body] or 0) + 1
            local was = plateWasPressed[body]
            local pressed = touching or (was and plateFreeFrames[body] < lib.plateReleaseFrames) or false
            edge(plateWasPressed, body, plate, was == nil and touching or pressed)
        end
    end
end

-- After a scene loads, drive every gate to its saved state.
function lib.applySavedStates()
    if not state.physicsWorld then return end
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        local b = findBehavior(body, 'SIGNAL_GATE')
        if b then lib.setGate(body, b.open or false) end
    end
end

return lib
