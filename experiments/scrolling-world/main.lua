--https://grafiek.royscholten.nl/project/50-vogels/
package.path = package.path .. ";../../?.lua"

--Camera = require 'vendor.brady'
inspect = require 'vendor.inspect'
tween = require 'vendor.tween'
ProFi = require 'vendor.ProFi'
Vector = require 'vendor.brinevector'
Concord = require 'vendor.concord.init'
SM = require 'vendor.SceneMgr'

require 'lib.basic-tools'
--require 'lib.polyline'
--require 'lib.generate-polygon'
require 'lib.ui'
require 'lib.camera'
--local cam = getCamera()
local cam = require('lib.cameraBase').getInstance()
require 'lib.generateWorld'



require 'src.groundplane'
--require 'src.fillstuf'
require 'src.removeAddItems'
require 'src.pointer-interactions'

require 'src.newton'
require 'src.actor'


random = love.math.random

local parse = require 'lib.parse-file'
local bbox = require 'lib.bbox'
local mesh = require 'lib.mesh'
local parentize = require 'lib.parentize'
local numbers = require 'lib.numbers'
local round2 = numbers.round2

--[[
   TODO:
   * the bbox functions have 2 ways of returning the data
   {tlx, tly, brx, bry} and {tl={x,y}, br={x,y}}
   make that just one way

   https://stackoverflow.com/questions/168891/is-it-faster-to-sort-a-list-after-inserting-items-or-adding-them-to-a-sorted-lis

]] --


-- utility functions that ought to be somewehre else

function pickRandom(array)
   --   plantUrls[math.ceil(random()* #plantUrls)]
   local index = math.ceil(random() * #array)
   --print(index, #array)
   return array[index]
end

function shuffleAndMultiply(items, mul)
   local result = {}
   for i = 1, (#items * mul) do
      table.insert(result, items[random() * #items])
   end
   return result
end

function love.keypressed(key)
   if key == 'escape' then love.event.quit() end
   if key == 'space' then cameraFollowPlayer = not cameraFollowPlayer end
   if (key == 'p') then
      if not profiling then
         ProFi:start()
      else
         ProFi:stop()
         ProFi:writeReport('profilingReport.txt')
      end
      profiling = not profiling
   end
end

--function sortOnDepth(list)
--   table.sort( list, function(a,b) return a.depth <  b.depth end)
--end



function drawDebugStrings()

   if uiState.showFPS then
      love.graphics.setFont(smallfont)
      shadedText('fps: ' .. love.timer.getFPS(), 20, 20)

      local delta = love.timer.getAverageDelta()
      shadedText(string.format("Avg. frame time: %.3f ms", 1000 * delta), 200, 20)
      love.graphics.setFont(font)

   end

   if uiState.showNumbers then
      shadedText('renderCount.optimized: ' .. renderCount.optimized, 20, 40)
      shadedText('renderCount.normal: ' .. renderCount.normal, 20, 70)
      shadedText('renderCount.groundMesh: ' .. renderCount.groundMesh, 20, 100)
      --shadedText('childCount: '..#middleLayer.children, 20, 130)

      if (tweenCameraDelta ~= 0 or followPlayerCameraDelta ~= 0) then
         shadedText('d1 ' .. round2(tweenCameraDelta, 2) .. ' d2 ' .. round2(followPlayerCameraDelta, 2), 20, 160)
      end
   end

   love.graphics.setColor(1, 1, 1, 1)
end

function drawUI()

   local W, H = love.graphics.getDimensions()

   if uiState.show then
      love.graphics.setFont(font)
      local toggleString = function(state, str)
         if state then return '(x) ' .. str else return '(o) ' .. str end
      end

      local runningY = 10

      local toggleButton = function(str, prop)
         local buttonMarginSide = 16
         str = toggleString(uiState[prop], str)
         local w = font:getWidth(str) + buttonMarginSide
         local h = font:getHeight(str)

         love.graphics.scale(1, 1)
         if labelbutton(str, str, 0, runningY, w, h, buttonMarginSide / 2).clicked then
            print(prop)
            uiState[prop] = not uiState[prop]
         end
         runningY = runningY + 35
      end

      toggleButton('show numbers', 'showNumbers')
      toggleButton('show FPS', 'showFPS')
      toggleButton('show walkbuttons', 'showWalkButtons')
      toggleButton('show bouncey', 'showBouncy')
      toggleButton('show bboxes', 'showBBoxes')
      toggleButton('show touches', 'showTouches')

      local sl = h_slider('gravity', 20, runningY, 300, uiState.gravityValue, -10000, 10000)
      if sl.value ~= nil then
         uiState.gravityValue = sl.value
      end
      shadedTextTransparent('gravity', 0.8, 20, runningY)
      shadedText(round2(uiState.gravityValue), 340, runningY)
   end


   if uiState.showWalkButtons then
      love.graphics.circle('fill', 50, (H / 2) - 25, 50)
      love.graphics.circle('fill', W - 50, (H / 2) - 25, 50)
   end

   love.graphics.circle('fill', W - 25, 25, 25)

end

function love.wheelmoved(dx, dy)
   cam:scaleToPoint(1 + dy / 10)
end

function love.resize(w, h)
   setCameraViewport(cam, 1000, 1000)

   cam:update(w, h)
end

function love.filedropped(file)

end

function love.load()
   -- Set path of your scene files
   renderCount = { normal = 0, optimized = 0, groundMesh = 0 }
   meshCache = {}

   --gestureState = {
   --   list = {},
   --   updateResolutionCounter = 0,
   --   updateResolution = 0.0167
   --}

   --translateScheduler = {
   --   x = 0,
   --   y = 0,
   --   justItem = { x = 0, y = 0 },
   --   happenedByPressedItems = false,
   --   cache = { value = 0, cacheValue = 0, stopped = true, stoppedAt = 0, tweenValue = 0 }
   --}

   tweenCameraDelta = 0
   followPlayerCameraDelta = 0

   font = love.graphics.newFont("assets/adlib.ttf", 32)
   smallfont = love.graphics.newFont("assets/adlib.ttf", 20)

   cursors = {
      --   hand= love.mouse.getSystemCursor("hand"),
      --   arrow= love.mouse.getSystemCursor("arrow")
   }


   love.graphics.setFont(font)


   uiState = {
      show = false,
      showFPS = true,
      showNumbers = true,
      showBBoxes = false,
      showBouncy = true,
      showTouches = false,
      gravityValue = 5000
   }
   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = { x = 0, y = 0 }
   }

   GLOBALS = {
      parallax = nil
   }

   SM.setPath("scenes/")

   -- Add scene "intro" to scene table
   SM.load("world")




end

function love.update(dt)
   -- Run your scene files update function
   updateGestureCounter(dt)


   SM.update(dt)
end

function love.draw()
   -- Run your scene files render function

   renderCount = { normal = 0, optimized = 0, groundMesh = 0 }

   handleMouseClickStart()

   SM.draw()
   local W, H = love.graphics.getDimensions()
   if uiState.showBouncy then
      local value = getTranslateSchedulerValues()
      love.graphics.line(W / 2, 100, W / 2 + value, 0)
      --if translateScheduler.cache.value ~= 0 then
      --  love.graphics.line(W / 2, 100, W / 2 + translateScheduler.cache.value, 0)
      --else
      --   love.graphics.line(W / 2, 100, W / 2 + translateScheduler.cache.tweenValue, 0)
      --end
   end
   if uiState.showTouches then
      local touches = love.touch.getTouches()
      for i, id in ipairs(touches) do
         local x, y = love.touch.getPosition(id)
         love.graphics.setColor(1, 1, 1, 1)
         love.graphics.circle("fill", x, y, 20)
         love.graphics.setColor(1, 0, 0)
         love.graphics.print(tostring(id), x, y)
      end
   end
   --   print(collectgarbage('count'))
end
