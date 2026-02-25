local lib = {}

local ui = require('src.ui.all')
local state = require('src.state')
local sceneIO = require('src.io')
local utils = require('src.utils')
local recorder = require('src.recorder')
local Peeker = require('vendor.peeker')
local camera = require('src.camera')
local cam = camera.getInstance()

local PANEL_WIDTH = 300
local BUTTON_HEIGHT = ui.theme.lineHeight
local BUTTON_SPACING = 10
local FPS = 60

function lib.drawRecordingUI()
    local startX = 800
    local startY = 70
    local panelWidth = PANEL_WIDTH
    --local panelHeight = 255
    local buttonHeight = ui.theme.button.height

    local titleHeight = ui.font:getHeight() + BUTTON_SPACING
    local panelHeight = titleHeight + titleHeight + (9 * (buttonHeight + BUTTON_SPACING) + BUTTON_SPACING)
    ui.panel(startX, startY, panelWidth, panelHeight, '• recording stuff •', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + titleHeight + BUTTON_SPACING
        })
        local width = panelWidth - BUTTON_SPACING * 2
        local x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        local nextRow = function()
            x, y = ui.nextLayoutPosition(layout, width, BUTTON_HEIGHT)
        end

        local function startFromCurrentCheckpoint()
            state.selection.selectedJoint = nil
            state.selection.selectedObj = nil
            local checkpoint = state.scene.checkpoints[state.scene.activeCheckpointIndex]
            sceneIO.buildWorld(checkpoint.saveData, state.physicsWorld, cam, true)
            --

            if state.scene.sceneScript then state.scene.sceneScript.onStart() end
        end

        local addcheckpointbutton = ui.button(x, y, width, 'add checkpoint')
        if addcheckpointbutton then
            local saveData = sceneIO.gatherSaveData(state.physicsWorld, cam)
            table.insert(state.scene.checkpoints, { saveData = saveData, recordings = {} })
        end
        nextRow()
        local chars = { 'A', 'B', 'C', 'D', 'E', 'F' }
        for i = 1, #state.scene.checkpoints do
            if ui.button(x + (i - 1) * 45, y, 40, chars[i]) then
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
        y = y + 15
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)
        nextRow()




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
                nextRow()

                local replaybutton = ui.button(x, y, width, 'replay gestures')
                if replaybutton then
                    startFromCurrentCheckpoint()
                    recorder:startReplay()
                end
            end
        end
        y = y + 15
        love.graphics.line(x - 20, y + 20, x + panelWidth + 20, y + 20)
        nextRow()
        nextRow()


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
            nextRow()
        end
        local saveloc = ui.button(x, y, width, 'open savedir')
        if saveloc then
            love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
        end

        nextRow()
        -- local peekerbutton2 = ui.button(x, y, width,
        --     Peeker.get_status() and 'RECORDING video' or 'record vanilla video')
        -- if peekerbutton2 then
        --     videoing(false)
        -- end
        nextRow()
    end)
end

return lib
