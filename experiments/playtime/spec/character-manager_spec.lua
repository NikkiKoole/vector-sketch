-- spec/character-manager_spec.lua
-- Tests for character DNA structure, face updates, z-ordering, and randomization.
-- Run with: love . --specs spec/character-manager_spec.lua

if not love then return end

-- Fresh-require modules
package.loaded['src.character-manager'] = nil
package.loaded['src.registry'] = nil
package.loaded['src.state'] = nil
package.loaded['src.utils'] = nil
package.loaded['src.subtypes'] = nil
package.loaded['src.fixtures'] = nil
package.loaded['src.mipo-registry'] = nil
package.loaded['src.ui.mipo-editor'] = nil

local CharacterManager = require('src.character-manager')
local registry = require('src.registry')
local state = require('src.state')
local utils = require('src.utils')
local subtypes = require('src.subtypes')
local mipoRegistry = require('src.mipo-registry')

-- ─── Helpers ───

local function makeWorld()
    return love.physics.newWorld(0, 9.81 * 100, true)
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

local function getFixtureExtras(body)
    local result = {}
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.extra then
            table.insert(result, ud)
        end
    end
    return result
end

local function findFixtureByLabel(body, label)
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.label == label then
            return ud
        end
    end
    return nil
end

local function findFixturesBySubtype(body, subtype)
    local result = {}
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and subtypes.is(ud, subtype) then
            table.insert(result, ud)
        end
    end
    return result
end

-- ─── Tests ───

describe("character-manager", function()
    local world, instance

    before_each(function()
        world = makeWorld()
        registry.reset()
        instance = createHumanoid(world)
    end)

    after_each(function()
        destroyInstance(instance)
        if world and not world:isDestroyed() then
            world:destroy()
        end
    end)

    -- ─── DNA Template Defaults ───

    describe("DNA template defaults", function()
        it("should create an instance with parts", function()
            assert.is_truthy(instance)
            assert.is_truthy(instance.parts.torso1)
            assert.is_truthy(instance.parts.lear)
            assert.is_truthy(instance.parts.rear)
        end)

        it("torso-segment-template skin should have zOffset 200", function()
            local skin = instance.dna.parts.torso1.appearance.skin
            assert.is_truthy(skin)
            assert.are.equal(200, skin.zOffset)
        end)

        it("head skin should have zOffset 200", function()
            local headDNA = instance.dna.parts.head
            if headDNA and headDNA.appearance and headDNA.appearance.skin then
                assert.are.equal(200, headDNA.appearance.skin.zOffset)
            end
        end)

        it("ear skins should default to zOffset 190", function()
            local learSkin = instance.dna.parts.lear.appearance.skin
            local rearSkin = instance.dna.parts.rear.appearance.skin
            assert.are.equal(190, learSkin.zOffset)
            assert.are.equal(190, rearSkin.zOffset)
        end)

        it("face template should have all required sub-tables", function()
            local face = instance.dna.parts.torso1.appearance.face
            assert.is_truthy(face)
            assert.is_truthy(face.eye)
            assert.is_truthy(face.pupil)
            assert.is_truthy(face.brow)
            assert.is_truthy(face.mouth)
            assert.is_truthy(face.positioners)
            assert.is_truthy(face.positioners.eye)
            assert.is_truthy(face.positioners.brow)
            assert.is_truthy(face.positioners.nose)
            assert.is_truthy(face.positioners.mouth)
        end)

        it("should assign zGroupOffset to all fixture extras", function()
            assert.is_truthy(instance.zGroupOffset)
            for partName, part in pairs(instance.parts) do
                for _, f in ipairs(part.body:getFixtures()) do
                    local ud = f:getUserData()
                    if ud and ud.extra then
                        assert.are.equal(instance.zGroupOffset, ud.extra.zGroupOffset,
                            partName .. " fixture missing zGroupOffset")
                    end
                end
            end
        end)
    end)

    -- ─── updateFaceOfPart ───

    describe("updateFaceOfPart", function()
        local faceOwner

        before_each(function()
            -- Find which part owns the face (torso1 for potato, head otherwise)
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face then
                    faceOwner = partName
                    break
                end
            end
            assert.is_truthy(faceOwner, "should find a face owner part")
        end)

        it("should update eye shape", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeShape = 5 })
            assert.are.equal(5, instance.dna.parts[faceOwner].appearance.face.eye.shape)
        end)

        it("should update eye colors", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, {
                eyeBgHex = 'ff0000ff',
                eyeFgHex = '00ff00ff',
            })
            local eye = instance.dna.parts[faceOwner].appearance.face.eye
            assert.are.equal('ff0000ff', eye.bgHex)
            assert.are.equal('00ff00ff', eye.fgHex)
        end)

        it("should update eye multipliers", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeWMul = 2.5, eyeHMul = 0.5 })
            local eye = instance.dna.parts[faceOwner].appearance.face.eye
            assert.are.equal(2.5, eye.wMul)
            assert.are.equal(0.5, eye.hMul)
        end)

        it("should update pupil shape and colors", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, {
                pupilShape = 3,
                pupilBgHex = 'aabbccff',
            })
            local pupil = instance.dna.parts[faceOwner].appearance.face.pupil
            assert.are.equal(3, pupil.shape)
            assert.are.equal('aabbccff', pupil.bgHex)
        end)

        it("should update lookAtMouse flag", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeLookAtMouse = true })
            assert.is_true(instance.dna.parts[faceOwner].appearance.face.eye.lookAtMouse)

            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeLookAtMouse = false })
            assert.is_false(instance.dna.parts[faceOwner].appearance.face.eye.lookAtMouse)
        end)

        it("should update brow properties", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, {
                browShape = 4,
                browBgHex = '112233ff',
                browBend = 7,
                browWMul = 1.5,
                browHMul = 0.8,
            })
            local brow = instance.dna.parts[faceOwner].appearance.face.brow
            assert.are.equal(4, brow.shape)
            assert.are.equal('112233ff', brow.bgHex)
            assert.are.equal(7, brow.bend)
            assert.are.equal(1.5, brow.wMul)
            assert.are.equal(0.8, brow.hMul)
        end)

        it("should update nose properties", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, {
                noseShape = 10,
                noseBgHex = 'aaaaaa ff',
                noseY = 0.6,
            })
            local nose = instance.dna.parts[faceOwner].appearance.face.nose
            assert.are.equal(10, nose.shape)
            assert.are.equal(0.6, instance.dna.parts[faceOwner].appearance.face.positioners.nose.y)
        end)

        it("should update mouth properties", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, {
                mouthShape = 5,
                mouthLipHex = 'ff00ffff',
                mouthLipScale = 0.3,
                mouthWMul = 1.2,
                mouthHMul = 0.8,
                mouthY = 0.85,
            })
            local mouth = instance.dna.parts[faceOwner].appearance.face.mouth
            assert.are.equal(5, mouth.shape)
            assert.are.equal('ff00ffff', mouth.lipHex)
            assert.are.equal(0.3, mouth.lipScale)
            assert.are.equal(1.2, mouth.wMul)
            assert.are.equal(0.8, mouth.hMul)
            assert.are.equal(0.85, instance.dna.parts[faceOwner].appearance.face.positioners.mouth.y)
        end)

        it("should update teeth properties", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, {
                teethShape = 3,
                teethHMul = 2.0,
                teethStickOut = true,
                teethBgHex = 'ffffffaa',
            })
            local teeth = instance.dna.parts[faceOwner].appearance.face.teeth
            assert.are.equal(3, teeth.shape)
            assert.are.equal(2.0, teeth.hMul)
            assert.is_true(teeth.stickOut)
            assert.are.equal('ffffffaa', teeth.bgHex)
        end)

        it("should update eye positioners", function()
            CharacterManager.updateFaceOfPart(instance, faceOwner, {
                eyeX = 0.35,
                eyeY = 0.6,
                eyeR = 1.5,
            })
            local eyePos = instance.dna.parts[faceOwner].appearance.face.positioners.eye
            assert.are.equal(0.35, eyePos.x)
            assert.are.equal(0.6, eyePos.y)
            assert.are.equal(1.5, eyePos.r)
        end)

        it("should do nothing for a part without face appearance", function()
            -- lear has no face appearance — should not error
            CharacterManager.updateFaceOfPart(instance, 'lear', { eyeShape = 5 })
            -- No assertion needed — just checking it doesn't crash
        end)

        it("should initialize missing sub-tables with defaults", function()
            -- Strip all face sub-tables to test auto-initialization
            local face = instance.dna.parts[faceOwner].appearance.face
            face.eye = nil
            face.pupil = nil
            face.brow = nil
            face.nose = nil
            face.teeth = nil
            face.mouth = nil
            face.positioners = nil

            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeShape = 2 })

            face = instance.dna.parts[faceOwner].appearance.face
            assert.is_truthy(face.eye)
            assert.are.equal(2, face.eye.shape)
            assert.is_truthy(face.pupil)
            assert.is_truthy(face.brow)
            assert.is_truthy(face.nose)
            assert.is_truthy(face.teeth)
            assert.is_truthy(face.mouth)
            assert.is_truthy(face.positioners)
            assert.is_truthy(face.positioners.eye)
            assert.is_truthy(face.positioners.brow)
            assert.is_truthy(face.positioners.nose)
            assert.is_truthy(face.positioners.mouth)
        end)
    end)

    -- ─── Z-ordering and addTexturesFromInstance2 ───

    describe("z-ordering", function()
        it("ears-over-head toggle should change ear zOffset in DNA", function()
            local learSkin = instance.dna.parts.lear.appearance.skin
            local rearSkin = instance.dna.parts.rear.appearance.skin

            -- Toggle to over
            learSkin.zOffset = 210
            rearSkin.zOffset = 210

            assert.are.equal(210, learSkin.zOffset)
            assert.are.equal(210, rearSkin.zOffset)

            -- Toggle back to under
            learSkin.zOffset = 190
            rearSkin.zOffset = 190

            assert.are.equal(190, learSkin.zOffset)
            assert.are.equal(190, rearSkin.zOffset)
        end)

        it("addTexturesFromInstance2 should preserve zGroupOffset on recreated fixtures", function()
            local originalZGroup = instance.zGroupOffset
            assert.is_truthy(originalZGroup)

            -- Recreate textures (this destroys and recreates sfixtures)
            CharacterManager.addTexturesFromInstance2(instance)

            -- All fixtures should still have the correct zGroupOffset
            for partName, part in pairs(instance.parts) do
                for _, f in ipairs(part.body:getFixtures()) do
                    local ud = f:getUserData()
                    if ud and ud.extra then
                        assert.are.equal(originalZGroup, ud.extra.zGroupOffset,
                            partName .. " lost zGroupOffset after addTexturesFromInstance2")
                    end
                end
            end
        end)

        it("ear texfixture zOffset should match DNA after addTexturesFromInstance2", function()
            -- Change ear zOffset in DNA
            instance.dna.parts.lear.appearance.skin.zOffset = 210

            -- Recreate textures
            CharacterManager.addTexturesFromInstance2(instance)

            -- Find the texfixture on lear body
            local learBody = instance.parts.lear.body
            local texfixtures = findFixturesBySubtype(learBody, subtypes.TEXFIXTURE)
            assert.is_true(#texfixtures > 0, "lear should have at least one texfixture")

            local found210 = false
            for _, ud in ipairs(texfixtures) do
                if ud.extra.zOffset == 210 then found210 = true end
            end
            assert.is_true(found210, "lear texfixture should have zOffset 210 after toggle")
        end)

        it("torso skin zOffset should be 200 (above ears at 190, below ears at 210)", function()
            local torsoBody = instance.parts.torso1.body
            local texfixtures = findFixturesBySubtype(torsoBody, subtypes.TEXFIXTURE)

            local found200 = false
            for _, ud in ipairs(texfixtures) do
                if ud.extra.zOffset == 200 then found200 = true end
            end
            assert.is_true(found200, "torso1 should have a texfixture with zOffset 200")
        end)
    end)

    -- ─── Pupil extras ───

    describe("pupil sfixture extras", function()
        it("pupil decals should have eyeW, eyeH, and lookAtMouse", function()
            local faceOwner
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face and instance.parts[partName] then
                    faceOwner = partName
                    break
                end
            end
            assert.is_truthy(faceOwner)

            local body = instance.parts[faceOwner].body
            local lpupil = findFixtureByLabel(body, 'lpupil')
            local rpupil = findFixtureByLabel(body, 'rpupil')

            assert.is_truthy(lpupil, "should have lpupil decal")
            assert.is_truthy(rpupil, "should have rpupil decal")

            -- Check extras
            assert.is_truthy(lpupil.extra.eyeW, "lpupil should have eyeW")
            assert.is_truthy(lpupil.extra.eyeH, "lpupil should have eyeH")
            assert.is_number(lpupil.extra.eyeW)
            assert.is_number(lpupil.extra.eyeH)
            assert.is_truthy(rpupil.extra.eyeW, "rpupil should have eyeW")
            assert.is_truthy(rpupil.extra.eyeH, "rpupil should have eyeH")

            -- lookAtMouse defaults to false
            assert.are.equal(false, lpupil.extra.lookAtMouse)
            assert.are.equal(false, rpupil.extra.lookAtMouse)
        end)

        it("enabling lookAtMouse should propagate to pupil extras after rebuild", function()
            local faceOwner
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face and instance.parts[partName] then
                    faceOwner = partName
                    break
                end
            end

            -- Enable lookAtMouse in DNA
            CharacterManager.updateFaceOfPart(instance, faceOwner, { eyeLookAtMouse = true })
            CharacterManager.addTexturesFromInstance2(instance)

            local body = instance.parts[faceOwner].body
            local lpupil = findFixtureByLabel(body, 'lpupil')
            local rpupil = findFixtureByLabel(body, 'rpupil')

            assert.is_true(lpupil.extra.lookAtMouse)
            assert.is_true(rpupil.extra.lookAtMouse)
        end)

        it("pupil eyeW/eyeH should be positive and smaller than body dimensions", function()
            local faceOwner
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face and instance.parts[partName] then
                    faceOwner = partName
                    break
                end
            end

            local body = instance.parts[faceOwner].body
            local lpupil = findFixtureByLabel(body, 'lpupil')

            assert.is_true(lpupil.extra.eyeW > 0, "eyeW should be positive")
            assert.is_true(lpupil.extra.eyeH > 0, "eyeH should be positive")
            -- Pupil should be smaller than eye
            assert.is_true(lpupil.extra.w < lpupil.extra.eyeW,
                "pupil width should be smaller than eye width")
            assert.is_true(lpupil.extra.h < lpupil.extra.eyeH,
                "pupil height should be smaller than eye height")
        end)

        it("pupil extras should have eyeMaskURL", function()
            local faceOwner
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face and instance.parts[partName] then
                    faceOwner = partName
                    break
                end
            end

            local body = instance.parts[faceOwner].body
            local lpupil = findFixtureByLabel(body, 'lpupil')

            assert.is_truthy(lpupil.extra.eyeMaskURL, "pupil should have eyeMaskURL")
            assert.is_string(lpupil.extra.eyeMaskURL)
        end)
    end)

    -- ─── Brow decals ───

    describe("brow decals", function()
        it("should create left and right brow decals with browMirror", function()
            local faceOwner
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face and instance.parts[partName] then
                    faceOwner = partName
                    break
                end
            end

            local body = instance.parts[faceOwner].body
            local lbrow = findFixtureByLabel(body, 'lbrow')
            local rbrow = findFixtureByLabel(body, 'rbrow')

            assert.is_truthy(lbrow, "should have lbrow")
            assert.is_truthy(rbrow, "should have rbrow")

            -- lbrow should NOT be mirrored, rbrow should be mirrored
            assert.is_false(lbrow.extra.browMirror)
            assert.is_true(rbrow.extra.browMirror)
        end)

        it("brow extras should have browCurve and browBend", function()
            local faceOwner
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face and instance.parts[partName] then
                    faceOwner = partName
                    break
                end
            end

            local body = instance.parts[faceOwner].body
            local lbrow = findFixtureByLabel(body, 'lbrow')

            assert.is_true(lbrow.extra.browCurve)
            assert.is_number(lbrow.extra.browBend)
            assert.is_true(lbrow.extra.browBend >= 1 and lbrow.extra.browBend <= 10)
        end)
    end)

    -- ─── Randomization ───

    describe("randomizeMipo", function()
        local mipo
        before_each(function()
            package.loaded['src.ui.mipo-editor'] = nil
            mipo = require('src.ui.mipo-editor')
        end)

        it("should not crash", function()
            mipo.randomizeMipo(instance)
        end)

        it("should produce valid face DNA after randomization", function()
            mipo.randomizeMipo(instance)

            local faceOwner
            for partName, partData in pairs(instance.dna.parts) do
                if partData.appearance and partData.appearance.face and instance.parts[partName] then
                    faceOwner = partName
                    break
                end
            end
            assert.is_truthy(faceOwner)

            local face = instance.dna.parts[faceOwner].appearance.face
            assert.is_truthy(face.eye)
            assert.is_number(face.eye.shape)
            assert.is_truthy(face.pupil)
            assert.is_number(face.pupil.shape)
            assert.is_truthy(face.brow)
            assert.is_number(face.brow.shape)
            assert.is_truthy(face.mouth)
            assert.is_number(face.mouth.shape)
        end)

        it("should keep ear zOffsets valid after randomization", function()
            mipo.randomizeMipo(instance)

            local learSkin = instance.dna.parts.lear.appearance.skin
            local rearSkin = instance.dna.parts.rear.appearance.skin
            assert.is_number(learSkin.zOffset)
            assert.is_number(rearSkin.zOffset)
        end)

        it("should produce valid fixtures with zGroupOffset after randomization", function()
            mipo.randomizeMipo(instance)

            for partName, part in pairs(instance.parts) do
                if part.body and not part.body:isDestroyed() then
                    for _, f in ipairs(part.body:getFixtures()) do
                        local ud = f:getUserData()
                        if ud and ud.extra then
                            assert.is_truthy(ud.extra.zGroupOffset,
                                partName .. " fixture missing zGroupOffset after randomize")
                        end
                    end
                end
            end
        end)
    end)
end)
