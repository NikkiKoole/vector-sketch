-- What's kept between frames about sfixtures, through editing (2026-10-31: masks, hasTexture,
-- registry.sfixturesOf). sfixtures don't collide, except a Mipo's feet (registry.GROUND_PARTS:
-- mipo-actions.isGrounded counts their pictures touching) after a build, a scene load, the
-- Mipo editor rebuilding a part and the body inspector rebuilding a body. hasTexture and
-- sfixturesOf follow sfixtures coming and going.
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local sceneLoader = require('src.scene-loader')
local CM = require('src.character-manager')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local subtypes = require('src.subtypes')
local box2dDraw = require('src.physics.box2d-draw')

-- does every sfixture on this body collide (true), none (false); nil without sfixtures or mixed
local function sfixturesCollide(body)
    local open, closed = 0, 0
    for _, fixture in ipairs(body:getFixtures()) do
        if type(fixture:getUserData()) == 'table' then
            local _, mask = fixture:getFilterData()
            if mask == 0 then closed = closed + 1 else open = open + 1 end
        end
    end
    if open > 0 and closed == 0 then return true end
    if closed > 0 and open == 0 then return false end
    return nil
end

local function contains(list, item)
    for _, x in ipairs(list) do if x == item then return true end end
    return false
end

describe('sfixtures through editing', function()
    local world

    before_each(function()
        love.math.setRandomSeed(1)
        math.randomseed(1)
        world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld = world
        registry.reset()
        mipoRegistry.reset()
    end)

    after_each(function()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function newMipo()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        CM.randomizeMipo(instance)
        return instance
    end

    it('a built Mipo: its feet collide, its torso and ears do not', function()
        local instance = newMipo()
        assert.is_true(sfixturesCollide(instance.parts.lfoot.body))
        assert.is_true(sfixturesCollide(instance.parts.rfoot.body))
        assert.is_false(sfixturesCollide(instance.parts.torso1.body))
        if instance.parts.lear then assert.is_false(sfixturesCollide(instance.parts.lear.body)) end
    end)

    it('the Mipo editor resizing a foot: the new foot still collides', function()
        local instance = newMipo()
        local data = instance.dna.parts.lfoot
        CM.updatePart('lfoot', { shape8URL = data.shape8URL, sx = 1.3, sy = data.dims.sy or 1 }, instance)
        CM.rebuildTextures(instance) -- as the editor does after a part (ui/mipo/widgets editPartAndMirror)
        assert.is_true(sfixturesCollide(instance.parts.lfoot.body))
        assert.is_false(sfixturesCollide(instance.parts.torso1.body))
    end)

    it('the polygon editor moving a foot\'s corner: the rebuilt body still collides', function()
        -- poly-edit rebuilds the body from its edited vertices (objectManager.recreateThingFromBody),
        -- which registers the sfixtures before the new body has its thing
        local instance = newMipo()
        local thing = instance.parts.lfoot
        local verts = {}
        for i, v in ipairs(thing.vertices) do verts[i] = v * 1.1 end
        local rebuilt = objectManager.recreateThingFromBody(thing.body, { optionalVertices = verts })
        assert.is_true(sfixturesCollide(rebuilt.body))
    end)

    it('a scene load: the feet collide again once the bodies know their parts', function()
        sceneLoader.loadScriptAndScene('spine-test')
        local feet = 0
        for _, instance in pairs(mipoRegistry.getAll()) do
            for _, name in ipairs({ 'lfoot', 'rfoot' }) do
                local part = instance.parts[name]
                if part and sfixturesCollide(part.body) ~= nil then
                    feet = feet + 1
                    assert.is_true(sfixturesCollide(part.body), name .. ' of ' .. instance.id)
                end
            end
        end
        assert.is_true(feet > 0, 'no Mipo feet in spine-test')
        state.physicsWorld:destroy()
    end)

    it('hasTexture follows a picture added and removed', function()
        local body = love.physics.newBody(world, 0, 0, 'dynamic')
        love.physics.newFixture(body, love.physics.newRectangleShape(100, 100))
        body:setUserData({ thing = { id = 'plain' } })
        assert.is_false(box2dDraw.hasTexture(body))
        local tex = fixtures.createSFixture(body, 0, 0, subtypes.TEXFIXTURE, { width = 100, height = 100 })
        assert.is_true(box2dDraw.hasTexture(body))
        fixtures.destroyFixture(tex)
        assert.is_false(box2dDraw.hasTexture(body))
    end)

    it('sfixturesOf follows an sfixture added and removed', function()
        local body = love.physics.newBody(world, 0, 0, 'static')
        love.physics.newFixture(body, love.physics.newRectangleShape(200, 100))
        body:setUserData({ thing = { id = 'tank' } })
        assert.are.equal(0, #registry.sfixturesOf(subtypes.LIQUID))
        local water = fixtures.createSFixture(body, 0, 0, subtypes.LIQUID, { radius = 40 })
        assert.is_true(contains(registry.sfixturesOf(subtypes.LIQUID), water))
        assert.is_false(contains(registry.sfixturesOf(subtypes.TEXFIXTURE), water))
        fixtures.destroyFixture(water)
        assert.are.equal(0, #registry.sfixturesOf(subtypes.LIQUID))
    end)
end)
