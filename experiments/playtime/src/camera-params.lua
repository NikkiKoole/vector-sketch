-- camera-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's camera
-- section (src/ui/world-settings.lua). The target is the scene's camera settings
-- (src/camera-follow.lua, state.cameraSettings), saved with the scene.
local lib = {}

local function cameraFollow() return require('src.camera-follow') end

local function field(key, label, kind, min, max, advanced)
    return { key = label, kind = kind, min = min, max = max, advanced = advanced,
        get = function(s) return s[key] end,
        set = function(s, v) s[key] = v end }
end

-- One side of the bounds, as a plain number field (shown once there are bounds).
local function side(i, label)
    return { key = label, kind = 'numberText',
        visible = function(s) return s.bounds ~= nil end,
        get = function(s) return s.bounds[i] end,
        set = function(s, v) s.bounds[i] = v end }
end

lib.rows = {
    field('follow', 'follow', 'bool'),
    field('edgePan', 'edge pan', 'bool'), -- dragging something to the screen edge pans
    field('deadZone', 'dead zone', 'number', 0, 0.45),
    field('speed', 'catch up', 'number', 0.5, 10),
    field('lookAhead', 'look ahead', 'number', 0, 1),
    field('minZoom', 'min zoom', 'number', 0.05, 2),
    field('maxZoom', 'max zoom', 'number', 0.5, 10),
    { key = 'bounds', kind = 'note',
      label = function(s)
          if not s.bounds then return 'no bounds: the camera goes anywhere' end
          return 'bounds (playing keeps the view inside)'
      end },
    side(1, 'left'), side(2, 'top'), side(3, 'right'), side(4, 'bottom'),
    { kind = 'action', label = 'bounds = this view',
      run = function() cameraFollow().boundsFromView() end },
    { kind = 'action', label = 'no bounds',
      run = function(_, s) s.bounds = nil end },
    -- advanced
    field('maxLead', 'max lead', 'number', 0, 0.45, true),
    field('edgeMargin', 'edge px', 'number', 10, 250, true),
    field('edgeSpeed', 'edge speed', 'number', 100, 3000, true),
    field('edgeLag', 'edge lag', 'number', 20, 600, true), -- held thing this far behind the cursor: no pan
}

function lib.target() return cameraFollow().settings() end

return lib
