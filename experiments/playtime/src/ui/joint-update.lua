local lib = {}

local ui = require('src.ui.all')
local joints = require('src.joints')
local inspector = require('src.ui.inspector')
local jointParams = require('src.joint-params')


function lib.drawJointUpdateUI(joint, panelX, panelY, w, h)
    if joint:isDestroyed() then return end
    -- title: what kind of thing it is; first row: its name (label), then destroy
    ui.panel(panelX, panelY, w, h, '∞ ' .. joint:getType() .. ' joint ∞', function()
        ui.scrollPanel('joint-panel', panelX, panelY + ui.theme.panelHeader, w, h - ui.theme.panelHeader - 5, function()
            local x, y = panelX + 10, panelY + ui.theme.panelHeader + ui.theme.spacing + 5
            local rows = {}
            for _, row in ipairs(jointParams.header) do rows[#rows + 1] = row end
            for _, row in ipairs(jointParams.byType[joint:getType()] or {}) do rows[#rows + 1] = row end
            inspector.drawParams('joint_' .. tostring(joints.getJointId(joint)), rows, joint, nil, x, y, w - 20)
        end)
    end)
end

return lib
