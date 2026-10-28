local lib = {}

local ui = require('src.ui.all')
local registry = require('src.registry')
local joints = require('src.joints')
local inspector = require('src.ui.inspector')
local jointParams = require('src.joint-params')

local BUTTON_HEIGHT = ui.theme.lineHeight

function lib.drawJointUpdateUI(joint, panelX, panelY, w, h)
    if joint:isDestroyed() then return end
    ui.panel(panelX, panelY, w, h, '∞ ' .. joint:getType() .. ' ∞', function()
        ui.scrollPanel('joint-panel', panelX, panelY + ui.theme.panelHeader, w, h - ui.theme.panelHeader - 5, function()
            local x, y = panelX + 10, panelY + ui.theme.panelHeader + ui.theme.spacing + 5
            if ui.button(x, y, w - 20, 'destroy') then
                registry.unregisterJoint(joints.getJointId(joint))
                joint:destroy()
                return
            end
            local params = jointParams.byType[joint:getType()]
            if params then
                inspector.drawParams('joint_' .. tostring(joints.getJointId(joint)), params, joint, nil,
                    x, y + BUTTON_HEIGHT + 20, w - 20)
            end
        end)
    end)
end

return lib
