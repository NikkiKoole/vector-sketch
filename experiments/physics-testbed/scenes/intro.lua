local scene      = {}
local gradient   = require 'lib.gradient'
local fluxObject = { blobScale = 0, blobOffset = 0, headerOffset = 0, alpha1 = 0.1, alpha2 = .25 }
local Timer      = require 'vendor.timer'
local creamColor = { 238 / 255, 226 / 255, 188 / 255, 1 }
local addMipos   = require 'addMipos'
local isGoing    = false
local phys       = require 'lib.mainPhysics'
local dna = require 'lib.dna'
local swipes           = require 'lib.screen-transitions'

local inspect = require 'vendor.inspect'



function loadDNA5File()
    local contents, size = love.filesystem.read('assets/dna5.txt')
    --print('wants to load an earlier saved file')
    local parsed = (loadstring("return " .. contents)())

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

function gotoNext()
    if not isGoing then
        isGoing = true

        Timer.tween(.3, fluxObject, { alpha1 = 0, alpha2 = 0 }, 'out-bounce')
        Timer.after(.4,
            function()
                Timer.clear()

                if not mipos then
                    mipos = addMipos.make(1)
                end
                swipes.fadeOutTransition(.2 , function()
                SM.load("downhill") end )
            end)
    end
end

function scene.load()
    mipoGenetics = loadDNA5File()
    phys.setupWorld(500)
    stepSize = 300
end

function scene.update(dt)
    function love.keypressed(key, unicode)
        if key == 'm' then
            --   makeMarketingScreenshots('phys')
        end
        if key == 'escape' then love.event.quit() end


        if key == '1' or key == '2' or key == '3' or key == '4' or key == '5' then
            -- print('key', key)

            love.math.setRandomSeed((key + 0))
            --print(inspect(mipoGenetics[key+0].dna))
            mipos = addMipos.makeFromDNA(mipoGenetics[key+0].dna)
            gotoNext()
        else
            gotoNext()
        end
    end

    function love.touchpressed(key, unicode)
        gotoNext()
    end

    function love.mousepressed(key, unicode)
        gotoNext()
    end

    Timer.update(dt)
end

local dayTimeTransition = { t = 0 }

function scene.draw()
    love.graphics.setColor(1, 1, 1, 1)
    local skyGradient2 = gradient.lerpSkyGradient(10, 22, dayTimeTransition.t)
    love.graphics.draw(skyGradient2, 0, 0, 0, love.graphics.getDimensions())

    love.graphics.print('press 1 - 5 to pick a mipo')
    --love.graphics.clear(creamColor)
    if swipes.getTransition() then
        swipes.renderTransition(swipes.getTransition())
    end
end

return scene
