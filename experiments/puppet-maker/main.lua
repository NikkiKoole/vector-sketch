package.path = package.path .. ";../../?.lua"

local manual_gc = require 'vendor.batteries.manual_gc'

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
-- wooooohoooo
-- todo this takes out all the weird jumpiness of the GC !!!
--https://love2d.org/forums/viewtopic.php?t=91198
jit.off()
--jit.opt.start(3, '-loop', 'maxtrace=5000', 'hotloop=100')


-- cool webdeveloper doing lots of nice generative stuff
--https://codepen.io/georgedoescode/pens/popular?cursor=ZD0xJm89MCZwPTQ=

-- get inner rectangle from rotated outer rectangle
-- https://stackoverflow.com/questions/5789239/calculate-largest-inscribed-rectangle-in-a-rotated-rectangle


--https://nl.pinterest.com/pin/568086940505956798/

-- async image loading
--https://github.com/MikuAuahDark/lily


-- working ios payment stufff !!!!
-- https://love2d.org/forums/viewtopic.php?f=5&t=83107


SM = require 'vendor.SceneMgr'

require 'lib.printC'
gesture = require 'lib.gesture'
Concord = require 'vendor.concord.init'
myWorld = Concord.world()
inspect = require 'vendor.inspect'

PROF_CAPTURE = true
prof = require 'vendor.jprof'
ProFi = require 'vendor.ProFi'
local mesh = require "lib.mesh"
local text = require 'lib.text'
focussed = true


lurker = require 'vendor.lurker'
lurker.quiet = true
lurker.postswap = function(f)
    print("File " .. f .. " was swapped")
    focussed = true
end

creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }
blueColor = { 0x0a / 0xff, 0, 0x4b / 0xff, 1 }


local audioHelper = require 'lib.melody-paint-audio-helper'

audioHelper.startAudioThread()


function pickRandomFrom(array)
    local index = math.ceil(love.math.random() * #array)
    return array[index]
end

function findPart(name)
    for i = 1, #parts do
        --print(parts[i].name)
        if parts[i].name == name then
            return parts[i]
        end
    end
end

require 'src.generatePuppet'
local bodypartsGenerate = require 'src.puppetDNA'

if true then
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
        --print(a, b, c, d, e)
    until a == "focus" or a == 'mousepressed'
end
--local a, b, c, d, e
--repeat
--   a, b, c, d, e = love.event.wait()
--   print(a, b, c, d, e)
--until a == "keypressed"

--local camera = require 'lib.camera'
--local cam = require('lib.cameraBase').getInstance()



nullFolder = {
    folder = true,
    name = 'nullFolder',
    transforms = { l = { 0, 0, 0, 1, 1, 0, 0 } },
    children = {}
}
-- im sure it sometimes needs to just be the simplest ofunrenderables
nullChild = {
    name = 'nullChild',
    points = { { 0, 0 }, { 0, 0 }, { 0, 0 } }
}


function love.keypressed(key)
    if key == "escape" then love.event.quit() end
end

function love.load()
    --	1180 , 820
    -- iphone 1334, 750
    --love.mouse.setVisible(false)
    if false then
        --love.window.setMode(1024 / 2, 768 / 2,
        --    { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
        --love.window.setTitle('☺ Puppet Maker')

        local os = love.system.getOS()
        --print(os)
        if os == 'iOS' or os == 'Android' or ((os == 'OS X')) then
            love.window.setFullscreen(true)
        end
    end


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
        --table.insert(sprites, love.graphics.newImage('resources/' .. sample_data[i][1] .. '.png'))
        local data = love.sound.newSoundData('assets/instruments/' .. sample_data[i] .. '.wav')
        table.insert(samples, { s = love.audio.newSource(data, 'static'), p = sample_data[i] })
    end
    audioHelper.sendMessageToAudioThread({ type = "samples", data = samples });


    miSound2 = love.audio.newSource("assets/sounds/mi2.wav", "static")
    poSound2 = love.audio.newSource("assets/sounds/po2.wav", "static")
    miSound1 = love.audio.newSource("assets/sounds/mi.wav", "static")
    poSound1 = love.audio.newSource("assets/sounds/po.wav", "static")
    splashSound = love.audio.newSource("assets/sounds/music/mipolailoop.mp3", "static")
    introSound = love.audio.newSource("assets/sounds/music/introloop.mp3", "static")


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
        '020202', '333233', '814800', 'e6c800', 'efebd8',
        '808b1c', '1a5f8f', '66a5bc', '87727b', 'a23d7e',
        'f0644d', 'fa8a00', 'f8df00', 'ff7376', 'fef1d0',
        'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
        '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
        'CB433A', '8F4839', '8A934E', '69445D', 'EEC488',
        'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
        '798091', '4C5575', '6E4431', '626964', '613D41',
    }

    local base = {
        '020202',
        '4f3166', '6f323a', '872f44', 'efebd8', '8d184c', 'be193b', 'd2453a', 'd6642f', 'd98524',
        'dca941', 'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf', '9c9d9f',
        '938541', '86a542', '57843d', '45783c', '2a5b3e', '1b4141', '1e294b', '0d5f7f', '065966',
        '1b9079', '3ca37d', '49abac', '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3', '045b9f',
        '9377b2', '686094', '5f4769', '815562', '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34', 'a95c42', 'c37c61',
        'd19150', 'de9832', 'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
        '252f38', '42505f', '465059', '57595a', '6e7c8c', '75899c', 'aabdce', '807b7b',
        '857b7e', '8d7e8a', 'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267', 'd76656', 'b16890'

    }


    local base = {
        '020202',
        '4f3166', '69445D', '613D41', 'efebd8', '6f323a', '872f44', '8d184c', 'be193b', 'd2453a', 'd6642f', 'd98524',
        'dca941', 'e6c800', 'f8df00', 'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf', '9c9d9f',
        '938541', '808b1c', '8A934E', '86a542', '57843d', '45783c', '2a5b3e', '1b4141', '1e294b', '0d5f7f', '065966',
        '1b9079', '3ca37d', '49abac', '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3', '045b9f',
        '9377b2', '686094', '5f4769', '815562', '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34', 'CB433A', 'a95c42',
        'c37c61', 'd19150', 'de9832', 'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
        '252f38', '42505f', '465059', '57595a', '6e7c8c', '75899c', 'aabdce', '807b7b',
        '857b7e', '8d7e8a', 'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267', 'f0644d', 'ff7376', 'd76656', 'b16890',
        '020202', '333233', '814800', 'efebd8',
        '1a5f8f', '66a5bc', '87727b', 'a23d7e',
        'fa8a00', 'fef1d0',
        'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
        '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
        '8F4839', 'EEC488',
        'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
        '798091', '4C5575', '6E4431', '626964',

    }


    transition = nil

    for i = 1, #base do
        local r, g, b = hex2rgb(base[i])
        table.insert(palettes, { r, g, b })
    end

    fiveGuys = {} -- here we keep the 5 differnt guys around, I might as well just generate them here to begin with

    parts, urls = generateParts()
    for i = 1, #urls do
        -- mesh.getImage(urls[i])
    end
    print(inspect(urls))
    amountOfGuys = 5

    prof.push('frame')
    prof.push('creating-guys')
    if (PROF_CAPTURE) then ProFi:start() end


    -- todp move this to the DNA code I thinkk



    for i = 1, amountOfGuys do
        local values = generateValues()

        values = partRandomize(values, false)


        local teethIsempty = (values.teeth.shape == #findPart('teeth').imgs)
        fiveGuys[i] = {
            values = copy3(values),
            head = copyAndRedoGraphic('head', values),
            neck = createNeckRubberhose(values),
            body = copyAndRedoGraphic('body', values),
            hair = createHairVanillaLine(values),
            arm1 = createArmRubberhose(1, values),
            arm2 = createArmRubberhose(2, values),
            armhair1 = createArmHairRubberhose(1, values),
            armhair2 = createArmHairRubberhose(2, values),
            hand1 = copyAndRedoGraphic('hands', values),
            hand2 = copyAndRedoGraphic('hands', values),
            leg1 = createLegRubberhose(1, values),
            leg2 = createLegRubberhose(2, values),
            leghair1 = createLegHairRubberhose(1, values),
            leghair2 = createLegHairRubberhose(2, values),
            feet1 = copyAndRedoGraphic('feet', values),
            feet2 = copyAndRedoGraphic('feet', values),
            eye1 = copyAndRedoGraphic('eyes', values),
            eye2 = copyAndRedoGraphic('eyes', values),
            pupil1 = copyAndRedoGraphic('pupils', values),
            pupil2 = copyAndRedoGraphic('pupils', values),
            brow1 = createBrowBezier(values),
            brow2 = createBrowBezier(values),
            mouth = makeMouthParentThing(),
            teeth = teethIsempty and copy3(nullFolder) or copyAndRedoGraphic('teeth', values),
            upperlip = createUpperlipBezier(values),
            lowerlip = createLowerlipBezier(values),
            ear1 = copyAndRedoGraphic('ears', values),
            ear2 = copyAndRedoGraphic('ears', values),
            nose = copyAndRedoGraphic('nose', values),
        }

        -- maybe we can do a cleanuop phase for the leg and arm hair here.


        local guy = {
            folder = true,
            name = 'guy',
            transforms = { l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 } },
            children = {}
        }


        fiveGuys[i].guy = guy



        fiveGuys[i].body.transforms.l[2] = -700
        guy.children = guyChildren(fiveGuys[i])
    end
    if (PROF_CAPTURE) then
        ProFi:stop()
        ProFi:writeReport('profilingReportInit.txt')
    end


    prof.pop('creating-guys')
    prof.pop('frame')



    editingGuy = fiveGuys[1]
    loadSong('assets/mipo4.melodypaint.txt')
    SM.setPath("scenes/")
    SM.load("splash")
    print(love.graphics.getStats().texturememory / (1024 * 1024) ..
    ' MB of texture memory, for ' .. #fiveGuys .. ' guys.')
    print(love.filesystem.getIdentity())

    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });
    audioHelper.sendMessageToAudioThread({ type = "paused", data = true });
    love.event.wait()
    love.event.wait()

    -- local success = love.window.updateMode(1024, 768, { fullscreen = false }) --,
    --  { resizable = true, vsync = true, minwidth = 400, minheight = 300, msaa = 2, highdpi = true })
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

function partRandomize(values, applyChangeDirectly)
    -- print('doing a randomizer!')
    local parts = { 'head', 'ears', 'eyes', 'pupils', 'neck', 'nose', 'body', 'arms', 'hands', 'feet', 'legs', 'hair',
        'leghair', 'armhair',
        'brows', 'upperlip', 'lowerlip', 'skinPatchSnout', 'skinPatchEye1', 'skinPatchEye2', 'teeth' }


    values.overBite = love.math.random() < .5 and true or false

    values.legLength = math.ceil(love.math.random() * 7)
    values.armLength = math.ceil(love.math.random() * 7)
    values.legDefaultStance = 0.5 --0.25 +
    --math.floor(love.math.random() * 4) * 0.25 --0.25--  0--0.75 + (love.math.random() / 4.0)

    for i = 1, #parts do
        if values.potatoHead and parts[i] == 'neck' then

        else
            local p = findPart(parts[i])
            values[parts[i]].shape = math.ceil(love.math.random() * #(p.imgs))
            if (parts[i] == 'leghair' or parts[i] == 'armhair' or parts[i] == 'hair') then
                --   values[parts[i]].shape = #p.imgs
            end
            if (parts[i] == 'teeth') then
                --   values[parts[i]].shape = #p.imgs
            end
            values[parts[i]].fgPal = math.ceil(love.math.random() * #palettes)
            values[parts[i]].bgPal = math.ceil(love.math.random() * #palettes)
            --values[parts[i]].linePal = 13 --math.ceil(love.math.random() * #palettes)
            values[parts[i]].texScale = math.ceil(love.math.random() * 9)
            if (parts[i] == 'head' or parts[i] == 'body') then
                values[parts[i]].flipx = love.math.random() < .5 and -1 or 1
                values[parts[i]].flipy = love.math.random() < .5 and -1 or 1
            end
            if (parts[i] == 'nose') then
                --values[parts[i]].shape = #(p.imgs)
            end
            if (parts[i] == 'eyes') then
                values[parts[i]].fgPal = 5
                values[parts[i]].fgTex = 1
            end
            if (parts[i] == 'pupils') then
                values[parts[i]].fgPal = 5
                values[parts[i]].fgTex = 1
            end
            if (parts[i] == 'teeth') then
                values[parts[i]].fgPal = 5
                values[parts[i]].bgPal = 5
            end

            if (parts[i] == 'skinPatchEye1') then
                values.skinPatchEye1PV.tx = -2
                values.skinPatchEye1PV.ty = -3
            end
            if (parts[i] == 'skinPatchEye2') then
                values.skinPatchEye2PV.tx = 2
                values.skinPatchEye2PV.ty = -3
            end
            if (parts[i] == 'skinPatchEye2') then
            end

            if applyChangeDirectly then
                changePart(parts[i])
            end
        end
    end
    return values
end

function love.focus(f)
    focussed = f
end

function love.mousefocus(f)
    if f == true then
        focussed = f
    end
end

function love.update(dt)
    prof.push('frame')

    lurker.update()
    --require("vendor.lurker").update()
    if not focussed then
        -- print('this app is unfocessed!')
    end
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

    if focussed and not makingMarketingScreens then
        gesture.update(dt)
        SM.update(dt)
    end
    --collectgarbage()
    manual_gc(0.002, 2)
    prof.pop('frame')
end

makingMarketingScreens = false
makingMarketingScreensIndex = 0
makingMarketingScreensName = ''

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



function love.draw()
    if makingMarketingScreens then
        local w = resolutions[makingMarketingScreensIndex][1]
        local h = resolutions[makingMarketingScreensIndex][2]
        local type = resolutions[makingMarketingScreensIndex][3]
        print('making marketing screenhsot', makingMarketingScreensIndex, w, h)
        local success = love.window.updateMode(w / 2, h / 2, { fullscreen = false })
        love.resize(w, h)
        love.graphics.captureScreenshot('puppetmaker-marketing-' ..
            makingMarketingScreensName .. '-' .. type .. '-' .. os.date("%Y%m%d%H%M%S") .. '.png')
    end

    prof.push('frame')
    SM.draw()
    prof.pop('frame')

    if makingMarketingScreensIndex < #resolutions then
        makingMarketingScreensIndex = makingMarketingScreensIndex + 1
    else
        makingMarketingScreens = false
    end
end

--function love.resize(w, h)
--camera.setCameraViewport(cam, 1000, 1000)
--cam:update(w, h)
--end

function love.quit()
    -- this takes annoyingly long
    time = love.timer.getTime()
    prof.write("prof.mpack")
    print('writing took', love.timer.getTime() - time, 'seconds')
end

--function love.mousepressed(x, y, button, istouch, presses)
--print('mousepressed', button)
--if not istouch then
--   pointerPressed(x, y, 'mouse')
--end
--end

function love.lowmemory()
    print('LOW MEMORY!!!')
end

function makeMarketingScreenshots(name)
    makingMarketingScreens = true
    makingMarketingScreensIndex = 1
    makingMarketingScreensName = name or ''


    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end
