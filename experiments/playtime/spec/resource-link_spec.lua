-- spec/resource-link_spec.lua
-- MESHUSERT -> RESOURCE pairing (src/resource-link.lua): old scenes pair by
-- label and get linked by id on first use; a clone or placed prefab that has
-- both uses its own RESOURCE, not the original's, even though labels match;
-- a mesh copied without its RESOURCE keeps using the original's.
-- Run with: love . --specs spec/resource-link_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local sceneIO = require('src.io')
local library = require('src.library')
local resourceLink = require('src.resource-link')

local NAME = 'spec-resource-link'

describe('resource link', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
    end)

    after_each(function()
        library.delete(NAME)
        if world and not world:isDestroyed() then world:destroy() end
    end)

    -- a skin body with a MESHUSERT and a mapper body with its RESOURCE, both labelled 'skin'
    local function skinPair(x)
        local skin = objectManager.addThing('rectangle', { x = x, y = 0, width = 100, height = 100 })
        local mapper = objectManager.addThing('rectangle', { x = x + 200, y = 0, width = 100, height = 100 })
        local mesh = fixtures.createSFixture(skin.body, 0, 0, 'meshusert', { radius = 20 })
        local resource = fixtures.createSFixture(mapper.body, 0, 0, 'resource', { width = 20, height = 20 })
        mesh:getUserData().label = 'skin'
        resource:getUserData().label = 'skin'
        -- the sfixture may be recreated on its body; read back what's registered
        return skin, mapper, mesh, resource
    end

    local function meshOf(thing)
        for _, fixture in ipairs(thing.body:getFixtures()) do
            local ud = fixture:getUserData()
            if resourceLink.isUser(ud) then return ud end
        end
    end

    local function resourceBodyOf(thing)
        local found = resourceLink.find(meshOf(thing))
        return found and found:getBody()
    end

    it('finds by label once, then by the stored link', function()
        local skin, mapper = skinPair(0)
        local ud = meshOf(skin)
        assert.is_nil(ud.extra.resourceId)
        assert.are.equal(mapper.body, resourceBodyOf(skin))
        assert.is_not_nil(ud.extra.resourceId)
        ud.label = 'renamed' -- the link holds without the label
        assert.are.equal(mapper.body, resourceBodyOf(skin))
    end)

    it('a clone of both uses its own RESOURCE', function()
        local skin, mapper = skinPair(0)
        local cloned = library.clone({ skin, mapper })
        local cloneSkin, cloneMapper
        for _, thing in ipairs(cloned) do
            if meshOf(thing) then cloneSkin = thing else cloneMapper = thing end
        end
        assert.are.equal(cloneMapper.body, resourceBodyOf(cloneSkin))
        assert.are.equal(mapper.body, resourceBodyOf(skin))
    end)

    it('a clone of the mesh alone keeps the original RESOURCE', function()
        local skin, mapper = skinPair(0)
        local cloned = library.clone({ skin })
        assert.are.equal(mapper.body, resourceBodyOf(cloned[1]))
    end)

    it('a placed prefab of both uses its own RESOURCE', function()
        local skin, mapper = skinPair(0)
        assert.is_true((library.save(NAME, { skin, mapper })))
        local placed = library.place(NAME, 3000, 0)
        local placedSkin, placedMapper
        for _, thing in ipairs(placed) do
            if meshOf(thing) then placedSkin = thing else placedMapper = thing end
        end
        assert.are.equal(placedMapper.body, resourceBodyOf(placedSkin))
    end)

    it('an old prefab without the link prefers its own RESOURCE when placed', function()
        local skin, mapper = skinPair(0)
        assert.is_true((library.save(NAME, { skin, mapper })))
        -- strip the link, as in a prefab saved before resourceId existed
        local prefab = library.load(NAME)
        for _, bodyData in ipairs(prefab.bodies) do
            for _, fixtureData in ipairs(bodyData.fixtures or {}) do
                local extra = fixtureData.userData and fixtureData.userData.extra
                if extra then extra.resourceId = nil end
            end
        end
        love.filesystem.write(library.DIR .. '/' .. NAME .. '.playtime.json', require('vendor.dkjson').encode(prefab))
        local placed = library.place(NAME, 3000, 0)
        local placedSkin, placedMapper
        for _, thing in ipairs(placed) do
            if meshOf(thing) then placedSkin = thing else placedMapper = thing end
        end
        assert.are.equal(placedMapper.body, resourceBodyOf(placedSkin))
    end)

    it('an old skinned scene (Knut) links every mesh to its label partner and draws', function()
        local camera = require('src.camera')
        local box2dDrawTextured = require('src.physics.box2d-draw-textured')
        local contents = love.filesystem.read('scripts/tech/workmoreclean.playtime.json')
        sceneIO.load(contents, world, camera.getInstance())
        local meshes = 0
        for _, v in pairs(registry.sfixtures) do
            local ud = v:getUserData()
            if resourceLink.isUser(ud) and ud.label and #ud.label > 0 then
                local found = resourceLink.find(ud)
                assert.is_not_nil(found, 'no RESOURCE for ' .. ud.label)
                assert.are.equal(ud.label, found:getUserData().label)
                meshes = meshes + 1
            end
        end
        assert.is_true(meshes > 0)
        local canvas = love.graphics.newCanvas(400, 300)
        love.graphics.setCanvas(canvas)
        local ok, err = pcall(box2dDrawTextured.drawTexturedWorld, world)
        love.graphics.setCanvas()
        canvas:release()
        assert.is_true(ok, tostring(err))
    end)

    describe('the RESOURCE image', function()
        local savedBackdrops
        before_each(function() savedBackdrops = state.backdrops end)
        after_each(function() state.backdrops = savedBackdrops end)

        it('falls back to the saved backdrop URL, then the backdrop at the index', function()
            state.backdrops = { { url = 'a.png' }, { url = 'b.png' } }
            assert.are.equal('x.png', resourceLink.imageURL({ extra = { selectedBGURL = 'x.png', selectedBGIndex = 1 } }))
            assert.are.equal('b.png', resourceLink.imageURL({ extra = { selectedBGIndex = 2 } }))
            assert.are.equal('own.png', resourceLink.imageURL({ extra = { imageURL = 'own.png', selectedBGIndex = 1 } }))
        end)

        it('traces from the backdrop showing its image, never another picture', function()
            state.backdrops = { { url = 'a.png' }, { url = 'knut.png' } }
            local ud = { extra = { imageURL = 'knut.png', selectedBGIndex = 1 } }
            assert.are.equal(state.backdrops[2], resourceLink.backdrop(ud))
            assert.are.equal(2, ud.extra.selectedBGIndex)
            state.backdrops = { { url = 'a.png' } }
            assert.is_nil(resourceLink.backdrop(ud))
        end)

        it('a skinned Knut draws textured with no backdrops on stage', function()
            local camera = require('src.camera')
            local box2dDrawTextured = require('src.physics.box2d-draw-textured')
            sceneIO.load(love.filesystem.read('scripts/tech/workmoreclean.playtime.json'), world, camera.getInstance())
            for _, v in pairs(registry.sfixtures) do
                local ud = v:getUserData()
                if ud.subtype == 'resource' then
                    assert.are.equal('knut-is-dead/gevaarland.jpg', ud.extra.imageURL)
                end
            end
            state.backdrops = {}
            local newMesh, meshes = love.graphics.newMesh, {}
            love.graphics.newMesh = function(...)
                local mesh = newMesh(...)
                table.insert(meshes, mesh)
                return mesh
            end
            local canvas = love.graphics.newCanvas(400, 300)
            love.graphics.setCanvas(canvas)
            local ok, err = pcall(box2dDrawTextured.drawTexturedWorld, world)
            love.graphics.setCanvas()
            love.graphics.newMesh = newMesh
            canvas:release()
            assert.is_true(ok, tostring(err))
            local textured = 0
            for _, mesh in ipairs(meshes) do
                if mesh:getTexture() then textured = textured + 1 end
            end
            assert.is_true(textured > 0, 'no textured mesh drawn')
        end)
    end)
end)

-- BUG16: the RESOURCE panel triangulated every frame it was open. Now only when
-- the body, the backdrop, the outline or the split points changed.
describe('cdt.refreshResourceMesh', function()
    local cdt = require('src.cdt')
    local world, thing, ud, backdrop

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        thing = objectManager.addThing('custom', { x = 0, y = 0,
            vertices = { -50, -50, 50, -50, 50, 50, -50, 50 } })
        local resource = fixtures.createSFixture(thing.body, 0, 0, 'resource', { width = 20, height = 20 })
        ud = resource:getUserData()
        backdrop = { url = 'backdrops/spec.png', x = -100, y = -100, w = 200, h = 200 }
    end)

    after_each(function()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it('makes the mesh once, then again only after a change', function()
        assert.is_true(cdt.refreshResourceMesh(ud, thing.body, backdrop))
        assert.is_not_nil(ud.extra.uvs)
        assert.is_not_nil(ud.extra.triangles)
        assert.is_false(cdt.refreshResourceMesh(ud, thing.body, backdrop))

        thing.body:setPosition(10, 0) -- moved while tracing
        assert.is_true(cdt.refreshResourceMesh(ud, thing.body, backdrop))
        assert.is_false(cdt.refreshResourceMesh(ud, thing.body, backdrop))

        backdrop.w = 300 -- the backdrop was resized
        assert.is_true(cdt.refreshResourceMesh(ud, thing.body, backdrop))

        thing.extraSteiner = { 0, 0 } -- a split point
        assert.is_true(cdt.refreshResourceMesh(ud, thing.body, backdrop))

        ud.extra.uvs = nil -- a polygon edit drops the mesh
        assert.is_true(cdt.refreshResourceMesh(ud, thing.body, backdrop))
        assert.is_not_nil(ud.extra.uvs)
    end)
end)
