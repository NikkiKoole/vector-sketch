package.path = package.path .. ";../../?.lua"

local manual_gc = require 'vendor.batteries.manual_gc'
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end


jit.off()
require 'lib.printC'

if true then
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
        --print(a, b, c, d, e)
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

local mesh   = require 'lib.mesh'
local parse  = require 'lib.parse-file'
local node   = require 'lib.node'
local text   = require 'lib.text'
gesture      = require 'lib.gesture'
SM           = require 'vendor.SceneMgr'
inspect      = require 'vendor.inspect'
PROF_CAPTURE = true
prof         = require 'vendor.jprof'
ProFi        = require 'vendor.ProFi'
focussed     = true

local Timer  = require 'vendor.timer'
local dna    = require 'src.dna'
local phys   = require 'src.mainPhysics'
local lurker = require 'vendor.lurker'
lurker.quiet = true


local DEBUG_PROFILER = false
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


local audioHelper = require 'lib.audio-helper'
audioHelper.startAudioThread()

creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }
blueColor = { 0x0a / 0xff, 0, 0x4b / 0xff, 1 }

function playSound(sound, optionalPitch, volumeMultiplier)
    local s = sound:clone()
    local p = optionalPitch == nil and (.99 + .02 * love.math.random()) or optionalPitch
    s:setPitch(p)
    local volume = (.25 * (volumeMultiplier == nil and 1 or volumeMultiplier))

    s:setVolume(volume * mainVolume)
    love.audio.play(s)
    return s
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
    Timer.after(.1 + 0.001, function()
        Timer.tween(.15, guy.tweenVars, { eyesOpen = 1 }, 'out-quad')
    end)
end

function mouthSay(guy, length)
    local maxOpen = 1.25 + love.math.random() * 0.5
    local minWide = .5 + love.math.random() * 0.8

    local totalDur = length + 0.1
    Timer.tween(totalDur / 3, guy.tweenVars, { mouthOpen = maxOpen, mouthWide = minWide }, 'out-quad')
    Timer.after(totalDur / 3 + 0.001, function()
        Timer.tween(totalDur / 3, guy.tweenVars, { mouthOpen = 0, mouthWide = 1 }, 'out-quad')
    end)
end

function stripPath(root, path)
    if root and root.texture and root.texture.url and #root.texture.url > 0 then
        local str = root.texture.url
        local shortened = string.gsub(str, path, '')
        root.texture.url = shortened
    end

    if root.children then
        for i = 1, #root.children do
            stripPath(root.children[i], path)
        end
    end

    return root
end

local function stripPath(root, path)
    if root and root.texture and root.texture.url and #root.texture.url > 0 then
        local str = root.texture.url
        local shortened = string.gsub(str, path, '')
        root.texture.url = shortened
    end

    if root.children then
        for i = 1, #root.children do
            stripPath(root.children[i], path)
        end
    end

    return root
end

function loadGroupFromFile(url, groupName)
    local imgs = {}
    local parts = {}
    local whole = parse.parseFile(url)
    local group = node.findNodeByName(whole, groupName) or {}

    for i = 1, #group.children do
        local p = group.children[i]
        stripPath(p, '/experiments/puppet%-maker/')
        for j = 1, #p.children do
            if p.children[j].texture then
                imgs[i] = p.children[j].texture.url
                parts[i] = group.children[i]
            end
        end
    end
    return imgs, parts
end

function zeroTransform(arr)
    for i = 1, #arr do
        if arr[i].transforms then
            arr[i].transforms.l[1] = 0
            arr[i].transforms.l[2] = 0
        end
    end
end

function loadVectorSketchAndGetImages(path, groupName)
    local parts, img = loadVectorSketch(path, groupName, true)
    return img, parts
end

function loadVectorSketch(path, groupName, getImagesToo)
    local img, bodyParts = loadGroupFromFile(path, groupName)
    zeroTransform(bodyParts)

    local result = {}
    for i = 1, #bodyParts do
        local me = {
            pivotX = bodyParts[i].transforms.l[6] - bodyParts[i].transforms.l[1],
            pivotY = bodyParts[i].transforms.l[7] - bodyParts[i].transforms.l[2]
        }
        for j = 1, #bodyParts[i].children do
            local child = bodyParts[i].children[j]
            if child.texture and child.texture.url then
                local img = mesh.getImage(child.texture.url)
                me.url = child.texture.url
                me.texturePoints = child.points
            end
            if child.type == 'meta' then
                --print(inspect(child.points))
                me.points = child.points
            end
        end
        table.insert(result, me)
    end

    return result, img
end

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
end

function love.load()
    phys.setupWorld()

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

    loadSong('assets/mipo4.melodypaint.txt')


    splashSound = love.audio.newSource("assets/sounds/music/mipolailoop.mp3", "static")
    introSound = love.audio.newSource("assets/sounds/music/introloop.mp3", "static")
    miSound2 = love.audio.newSource("assets/sounds/mi2.wav", "static")
    poSound2 = love.audio.newSource("assets/sounds/po2.wav", "static")
    miSound1 = love.audio.newSource("assets/sounds/mi.wav", "static")
    poSound1 = love.audio.newSource("assets/sounds/po.wav", "static")

    audioHelper.sendMessageToAudioThread({ type = "volume", data = 0.2 });
    audioHelper.sendMessageToAudioThread({ type = "paused", data = true });
    audioHelper.sendMessageToAudioThread({ type = "samples", data = samples });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });

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
    for i = 1, 5 do
        local dna   = {
            multipliers = dna.getMultipliers(),
            creation = dna.getCreation(),
            values = dna.generateValues(),
            positioners = dna.getPositioners()
        }
        fiveGuys[i] = {
            id = i,
            dna = dna,
            b2d = nil,
            canvasCache = {},
            tweenVars = {
                eyesOpen = 1,
                mouthWide = 1,
                mouthOpen = 0
            }
        }
    end
    pickedFiveGuyIndex = 1

    SM.setPath("scenes/")
    --SM.load("intro")
    SM.load("editGuy")
end

function love.update(dt)
    if true then
        prof.push('frame')
        --    lurker.update()

        --require("vendor.lurker").update()
        if not focussed then
            -- print('this app is unfocessed!')
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
            --print('hello!')
            Timer.update(dt)
            gesture.update(dt)
            prof.push('SM.update')
            SM.update(dt)

            prof.pop('SM.update')
        else
            print('not updating the timer')
        end
        prof.push('world update')

        world:update(dt)
        prof.pop('world update')
        --collectgarbage()



        -- prof.push('gc')
        -- manual_gc(1, 1)
        --prof.pop('gc')
        prof.pop('frame')
    end
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
        print('making marketing screenhsot', index, w, h, url)
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
    love.graphics.setColor(1, 1, 1, 1)
    --local stats = love.graphics.getStats()
    love.graphics.print(
        world:getBodyCount() ..
        '  , ' .. world:getJointCount() .. '  , ' .. love.timer.getFPS() .. ', ' .. collectgarbage("count"), 180,
        10)
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
        { 2796,     1290,     '6-7' }, --6.7
        { 2796 / 2, 1290 / 2, '6-7-50%' }, --6.7
        { 2688,     1242,     '6-5' }, --6.5
        { 2688 / 2, 1242 / 2, '6-5-50%' }, --6.5
        { 2208,     1242,     '5-5' }, -- 5.5
        { 2208 / 2, 1242 / 2, '5-5-50%' }, -- 5.5
        { 2732,     2048,     '12-9' }, -- 12.9
        { 2732 / 2, 2048 / 2, '12-9-50%' }, -- 12.9
    }

    grabbingScreenshots.doing = true
    grabbingScreenshots.index = 1
    grabbingScreenshots.name = name or ''
    grabbingScreenshots.resolutions = resolutions
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end
