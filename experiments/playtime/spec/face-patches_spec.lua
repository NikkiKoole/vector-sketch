-- spec/face-patches_spec.lua
-- Face patches (src/face-patches.lua): one decal on the face holding the eye hollows and the
-- snout, put back when the textures are remade, sliding with the face as it turns (the snout
-- stays on the nose). FACE_PATCHES_PNG=<dir> also writes the face front-on and turned, to look at.
-- Run with: love . --specs spec/face-patches_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local facePatches = require('src.face-patches')
local facing = require('src.mipo-facing')

describe('face patches', function()
    local world

    before_each(function()
        registry.reset()
        mipoRegistry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        math.randomseed(5); love.math.setRandomSeed(5)
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
        mipoRegistry.reset()
    end)

    -- the part the face is on: torso1 on a potato head (no head of its own)
    local function faceBody(instance)
        return instance.parts[instance.dna.creation.isPotatoHead and 'torso1' or 'head'].body
    end

    local function decals(instance)
        local found = {}
        for _, fixture in ipairs(faceBody(instance):getFixtures()) do
            local ud = fixture:getUserData()
            if ud and ud.subtype == 'decal' and ud.label then found[ud.label] = ud.extra end
        end
        return found
    end

    -- a Mipo with a whole face (eyes, nose, mouth): the default one has no nose
    local function newMipo()
        local instance = CM.createCharacter('humanoid', 0, 0, 0.3)
        for _ = 1, 10 do
            CM.randomizeMipo(instance)
            if decals(instance).nose and decals(instance).lpupil then return instance end
        end
        return instance
    end

    local function snoutOf(extra)
        for _, patch in ipairs(extra.facePatches) do
            if patch.kind == 'snout' then return patch end
        end
    end

    -- the head drawn into a picture, written to dir/name.png
    local function writeFace(instance, dir, name)
        require('src.render.omp-bake').makeCombinedImages()
        local head = faceBody(instance)
        local hx, hy = head:getPosition()
        local canvas = love.graphics.newCanvas(500, 500)
        love.graphics.push('all')
        love.graphics.setCanvas({ canvas, stencil = true })
        love.graphics.clear(0.1, 0.25, 0.12, 1)
        love.graphics.origin()
        love.graphics.translate(250, 250)
        love.graphics.scale(1.4)
        love.graphics.translate(-hx, -hy)
        require('src.physics.box2d-draw-textured').drawTexturedWorld(world)
        love.graphics.pop()
        local file = io.open(dir .. '/' .. name .. '.png', 'wb')
        file:write(canvas:newImageData():encode('png'):getString())
        file:close()
    end

    it('puts eye hollows and a snout on the face, and keeps them through a redraw', function()
        local instance = newMipo()
        instance.facePatches = facePatches.defaults()
        facePatches.place(instance, true)
        local patches = decals(instance).facepatches
        assert.is_truthy(patches)
        assert.are.equal(3, #patches.facePatches)
        assert.are.equal(instance.zGroupOffset, patches.zGroupOffset)
        CM.rebuildTextures(instance)
        assert.are.equal(3, #decals(instance).facepatches.facePatches)
        instance.facePatches = nil
        facePatches.place(instance)
        assert.is_nil(decals(instance).facepatches)
    end)

    it('slides with the face as it turns: the snout stays on the nose', function()
        local instance = newMipo()
        local thing = faceBody(instance):getUserData().thing
        thing.gazeX, thing.gazeY = 0, 10000 -- the pupils look down, not at a mouse
        instance.facePatches = facePatches.defaults()
        instance.facePatches.snoutLight = 0.7
        facePatches.place(instance, true)
        local dir = os.getenv('FACE_PATCHES_PNG')
        if dir then writeFace(instance, dir, 'front') end
        local found = decals(instance)
        local noseFront, snoutFront = found.nose.ox, snoutOf(found.facepatches).ox
        instance._turnAngle = facing.faceTurn
        facing.applyFace(instance)
        found = decals(instance)
        assert.is_true(math.abs(found.nose.ox - noseFront) > 1)
        assert.is_near(found.nose.ox - noseFront, snoutOf(found.facepatches).ox - snoutFront, 0.01)
        if dir then writeFace(instance, dir, 'turned') end
    end)
end)
