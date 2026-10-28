-- spec/tool-rail_spec.lua
-- The left tool rail: the tab opens/closes a group's flyout, a flyout pick
-- becomes the group's last pick (what the rail button spawns next), a press
-- elsewhere closes the flyout, and a click on the rail button without a drag
-- leaves no body behind.
-- Run with: love . --specs spec/tool-rail_spec.lua

if not love then return end

local state = require('src.state')
local ui = require('src.ui.all')
local registry = require('src.registry')
local toolRail = require('src.ui.tool-rail')

describe('tool rail', function()
    local canvas
    local saved
    local world

    setup(function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        canvas = love.graphics.newCanvas(1200, 768)
        saved = state.toolRail
        state.toolRail = { open = nil, last = {} }
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
    end)

    teardown(function()
        canvas:release()
        world:destroy()
        state.toolRail = saved
    end)

    local function frame(mx, my, pressed, released)
        ui.startFrame()
        ui.mouseX, ui.mouseY = mx, my
        ui.mousePressed, ui.mouseReleased = pressed, released
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(toolRail.draw)
        love.graphics.setCanvas()
        assert.is_true(ok, tostring(err))
    end

    local function click(mx, my)
        frame(mx, my, true, false)
        frame(mx, my, false, true)
    end

    -- rail geometry, mirrored from tool-rail.lua (button 56 + tab 18 at x 10, y 60)
    local gap = ui.theme.spacing
    local buttonX, buttonY = 10 + gap + 28, 60 + gap + 28
    local tabX = 10 + gap + 56 + 9

    local function countBodies()
        local n = 0
        for _ in pairs(registry.bodies) do n = n + 1 end
        return n
    end

    it('the tab opens and closes the flyout', function()
        click(tabX, buttonY)
        assert.are.equal('shape', state.toolRail.open)
        click(tabX, buttonY)
        assert.is_nil(state.toolRail.open)
    end)

    it('a press elsewhere closes the flyout', function()
        click(tabX, buttonY)
        assert.are.equal('shape', state.toolRail.open)
        click(700, 700)
        assert.is_nil(state.toolRail.open)
    end)

    it('the rail button reuses the default pick and a click without a drag leaves nothing', function()
        assert.are.equal('rectangle', toolRail.lastPick(toolRail.groups[1]))
        local before = countBodies()
        click(buttonX, buttonY)
        assert.are.equal(before, countBodies())
    end)

    it('a flyout pick becomes the last pick and closes the flyout', function()
        click(tabX, buttonY)
        -- 'circle' is the second item of the first row: right column
        local flyoutX = 10 + gap * 2 + 56 + 18 + gap
        local circleX = flyoutX + gap + 110 + gap + 55
        local circleY = 60 + gap + gap + ui.theme.button.height / 2
        local before = countBodies()
        click(circleX, circleY)
        assert.are.equal('circle', toolRail.lastPick(toolRail.groups[1]))
        assert.is_nil(state.toolRail.open)
        assert.are.equal(before, countBodies())
    end)
end)
