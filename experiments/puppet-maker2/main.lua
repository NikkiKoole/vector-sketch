package.path = package.path .. ";../../?.lua"


if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

if jit then
    jit.off()
end
require 'lib.printC'

function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()


local text                = require 'lib.text'
gesture                   = require 'lib.gesture'
SM                        = require 'vendor.SceneMgr'
inspect                   = require 'vendor.inspect'
PROF_CAPTURE              = false
prof                      = require 'vendor.jprof'
ProFi                     = require 'vendor.ProFi'
focussed                  = true

local Timer               = require 'vendor.timer'
local dna                 = require 'lib.dna'
local phys                = require 'lib.mainPhysics'
local lurker              = require 'vendor.lurker'
lurker.quiet              = true
local cam                 = require('lib.cameraBase').getInstance()
local manual_gc           = require 'vendor.batteries.manual_gc'
local updatePart          = require 'lib.updatePart'
local texturedBox2d       = require 'lib.texturedBox2d'
local box2dGuyCreation    = require 'lib.box2dGuyCreation'
local DEBUG_PROFILER      = false
local LOAD_AND_SAVE_FILES = true
local canvas              = require 'lib.canvas'
local numbers             = require 'lib.numbers'
canvas.setShrinkFactor(2)
-- BEWARE: turning on the debug profiler will cause memory to grow endlessly (its saving profilingdata)...
if DEBUG_PROFILER == false then
    prof.push = function(a)
    end
    prof.pop  = function(a)
    end
end

lurker.postswap = function(f)
    print("File " .. f .. " was swapped")
    focussed = true
end

local audioHelper = require 'lib.melody-paint-audio-helper'
audioHelper.startAudioThread()

creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }
blueColor = { 0x0a / 0xff, 0, 0x4b / 0xff, 1 }



function setCategories(guy)
    local creation = guy.dna.creation
    categories = {}

    for i = 1, #parts do
        if parts[i].child ~= true then
            local skip = false
            if creation.isPotatoHead then
                local name = parts[i].name
                if name == 'head' or name == 'neck' or name == 'patches' then
                    skip = true
                end
            end
            if not creation.hasNeck then
                local name = parts[i].name
                if name == 'neck' then
                    skip = true
                end
            end

            if not skip then
                table.insert(categories, parts[i].name)
            end
        end
    end
end

function playSound(sound, optionalPitch, volumeMultiplier)
    local s = sound:clone()
    local p = optionalPitch == nil and (.99 + .02 * love.math.random()) or optionalPitch
    s:setPitch(p)
    local volume = (1 * (volumeMultiplier == nil and 1 or volumeMultiplier))

    s:setVolume(volume * mainVolume)
    love.audio.play(s)
    return s
end

function growl(pitch)
    if (playingSound) then playingSound:stop() end
    local index = math.ceil(love.math.random() * #hum)
    local sndLength = hum[math.ceil(index)]:getDuration() / pitch
    playingSound = playSound(hum[math.ceil(index)], pitch, 2)
    mouthSay(fiveGuys[pickedFiveGuyIndex], sndLength)
    --myWorld:emit('mouthSaySomething', mouth, editingGuy, sndLength)
end

function getPointToCenterTransitionOn()
    local bodyPart = fiveGuys[pickedFiveGuyIndex].b2d.head or fiveGuys[pickedFiveGuyIndex].b2d.torso
    local x, y = bodyPart:getWorldCenter()
    local bx, by = cam:getScreenCoordinates(x, y)
    return bx, by
end

function loadSong(filename)
    if text.ends_with(filename, 'melodypaint.txt') then
        local contents = love.filesystem.read(filename)
        local tab = (loadstring("return " .. contents)())
        local result = audioHelper.loadMelodyPaintTab(tab, samples)

        if result then
            song = result
            song.page = song.pages[1]
            audioHelper.sendMessageToAudioThread({ type = 'song', data = song })
        else
            print('no success loading meloypaint file')
        end
    else
        print('i only load files ending in .melodypaint.txt')
    end
end

function doinkBody(guy)
    guy.b2d.torso:applyLinearImpulse(0, 10000)
end

function breathBody(guy)
    guy.b2d.torso:applyLinearImpulse(0, -1000)
end

function eyeBlink(guy)
    Timer.tween(.1, guy.tweenVars, { eyesOpen = 0 }, 'out-quad')
    Timer.after(.1 + 0.1, function()
        Timer.tween(.15, guy.tweenVars, { eyesOpen = 1 }, 'out-quad')
    end)
end

function mouthSay(guy, length)
    local maxOpen = 1.25 + love.math.random() * 0.5
    local minWide = .5 + love.math.random() * 1.8

    local totalDur = length * 1.3
    Timer.tween(totalDur / 3, guy.tweenVars, { mouthOpen = maxOpen, mouthWide = minWide }, 'out-quad')
    Timer.after(totalDur / 3 + 0.1, function()
        Timer.tween(totalDur / 3, guy.tweenVars, { mouthOpen = 0, mouthWide = 1 }, 'out-quad')
    end)
end

function lookAt(guy, x, y)
    guy.tweenVars.lookAtCounter = 1 + love.math.random() * 4
    guy.tweenVars.lookAtPosX = x
    guy.tweenVars.lookAtPosY = y
end

function hasSavedDNA5File()
    local contents, size = love.filesystem.read('dna5.txt')
    return contents
end

--t odo get rid of all the meta stuff, it has too much data we cannot parse anymore

function loadDNA5File()
    local contents, size = love.filesystem.read('dna5.txt')
    --print('wants to load an earlier saved file')
    --print(inspect(contents))
    local parsed = (loadstring("return " .. contents)())
    --print(inspect(parsed))

    local result = {}
    for i = 1, 5 do
        result[i] = {
            init = false,
            id = i,
            dna = dna.patchDNA(parsed[i]),
            b2d = nil,
            canvasCache = {},
            facingVars = {
                legs = 'front', --'right'/front
            },
            tweenVars = {
                lookAtPosX = 0,
                lookAtPosY = 0,
                lookAtCounter = 0,
                blinkCounter = love.math.random() * 5,
                eyesOpen = 1,
                mouthWide = 1,
                mouthOpen = 0
            }
        }
    end
    return result
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function saveDNA5File()
    local saveData = {}


    for i = 1, #fiveGuys do
        saveData[i] = deepcopy(fiveGuys[i].dna)
        saveData[i].creation = deepcopy(dna.getCreation()) -- not writing the real creation parts, we let that regenerate

        -- but i do need to save these things....
        saveData[i].creation.isPotatoHead = fiveGuys[i].dna.creation.isPotatoHead
        saveData[i].creation.hasPhysicsHair = fiveGuys[i].dna.creation.hasPhysicsHair
        saveData[i].creation.hasNeck = fiveGuys[i].dna.creation.hasNeck

        saveData[i].creation.lear.stanceAngle = fiveGuys[i].dna.creation.lear.stanceAngle
        saveData[i].creation.rear.stanceAngle = fiveGuys[i].dna.creation.rear.stanceAngle

        saveData[i].creation.torso.flipx = fiveGuys[i].dna.creation.torso.flipx
        saveData[i].creation.torso.flipy = fiveGuys[i].dna.creation.torso.flipy

        saveData[i].creation.head.flipx = fiveGuys[i].dna.creation.head.flipx
        saveData[i].creation.head.flipy = fiveGuys[i].dna.creation.head.flipy
    end
    love.filesystem.write('dna5.txt', inspect(saveData, { indent = "" }))
    --print(inspect(fiveGuys))
    --print('wants to save a file')
    --local openURL = "file://" .. love.filesystem.getSaveDirectory() .. '/'
    --love.system.openURL(openURL)
end

local function contactShouldBeDisabled(a, b, contact)
    local ab = a:getBody()
    local bb = b:getBody()

    local fixtureA, fixtureB = contact:getFixtures()
    local result = false

    -- for some reason the other way around doesnt happen so fixtureA is the ground and the other one might be ball
    -- this disables contact between a dragged item and the ground
    for i = 1, #pointerJoints do
        local mj = pointerJoints[i]
        if (mj.jointBody) then
            if (bb == mj.jointBody and fixtureA:getUserData() and fixtureA:getUserData().bodyType == 'ground') then
                result = true
            end
        end
    end
    -- this disables contact between  balls and the ground if ballcenterY < collisionY (ball below ground)
    if fixtureA:getUserData() and fixtureB:getUserData() then
        if fixtureA:getUserData().bodyType == 'ground' and fixtureB:getUserData().bodyType == 'ball' then
            local x1, y1 = contact:getPositions()
            if y1 < bb:getY() then
                result = true
            end
        end
    end
    --return result

    return false
end

local function beginContact(a, b, contact)
    if contactShouldBeDisabled(a, b, contact) then
        contact:setEnabled(false)
        local point = { contact:getPositions() }
        -- i also should keep around what body (cirlcle) this is about,
        -- and also eventually probably also what touch id or mouse this is..

        for i = 1, #pointerJoints do
            local mj = pointerJoints[i]

            local bodyLastDisabledContact = nil
            if mj.jointBody == a:getBody() then
                bodyLastDisabledContact = a
            end
            if mj.jointBody == b:getBody() then
                bodyLastDisabledContact = b
            end
            if bodyLastDisabledContact then
                pointerJoints[i].bodyLastDisabledContact = bodyLastDisabledContact
                pointerJoints[i].positionOfLastDisabledContact = point
                table.insert(disabledContacts, contact)
            end
        end
    end
    --if isContactBetweenGroundAndCarGroundSensor(contact) then
    --    carIsTouching = carIsTouching + 1
    --end
end


local function endContact(a, b, contact)
    for i = #disabledContacts, 1, -1 do
        if disabledContacts[i] == contact then
            table.remove(disabledContacts, i)
        end
    end
end

local function preSolve(a, b, contact)
    -- this is so contacts keep on being disabled if they are on that list (sadly they are being re-enabled by box2d.... )
    for i = 1, #disabledContacts do
        disabledContacts[i]:setEnabled(false)
    end
end

local function postSolve(a, b, contact, normalimpulse, tangentimpulse)
    local fixtureA, fixtureB = contact:getFixtures()
    local aud = fixtureA:getUserData()
    local bud = fixtureB:getUserData()
    if aud and bud then
        -- print(a,b)
        --print(aud.bodyType, bud.bodyType)


        if (aud.bodyType == 'winegum' or bud.bodyType == 'winegum') then
            --print(normalimpulse, tangentimpulse)
            if normalimpulse > 60 and tangentimpulse > 3 then
                local index = math.ceil(love.math.random() * #winegumkisses)
                local pitch = numbers.mapInto(normalimpulse, 60, 300, 2, .1)
                local volume = numbers.mapInto(normalimpulse, 60, 300, .2, 1)
                if pitch < .25 then pitch = .25 end
                if volume < .2 then volume = .2 end

                -- check if these 2 bodies have had a collision in the last second or so
                -- print(normalimpulse, pitch, volume)

                local stillPlayingPlonkForSimilarCollision = false
                for i = 1, #playedPlonkSounds do
                    if playedPlonkSounds[i].aud == aud and playedPlonkSounds[i].bud == bud and playedPlonkSounds[i].timeAgo > 0 then
                        stillPlayingPlonkForSimilarCollision = true
                    end
                end

                if stillPlayingPlonkForSimilarCollision == false then
                    table.insert(playedPlonkSounds, { aud = aud, bud = bud, timeAgo = 0 })
                    playSound(winegumkisses[index], pitch, volume)
                end
            end
        end


        if (aud.bodyType == 'border' and (bud.bodyType == 'head' or bud.bodyType == 'torso' or bud.bodyType == 'lfoot' or bud.bodyType == 'rfoot'))
            or (bud.bodyType == 'body' and aud.bodyType == 'body')
            or (bud.bodyType == 'head' and aud.bodyType == 'head')
            or (bud.bodyType == 'head' and aud.bodyType == 'lhand')
            or (bud.bodyType == 'head' and aud.bodyType == 'rhand')
            or (bud.bodyType == 'body' and aud.bodyType == 'lhand')
            or (bud.bodyType == 'body' and aud.bodyType == 'rhand')

        then
            --- print(normalimpulse)
            -- print(normalimpulse, tangentimpulse)
            if normalimpulse > 300 and tangentimpulse > 50 then
                local index = math.ceil(love.math.random() * #rubberplonks)
                local pitch = numbers.mapInto(normalimpulse, 300, 10000, 2, 1)
                local volume = numbers.mapInto(normalimpulse, 300, 10000, .2, 1)
                if pitch < .5 then pitch = .5 end
                if volume < .2 then volume = .2 end

                -- check if these 2 bodies have had a collision in the last second or so
                -- print(normalimpulse, pitch, volume)

                local stillPlayingPlonkForSimilarCollision = false
                for i = 1, #playedPlonkSounds do
                    if playedPlonkSounds[i].aud == aud and playedPlonkSounds[i].bud == bud and playedPlonkSounds[i].timeAgo > 0 then
                        stillPlayingPlonkForSimilarCollision = true
                    end
                end

                if stillPlayingPlonkForSimilarCollision == false then
                    table.insert(playedPlonkSounds, { aud = aud, bud = bud, timeAgo = 0 })
                    playSound(rubberplonks[index], pitch, volume)
                end
            end
        end
    end
end




function love.load()
    winegums = {}
    upsideDown = false
    jointsEnabled = true
    phys.setupWorld(500)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    mainVolume = 1

    local sample_data = {
        'cr78/Conga Low',
        'cr78/Bongo Low',
        'cr78/Tamb 1',
        'cr78/Bongo High',
        'cr78/Guiro 1',
        'Triangles 101',
        'Triangles 103',
        'babirhodes/rhodes2',
        'babirhodes/ba',
        'babirhodes/bi',
        'babirhodes/biep2',
        'babirhodes/biep3',
        'mipo/pi',
        'mipo/po3',
        'mp7/Quijada' }

    samples = {}
    for i = 1, #sample_data do
        local data = love.sound.newSoundData('assets/instruments/' .. sample_data[i] .. '.wav')
        table.insert(samples, { s = love.audio.newSource(data, 'static'), p = sample_data[i] })
    end


    rollingMemoryUsage = {}

    for i = 1, 10 do
        rollingMemoryUsage[i] = 0
    end

    loadSong('assets/mipo4.melodypaint.txt')

    splashSound = love.audio.newSource("assets/sounds/music/mipolailoop.mp3", "static")
    introSound = love.audio.newSource("assets/sounds/music/introloop.mp3", "static")

    miSound1 = love.audio.newSource("assets/sounds/mi.wav", "static")
    miSound2 = love.audio.newSource("assets/sounds/mi2.wav", "static")
    moSound1 = love.audio.newSource("assets/sounds/mo.wav", "static")
    poSound1 = love.audio.newSource("assets/sounds/po.wav", "static")
    poSound2 = love.audio.newSource("assets/sounds/po2.wav", "static")
    piSound1 = love.audio.newSource("assets/sounds/pi.wav", "static")

    audioHelper.sendMessageToAudioThread({ type = "volume", data = 0.2 });
    audioHelper.sendMessageToAudioThread({ type = "paused", data = true });
    audioHelper.sendMessageToAudioThread({ type = "samples", data = samples });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });

    if false then
        textures = {
            love.graphics.newImage('assets/img/bodytextures/texture-type0.png'),
            love.graphics.newImage('assets/img/bodytextures/texture-type2t.png'),
            love.graphics.newImage('assets/img/bodytextures/texture-type1.png'),
            love.graphics.newImage('assets/img/bodytextures/texture-type3.png'),
            love.graphics.newImage('assets/img/bodytextures/texture-type4.png'),
            love.graphics.newImage('assets/img/bodytextures/texture-type5.png'),
            love.graphics.newImage('assets/img/bodytextures/texture-type6.png'),
            love.graphics.newImage('assets/img/bodytextures/texture-type7.png'),
            love.graphics.newImage('assets/img/tiles/tiles2.png'),
            love.graphics.newImage('assets/img/tiles/tiles.png'),
        }
    end
    winegumkisses = {
        love.audio.newSource('assets/sounds/fx/winegum-kiss1.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/winegum-kiss2.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/winegum-kiss3.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/winegum-kiss4.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/winegum-kiss5.wav', 'static'),
    }

    hum = {
        love.audio.newSource('assets/sounds/fx/humup1.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/humup2.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/humup3.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/blah1.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/blah2.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/blah3.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/huh.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/huh2.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/tsk.wav', 'static'),
        love.audio.newSource('assets/sounds/fx/tsk2.wav', 'static'),
    }

    rubberplonks = {
        love.audio.newSource("assets/sounds/fx/rubber-plonk1.wav", "static"),
        love.audio.newSource("assets/sounds/fx/rubber-plonk2.wav", "static"),
        love.audio.newSource("assets/sounds/fx/rubber-plonk3.wav", "static")
    }

    playedPlonkSounds = {}

    rubberstretches = {
        love.audio.newSource("assets/sounds/fx/rubber-stretch1.wav", "static"),
        love.audio.newSource("assets/sounds/fx/rubber-stretch2.wav", "static"),
    }

    for i = 1, #textures do
        textures[i]:setWrap('mirroredrepeat', 'mirroredrepeat')
    end

    palettes = {}

    local base = {
        '020202', '4f3166', '69445D', '613D41', 'efebd8',
        '6f323a', '872f44', '8d184c', 'be193b', 'd2453a',
        'd6642f', 'd98524', 'dca941', 'e6c800', 'f8df00',
        'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf',
        '9c9d9f', '938541', '808b1c', '8A934E', '86a542',
        '57843d', '45783c', '2a5b3e', '1b4141', '1e294b',
        '0d5f7f', '065966', '1b9079', '3ca37d', '49abac',
        '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3',
        '045b9f', '9377b2', '686094', '5f4769', '815562',
        '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34',
        'CB433A', 'a95c42', 'c37c61', 'd19150', 'de9832',
        'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
        '252f38', '42505f', '465059', '57595a', '6e7c8c',
        '75899c', 'aabdce', '807b7b', '857b7e', '8d7e8a',
        'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267',
        'f0644d', 'ff7376', 'd76656', 'b16890', '020202',
        '333233', '814800', 'efebd8', '1a5f8f', '66a5bc',
        '87727b', 'a23d7e', 'fa8a00', 'fef1d0', 'ffa8a2',
        '6e614c', '418090', 'b5d9a4', 'c0b99e', '4D391F',
        '4B6868', '9F7344', '9D7630', 'D3C281', '8F4839',
        'EEC488', 'C77D52', 'C2997A', '9C5F43', '9C8D81',
        '965D64', '798091', '4C5575', '6E4431', '626964',
    }

    function hex2rgb(hex)
        hex = hex:gsub("#", "")
        return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
            tonumber("0x" .. hex:sub(5, 6))
            / 255
    end

    for i = 1, #base do
        local r, g, b = hex2rgb(base[i])
        table.insert(palettes, { r, g, b })
    end

    fiveGuys = {}
    parts = dna.generateParts()

    --local foundSaveFile = false
    if LOAD_AND_SAVE_FILES and hasSavedDNA5File() then
        fiveGuys = loadDNA5File()
    else
        for i = 1, 5 do
            local dna   = {
                multipliers = dna.getMultipliers(),
                creation = dna.getCreation(),
                values = dna.generateValues(),
                positioners = dna.getPositioners()
            }
            fiveGuys[i] = {
                init = false,
                id = i,
                dna = dna,
                b2d = nil,
                canvasCache = {},
                facingVars = {
                    legs = 'left', --'right'/front

                },
                tweenVars = {
                    lookAtPosX = 0,
                    lookAtPosY = 0,
                    lookAtCounter = 0,
                    blinkCounter = love.math.random() * 5,
                    eyesOpen = 1,
                    mouthWide = 1,
                    mouthOpen = 0
                }
            }
        end
        for i = 1, #fiveGuys do
            updatePart.randomizeGuy(fiveGuys[i], true)
        end
    end
    if LOAD_AND_SAVE_FILES and not hasSavedDNA5File() then
        -- this path is only taken the very first time, we want to use save and load functionality
        -- but nothing is saved (yet), so we immediately save it.
        saveDNA5File()
    end
    DEBUG_FIVE_GUYS_IN_EDIT = false
    pickedFiveGuyIndex = 3


    -- trying to render portraits of the five guys!



    SM.setPath("scenes/")
    --SM.load("splash")
    --SM.load("splash")


    -- print('hello good')
    SM.load("editGuy")
    -- SM.load("outside")
end

function toggleJoints()
    jointsEnabled = not jointsEnabled
    for i = 1, #fiveGuys do
        if (fiveGuys[i].b2d) then
            box2dGuyCreation.toggleAllJointLimits(fiveGuys[i], jointsEnabled)
        end
    end
    if jointsEnabled then
        for i = 1, #fiveGuys do
            updatePart.resetPositions(fiveGuys[i])
        end
    end
end

local function pickRandom(array)
    local index = math.ceil(love.math.random() * #array)
    return array[index]
end

function calculateRollingAverage(valueList)
    local sum = 0
    for _, value in ipairs(valueList) do
        sum = sum + value
    end
    return sum / #valueList
end

function love.update(dt)
    function love.keypressed(key)
        if key == "escape" then love.event.quit() end
        if key == 'p' then
            if true then
                if (PROF_CAPTURE) then
                    if profiling then
                        ProFi:stop()
                        ProFi:writeReport('profilingReport.txt')
                        profiling = false
                    else
                        ProFi:start()
                        profiling = true
                    end
                end
            end
        end
        if key == 'b' then
            local guy = fiveGuys[pickedFiveGuyIndex]
            guy.facingVars.legs = pickRandom({ 'left', 'right', 'front' })
            updatePart.updatePart('legs', guy)
            updatePart.resetPositions(guy)
            breathBody(guy)

            if false then
                -- i wanna tween length the body anf legs
                local guy = fiveGuys[pickedFiveGuyIndex]
                local initialLMultiplier = guy.dna.multipliers.leg.lMultiplier
                local newL = initialLMultiplier * 2
                Timer.tween(1, guy.dna.multipliers.leg, { lMultiplier = newL }, 'out-quad')
                Timer.after(1.1, function()
                    Timer.tween(.1, guy.dna.multipliers.leg, { lMultiplier = initialLMultiplier },
                        'out-quad')
                end)

                local initialTorsoW = guy.dna.multipliers.torso.wMultiplier
                local initialTorsoH = guy.dna.multipliers.torso.hMultiplier
                local newTorsoW = initialTorsoW * 3.2
                local newTorsoH = initialTorsoH * 3.2

                Timer.tween(1, guy.dna.multipliers.torso,
                    { wMultiplier = newTorsoW, hMultiplier = newTorsoH }, 'out-quad')

                Timer.after(1.1, function()
                    Timer.tween(.1, guy.dna.multipliers.torso,
                        { wMultiplier = initialTorsoW, hMultiplier = initialTorsoH },
                        'out-quad')
                end)

                Timer.during(1.3, function(dt)
                    --changePart('legs')
                    updatePart.updatePart('body', guy)
                    updatePart.updatePart('legs', guy)
                end)
            end
            --'dna.multipliers.leg.lMultiplier'
        end
        if false then
            if key == 'u' then
                upsideDown = not upsideDown
                print('upsidedown', upsideDown)
            end
            if key == 'w' then
                addWineGums()
            end
            if key == 'j' then
                toggleJoints()
            end
        end
        --print(key)
    end

    if true then
        prof.push('frame')
        --    lurker.update()

        --require("vendor.lurker").update()
        if not focussed then
            -- print('this app is unfocussed!')
        end

        if true then
            local msg = audioHelper.getMessageFromAudioThread()
            if msg then
                if (msg.type == 'beat') then
                    --print('beat')
                end
                if (msg.type == 'played') then
                    -- print('played', msg.data.path, msg.data.source, msg.data.pitch)
                end
                if SM.handleAudioMessage then
                    SM.handleAudioMessage(msg)
                end
            end
        end
        if focussed and not grabbingScreenshots.doing then
            for i = 1, #fiveGuys do
                fiveGuys[i].tweenVars.blinkCounter = fiveGuys[i].tweenVars.blinkCounter - dt
                if fiveGuys[i].tweenVars.blinkCounter < 0 then
                    eyeBlink(fiveGuys[i])
                    fiveGuys[i].tweenVars.blinkCounter = love.math.random() * 5
                end
                if (fiveGuys[i].tweenVars.lookAtCounter > 0) then
                    fiveGuys[i].tweenVars.lookAtCounter = fiveGuys[i].tweenVars.lookAtCounter - dt
                    if fiveGuys[i].tweenVars.lookAtCounter <= 0 then
                        fiveGuys[i].tweenVars.lookAtCounter = 0
                    end
                end
            end
            Timer.update(dt)
            gesture.update(dt)
            prof.push('SM.update')
            SM.update(dt)

            prof.pop('SM.update')
        else
            print('not updating the timer')
        end
        prof.push('world update')


        for i = #playedPlonkSounds, 1, -1 do
            playedPlonkSounds[i].timeAgo = playedPlonkSounds[i].timeAgo + dt
            if playedPlonkSounds[i].timeAgo >= .5 then
                table.remove(playedPlonkSounds, i)
            end
        end
        if SM.cName ~= 'intro' then
            world:update(dt)
        end
        -- if SM.cName == 'intro' then
        --     world:update(dt / 1000)
        -- end
        prof.pop('world update')
        --collectgarbage()



        -- prof.push('gc')
        -- manual_gc(1, 1)
        --prof.pop('gc')
        prof.pop('frame')
    end
    table.insert(rollingMemoryUsage, collectgarbage("count") / 1000)
    table.remove(rollingMemoryUsage, 1)
    manual_gc(0.002, 2)
end

grabbingScreenshots = {
    doing = false,
    index = 0,
    resolutions = {},
    work = function()
        local index = grabbingScreenshots.index
        local w = grabbingScreenshots.resolutions[index][1]
        local h = grabbingScreenshots.resolutions[index][2]
        local type = grabbingScreenshots.resolutions[index][3]

        local url = 'puppetmaker-marketing-' ..
            grabbingScreenshots.name .. '-' .. type .. '-' .. os.date("%Y%m%d%H%M%S") .. '.png'
        local success = love.window.updateMode(w / 2, h / 2, { fullscreen = false })
        if love.resize then love.resize(w, h) end
        print('making marketing screenshot', index, w, h, url)
        SM.draw()
        love.graphics.captureScreenshot(url)
    end,
    advance = function()
        if grabbingScreenshots.index < #grabbingScreenshots.resolutions then
            grabbingScreenshots.index = grabbingScreenshots.index + 1
        else
            grabbingScreenshots.doing = false
        end
    end
}

function love.draw()
    if true then
        prof.push('frame')
        if grabbingScreenshots.doing then
            grabbingScreenshots.work()
        end
        prof.push('SM.draw')
        SM.draw()
        prof.pop('SM.draw')

        if grabbingScreenshots.doing then
            grabbingScreenshots.advance()
        end
        prof.push('gc draw')
        prof.pop('gc draw')
        prof.pop('frame')
    end
    --  love.graphics.setColor(1, 1, 1, 1)
    -- local stats = love.graphics.getStats()
    -- love.graphics.print(inspect(stats), 10, 10)
    --love.graphics.print(
    --     world:getBodyCount() ..
    --     '  , ' .. world:getJointCount() .. '  , ' .. love.timer.getFPS() .. ', ' .. collectgarbage("count"), 180,
    --     10)
end

function love.quit()
    -- this takes annoyingly long
    time = love.timer.getTime()
    prof.write("prof.mpack")
    --local openURL = "file://" .. love.filesystem.getSaveDirectory()
    --love.system.openURL(openURL)
    --print('writing [profe.mpack] took', love.timer.getTime() - time, 'seconds')
end

function makeMarketingScreenshots(name)
    local resolutions = {
        { 2796,     1290,     '6-7' },      --6.7
        { 2796 / 2, 1290 / 2, '6-7-50%' },  --6.7
        { 2688,     1242,     '6-5' },      --6.5
        { 2688 / 2, 1242 / 2, '6-5-50%' },  --6.5
        { 2208,     1242,     '5-5' },      -- 5.5
        { 2208 / 2, 1242 / 2, '5-5-50%' },  -- 5.5
        { 2732,     2048,     '12-9' },     -- 12.9
        { 2732 / 2, 2048 / 2, '12-9-50%' }, -- 12.9
    }

    grabbingScreenshots.doing = true
    grabbingScreenshots.index = 1
    grabbingScreenshots.name = name or ''
    grabbingScreenshots.resolutions = resolutions
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end

function findPart(name)
    for i = 1, #parts do
        if parts[i].name == name then
            return parts[i]
        end
    end
end
