-- sky-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's sky section
-- (src/ui/world-settings.lua): the scene's sky (src/scene-sky.lua, docs/SKY.md). Saved with the scene.
local lib = {}

local sceneSky = require('src.scene-sky')

local function on(s) return s.on == true end
local function runs(s) return s.on == true and s.runs == true end

local function clock(hour)
    local h = math.floor(hour)
    return string.format('%02d:%02d', h, math.floor((hour - h) * 60))
end

lib.rows = {
    { key = 'sky', kind = 'bool',
      get = function(s) return s.on == true end,
      set = function(s, v) s.on = v and true or false end },
    { key = 'hour', kind = 'number', min = 0, max = 24, step = 0.25, visible = on,
      get = function(s) return s.hour end,
      set = function(s, v) s.hour = v % 24 end },
    { key = 'clock', kind = 'note', visible = on,
      label = function(s) return 'the time: ' .. clock(s.hour) end },
    { key = 'day runs', kind = 'bool', visible = on,
      get = function(s) return s.runs == true end,
      set = function(s, v) s.runs = v and true or false end },
    { key = 'day length (s)', kind = 'number', min = 10, max = 1200, step = 10, visible = runs,
      get = function(s) return s.dayLength end,
      set = function(s, v) s.dayLength = v end },
    { key = 'horizon y', kind = 'numberText', visible = on,
      get = function(s) return s.horizon end,
      set = function(s, v) s.horizon = v end },
    { kind = 'action', label = 'horizon at feet', visible = on, -- where the Mipos' feet are
      run = function() sceneSky.horizonAtFeet() end },
}

function lib.target() return sceneSky.settings() end

return lib
