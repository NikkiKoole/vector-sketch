local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local sceneIO = require('src.io')
local utils = require('src.utils')
local recorder = require('src.recorder')
local script = require('src.script')
local SE = require('src.script-events')
local Peeker = require('vendor.peeker')
local camera = require('src.camera')
local cam = camera.getInstance()

local BUTTON_SPACING = ui.theme.spacing
local FPS = 60

-- Wide, not tall: three columns side by side, checkpoints | gestures | video.
function lib.drawRecordingUI()
    local columnW = 220
    local gap = BUTTON_SPACING
    local panelWidth = columnW * 3 + gap * 4
    local buttonHeight = ui.theme.button.height
    local panelHeight = ui.theme.contentTop + 2 * (buttonHeight + gap) + gap
    local startX, startY = ui.topCenter(panelWidth)
    ui.panel(startX, startY, panelWidth, panelHeight, '• recording stuff •', function()
        local top = startY + ui.theme.contentTop
        local function column(i) return startX + gap + (i - 1) * (columnW + gap) end
        local width = columnW
        local function startFromCurrentCheckpoint()
            state.selection.selectedJoint = nil
            state.selection.selectedObj = nil
            local checkpoint = state.scene.checkpoints[state.scene.activeCheckpointIndex]
            sceneIO.buildWorld(checkpoint.saveData, state.physicsWorld, cam, true)
            --

            script.call(SE.ON_START)
        end

        -- checkpoints: add one, then A B C ... to start from it
        local x, y = column(1), top
        local addcheckpointbutton = ui.button(x, y, width, 'add checkpoint')
        if addcheckpointbutton then
            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)
            table.insert(state.scene.checkpoints, { saveData = saveData, recordings = {} })
        end
        y = y + buttonHeight + gap
        local chars = { 'A', 'B', 'C', 'D', 'E', 'F' }
        for i = 1, #state.scene.checkpoints do
            if ui.button(x + (i - 1) * 45, y, 40, chars[i] or tostring(i)) then
                if state.scene.activeCheckpointIndex > 0 then
                    state.scene.checkpoints[state.scene.activeCheckpointIndex].recordings = utils.deepCopy(recorder
                        .recordings)
                end

                state.scene.activeCheckpointIndex = i

                recorder.recordings = utils.deepCopy(state.scene.checkpoints[state.scene.activeCheckpointIndex]
                    .recordings)
                startFromCurrentCheckpoint()
            end
        end
        local function videoing()
            if Peeker.get_status() then
                Peeker.isProcessing = true
                Peeker.stop()
            else
                Peeker.isProcessing = false
                Peeker.start({
                    --w = 320,   --optional
                    --h = 320,   --optional
                    scale = 1, --this overrides w, h above, this is preferred to keep aspect ratio
                    --n_threads = 1,
                    fps = FPS,
                    out_dir = string.format("awesome_video"), --optional
                    -- format = "mkv", --optional
                    overlay = "circle",                       --or "text"
                    post_clean_frames = false,
                    total_frames = 1000,
                })
            end
        end

        -- gestures: record / replay from the active checkpoint
        x, y = column(2), top
        if state.scene.activeCheckpointIndex > 0
            and ((not recorder.isRecording and state.world.paused) or recorder.isRecording) then
            local pointerbutton = ui.button(x, y, width,
                recorder.isRecording and 'RECORDING gestures' or 'record gestures')
            if pointerbutton then
                if recorder.isRecording then
                    recorder:stopRecording()
                else
                    startFromCurrentCheckpoint()
                    recorder:startRecording()
                    recorder:startReplay() -- needed to replay earlier recordings if any.
                end
            end
            if #recorder.recordings > 0 then
                y = y + buttonHeight + gap

                local replaybutton = ui.button(x, y, width, 'replay gestures')
                if replaybutton then
                    startFromCurrentCheckpoint()
                    recorder:startReplay()
                end
            end
        end
        -- video: record the gestures as video, open the save folder
        x, y = column(3), top
        -- only allowed to start recording from pause
        if state.scene.activeCheckpointIndex > 0 then
            local peekerbutton = ui.button(x, y, width,
                Peeker.get_status() and 'RECORDING gesture video' or 'record gesture video')
            if peekerbutton then
                if not Peeker.get_status() then
                    state.world.paused = true -- it starts recording from pause so should start playing like that too
                    startFromCurrentCheckpoint()
                    recorder:startReplay()
                end
                videoing()
            end
            y = y + buttonHeight + gap
        end
        local saveloc = ui.button(x, y, width, 'open savedir')
        if saveloc then
            love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
        end

    end)
end

return lib
