local s = {}

local shoulderWidth = 100
local waistWidth = 60
local hipWidth = 80


local neckHeight = 20 -- the point that sticks out
local upperHeight = 30
local lowerHeight = 30
local hipHeight = 20 -- the point that sticks out


local function updateTorsoPoly(body)
    objectManager.recreateThingFromBody(body,
        { optionalVertices = { 100, 100, 200, 200, 300, 300, 100, 300 } })
end


function s.onStart()
    worldState.paused = false
    torsothing = getObjectsByLabel('torso')[1]

    updateTorsoPoly(torsothing.body)
end

function s.drawUI()
    local w, h = love.graphics.getDimensions()
    local BUTTON_SPACING = 10
    local BUTTON_HEIGHT = 40
    local margin = 20
    local startX = margin
    local panelWidth = 350 --w - margin * 2

    local panelHeight = BUTTON_HEIGHT * 10
    local startY = h - panelHeight - margin


    ui.panel(startX, startY, panelWidth, panelHeight, '•• torso ••', function()
        local layout = ui.createLayout({
            type = 'columns',
            spacing = BUTTON_SPACING,
            startX = startX + BUTTON_SPACING,
            startY = startY + BUTTON_SPACING
        })

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)


        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        local newShoulderWidth = ui.sliderWithInput(' shoulderWidth', x, y, 200, 10, 200, shoulderWidth)
        if newShoulderWidth then
            shoulderWidth = newShoulderWidth
        end
        ui.label(x, y, ' shoulderWidth')

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        local newWaistWidth = ui.sliderWithInput(' waistWidth', x, y, 200, 10, 200, waistWidth)
        if newWaistWidth then
            waistWidth = newWaistWidth
        end
        ui.label(x, y, ' waistWidth')

        local x, y = ui.nextLayoutPosition(layout, panelWidth - 20, BUTTON_HEIGHT)
        local newHipWidth = ui.sliderWithInput(' hipWidth', x, y, 200, 10, 200, hipWidth)
        if newHipWidth then
            hipWidth = newHipWidth
        end
        ui.label(x, y, ' hipWidth')
    end)
end

return s
