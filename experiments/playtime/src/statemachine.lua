-- statemachine.lua — small state-machine helper for Mipolai apps.
--
-- See docs/MIPOLAI-COMMON.md ("Game state machine") for design rationale.
-- A game IS its top-level state machine. This helper makes that explicit so
-- transitions can't bypass the lifecycle, overlays don't leak, and data
-- flows cleanly between states.
--
-- Each state is a table with optional hooks:
--   enter(data)            called when the state becomes the active top
--   update(dt)             called each frame while the state is the active top
--   draw()                 called each frame while the state is the active top
--   leave(nextState, data) called when the state stops being active
--                          (transition away, pop, back, clear)
--   resume(returnedData)   called when an overlay above this state popped and
--                          this state is the new top again
--
-- States form a stack. The top is the active state. Three navigation ops:
--   transition(to, data)   replace the top — linear flow (bath -> reveal -> bath)
--   push(to, data)         add an overlay — previous top stays alive but inactive
--   pop(data)              remove the top — previous top below gets resume(data)
--
-- Plus convenience:
--   back(data)             transition to the previous state recorded in history
--   clear()                pop everything (firing leave on each), escape hatch
--
-- Set `sm.log = true` to print every navigation event — useful for /console
-- inspection via the bridge during development.

local lib = {}
local SM = {}
SM.__index = SM

local function _now()
    return (love and love.timer) and love.timer.getTime() or 0
end

local function _callHook(self, name, hook, ...)
    local s = self.states[name]
    if s and s[hook] then s[hook](...) end
end

local function _log(self, msg)
    if self.log then print('[sm] ' .. msg) end
end

local function _enterState(self, to, data)
    self.stack[#self.stack + 1] = to
    self.stateEnteredAt = _now()
    _callHook(self, to, 'enter', data)
end

function lib.new()
    local self = setmetatable({}, SM)
    self.states = {}            -- name -> hooks table
    self.stack = {}             -- active stack of state names; top = stack[#stack]
    self.history = {}           -- linear chain of past states from transition()
    self.stateEnteredAt = nil   -- _now() at the last enter, for timeInState()
    self.log = false
    return self
end

function SM:state(name, hooks)
    assert(type(name) == 'string', 'state(): name must be a string')
    assert(type(hooks) == 'table', 'state(): hooks must be a table')
    self.states[name] = hooks
    return self
end

function SM:transition(to, data)
    assert(self.states[to], "transition: state '" .. tostring(to) .. "' not registered")
    local from = self:current()
    if from then
        _callHook(self, from, 'leave', to, data)
        table.insert(self.history, from)
        self.stack[#self.stack] = nil
    end
    _log(self, (from or '(none)') .. ' -> ' .. to)
    _enterState(self, to, data)
end

function SM:push(to, data)
    assert(self.states[to], "push: state '" .. tostring(to) .. "' not registered")
    local under = self:current()
    _log(self, 'push ' .. to .. ' (under ' .. (under or '(none)') .. ')')
    _enterState(self, to, data)
end

function SM:pop(data)
    local top = self:current()
    assert(top, 'pop: stack is empty')
    local under = self.stack[#self.stack - 1]
    _callHook(self, top, 'leave', under, data)
    self.stack[#self.stack] = nil
    _log(self, 'pop ' .. top .. ' -> ' .. (under or '(empty)'))
    if under then
        self.stateEnteredAt = _now()
        _callHook(self, under, 'resume', data)
    end
end

-- Go to the previous state in history. Unlike transition, does NOT record
-- the current state onto history (otherwise back-back-back would oscillate).
function SM:back(data)
    local prev = table.remove(self.history)
    if not prev then return false end
    local from = self:current()
    if from then
        _callHook(self, from, 'leave', prev, data)
        self.stack[#self.stack] = nil
    end
    _log(self, 'back ' .. (from or '(none)') .. ' -> ' .. prev)
    _enterState(self, prev, data)
    return true
end

-- Pop the entire stack, firing leave on each top in turn. Use as an escape
-- hatch, or before a fresh transition when overlays were left in place.
function SM:clear()
    while #self.stack > 0 do
        local top = self.stack[#self.stack]
        local under = self.stack[#self.stack - 1]
        _callHook(self, top, 'leave', under, nil)
        self.stack[#self.stack] = nil
    end
    _log(self, 'clear')
end

function SM:update(dt)
    local top = self:current()
    if top then _callHook(self, top, 'update', dt) end
end

function SM:draw()
    local top = self:current()
    if top then _callHook(self, top, 'draw') end
end

function SM:current() return self.stack[#self.stack] end
function SM:depth()   return #self.stack end

function SM:timeInState()
    if not self.stateEnteredAt then return 0 end
    return _now() - self.stateEnteredAt
end

function SM:getHistory()
    local copy = {}
    for i, v in ipairs(self.history) do copy[i] = v end
    return copy
end

return lib
