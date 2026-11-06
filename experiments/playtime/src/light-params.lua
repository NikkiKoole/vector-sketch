-- light-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's light section
-- (src/ui/world-settings.lua): the scene's light level (also the bulb under the sound button) and its
-- floor, for the full level's 3D shadows (src/scene-light.lua). Saved with the scene.
local lib = {}

local sceneLight = require('src.scene-light')
local state = require('src.state')

local function levelNames()
    local names = {}
    for i, level in ipairs(sceneLight.LEVELS) do names[i] = level.name end
    return names
end

local function hasFloor(s) return s.floor ~= nil end

lib.rows = {
    { key = 'level', kind = 'choice', options = levelNames(),
      get = function(s) return s.level end,
      set = function(s, v) s.level = v end },
    { key = 'floor', kind = 'note',
      label = function(s)
          if not s.floor then return 'no floor: no 3D shadows (full)' end
          return 'floor: 3D shadows at full'
      end },
    { kind = 'action', label = 'floor at feet', -- where the Mipos' feet are
      run = function()
          -- shown on the stage right away: what was just set
          if sceneLight.floorUnderMipos() then state.floorGuideOn = true end
      end },
    { kind = 'action', label = 'no floor',
      run = function(_, s) s.floor = nil end },
    -- the floor's lines on the stage (src/floor-guide.lua), to see and drag them; off by default and not
    -- saved: a deep setting, not something to look at all the time (Nikki 2026-11-06)
    { key = 'floor on stage', kind = 'bool', visible = hasFloor,
      get = function() return state.floorGuideOn == true end,
      set = function(_, v) state.floorGuideOn = v or nil end },
    { key = 'stand y', kind = 'numberText', visible = hasFloor,
      get = function(s) return s.floor.standY end,
      set = function(s, v) s.floor.standY = v end },
    { key = 'depth', kind = 'number', min = 50, max = 1200, step = 10, visible = hasFloor,
      get = function(s) return s.floor.depth end,
      set = function(s, v) s.floor.depth = v end },
}

function lib.target() return sceneLight.settings() end

return lib
