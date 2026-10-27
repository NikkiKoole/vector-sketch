-- spec/right-column_spec.lua
-- The right column: clicking a tab switches it, the properties tab hands its
-- rect (below the tab bar, inside the window) to the selection's panel, the
-- empty properties tab offers pause while a scene script plays, and the other
-- tabs don't draw properties.
-- Run with: love . --specs spec/right-column_spec.lua

if not love then return end

local state = require('src.state')
local ui = require('src.ui.all')
local rightColumn = require('src.ui.right-column')

describe('right column', function()
    local canvas

    setup(function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        canvas = love.graphics.newCanvas(1200, 768)
    end)

    teardown(function()
        canvas:release()
        state.rightColumn.tab = 'properties'
    end)

    local function frame(mx, my, pressed, released, drawProperties)
        ui.startFrame()
        ui.mouseX, ui.mouseY = mx, my
        ui.mousePressed, ui.mouseReleased = pressed, released
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(rightColumn.draw, drawProperties or function() return false end)
        love.graphics.setCanvas()
        assert.is_true(ok, tostring(err))
    end

    local function clickTab(name)
        local x, y, w = rightColumn.rect()
        local tabW = w / #rightColumn.TABS
        for i, tab in ipairs(rightColumn.TABS) do
            if tab == name then
                local mx, my = x + (i - 0.5) * tabW, y + 5
                frame(mx, my, true, false)
                frame(mx, my, false, true)
            end
        end
    end

    it('clicking a tab switches to it', function()
        state.rightColumn.tab = 'properties'
        clickTab('library')
        assert.are.equal('library', state.rightColumn.tab)
        clickTab('on stage')
        assert.are.equal('on stage', state.rightColumn.tab)
        clickTab('properties')
        assert.are.equal('properties', state.rightColumn.tab)
    end)

    it('properties get a rect below the tab bar, inside the window', function()
        state.rightColumn.tab = 'properties'
        local got
        frame(0, 0, false, false, function(x, y, w, h)
            got = { x, y, w, h }
            return true
        end)
        local cx, cy = rightColumn.rect()
        local ww, wh = love.graphics.getDimensions()
        assert.are.equal(cx, got[1])
        assert.is_true(got[2] > cy + ui.theme.button.height)
        assert.is_true(got[1] + got[3] <= ww and got[2] + got[4] <= wh - 20)
    end)

    it('while a scene script plays, the empty properties tab pauses', function()
        state.rightColumn.tab = 'properties'
        local oldScript, oldPaused = state.scene.sceneScript, state.world.paused
        state.scene.sceneScript, state.world.paused = {}, false
        local x, y, w = rightColumn.contentRect()
        local mx, my = x + w / 2, y + 80 -- the pause button
        frame(mx, my, true, false)
        frame(mx, my, false, true)
        local paused = state.world.paused
        state.scene.sceneScript, state.world.paused = oldScript, oldPaused
        assert.is_true(paused)
    end)

    it('other tabs leave the properties alone', function()
        state.rightColumn.tab = 'library'
        local called = false
        frame(0, 0, false, false, function() called = true return true end)
        assert.is_false(called)
    end)
end)
