-- light-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's light section
-- (src/ui/world-settings.lua): the scene's light level (also the bulb under the sound button); the Mipos'
-- look on top of the level's (clay, light from the front, swing, roundness); what the shadows land on and
-- how dark and far; its floor, for the full level's 3D shadows (src/scene-light.lua). Saved with the scene.
local lib = {}

local sceneLight = require('src.scene-light')
local state = require('src.state')

local function levelNames()
    local names = {}
    for i, level in ipairs(sceneLight.LEVELS) do names[i] = level.name end
    return names
end

local function hasFloor(s) return s.floor ~= nil end
local function lit(s) return s.level ~= 'off' end
local function shadows(s) return s.level == 'shadows' or s.level == 'full' end

-- a Mipo row: the scene's own value, else the level's
local function mipoRow(name, label, min, max, step)
    return { key = label, kind = 'number', min = min, max = max, step = step, visible = lit,
        get = function(s) local m = s.mipo; if m and m[name] ~= nil then return m[name] end
            return sceneLight.mipoDefault(name) end,
        set = function(s, v) s.mipo = s.mipo or {}; s.mipo[name] = v end }
end

lib.rows = {
    { key = 'level', kind = 'choice', options = levelNames(),
      get = function(s) return s.level end,
      set = function(s, v) s.level = v end },

    -- the Mipos (the Mipo shader's settings the level puts on their parts)
    { key = 'mipos', kind = 'note', visible = lit, label = '- Mipos -' },
    { key = 'clay', kind = 'choice', options = { 'level', 'on', 'off' }, visible = lit,
      get = function(s) local c = s.mipo and s.mipo.clay; if c == nil then return 'level' end
          return c and 'on' or 'off' end,
      set = function(s, v) s.mipo = s.mipo or {}
          if v == 'level' then s.mipo.clay = nil else s.mipo.clay = v == 'on' end end,
      display = function(_, v)
          if v ~= 'level' then return v end
          return 'as the level (' .. (sceneLight.mipoDefault('clay') and 'on' or 'off') .. ')'
      end },
    mipoRow('front', 'front', 0, 1.5, 0.05),
    mipoRow('swing', 'swing', 0, 1, 0.05),
    mipoRow('round', 'round', 0, 1, 0.05),
    -- parts shadowing each other (src/part-shadows.lua): an arm on its torso, a Mipo on the one behind
    { key = 'part shadows', kind = 'number', min = 0, max = 1, step = 0.05, visible = lit,
      get = function(s) return s.partShadow or 0 end,
      set = function(s, v) s.partShadow = v > 0 and v or nil end },
    { kind = 'action', label = 'Mipos as the level', visible = lit,
      run = function(_, s) s.mipo = nil end },

    -- the wall: what the shadows land on (no shadow on open sky)
    { key = 'wall', kind = 'note', visible = shadows, label = '- wall -' },
    -- options looked up when drawn: a hot swap that reloads this file before scene-light's had nil here
    { key = 'falls on', kind = 'choice', options = function() return sceneLight.WALL_CHOICES end,
      visible = shadows,
      get = function(s) return s.wall or 'auto' end,
      set = function(s, v) s.wall = v ~= 'auto' and v or nil end,
      display = function(s, v)
          if v ~= 'auto' then return v end
          return 'auto (' .. sceneLight.wallOf(s) .. ')'
      end },
    { key = 'dark', kind = 'number', min = 0, max = 2, step = 0.05, visible = shadows,
      get = function(s) return s.wallShadow or 1 end,
      set = function(s, v) s.wallShadow = v ~= 1 and v or nil end },
    { key = 'behind', kind = 'number', min = 0, max = 400, step = 10, visible = shadows,
      get = function(s) return s.wallBehind or sceneLight.DEFAULT_BEHIND end,
      set = function(s, v) s.wallBehind = v ~= sceneLight.DEFAULT_BEHIND and v or nil end },

    -- the floor, for the full level's 3D shadows
    { key = 'floorhead', kind = 'note', label = '- floor -' },
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
