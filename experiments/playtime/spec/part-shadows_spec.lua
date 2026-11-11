-- spec/part-shadows_spec.lua
-- Parts shadowing each other (src/part-shadows.lua, LIGHT-AND-SHADOW LS20): a picture in front darkens the
-- one behind it where it lies toward the light, not on its other side, not itself; off, nothing.
-- Run with: love . --specs spec/part-shadows_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local partShadows = require('src.part-shadows')

local W, H = 400, 300

local function pictured(x, y, w, h, z, hex)
    local box = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h, bodyType = 'static' })
    local fixture = fixtures.createSFixture(box.body, 0, 0, subtypes.TEXFIXTURE, { width = w, height = h })
    local e = fixture:getUserData().extra
    e.OMP, e.dirty, e.zOffset = true, true, z
    e.main = { bgURL = 'mipo/body/body-03.png', fgURL = 'mipo/body/body-03-mask.png', pURL = 'type0.png',
        bgHex = hex, fgHex = hex, pHex = hex }
    return box
end

-- the world drawn as the game does: the textured world, then the parts' shadows over it
local function render(world)
    box2dDrawTextured.makeCombinedImages()
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(W / 2, H / 2)
    box2dDrawTextured.drawTexturedWorld(world)
    partShadows.draw(world)
    love.graphics.pop()
    love.graphics.setCanvas()
    return canvas:newImageData()
end

local function at(img, wx, wy)
    local r, g, b = img:getPixel(wx + W / 2, wy + H / 2)
    return (r + g + b) / 3
end

describe('part shadows', function()
    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        -- a big light picture behind, a small one in front over its middle; the light from the left
        pictured(0, 0, 240, 200, 0, 'ddddddff')
        pictured(-20, 0, 60, 60, 50, 'ddddddff')
        state.backdropShadows = { offset = { 30, 0 }, wall = function() end } -- away from a light on the left
        state.partShadows = { strength = 0.8, reach = 20 }
    end)

    after_each(function()
        state.partShadows, state.backdropShadows = nil, nil
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('darkens the picture behind just past the front one, away from the light', function()
        local lit = render(state.physicsWorld)
        if os.getenv('PART_SHADOWS_PNG') then lit:encode('png', 'part-shadows-spec.png') end -- to look at
        state.partShadows = nil
        local plain = render(state.physicsWorld)
        -- the front picture's right edge is near x 10 (its outline inside the 60 box); just past it
        local darker = 0
        for x = 10, 30 do
            if at(lit, x, 0) < at(plain, x, 0) - 0.05 then darker = darker + 1 end
        end
        assert.is_true(darker > 3, 'a shadow just right of the front picture: ' .. darker .. ' pixels')
        assert.is_true(math.abs(at(lit, -80, 0) - at(plain, -80, 0)) < 0.02, 'none on the light side')
        assert.is_true(math.abs(at(lit, -20, 0) - at(plain, -20, 0)) < 0.02, 'none on the front one itself')
    end)

    it('off, nothing', function()
        state.partShadows = nil
        local a = render(state.physicsWorld)
        local b = render(state.physicsWorld)
        assert.are.equal(at(a, 20, 0), at(b, 20, 0))
    end)
end)
