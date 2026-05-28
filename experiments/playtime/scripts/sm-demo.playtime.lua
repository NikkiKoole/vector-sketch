-- sm-demo.playtime.lua — runnable example of the state-machine helper.
-- Bathhouse-shaped: splash → bath → reveal → bath → ... with a 'paused' overlay.
--
-- Interactive (in playtime):
--   space — advance through splash → bath → reveal → bath (...)
--   p     — toggle the 'paused' overlay
--
-- Programmatic (used by spec/statemachine_integration_spec.lua):
--   state.scene.sceneScript.app — the state machine instance
--   state.scene.sceneScript.discovered — the accumulating list

-- `statemachine` is in the scene-script env (see src/script.lua scriptEnv);
-- no require needed.
local s = {}

local app = statemachine.new()
app.log = false   -- flip true to trace navigation to /console

-- App-scope state. Lives as plain locals at the module top; persists across
-- state transitions because the script isn't reloaded between them.
local discovered = {}
local currentMipo = nil

app:state('splash', {
    enter = function() print('[sm-demo] splash — press space to start') end,
    draw  = function() love.graphics.print('SPLASH (space to start)', 20, 20) end,
})

app:state('bath', {
    enter = function(data)
        -- `data` lets us thread context in. From splash there's none; from
        -- the next-blob path we could pass the chosen mipo.
        currentMipo = (data and data.mipo) or ('mipo' .. (#discovered + 1))
        print('[sm-demo] bath — washing ' .. currentMipo)
    end,
    draw = function() love.graphics.print('BATH — washing ' .. tostring(currentMipo), 20, 20) end,
})

app:state('reveal', {
    enter = function(data)
        -- Persistent record of every discovery. App-scope state, untouched
        -- by transitions.
        if data and data.mipo then table.insert(discovered, data.mipo) end
        print('[sm-demo] reveal — discovered ' .. tostring(data and data.mipo))
    end,
    draw = function()
        love.graphics.print('REVEAL — ' .. tostring(currentMipo) .. ' discovered (' .. #discovered .. ' total)', 20, 20)
    end,
})

app:state('paused', {
    -- Overlay: pushed on top of whatever was active. Bath stays alive
    -- underneath and gets `resume(data)` when this is popped.
    enter  = function() print('[sm-demo] paused (overlay)') end,
    draw   = function() love.graphics.print('PAUSED — press p to resume', 20, 60) end,
})

-- Scene-script lifecycle hooks forward to the state machine.
function s.onStart()  app:transition('splash') end
function s.update(dt) app:update(dt) end
function s.draw()     app:draw() end

function s.onKeyPress(key)
    if key == 'space' then
        local cur = app:current()
        if cur == 'splash' then app:transition('bath')
        elseif cur == 'bath' then app:transition('reveal', { mipo = currentMipo })
        elseif cur == 'reveal' then app:transition('bath')
        end
    elseif key == 'p' then
        if app:current() == 'paused' then app:pop() else app:push('paused') end
    end
end

-- Expose internals so the integration spec can drive and inspect.
s.app = app
s.discovered = discovered

return s
