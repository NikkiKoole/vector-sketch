-- signals.lua
-- Wiring for contraptions (docs/DOLL-PLAY.md, contraption kit): triggers send a
-- named signal, receivers listening to that name act on it. Both are behaviors on
-- the body's thing, so they save with the scene and show up in the editor's
-- "add behavior" list:
--   { name = 'SIGNAL_BUTTON', signal = 'gate1' }             tap it -> sends 'gate1'
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

-- Gate: a body on a prismatic joint whose upper limit is 'closed' and lower
-- limit 'open'. The motor drives it to one end.
function lib.setGate(body, open)
    local b = findBehavior(body, 'SIGNAL_GATE')
    local joint = prismaticOf(body)
    if not b or not joint then return end
    b.open = open
    joint:setMotorEnabled(true)
    joint:setMaxMotorForce(lib.gateForce)
    joint:setMotorSpeed(open and -lib.gateSpeed or lib.gateSpeed)
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
local triggerNames = { SIGNAL_BUTTON = true }

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

-- After a scene loads, drive every gate to its saved state.
function lib.applySavedStates()
    if not state.physicsWorld then return end
    for _, body in ipairs(state.physicsWorld:getBodies()) do
        local b = findBehavior(body, 'SIGNAL_GATE')
        if b then lib.setGate(body, b.open or false) end
    end
end

return lib
