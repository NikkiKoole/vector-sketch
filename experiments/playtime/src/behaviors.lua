local lib = {}
local utils = require('src.utils')

-- `params`: what the inspector (src/ui/inspector.lua) shows for a behavior, in
-- order. Each row: { key, kind = 'text'|'number'|'bool'|'choice'|'action',
-- label?, default?, min/max/step (number), options (choice), advanced = true
-- (hidden behind 'more') }. An 'action' row is a button: `label` may be a
-- function(behavior) and `run(body, behavior)` does the work.

local function signals() return require('src.signals') end -- lazy: signals -> state

local signalRow = { key = 'signal', kind = 'text', default = 'signal1' }
local modeRow = { key = 'mode', kind = 'choice', options = { 'hold', 'toggle' }, default = 'hold' }

lib.allBehaviors = {
    { name = 'KEEP_ANGLE',
      description = 'keep a body at a certain angle, still not completely settled on the other variables. Kp*I etc.',
      params = {
          { key = 'angle', kind = 'number', min = -180, max = 180, step = 1, default = 0 },
          { key = 'enabled', kind = 'bool', default = true },
          { key = 'kp', label = 'strength', kind = 'number', min = 1, max = 100, step = 1, default = 20,
            advanced = true },
          { key = 'maxOmega', label = 'max spin', kind = 'number', min = 1, max = 40, step = 1, default = 15,
            advanced = true },
      } },
    { name = 'LIMB_HUB',
      description = 'a polygon that has things attached, the location where is defined in here, '
        .. 'by its edge number and a lerp between vertex -1 and vertex.' },
    { name = 'SIGNAL_BUTTON',
      description = 'tap it to send its signal (default gate1) to receivers (src/signals.lua).',
      params = {
          signalRow,
          { kind = 'action', label = 'send now', run = function(_, b) signals().emit(b.signal) end },
      } },
    { name = 'SIGNAL_PLATE',
      description = 'pressure plate: anything resting on it sends its signal; hold mode sends again when free.',
      params = { signalRow, modeRow } },
    { name = 'SIGNAL_SOCKET',
      description = 'socket: something snapped onto it (not a Mipo hand; label = accepts if set) sends its signal.',
      params = {
          signalRow, modeRow,
          { key = 'accepts', kind = 'text', default = '' },
      } },
    { name = 'SIGNAL_GATE',
      description = 'a body on a prismatic joint; toggles open/closed on its signal (src/signals.lua).',
      params = {
          signalRow,
          { kind = 'action', label = function(b) return b.open and 'open' or 'closed' end,
            run = function(body, b) signals().setGate(body, not b.open) end },
      } },
    { name = 'DOOR',
      description = 'a door to another room (src/doors.lua): tap to open, drop a Mipo on it, tap to go in. '
        .. 'door = its own name, to = the room (scripts/<to>.playtime.json), arrive = the door you come out of there.',
      params = {
          { key = 'door', kind = 'text', default = 'door1' },
          { key = 'to', kind = 'text', default = '' },
          { key = 'arrive', kind = 'text', default = '' },
      } },
    { name = 'SQUISHY',
      description = 'soft prop: plays a winegum-kiss sound when it hits something (src/mipo-voice.lua).',
      params = {} },
}

-- A body's behaviors ({} for none, or a destroyed body).
function lib.all(body)
    if body:isDestroyed() then return {} end
    local thing = utils.thingOf(body)
    return thing and thing.behaviors or {}
end

-- The body's behavior called `name`, or nil.
function lib.find(body, name)
    for _, b in ipairs(lib.all(body)) do
        if b.name == name then return b end
    end
    return nil
end

-- A SIGNAL_* behavior that has its signal set.
function lib.isSignal(b)
    return b.signal ~= nil and b.name:find('^SIGNAL_') ~= nil
end

-- Add the behavior `name` to a body's thing, in place: whoever holds that thing
-- (the selection, a Mipo's parts) still sees it. The panel used to put a copy of
-- the whole userData on the body, and the selection kept the old thing (BUG9).
function lib.add(body, name)
    local thing = utils.thingOf(body)
    thing.behaviors = thing.behaviors or {}
    local added = { name = name }
    if name:find('^SIGNAL_') then added.signal = 'signal1' end
    if name == 'DOOR' then
        -- a door doesn't collide: Mipos walk past it (sfixtures keep their own setting)
        added.door = 'door1'
        for _, fixture in ipairs(body:getFixtures()) do
            if not fixture:getUserData() then fixture:setSensor(true) end
        end
    end
    table.insert(thing.behaviors, added)
    return added
end

return lib
