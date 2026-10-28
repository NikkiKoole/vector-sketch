local lib = {}

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


return lib
