-- spec/ship-list_spec.lua
-- What a build packs (claudetools/ship-list.py, docs/ASSETS-AND-BUILDS.md AB5) against what the game
-- really opens: the rooms of the builds' scenes loaded, drawn, knocked about (impact sounds) and a few
-- random Mipos made and drawn, with every picture, sound and font the game asks for written down.
-- Any of those on disk but not on the ship list would be missing in the web or phone build.
-- Desktop only (it runs the python script). love . --specs spec/ship-list_spec.lua (--audio: the
-- voices load too)
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local mipoRegistry = require('src.mipo-registry')
local sceneIO = require('src.io')
local camera = require('src.camera')
local box2dDrawTextured = require('src.physics.box2d-draw-textured')
local CharacterManager = require('src.character-manager')
local physicsCallbacks = require('src.physics.physics-callbacks')

local SCENES = { 'dollhouse', 'overworld' } -- what the builds are made of (and the rooms behind their doors)

local function shipList(scene)
    local pipe = io.popen('python3 -I claudetools/ship-list.py ' .. scene .. ' 2>/dev/null')
    if not pipe then return nil end
    local list, rooms = {}, {}
    for line in pipe:lines() do
        list[line] = true
        local room = line:match('^scripts/(.+)%.playtime%.json$')
        if room then rooms[#rooms + 1] = room end
    end
    pipe:close()
    return next(list) and list or nil, rooms
end

-- every textures/ or assets/ path the game asks for while fn runs
local function recording(fn)
    local opened = {} -- [path] = 'listed' (getDirectoryItems) or true
    local function note(path, how)
        if type(path) == 'string' and (path:find('^textures/') or path:find('^assets/')) then
            opened[path] = how or opened[path] or true
        end
    end
    local wrapped = {
        { love.filesystem, 'getInfo' }, { love.filesystem, 'getDirectoryItems' }, { love.filesystem, 'read' },
        { love.graphics, 'newImage' }, { love.image, 'newImageData' }, { love.graphics, 'newFont' },
    }
    if love.audio then wrapped[#wrapped + 1] = { love.audio, 'newSource' } end
    if love.sound then wrapped[#wrapped + 1] = { love.sound, 'newSoundData' } end
    local real = {}
    for i, w in ipairs(wrapped) do
        real[i] = w[1][w[2]]
        local how = w[2] == 'getDirectoryItems' and 'listed' or nil
        w[1][w[2]] = function(path, ...)
            note(path, how)
            return real[i](path, ...)
        end
    end
    local ok, err = pcall(fn)
    for i, w in ipairs(wrapped) do w[1][w[2]] = real[i] end
    assert(ok, err)
    return opened
end

local function drawOnce(world)
    box2dDrawTextured.makeCombinedImages()
    local canvas = love.graphics.newCanvas(64, 64)
    love.graphics.setCanvas({ canvas, stencil = true })
    pcall(box2dDrawTextured.drawTexturedWorld, world)
    love.graphics.setCanvas()
    love.graphics.setShader()
    canvas:release()
end

local function playRoom(room)
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    world:setCallbacks(unpack(physicsCallbacks))
    state.physicsWorld = world
    registry.reset()
    mipoRegistry.reset()
    state.backdrops = {}
    math.randomseed(1); love.math.setRandomSeed(1)
    sceneIO.load(love.filesystem.read('scripts/' .. room .. '.playtime.json'), world, camera.getInstance())
    drawOnce(world)
    -- knock everything down hard, for the impact sounds
    for _, body in ipairs(world:getBodies()) do
        if body:getType() == 'dynamic' then body:setLinearVelocity(0, 4000) end
    end
    for _ = 1, 30 do world:update(1 / 60) end
    -- random Mipos: any part picture the randomizer can pick
    for seed = 1, 6 do
        love.math.setRandomSeed(seed); math.randomseed(seed)
        local instance = CharacterManager.createCharacter('humanoid', 0, -2000, 0.3)
        CharacterManager.randomizeMipo(instance)
    end
    drawOnce(world)
    for _, body in ipairs(world:getBodies()) do body:setUserData(nil) end
    world:setCallbacks()
    world:destroy()
    registry.reset()
    mipoRegistry.reset()
end

describe('the ship list', function()
    it('has every picture, sound and font the builds\' rooms open', function()
        local total = 0 -- the pictures stay cached between scenes, so counted over all of them
        for _, scene in ipairs(SCENES) do
            local list, rooms = shipList(scene)
            if not list then
                pending('no python3 with the ship list (claudetools/ship-list.py)')
                return
            end
            local opened = {}
            for _, room in ipairs(rooms) do
                for path, how in pairs(recording(function() playRoom(room) end)) do
                    opened[path] = (opened[path] == 'listed' or how == 'listed') and 'listed' or true
                end
            end
            local missing, count = {}, 0
            for path, how in pairs(opened) do
                local info = love.filesystem.getInfo(path)
                if info and info.type == 'file' then
                    count = count + 1
                    if not list[path] then missing[#missing + 1] = path end
                elseif info and info.type == 'directory' and how == 'listed' then -- the code lists it: all ships
                    for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
                        local file = path:gsub('/$', '') .. '/' .. item
                        local i = love.filesystem.getInfo(file)
                        if i and i.type == 'file' and not item:find('^%.') and item ~= 'README.md' then
                            count = count + 1
                            if not list[file] then missing[#missing + 1] = file end
                        end
                    end
                end
            end
            table.sort(missing)
            total = total + count
            assert.are.equal(0, #missing, scene .. ' opens what its build leaves out:\n  ' ..
                table.concat(missing, '\n  '))
        end
        assert.is_true(total > 50, 'only ' .. total .. ' files opened: the recording missed them')
    end)
end)
