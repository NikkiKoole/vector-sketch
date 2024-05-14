package.path = package.path .. ";../../?.lua"
require 'lib.printC'
local inspect          = require 'vendor.inspect'
local cam              = require('lib.cameraBase').getInstance()
local camera           = require 'lib.camera'
local phys             = require 'lib.mainPhysics'
local box2dGuyCreation = require 'lib.box2dGuyCreation'
local texturedBox2d    = require 'lib.texturedBox2d'
local addMipos         = require 'addMipos'
local updatePart       = require 'lib.updatePart'
local gradient         = require 'lib.gradient'
local skygradient      = gradient.makeSkyGradient(10)

function love.load()
    phys.setupWorld(500)
    mipos = addMipos.make(1)
    local w, h = love.graphics.getDimensions()
    camera.setCameraViewport(cam, w, h)
    camera.centerCameraOnPosition(0, 0, 3000, 3000)
    local targetX, targetY = mipos[1].b2d.torso:getPosition()
    camera.centerCameraOnPosition(targetX, targetY, 3000, 3000)
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())


    local w, h = love.graphics.getDimensions()

    local camtlx, camtly = cam:getWorldCoordinates(0, 0)
    local cambrx, cambry = cam:getWorldCoordinates(w, h)

    cam:push()
    phys.drawWorld(world)
    for i = 1, #mipos do
        local bx = mipos[i].b2d.torso:getX()
        if (bx > camtlx - 1000 and bx < cambrx + 1000) then
            texturedBox2d.drawSkinOver(mipos[i].b2d, mipos[i])
            --texturedBox2d.drawNumbersOver(mipos[i].b2d)
        end
    end
    cam:pop()
end

function love.keypressed(k)
    if k == 'escape' then
        love.event.quit()
    end
end
