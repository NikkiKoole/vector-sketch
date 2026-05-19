-- spec/character-persistence_spec.lua
-- Tests for Mipo DNA save/load persistence across scene cycles.
-- Verifies that character instances survive gatherSaveData → loadScene round-trips,
-- that mipoRegistry is correctly rebuilt on load, and that the format is
-- forward/backward compatible as the DNA schema evolves.
--
-- Run with: love . --specs spec/character-persistence_spec.lua

if not love then return end

package.loaded['src.character-manager'] = nil
package.loaded['src.mipo-registry'] = nil
package.loaded['src.registry'] = nil
package.loaded['src.state'] = nil
package.loaded['src.io'] = nil

local CharacterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')
local registry = require('src.registry')
local state = require('src.state')
local sceneIO = require('src.io')
local utils = require('src.utils')

-- ─── Helpers ───

local function makeWorld()
    return love.physics.newWorld(0, 9.81 * 100, true)
end

local function makeCamera()
    local s = { x = 0, y = 0, scale = 1 }
    local cam = {}
    function cam:getTranslation() return s.x, s.y end
    function cam:getRotation() return 0 end
    function cam:getScale() return s.scale end
    function cam:setTranslation(x, y) s.x = x; s.y = y end
    function cam:setScale(v) s.scale = v end
    return cam
end

local function createHumanoid(world)
    state.physicsWorld = world
    return CharacterManager.createCharacter('humanoid', 0, 0, 1)
end

local function destroyInstance(instance)
    if not instance then return end
    for _, part in pairs(instance.parts) do
        if part.body and not part.body:isDestroyed() then
            part.body:destroy()
        end
    end
end

-- ─── serializeCharacters ───

describe("CharacterManager.serializeCharacters", function()
    local world, instance

    before_each(function()
        world = makeWorld()
        registry.reset()
        mipoRegistry.reset()
        instance = createHumanoid(world)
    end)

    after_each(function()
        destroyInstance(instance)
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it("returns an empty array when no characters are registered", function()
        mipoRegistry.reset()
        local result = CharacterManager.serializeCharacters()
        assert.is_table(result)
        assert.are.equal(0, #result)
    end)

    it("returns one entry after creating a character", function()
        local result = CharacterManager.serializeCharacters()
        assert.are.equal(1, #result)
    end)

    it("each entry has version, id, dna, scale, zGroupOffset", function()
        local result = CharacterManager.serializeCharacters()
        local entry = result[1]
        assert.are.equal(1, entry.version)
        assert.is_string(entry.id)
        assert.is_table(entry.dna)
        assert.is_number(entry.scale)
        assert.is_number(entry.zGroupOffset)
    end)

    it("id matches the instance id", function()
        local result = CharacterManager.serializeCharacters()
        assert.are.equal(instance.id, result[1].id)
    end)

    it("dna is a deep copy, not the same reference", function()
        local result = CharacterManager.serializeCharacters()
        assert.are_not.equal(instance.dna, result[1].dna)
        assert.are_not.equal(instance.dna.creation, result[1].dna.creation)
    end)

    it("dna contains creation, parts, and positioners", function()
        local result = CharacterManager.serializeCharacters()
        local dna = result[1].dna
        assert.is_table(dna.creation)
        assert.is_table(dna.parts)
        assert.is_table(dna.positioners)
    end)

    it("dna.metadata round-trips transparently if present", function()
        instance.dna.metadata = { kind = 'BLOB', code = 'TEST-XXXXX-YYYYY' }
        local result = CharacterManager.serializeCharacters()
        assert.is_table(result[1].dna.metadata)
        assert.are.equal('BLOB', result[1].dna.metadata.kind)
        assert.are.equal('TEST-XXXXX-YYYYY', result[1].dna.metadata.code)
    end)
end)

-- ─── mipoId/mipoPartName on bodies ───

describe("mipoId and mipoPartName on body things", function()
    local world, instance

    before_each(function()
        world = makeWorld()
        registry.reset()
        mipoRegistry.reset()
        instance = createHumanoid(world)
    end)

    after_each(function()
        destroyInstance(instance)
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it("torso1 body thing has mipoId set", function()
        local torso = instance.parts.torso1
        assert.is_truthy(torso)
        assert.are.equal(instance.id, torso.mipoId)
    end)

    it("torso1 body thing has mipoPartName set to 'torso1'", function()
        local torso = instance.parts.torso1
        assert.are.equal('torso1', torso.mipoPartName)
    end)

    it("all parts have mipoId matching instance id", function()
        for partName, part in pairs(instance.parts) do
            assert.are.equal(instance.id, part.mipoId,
                partName .. " should have mipoId = instance.id")
        end
    end)

    it("all parts have mipoPartName matching their key", function()
        for partName, part in pairs(instance.parts) do
            assert.are.equal(partName, part.mipoPartName,
                partName .. " should have mipoPartName = '" .. partName .. "'")
        end
    end)
end)

-- ─── gatherSaveData includes characters ───

describe("gatherSaveData characters serialization", function()
    local world, instance, camera

    before_each(function()
        world = makeWorld()
        registry.reset()
        mipoRegistry.reset()
        state.backdrops = {}
        instance = createHumanoid(world)
        camera = makeCamera()
    end)

    after_each(function()
        destroyInstance(instance)
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it("saveData has a characters array", function()
        local saveData = sceneIO.gatherSaveData(world, camera)
        assert.is_table(saveData.characters)
    end)

    it("characters array has one entry for one mipo", function()
        local saveData = sceneIO.gatherSaveData(world, camera)
        assert.are.equal(1, #saveData.characters)
    end)

    it("body things have mipoId and mipoPartName serialized", function()
        local saveData = sceneIO.gatherSaveData(world, camera)
        local torsoData
        for _, bd in ipairs(saveData.bodies) do
            if bd.label == 'torso1' then torsoData = bd; break end
        end
        assert.is_truthy(torsoData, "should find torso1 in saved bodies")
        assert.is_string(torsoData.mipoId)
        assert.are.equal('torso1', torsoData.mipoPartName)
    end)

    it("non-mipo bodies do not have mipoId", function()
        -- Create a plain body (not part of a character)
        local plainBody = love.physics.newBody(world, 0, 0, 'dynamic')
        local shape = love.physics.newRectangleShape(50, 50)
        local fixture = love.physics.newFixture(plainBody, shape)
        local uuid = require('src.uuid')
        plainBody:setUserData({ thing = { id = uuid.generateID(), label = 'box', shapeType = 'rectangle', width = 50, height = 50 } })

        local saveData = sceneIO.gatherSaveData(world, camera)
        local boxData
        for _, bd in ipairs(saveData.bodies) do
            if bd.label == 'box' then boxData = bd; break end
        end
        assert.is_truthy(boxData)
        assert.is_nil(boxData.mipoId)

        plainBody:destroy()
    end)
end)

-- ─── reconstructInstance ───

describe("CharacterManager.reconstructInstance", function()
    local world, instance

    before_each(function()
        world = makeWorld()
        registry.reset()
        mipoRegistry.reset()
        instance = createHumanoid(world)
    end)

    after_each(function()
        destroyInstance(instance)
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it("returns nil when partBodies is nil", function()
        local charData = { version = 1, id = 'test', dna = utils.deepCopy(instance.dna), scale = 1, zGroupOffset = 1 }
        local result = CharacterManager.reconstructInstance(charData, nil)
        assert.is_nil(result)
    end)

    it("returns an instance table", function()
        local partBodies = {}
        for partName, part in pairs(instance.parts) do
            partBodies[partName] = part.body
        end
        local charData = { version = 1, id = instance.id, dna = utils.deepCopy(instance.dna), scale = instance.scale, zGroupOffset = instance.zGroupOffset }
        mipoRegistry.reset()
        local result = CharacterManager.reconstructInstance(charData, partBodies)
        assert.is_table(result)
    end)

    it("reconstructed instance has correct id", function()
        local partBodies = {}
        for partName, part in pairs(instance.parts) do
            partBodies[partName] = part.body
        end
        local charData = { version = 1, id = instance.id, dna = utils.deepCopy(instance.dna), scale = instance.scale, zGroupOffset = instance.zGroupOffset }
        mipoRegistry.reset()
        local result = CharacterManager.reconstructInstance(charData, partBodies)
        assert.are.equal(instance.id, result.id)
    end)

    it("reconstructed instance parts map body things correctly", function()
        local partBodies = {}
        for partName, part in pairs(instance.parts) do
            partBodies[partName] = part.body
        end
        local charData = { version = 1, id = instance.id, dna = utils.deepCopy(instance.dna), scale = instance.scale, zGroupOffset = instance.zGroupOffset }
        mipoRegistry.reset()
        local result = CharacterManager.reconstructInstance(charData, partBodies)
        assert.is_truthy(result.parts.torso1)
        assert.are.equal(instance.parts.torso1.body, result.parts.torso1.body)
    end)

    it("reconstructed instance is retrievable via mipoRegistry", function()
        local partBodies = {}
        for partName, part in pairs(instance.parts) do
            partBodies[partName] = part.body
        end
        local charData = { version = 1, id = instance.id, dna = utils.deepCopy(instance.dna), scale = instance.scale, zGroupOffset = instance.zGroupOffset }
        mipoRegistry.reset()
        CharacterManager.reconstructInstance(charData, partBodies)
        local retrieved, partName = mipoRegistry.getFromBody(instance.parts.torso1.body)
        assert.is_truthy(retrieved)
        assert.are.equal('torso1', partName)
    end)

    it("reconstructed instance has childrenMap, topology, and entryMap", function()
        local partBodies = {}
        for partName, part in pairs(instance.parts) do
            partBodies[partName] = part.body
        end
        local charData = { version = 1, id = instance.id, dna = utils.deepCopy(instance.dna), scale = instance.scale, zGroupOffset = instance.zGroupOffset }
        mipoRegistry.reset()
        local result = CharacterManager.reconstructInstance(charData, partBodies)
        assert.is_table(result.childrenMap, "should have childrenMap for updatePart/mutateSizes")
        assert.is_table(result.topology, "should have topology")
        assert.is_table(result.entryMap, "should have entryMap")
    end)

    it("fills missing DNA fields with defaults (forward compat)", function()
        local partBodies = {}
        for partName, part in pairs(instance.parts) do
            partBodies[partName] = part.body
        end
        -- Simulate a future DNA field being missing
        local strippedDna = utils.deepCopy(instance.dna)
        strippedDna.creation.noseMode = nil
        local charData = { version = 1, id = instance.id, dna = strippedDna, scale = instance.scale, zGroupOffset = instance.zGroupOffset }
        mipoRegistry.reset()
        local result = CharacterManager.reconstructInstance(charData, partBodies)
        assert.are.equal('overlay', result.dna.creation.noseMode)
    end)

    it("unknown DNA fields (from future versions) are preserved", function()
        local partBodies = {}
        for partName, part in pairs(instance.parts) do
            partBodies[partName] = part.body
        end
        local futureDna = utils.deepCopy(instance.dna)
        futureDna.metadata = { kind = 'BLOB', futureField = 42 }
        local charData = { version = 1, id = instance.id, dna = futureDna, scale = instance.scale, zGroupOffset = instance.zGroupOffset }
        mipoRegistry.reset()
        local result = CharacterManager.reconstructInstance(charData, partBodies)
        assert.is_truthy(result.dna.metadata)
        assert.are.equal('BLOB', result.dna.metadata.kind)
        assert.are.equal(42, result.dna.metadata.futureField)
    end)
end)

-- ─── Full round-trip: gatherSaveData → buildWorld ───

describe("character persistence round-trip", function()
    local world, instance, camera
    local json = require('vendor.dkjson')

    local function saveAndDecode()
        local saveData = sceneIO.gatherSaveData(world, camera)
        local jsonStr = json.encode(saveData, { indent = true })
        return json.decode(jsonStr)
    end

    local function buildFreshWorld(decodedData)
        registry.reset()
        mipoRegistry.reset()
        local newWorld = makeWorld()
        state.physicsWorld = newWorld
        sceneIO.buildWorld(decodedData, newWorld, camera)
        return newWorld
    end

    local function destroyWorld(w)
        if w and not w:isDestroyed() then
            for _, b in ipairs(w:getBodies()) do
                if not b:isDestroyed() then b:destroy() end
            end
            w:destroy()
        end
    end

    before_each(function()
        world = makeWorld()
        registry.reset()
        mipoRegistry.reset()
        state.backdrops = {}
        state.physicsWorld = world
        instance = createHumanoid(world)
        camera = makeCamera()
    end)

    after_each(function()
        destroyWorld(world)
    end)

    it("gatherSaveData encodes to JSON without error", function()
        local saveData = sceneIO.gatherSaveData(world, camera)
        local ok, err = pcall(json.encode, saveData, { indent = true })
        assert.is_true(ok, "json.encode should not fail: " .. tostring(err))
    end)

    it("mipoRegistry survives a save/load cycle", function()
        local decoded = saveAndDecode()
        local newWorld = buildFreshWorld(decoded)

        local all = mipoRegistry.getAll()
        local count = 0
        for _ in pairs(all) do count = count + 1 end
        assert.are.equal(1, count, "should have one reconstructed character instance")

        destroyWorld(newWorld)
    end)

    it("reconstructed instance has same DNA as original after round-trip", function()
        local decoded = saveAndDecode()
        local newWorld = buildFreshWorld(decoded)

        local all = mipoRegistry.getAll()
        local loaded
        for _, inst in pairs(all) do loaded = inst; break end

        assert.is_truthy(loaded)
        assert.is_table(loaded.dna)
        assert.is_table(loaded.dna.creation)
        assert.are.equal(instance.dna.creation.isPotatoHead, loaded.dna.creation.isPotatoHead)
        assert.are.equal(instance.dna.creation.torsoSegments, loaded.dna.creation.torsoSegments)

        destroyWorld(newWorld)
    end)

    it("getFromBody works on loaded bodies after round-trip", function()
        local decoded = saveAndDecode()
        local newWorld = buildFreshWorld(decoded)

        local found = false
        for _, b in ipairs(newWorld:getBodies()) do
            local inst, partName = mipoRegistry.getFromBody(b)
            if inst then
                found = true
                assert.is_string(partName)
                assert.is_table(inst.dna)
                break
            end
        end
        assert.is_true(found, "should find at least one body linkable to an instance")

        destroyWorld(newWorld)
    end)

    it("loading a second scene clears instances from the first", function()
        local decoded1 = saveAndDecode()
        local newWorld = buildFreshWorld(decoded1)

        -- Verify first scene has an instance
        local count1 = 0
        for _ in pairs(mipoRegistry.getAll()) do count1 = count1 + 1 end
        assert.are.equal(1, count1)

        -- Load an empty second scene (no characters) into the same world
        local emptyData = { version = "1.0", bodies = {}, joints = {}, camera = {}, backdrops = {} }
        sceneIO.buildWorld(emptyData, newWorld, camera)

        -- Registry should be empty — old destroyed bodies gone
        local count2 = 0
        for _ in pairs(mipoRegistry.getAll()) do count2 = count2 + 1 end
        assert.are.equal(0, count2, "mipo registry should be cleared after loading new scene")

        destroyWorld(newWorld)
    end)

    it("scene with no characters key (old save format) loads without crash", function()
        local saveData = sceneIO.gatherSaveData(world, camera)
        saveData.characters = nil  -- strip it, simulating old format
        local jsonStr = json.encode(saveData, { indent = true })
        local decoded = json.decode(jsonStr)

        local ok, err = pcall(function()
            local newWorld = buildFreshWorld(decoded)
            destroyWorld(newWorld)
        end)
        assert.is_true(ok, "load should not crash on old saves: " .. tostring(err))
    end)

    it("zGroupOffset is preserved across round-trip", function()
        local originalZGroup = instance.zGroupOffset
        assert.is_truthy(originalZGroup)

        local decoded = saveAndDecode()
        local newWorld = buildFreshWorld(decoded)

        local all = mipoRegistry.getAll()
        local loaded
        for _, inst in pairs(all) do loaded = inst; break end

        assert.are.equal(originalZGroup, loaded.zGroupOffset)

        destroyWorld(newWorld)
    end)
end)
