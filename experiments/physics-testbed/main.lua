if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

if jit then
    jit.off()
end


function waitForEvent()
    local a, b, c, d, e
    repeat
        a, b, c, d, e = love.event.wait()
    until a == "focus" or a == 'mousepressed' or a == 'touchpressed'
end

waitForEvent()

package.path = package.path .. ";../../?.lua"
SM = require 'vendor.SceneMgr'

require 'lib.printC'

local inspect       = require 'vendor.inspect'
local cam           = require('lib.cameraBase').getInstance()
local camera        = require 'lib.camera'
local phys          = require 'lib.mainPhysics'
local ui            = require "lib.ui"
local animParticles = require 'frameAnimParticle'
local dj            = require 'organicMusic'


-- skygradient
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return { lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t) }
end

----- rest




function love.update(dt)
    SM.update(dt)
    dj.update()
    animParticles.updateAnimParticles(dt)
end

function love.draw()
    SM.draw()
end

function love.mousemoved(x, y, dx, dy)
    if followCamera == 'free' then
        if love.keyboard.isDown('space') or love.mouse.isDown(3) then
            local x, y = cam:getTranslation()
            cam:setTranslation(x - dx / cam.scale, y - dy / cam.scale)
        end
    end
end

function love.wheelmoved(dx, dy)
    if followCamera == 'free' then
        local newScale = cam.scale * (1 + dy / 10)
        if (newScale > 0.01 and newScale < 50) then
            cam:scaleToPoint(1 + dy / 10)
        end
    end
end

local function pointerReleased(x, y, id)
    phys.handlePointerReleased(x, y, id)
    ui.removeFromPressedPointers(id)
end

function love.mousereleased(x, y, button, istouch)
    lastDraggedElement = nil
    if not istouch then
        pointerReleased(x, y, 'mouse')
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    pointerReleased(x, y, id)
    --ui.removeFromPressedPointers(id)
end

function addScoreMessage(msg)
    print(msg)
end

function love.load()
    SM.setPath("scenes/")
    SM.load("splash")
end
