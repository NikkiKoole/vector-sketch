package.path = package.path .. ";../../?.lua"


local manual_gc = require 'vendor.batteries.manual_gc'

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

jit.off()
require 'lib.printC'

local text = require 'lib.text'

SM = require 'vendor.SceneMgr'
inspect = require 'vendor.inspect'

PROF_CAPTURE = true
prof = require 'vendor.jprof'
ProFi = require 'vendor.ProFi'

focussed = true

lurker = require 'vendor.lurker'
lurker.quiet = true
lurker.postswap = function(f)
    print("File " .. f .. " was swapped")
    focussed = true
end

local audioHelper = require 'lib.audio-helper'

audioHelper.startAudioThread()

creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }
blueColor = { 0x0a / 0xff, 0, 0x4b / 0xff, 1 }

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

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
end

function love.load()
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
    loadSong('assets/mipo4.melodypaint.txt')


    splashSound = love.audio.newSource("assets/sounds/music/mipolailoop.mp3", "static")
    introSound = love.audio.newSource("assets/sounds/music/introloop.mp3", "static")
    miSound2 = love.audio.newSource("assets/sounds/mi2.wav", "static")
    poSound2 = love.audio.newSource("assets/sounds/po2.wav", "static")
    miSound1 = love.audio.newSource("assets/sounds/mi.wav", "static")
    poSound1 = love.audio.newSource("assets/sounds/po.wav", "static")



    SM.setPath("scenes/")
    SM.load("splash")

    audioHelper.sendMessageToAudioThread({ type = "samples", data = samples });
    audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.pages[2] });
    audioHelper.sendMessageToAudioThread({ type = "paused", data = true });
    --love.window.updateMode(200, 200, { fullscreen = false })
end

function love.update(dt)
    prof.push('frame')
    --    lurker.update()

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

    if focussed and not grabbingScreenshots.doing then
        --   gesture.update(dt)
        SM.update(dt)
    else
        print('not updating the timer')
    end
    --collectgarbage()
    manual_gc(0.002, 2)
    prof.pop('frame')
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
    if grabbingScreenshots.doing then
        grabbingScreenshots.work()
    end

    prof.push('frame')
    SM.draw()
    prof.pop('frame')


    if grabbingScreenshots.doing then
        grabbingScreenshots.advance()
    end
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
