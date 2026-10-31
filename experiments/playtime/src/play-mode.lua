-- play-mode.lua — the scene as its shipped self (docs/DOLL-PLAY.md F2): no editor
-- panels, overlays, grid or HUD, physics running, and the pointer only plays (grab,
-- onPressed/onReleased, signals, doors). Tab goes in and out; `love . --play <scene>`
-- (or `./playtime.sh play <scene>`) starts in it. Leaving puts back the pause the
-- editor had; the selection and tool mode are left alone, so you're back where you were.
local lib = {}

local state = require('src.state')
local ui = require('src.ui.all')

local HINT_SECONDS = 2.5

function lib.isOn() return state.playMode == true end

function lib.enter()
    if lib.isOn() then return end
    state.playMode = true
    state.playModeSaved = { paused = state.world.paused }
    state.playModeEnteredAt = love.timer.getTime()
    state.world.paused = false
    state.interaction.draggingObj = nil
    state.interaction.startSelection = nil
    ui.overPanel = false
    ui.focusedTextInputID = nil
end

function lib.exit()
    if not lib.isOn() then return end
    state.playMode = false
    local saved = state.playModeSaved or {}
    state.world.paused = saved.paused ~= false
    state.playModeSaved = nil
end

function lib.toggle()
    if lib.isOn() then lib.exit() else lib.enter() end
end

-- The way back to the editor on a phone (no tab key there): a small faint circle in the
-- top-left corner. Phones only; on a desktop play mode stays clean and tab goes back.
-- (A kids' build would hide this behind a parent gate, a long press say.)
local EXIT_X, EXIT_Y, EXIT_R = 30, 30, 18 -- screen points; the hit area is a bit bigger

local function onPhone()
    local system = love.system.getOS()
    return system == 'iOS' or system == 'Android'
end

function lib.drawExitButton()
    if not lib.isOn() or not onPhone() then return end
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.circle('fill', EXIT_X, EXIT_Y, EXIT_R)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.circle('line', EXIT_X, EXIT_Y, EXIT_R)
    -- two bars: 'pause, back to the editor'
    love.graphics.rectangle('fill', EXIT_X - 6, EXIT_Y - 7, 4, 14)
    love.graphics.rectangle('fill', EXIT_X + 2, EXIT_Y - 7, 4, 14)
    love.graphics.setColor(1, 1, 1, 1)
end

-- True when touch `id` at (x, y) (screen points) pressed the exit button. Play mode is left
-- when that finger lifts (releasedExitButton): left on the press, the finger was still
-- down in the editor, on its play button, and lifting it went straight back in.
function lib.pressedExitButton(id, x, y)
    if not lib.isOn() or not onPhone() then return false end
    if (x - EXIT_X) ^ 2 + (y - EXIT_Y) ^ 2 > (EXIT_R + 12) ^ 2 then return false end
    state.playModeExitTouch = id
    return true
end

-- True when touch `id` was the exit button's; leaves play mode.
function lib.releasedExitButton(id)
    if state.playModeExitTouch == nil or state.playModeExitTouch ~= id then return false end
    state.playModeExitTouch = nil
    lib.exit()
    return true
end

-- A small 'tab: editor' that fades out after going in (screen space).
function lib.drawHint()
    if not lib.isOn() or not state.playModeEnteredAt then return end
    local age = love.timer.getTime() - state.playModeEnteredAt
    if age > HINT_SECONDS then return end
    local alpha = math.min(1, (HINT_SECONDS - age) / 0.6)
    local w = love.graphics.getDimensions()
    local text = 'tab: editor'
    local font = love.graphics.getFont()
    local tw = font:getWidth(text)
    love.graphics.setColor(0, 0, 0, 0.35 * alpha)
    love.graphics.rectangle('fill', w - tw - 34, 14, tw + 20, font:getHeight() + 8, 8, 8)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, w - tw - 24, 18)
    love.graphics.setColor(1, 1, 1, 1)
end

-- `--play <scene>` on the command line: the scene to start in play mode, else nil.
function lib.sceneFromArgs(args)
    for i = 1, #args do
        if args[i] == '--play' and args[i + 1] then return args[i + 1] end
    end
    return nil
end

return lib
