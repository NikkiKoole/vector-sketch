-- spec/mipo-dna-roundtrip_spec.lua
-- A Mipo's whole DNA through a scene save and load (JSON and back), and old saved DNA moved
-- over by migrateDNA (src/mipo-build.lua). character-persistence_spec covers the registry,
-- masses and the save format; this one guards every DNA field, before the breeds (MIPO-BREEDS
-- B2-B5) change what's in the DNA.
--
-- Run with: love . --specs spec/mipo-dna-roundtrip_spec.lua

if not love then return end

local CharacterManager = require('src.character-manager')
local mipoRegistry = require('src.mipo-registry')
local registry = require('src.registry')
local state = require('src.state')
local sceneIO = require('src.io')
local JT = require('src.joint-types')
local json = require('vendor.dkjson')

local function makeWorld()
    return love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
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

local function destroyWorld(w)
    if w and not w:isDestroyed() then
        for _, b in ipairs(w:getBodies()) do
            if not b:isDestroyed() then b:destroy() end
        end
        w:destroy()
    end
end

-- The first difference between two tables as a path, or nil when they're the same.
-- Numbers compare within a hair: JSON writes them as text.
local function firstDifference(a, b, path)
    path = path or 'dna'
    if type(a) ~= type(b) then
        return string.format('%s: %s vs %s', path, tostring(a), tostring(b))
    end
    if type(a) == 'number' then
        if math.abs(a - b) > 1e-9 * math.max(1, math.abs(a)) then
            return string.format('%s: %.12g vs %.12g', path, a, b)
        end
        return nil
    end
    if type(a) ~= 'table' then
        if a ~= b then return string.format('%s: %s vs %s', path, tostring(a), tostring(b)) end
        return nil
    end
    for k, v in pairs(a) do
        local d = firstDifference(v, b[k], path .. '.' .. tostring(k))
        if d then return d end
    end
    for k, v in pairs(b) do
        if a[k] == nil then return string.format('%s.%s: missing before, %s after', path, tostring(k), tostring(v)) end
    end
    return nil
end

describe("a Mipo's DNA through a scene save and load", function()
    local world, camera

    before_each(function()
        world = makeWorld()
        registry.reset()
        mipoRegistry.reset()
        state.backdrops = {}
        state.physicsWorld = world
        camera = makeCamera()
    end)

    after_each(function()
        destroyWorld(state.physicsWorld)
        if world ~= state.physicsWorld then destroyWorld(world) end
    end)

    -- save the scene to JSON text, change the decoded data (an old save), load it in a fresh world
    local function saveAndLoad(change)
        local decoded = json.decode(json.encode(sceneIO.gatherSaveData(world, camera), { indent = true }))
        if change then change(decoded.characters[1].dna) end
        registry.reset()
        mipoRegistry.reset()
        local newWorld = makeWorld()
        state.physicsWorld = newWorld
        sceneIO.buildWorld(decoded, newWorld, camera)
        local _, loaded = next(mipoRegistry.getAll())
        return loaded
    end

    for _, seed in ipairs({ 1, 2, 3, 4, 5, 6 }) do
        it("comes back the same, every field (seed " .. seed .. ")", function()
            math.randomseed(seed); love.math.setRandomSeed(seed)
            local mipo = CharacterManager.createCharacter('humanoid', 0, 0, 1)
            if seed % 2 == 0 then CharacterManager.randomizeMipo(mipo) else CharacterManager.randomizeMipoConstrained(mipo) end
            local loaded = saveAndLoad()
            assert.is_not_nil(loaded, 'no Mipo after load')
            local d = firstDifference(mipo.dna, loaded.dna)
            assert.is_nil(d, d)
        end)
    end

    describe("old saved DNA moved over (migrateDNA)", function()
        local mipo

        before_each(function()
            math.randomseed(7); love.math.setRandomSeed(7)
            mipo = CharacterManager.createCharacter('humanoid', 0, 0, 1)
            CharacterManager.randomizeMipoConstrained(mipo)
        end)

        local function torsoName(dna)
            for name in pairs(dna.parts) do
                if name:find('^torso%d') and dna.parts[name].appearance and dna.parts[name].appearance.skin then return name end
            end
        end

        local function facePart(dna)
            for name, part in pairs(dna.parts) do
                if part.appearance and part.appearance.face and part.appearance.face.mouth then return name end
            end
        end

        it("a nose saved at z 490 (above the arms) goes to 350", function()
            local loaded = saveAndLoad(function(dna)
                dna.parts['nose-single-template'].appearance.skin.zOffset = 490
            end)
            assert.are.equal(350, loaded.dna.parts['nose-single-template'].appearance.skin.zOffset)
        end)

        it("ears saved on a hinge get the soft weld", function()
            local loaded = saveAndLoad(function(dna)
                for _, ear in ipairs({ 'lear', 'rear' }) do
                    dna.parts[ear].j = { type = JT.REVOLUTE, limits = { low = -0.2, up = 0.2 } }
                end
            end)
            for _, ear in ipairs({ 'lear', 'rear' }) do
                assert.are.equal(JT.WELD, loaded.dna.parts[ear].j.type, ear)
                assert.is_not_nil(loaded.dna.parts[ear].j.frequency, ear .. ' has no spring')
            end
        end)

        it("a torso skin saved at z 200 goes under the head", function()
            local name = torsoName(mipo.dna)
            assert.is_not_nil(name, 'no torso part with a skin in the DNA')
            local loaded = saveAndLoad(function(dna) dna.parts[name].appearance.skin.zOffset = 200 end)
            assert.is_true(loaded.dna.parts[name].appearance.skin.zOffset < 200,
                'torso skin still at ' .. loaded.dna.parts[name].appearance.skin.zOffset)
        end)

        it("the dropped duck-beak upper lip (4) becomes lip 1", function()
            local name = facePart(mipo.dna)
            assert.is_not_nil(name, 'no part with a face in the DNA')
            local loaded = saveAndLoad(function(dna) dna.parts[name].appearance.face.mouth.upperLipShape = 4 end)
            assert.are.equal(1, loaded.dna.parts[name].appearance.face.mouth.upperLipShape)
        end)

        it("leaves today's DNA alone", function()
            local loaded = saveAndLoad()
            local d = firstDifference(mipo.dna, loaded.dna)
            assert.is_nil(d, d)
        end)
    end)
end)
