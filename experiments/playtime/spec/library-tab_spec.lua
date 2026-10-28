-- spec/library-tab_spec.lua
-- The library tab's shelves: 'toys' is the default, the switch flips to 'mine'
-- and back, and pressing a toy builds it (a ball is one body).
-- Run with: love . --specs spec/library-tab_spec.lua

if not love then return end

local state = require('src.state')
local ui = require('src.ui.all')
local registry = require('src.registry')
local libraryTab = require('src.ui.library-tab')

describe('library tab shelves', function()
    local canvas, world, savedShelf
    local X, Y, W, H = 700, 100, 300, 600

    setup(function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        canvas = love.graphics.newCanvas(1200, 768)
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        savedShelf = state.rightColumn.shelf
        state.rightColumn.shelf = nil
    end)

    teardown(function()
        canvas:release()
        world:destroy()
        state.rightColumn.shelf = savedShelf
        state.selection.selectedBodies = nil
        state.interaction.draggingObj = nil
    end)

    local function frame(mx, my, pressed, released)
        ui.startFrame()
        ui.mouseX, ui.mouseY = mx, my
        ui.mousePressed, ui.mouseReleased = pressed, released
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(libraryTab.draw, X, Y, W, H)
        love.graphics.setCanvas()
        assert.is_true(ok, tostring(err))
    end

    local function click(mx, my)
        frame(mx, my, true, false)
        frame(mx, my, false, true)
    end

    local gap = ui.theme.spacing
    local rowH = ui.theme.button.height
    local rowX, rowW = X + 10, W - 20
    local switchY = Y + ui.theme.panelHeader + gap + rowH / 2
    local half = (rowW - gap) / 2

    it('starts on toys and the switch flips shelves', function()
        assert.are.equal('toys', libraryTab.shelf())
        click(rowX + half + gap + half / 2, switchY)
        assert.are.equal('mine', libraryTab.shelf())
        click(rowX + half / 2, switchY)
        assert.are.equal('toys', libraryTab.shelf())
    end)

    it('pressing a toy builds it', function()
        local before = 0
        for _ in pairs(registry.bodies) do before = before + 1 end
        -- 'ball' is the first toy: left column, first row under the switch
        click(rowX + half / 2, switchY + rowH + gap * 2)
        local after = 0
        for _ in pairs(registry.bodies) do after = after + 1 end
        assert.are.equal(before + 1, after)
    end)
end)
