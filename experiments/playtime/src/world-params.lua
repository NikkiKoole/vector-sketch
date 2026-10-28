-- world-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the world settings panel
-- (src/ui/world-settings.lua). The target is `state.world`; the grid lives in
-- `state.editorPreferences`. Debug draw switches and the profiler sit behind
-- '+ more'. Ranges are the ones the old panel used.
local lib = {}

local function state() return require('src.state') end

local function flag(key, label, advanced)
    return { key = label, kind = 'bool', advanced = advanced,
        get = function(world) return world[key] == true end,
        set = function(world, v) world[key] = v end }
end

local function number(key, label, min, max, advanced)
    return { key = label, kind = 'number', min = min, max = max, advanced = advanced,
        get = function(world) return world[key] end,
        set = function(world, v) world[key] = v end }
end

local profileFrames = 0

-- Profile 60 frames with ProFi, then write profilingReport.txt.
local function stopProfiling(world)
    local ProFi = require('vendor.ProFi')
    ProFi:stop()
    ProFi:writeReport('profilingReport.txt')
    world.profiling = false
    profileFrames = 0
end

-- Called every frame the panel is open (the old panel counted frames the same way).
function lib.tick(world)
    if world.profiling then
        profileFrames = profileFrames + 1
        if profileFrames >= 60 then stopProfiling(world) end
    end
end

lib.rows = {
    { key = 'gravity', kind = 'number', min = -10, max = 20,
      get = function(world) return world.gravity end,
      set = function(world, v)
          world.gravity = v
          local physicsWorld = state().physicsWorld
          if physicsWorld then physicsWorld:setGravity(0, v * world.meter) end
      end },
    number('speedMultiplier', 'speed', 0.1, 10),
    { key = 'grid', kind = 'bool',
      get = function() return state().editorPreferences.showGrid == true end,
      set = function(_, v) state().editorPreferences.showGrid = v end },
    flag('showTextures', 'textures'),
    flag('textureOrBody', 'tex/body'), -- textured bodies show only their texture (src/physics/box2d-draw.lua)
    flag('darkMode', 'dark'),
    { key = 'compact', kind = 'bool', -- src/ui/density.lua; applied between frames (main.lua)
      get = function() return (state().pendingDensity or require('src.ui.density').name()) == 'compact' end,
      set = function(_, v) state().pendingDensity = v and 'compact' or 'roomy' end },
    -- advanced
    flag('debugDrawMode', 'debug', true),
    number('debugAlpha', 'alpha', 0, 1, true),
    flag('debugDrawBodies', 'bodies', true),
    flag('debugDrawJoints', 'joints', true),
    flag('drawFixtures', 'sfixtures', true),
    flag('drawOutline', 'outline', true),
    flag('showDebugIds', 'ids', true),
    number('mouseForce', 'drag', 0, 1000000, true),
    number('mouseDamping', 'damp', 0.001, 1, true),
    { kind = 'action', advanced = true,
      label = function(world) return world.profiling and 'profiling...' or 'profile 60 frames' end,
      run = function(_, world)
          if world.profiling then
              stopProfiling(world)
          else
              profileFrames = 0
              require('vendor.ProFi'):start()
              world.profiling = true
          end
      end },
    { kind = 'note', advanced = true,
      label = function() return require('src.registry').print() end },
    { kind = 'note', advanced = true,
      label = function()
          local stats = love.graphics.getStats()
          return string.format('%.2f MB, %d batched', stats.texturememory / 1000000, stats.drawcallsbatched)
      end },
}

-- The selected backdrop in the backdrops panel (an entry of `state.backdrops`).
lib.backdropRows = {
    { key = 'scale', kind = 'number', min = 0.05, max = 3, default = 1 },
    { key = 'foreground', kind = 'bool', get = function(bd) return bd.foreground == true end },
    { key = 'border', kind = 'bool', get = function(bd) return bd.border == true end },
}

return lib
