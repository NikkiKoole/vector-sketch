-- src/save-migrations.lua: the save versions and the ordered steps (docs/LANDING-2026-11.md L3). An
-- older file runs every step from its version up, a file saved today none, a newer one is refused.
-- The scene part is pure (recording steps); the DNA part runs under LÖVE (love . --specs).
local migrations = require('src.save-migrations')

describe('save versions', function()
    it('reads "1.0" and no version as 1, a number as itself, nonsense as nil', function()
        assert.equal(1, migrations.sceneVersion({ version = '1.0' }))
        assert.equal(1, migrations.sceneVersion({}))
        assert.equal(2, migrations.sceneVersion({ version = 2 }))
        assert.is_nil(migrations.sceneVersion({ version = 'banana' }))
        assert.is_nil(migrations.sceneVersion({ version = 1.5 }))
        assert.equal(1, migrations.dnaVersion(nil))
        assert.equal(3, migrations.dnaVersion(3))
    end)
end)

describe('upgradeScene', function()
    local savedSteps, savedVersion, ran

    before_each(function()
        savedSteps, savedVersion, ran = migrations.SCENE_STEPS, migrations.SCENE_VERSION, {}
        migrations.SCENE_VERSION = 4
        migrations.SCENE_STEPS = {
            [1] = { scene = function() ran[#ran + 1] = 1 end, meshusert = function() end },
            [2] = { scene = function() ran[#ran + 1] = 2 end },
            [3] = { scene = function() ran[#ran + 1] = 3 end, meshusert = function() end },
        }
    end)

    after_each(function()
        migrations.SCENE_STEPS, migrations.SCENE_VERSION = savedSteps, savedVersion
    end)

    it('runs every step from the file\'s version up, in order, and marks it today\'s', function()
        local data = { version = '1.0' }
        assert.is_true(migrations.upgradeScene(data))
        assert.same({ 1, 2, 3 }, ran)
        assert.equal(4, data.version)
        assert.equal(1, data.migratedFrom)
        assert.equal(2, #migrations.sceneSteps(data)) -- the MESHUSERT steps of 1 and 3
    end)

    it('starts at the file\'s own version', function()
        local data = { version = 3 }
        assert.is_true(migrations.upgradeScene(data))
        assert.same({ 3 }, ran)
    end)

    it('runs nothing for a file saved today', function()
        local data = { version = 4 }
        assert.is_true(migrations.upgradeScene(data))
        assert.same({}, ran)
        assert.same({}, migrations.sceneSteps(data))
    end)

    it('refuses a file from a newer Playtime, untouched', function()
        local data = { version = 5 }
        local ok, why = migrations.upgradeScene(data)
        assert.is_false(ok)
        assert.truthy(why:find('newer'))
        assert.equal(5, data.version)
        assert.same({}, ran)
    end)

    it('goes by the data\'s own version when not upgraded (built directly)', function()
        assert.equal(2, #migrations.sceneSteps({ version = '1.0' }))
        assert.equal(0, #migrations.sceneSteps({ version = 4 }))
    end)
end)

-- the DNA steps read src/mipo-dna.lua, which needs LÖVE
if not love then return end

describe('upgradeDNA', function()
    it('moves DNA saved before versions over, once', function()
        local dna = { parts = {
            nose1 = { appearance = { skin = { zOffset = 490 } } },
            torso1 = { appearance = { skin = { zOffset = 200 } } },
            head = { appearance = { face = { mouth = { upperLipShape = 4 } } } },
        } }
        local parts, now = migrations.upgradeDNA(dna, nil)
        assert.equal(migrations.DNA_VERSION, now)
        assert.equal(1, #parts) -- the saved bodies' fixtures still to move over
        assert.equal(350, dna.parts.nose1.appearance.skin.zOffset)
        assert.equal(require('src.mipo-dna').TORSO_SKIN_Z, dna.parts.torso1.appearance.skin.zOffset)
        assert.equal(1, dna.parts.head.appearance.face.mouth.upperLipShape)
        local again = migrations.upgradeDNA(dna, now)
        assert.same({}, again)
    end)

    it('builds a Mipo from a newer Playtime as it is', function()
        local dna = { parts = { nose1 = { appearance = { skin = { zOffset = 490 } } } } }
        local parts, now = migrations.upgradeDNA(dna, migrations.DNA_VERSION + 1)
        assert.same({}, parts)
        assert.equal(migrations.DNA_VERSION + 1, now)
        assert.equal(490, dna.parts.nose1.appearance.skin.zOffset)
    end)
end)
