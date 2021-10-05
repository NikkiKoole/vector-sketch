package.path = package.path .. ";../../?.lua"

local Camera = require 'custom-vendor.brady'
local inspect = require 'vendor.inspect'
local ProFi = require 'vendor.ProFi'
local Vector = require 'vendor.brinevector'
local tween = require 'vendor.tween'

require 'lib.basic-tools'
require 'lib.basics'
require 'lib.poly'
require 'lib.toolbox'
require 'lib.main-utils'
require 'lib.bbox'
require 'lib.polyline'
require 'lib.border-mesh'
require 'lib.generate-polygon'
require 'lib.ui'

require 'generateWorld'
require 'gradient'
require 'groundplane'
require 'fillstuf'
require 'removeAddItems'
require 'pointer-interactions'

random = love.math.random

--[[
TODO:

* the bbox functions have 2 ways of returning the data
{tlx, tly, brx, bry} and {tl={x,y}, br={x,y}}
make that just one way

* I'd like to be able to have negative masses (balloons) and tiny and large
masses, my calculations break down currently
maybe also have a few differnt looking objects for that use case

]]--


function applyForce(motionObject, force)
   local f = force / motionObject.mass
   if motionObject.mass < 1 then
      f = f * motionObject.mass
   end

   motionObject.acceleration =  motionObject.acceleration + f
end

function makeMotionObject()
   return {
      velocity = Vector(0,0),
      acceleration = Vector(0,0),
      mass = 1
   }
end


-- utility functions that ought to be somewehre else


function shuffleAndMultiply(items, mul)
   local result = {}
   for i = 1, (#items * mul) do
      table.insert(result, items[random()*#items])
   end
   return result
end

function copy3(obj, seen)
   -- Handle non-tables and previously-seen tables.
   if type(obj) ~= 'table' then return obj end
   if seen and seen[obj] then return seen[obj] end

   -- New table; mark it as seen and copy recursively.
   local s = seen or {}
   local res = {}
   s[obj] = res
   for k, v in pairs(obj) do res[copy3(k, s)] = copy3(v, s) end
   return setmetatable(res, getmetatable(obj))
end

function readFileAndAddToCache(url)
   if not meshCache[url] then
      local g2 = parseFile(url)[1]
      assert(g2)
      meshAll(g2)
      --print(inspect(g2))
      makeOptimizedBatchMesh(g2)
      --print(inspect(g2))

      local bbox = getBBoxOfChildren(g2.children)
      g2.bbox = {bbox.tl.x, bbox.tl.y, bbox.br.x, bbox.br.y}
      meshCache[url] = g2
   end

   return meshCache[url]
end


function recursivelyAddOptimizedMesh(root)
   if root.folder then
      if root.url then
	root.optimizedBatchMesh = meshCache[root.url].optimizedBatchMesh
      end
   end

   if root.children then
      for i=1, #root.children do
         if root.children[i].folder then
            recursivelyAddOptimizedMesh(root.children[i])
         end
      end
   end
end

-- end utility functions


function love.keypressed( key )
   if key == 'escape' then love.event.quit() end
   if key == 'space' then cameraFollowPlayer = not cameraFollowPlayer end
   if (key == 'p') then
      if not profiling then
	 ProFi:start()
      else
	 ProFi:stop()
	 ProFi:writeReport( 'profilingReport.txt' )
      end
      profiling = not profiling
   end
end

local function resizeCamera( self, w, h )
   local scaleW, scaleH = w / self.w, h / self.h
   local scale = math.min( scaleW, scaleH )
   -- the line below keeps aspect
   --self.w, self.h = scale * self.w, scale * self.h
   -- the line below deosnt keep aspect
   self.w, self.h = scaleW * self.w, scaleH * self.h
   self.aspectRatio = self.w / w
   self.offsetX, self.offsetY = self.w / 2, self.h / 2
   offset = offset * scale
end

local function drawCameraBounds( cam, mode )
   love.graphics.rectangle( mode, cam.x, cam.y, cam.w, cam.h )
end

function generateCameraLayer(name, zoom)
   return cam:addLayer(name, zoom, {relativeScale=(1.0/zoom) * zoom})
end

function sortOnDepth(list)
   table.sort( list, function(a,b) return a.depth <  b.depth end)
end



function love.load()
   local loadStart = love.timer.getTime()
   --ProFi:start()

   local W, H = love.graphics.getDimensions()
   offset = 20
   counter = 0
   cameraFollowPlayer = false
   stuff = {} -- this is the testlayer with just some rectangles and the red player

   meshCache = {}

   depthMinMax = {min=-1, max=1}
   depthScaleFactors = { min=.8, max=1}

   carThickness = 12.5
   testCar = false
   testCameraViewpointRects = false
   renderCount = {normal=0, optimized=0, groundMesh=0}

   moving = nil

   local timeIndex = 18
   skygradient = gradientMesh("vertical", gradients[timeIndex].from, gradients[timeIndex].to)

   tileSize = 100

   cam = Camera(
      W - 2 * offset,
      H - 2 * offset,
      {
         x = offset, y = offset, resizable = true, maintainAspectRatio = true,
         resizingFunction = function( self, w, h )
            resizeCamera( self, w, h )
            local W, H = love.graphics.getDimensions()
            self.x = offset
            self.y = offset
         end,
         getContainerDimensions = function()
            local W, H = love.graphics.getDimensions()
            return W - 2 * offset, H - 2 * offset
         end
      }
   )
   lastCameraBounds = {math.huge, -math.huge}   -- this one is unrounded start and end positions

   
   --lastGroundBounds = {math.huge, -math.huge}  -- this one is just talking about indices
   layerBounds = {
      hack = {math.huge, -math.huge},
      farther = {math.huge, -math.huge}

   }
   hack = generateCameraLayer('hack', 1)
   hackFar = generateCameraLayer('hackFar', depthScaleFactors.min)
   hackClose = generateCameraLayer('hackClose', depthScaleFactors.max)
   farther = generateCameraLayer('farther', .7)
   close = generateCameraLayer('close', 1.5)


--   	return camera.projection_matrix * camera.view_matrix * model.matrix * TransformMatrix  * initial_vertex_position ;

   betterShader = love.graphics.newShader( [[
         extern mat4 view;
         extern mat4 m2;
         vec4 position(mat4 m, vec4 p) {
             return view  * TransformMatrix * m2 *  p;
         }
   ]])


   createStuff()
   
   parentize(middleLayer)
   renderThings(middleLayer)
   recursivelyAddOptimizedMesh(middleLayer)
   sortOnDepth(middleLayer.children)


   parentize(fartherLayer)
   renderThings(fartherLayer)
   recursivelyAddOptimizedMesh(fartherLayer)
   sortOnDepth(fartherLayer.children)

   
   cam:setTranslation(
      newPlayer.transforms.l[1] ,
      -H/2 + offset
   )

   gestureList = {}


   cameraTween = nil

   tweenCameraDelta = 0
   followPlayerCameraDelta = 0



   lastDT = 0

   font = love.graphics.newFont( "assets/adlib.ttf", 32)
   smallfont = love.graphics.newFont( "assets/adlib.ttf", 20)

   love.graphics.setFont(font)




   gestureUpdateResolutionCounter = 0
   gestureUpdateResolution = 0.0167  -- aka 60 fps

   translateScheduler = {x=0,y=0}
   translateSchedulerJustItem = {x=0,y=0}
   translateHappenedByPressedItems = false

   translateCache = {value=0, cacheValue=0, stopped=true, stoppedAt=0, tweenValue=0}

   bouncetween = nil

   showNumbersOnScreen = false
   --ui = {show=false}
   uiState = {
      show= false,
      showFPS=false,
      showNumbers=false,
      gravityValue= 5000
   }

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }

   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   }

   activeButton = nil

end


function love.update(dt)
   lastDT = dt
   local W, H = love.graphics.getDimensions()

   if bouncetween then
      bouncetween:update(dt)
   end

   local v = {x=0, y=0}

   if love.keyboard.isDown('left') or moving == 'left' then
      v.x = v.x - 1
   end
   if love.keyboard.isDown('right') or moving == 'right' then
      v.x = v.x + 1
   end
   if love.keyboard.isDown('up') then
      v.y = v.y - 1
   end
   if love.keyboard.isDown('down') then
      v.y = v.y + 1
   end

   local mag = math.sqrt((v.x * v.x) + (v.y * v.y))
   if mag > 0 then
      v.x = (v.x/mag) * player.speed * dt
      v.y = (v.y/mag) * player.speed * dt
      player.x = player.x + v.x
      player.depth = player.depth + (v.y)/100
      newPlayer.transforms.l[1] = newPlayer.transforms.l[1] + v.x
      newPlayer.depth =player.depth

      if testCar then
         -- doing the depth
         local otherScale = mapInto(carbody.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
         carbody.depth = player.depth
         carbodyVoor.depth = player.depth + carThickness * otherScale
         voor2.transforms.l[1] =  newPlayer.transforms.l[1]
         voor2.depth = player.depth + carThickness * otherScale -- to get a perspective going
         local dir = v.x > 0 and 1 or -1

         -- rotating the wheels
         newPlayer.children[1].children[2].transforms.l[3] =  newPlayer.children[1].children[2].transforms.l[3] +  10 * dt * dir
         newPlayer.children[1].children[3].transforms.l[3] =  newPlayer.children[1].children[3].transforms.l[3] +  10 * dt * dir
      end

   end

   if not cameraFollowPlayer then
      if cameraTween then

	 local delta = cam:setTranslationSmooth(
	    cameraTween.goalX,
	    cameraTween.goalY,
	    dt,
	    cameraTween.smoothValue
	 )
         if delta.x ~= 0 then
            cameraTranslateScheduleJustItem(delta.x * cameraTween.smoothValue * dt, 0)
         end

	 if (delta.x + delta.y) == 0 then
            for i = #gestureList, 1 -1 do
               if cameraTween.originalGesture == gestureList[i] then
		  if gestureList[i] ~= nil then
		     removeGestureFromList(gestureList[i])
		  end
               end
            end

	    cameraTween = nil

	 end
	 tweenCameraDelta = (delta.x + delta.y)
      end
   end

   if cameraFollowPlayer then
      local delta = cam:setTranslationSmooth(
            player.x + player.width/2 ,
            player.y - 350,
            dt,
            10
                                   )
      followPlayerCameraDelta = delta.x + delta.y
   end


   cam:update()

   updateGestureCounter(dt)

   for i =1, #gestureList do
      if gestureList[i] == nil then
         print('gesture is nil!', i)
      end
   end

   for i=1, #middleLayer.children do
      local thing = middleLayer.children[i]
      if thing.inMotion and not thing.pressed then

         --local gy = (6*980)
	 local gy = uiState.gravityValue * thing.inMotion.mass * dt
	 local gravity = Vector(0, gy);

	 applyForce(thing.inMotion, gravity)

         -- applying half the velocity before position
         -- other half after positioning
         --https://web.archive.org/web/20150322180858/http://www.niksula.hut.fi/~hkankaan/Homepages/gravity.html

	 thing.inMotion.velocity = thing.inMotion.velocity + thing.inMotion.acceleration/2

	 thing.transforms.l[1] = thing.transforms.l[1] + (thing.inMotion.velocity.x * dt)
	 thing.transforms.l[2] = thing.transforms.l[2] + (thing.inMotion.velocity.y * dt)



	 thing.inMotion.velocity = thing.inMotion.velocity + thing.inMotion.acceleration/2
	 thing.inMotion.acceleration = thing.inMotion.acceleration * 0;

	 if thing.transforms.l[2] >= 0 then
	    thing.transforms.l[2] = 0
	    thing.inMotion = nil
	 end
      end
   end

   cameraApplyTranslate()

end


function cameraTranslateScheduleJustItem(dx,dy)
   -- this comes from just the cameraTween
   translateSchedulerJustItem.x = dx
   translateSchedulerJustItem.y = dy

end


function cameraTranslateScheduler(dx, dy)
--   print(dx, 'try to average instead of adding')
   translateScheduler.x = translateScheduler.x + dx
   translateScheduler.y = translateScheduler.y + dy
end



function checkForBounceBack()
   -- this thing is meant for the elastic bounce back of items
   -- i dont really understand what this does anymore
   -- ah right, its the elements that will bounce in opposite direction of a camera tween
   -- just the little line right now that displays that
   if translateScheduler.x ~= 0 then
      translateCache.triggered= false
      translateCache.stopped = false
      translateCache.value = translateCache.value + translateScheduler.x
      translateCache.cacheValue = translateCache.value
   else
      if translateCache.stopped == false then
	 translateCache.stopped = true
	 translateCache.stoppedAt = translateCache.value
      end
      local multiplier = (0.5 ^ (lastDT*300))
      translateCache.cacheValue = translateCache.cacheValue * multiplier

      -- https://love2d.org/forums/viewtopic.php?f=3&t=82046&start=10
      if math.abs(translateCache.cacheValue) < 0.01 and translateCache.triggered == false then
	 translateCache.cacheValue = 0
	 translateCache.value = 0

	 translateCache.triggered= true
	 translateCache.tweenValue = translateCache.stoppedAt
	 bouncetween = tween.new(1, translateCache, {tweenValue=0}, 'outElastic')
      end
   end
end


function cameraApplyTranslate()

   cam:translate( translateScheduler.x, translateScheduler.y)
   local translateByPressed = false

   if true then

      for i =1 ,#middleLayer.children do
	 local c = middleLayer.children[i]
	 if c.pressed then
	    c.transforms.l[1] =
	       c.transforms.l[1] + translateScheduler.x + translateSchedulerJustItem.x
	    translateByPressed = (translateScheduler.x + translateSchedulerJustItem.x) ~= 0
	 end
      end


      --- this part is here for triggering a tween on ending item pressed drag
      if translateByPressed == true then
	 translateHappenedByPressedItems = true
      end
      if translateHappenedByPressedItems == true and  translateByPressed == false then
	 translateHappenedByPressedItems = false
	 local cx,cy = cam:getTranslation()
	 local delta = (translateScheduler.x + translateSchedulerJustItem.x) * 10
	 cameraTween = {goalX=cx + delta, goalY=cy, smoothValue=5}
      end
      ------ end that part

      checkForBounceBack()

      translateScheduler.x = 0
      translateScheduler.y = 0
      translateSchedulerJustItem.x = 0
      translateSchedulerJustItem.y = 0
   end
end

function resetCameraTween()
   if cameraTween then
      cameraTween = nil
      tweenCameraDelta = 0
   end
end


function love.mousepressed(x,y, button, istouch, presses)

   if (mouseState.hoveredSomething) then return end

   if not istouch then
      pointerPressed(x,y, 'mouse')
   end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
   pointerPressed(x,y, id)
end


function love.mousemoved(x, y,dx,dy, istouch)
   if not istouch then
      pointerMoved(x,y,dx,dy, 'mouse')
   end
end

function love.touchmoved(id, x,y, dx, dy, pressure)
   pointerMoved(x,y,dx,dy, id)
end


function love.mousereleased(x,y, button, istouch)
   lastDraggedElement = nil --{id=id}

   if not istouch then
      pointerReleased(x,y, 'mouse')
   end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
   pointerReleased(x,y, id)
end


--https://stackoverflow.com/questions/47856682/how-to-get-the-delta-of-swipe-draging-touch

function gestureRecognizer(gesture)
   if #gesture.positions > 1 then
      local startP = gesture.positions[1]
      local endP = gesture.positions[#gesture.positions]
      local gestureLength = 3
      if (#gesture.positions > gestureLength) then
	 startP = gesture.positions[#gesture.positions - gestureLength]
      end
      local dx = endP.x - startP.x
      local dy = endP.y - startP.y
      local distance = math.sqrt(dx*dx+dy*dy)

      local deltaTime = endP.time - startP.time
      local speed = distance / deltaTime

      if gesture.target == 'stage' then
	 local minSpeed = 200
	 local maxSpeed = 15000
	 local minDistance = 6
	 local minDuration = 0.005

	 if distance > minDistance then
	    if deltaTime > minDuration then
	       if speed >= minSpeed and speed < maxSpeed then
		  local cx,cy = cam:getTranslation()
		  local m = dx < 0 and -1 or 1

		  cameraTween = {goalX=cx-((dx) + (m* speed/7.5) ), goalY=cy, smoothValue=3.5, originalGesture=gesture}
	       else
		  --print('failed at speed', minSpeed, speed, maxSpeed)
	       end
	    else
	       --print('failed at duration', deltaTime, minDuration)
	    end
	 else
	    --print('failed at distance')
	 end
      else -- this is gesture target something else items basically!

	 if distance < 0.00001 then
	    distance = 0.00001
	 end
	 local  dxn = dx / distance
	 local  dyn = dy / distance

	 gesture.target.inMotion = makeMotionObject()
         local mass = gesture.target.inMotion.mass

	 local throwStrength = 1
         if mass < 0 then throwStrength = throwStrength / 100 end

         local impulse = Vector(dxn * speed * throwStrength ,
                                dyn * speed * throwStrength )

         --print('impulse', impulse)
	 applyForce(gesture.target.inMotion, impulse)
      end
   end
end

function getScreenBBoxForItem(c, hack)

   local tx, ty = c._globalTransform:transformPoint(c.bbox[1],c.bbox[2])
   local tlx, tly = cam:getScreenCoordinates(tx, ty, hack)
   local bx, by = c._globalTransform:transformPoint(c.bbox[3],c.bbox[4])
   local brx, bry = cam:getScreenCoordinates(bx, by, hack)
   return tlx, tly, brx, bry
end

function mouseIsOverItemBBox(mx, my, item)
   local hack =  {}
   hack.scale = mapInto(item.depth, depthMinMax.min, depthMinMax.max,
                        depthScaleFactors.min, depthScaleFactors.max)
   hack.relativeScale = (1.0/ hack.scale) * hack.scale
   local tlx, tly, brx, bry = getScreenBBoxForItem(item, hack)

   local wx, wy = cam:getWorldCoordinates(mx, my, hack)
   local invx, invy = item._globalTransform:inverseTransformPoint(wx, wy)


   return pointInRect(mx, my, tlx, tly, brx-tlx, bry-tly), invx, invy, tlx, tly, brx, bry
end

function mouseIsOverObjectInCamLayer(mx, my, item)
   local hack =  {}
   hack.scale = mapInto(item.depth, depthMinMax.min, depthMinMax.max,
                        depthScaleFactors.min, depthScaleFactors.max)
   hack.relativeScale = (1.0/ hack.scale) * hack.scale
   local mx2, my2 = cam:getWorldCoordinates(mx, my, hack)
   return  recursiveHitCheck(mx2, my2, item)
end



function drawCameraViewPointRectangles(cameraPoint)
   for _, v in pairs(cameraPoint) do
      love.graphics.setColor(1,0,1,.5)
      if v.selected then
         love.graphics.setColor(1,0,0,.6)
      end

      love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
   end
end

function drawCameraCross(W,H)
   love.graphics.setColor(1,1,1,.2)
   love.graphics.line(0,0,W,H)
   love.graphics.line(0,H,W,0)
end

function drawDebugStrings()

   --   love.graphics.scale(2,2)

   if uiState.showFPS then
      love.graphics.setFont(smallfont)
      love.graphics.setColor(0,0,0,.2)
      love.graphics.print('fps: '..love.timer.getFPS(), 20, 20)
      love.graphics.setColor(1,1,1,.8)
      love.graphics.print('fps: '..love.timer.getFPS(),21,21)
      love.graphics.setFont(font)
   end



   if uiState.showNumbers then
      love.graphics.setColor(0,0,0,.2)
      love.graphics.print('renderCount.optimized: '..renderCount.optimized, 20, 40)
      love.graphics.print('renderCount.normal: '..renderCount.normal, 20, 70)
      love.graphics.print('renderCount.groundMesh: '..renderCount.groundMesh, 20, 100)
      love.graphics.print('childCount: '..#middleLayer.children, 20, 130)
      if (tweenCameraDelta ~= 0 or followPlayerCameraDelta ~= 0) then
	 love.graphics.print('d1 '..round2(tweenCameraDelta, 2)..' d2 '..round2(followPlayerCameraDelta,2), 20, 160)
      end

      love.graphics.setColor(1,1,1,.8)

      love.graphics.print('renderCount.optimized: '..renderCount.optimized, 21, 41)
      love.graphics.print('renderCount.normal: '..renderCount.normal, 21, 71)
      love.graphics.print('renderCount.groundMesh: '..renderCount.groundMesh, 21, 101)
      love.graphics.print('childCount: '..#middleLayer.children, 21, 131)
      if (tweenCameraDelta ~= 0 or followPlayerCameraDelta ~= 0) then
	 love.graphics.print('d1 '..round2(tweenCameraDelta, 2)..' d2 '..round2(followPlayerCameraDelta,2), 21, 161)

      end

   end

   love.graphics.setColor(1,1,1,1)
--   love.graphics.scale(1,1)
end

function drawUI()

   local W, H = love.graphics.getDimensions()

   if false and ui.show then
      love.graphics.setColor(1,1,1, 0.3)
      love.graphics.rectangle('fill', 0,0, W, 50)

      love.graphics.setColor(0,0,0,.2)
      love.graphics.setFont(smallfont)
      love.graphics.print('tweaks', 120, 20)
      love.graphics.setFont(font)

      love.graphics.setColor(1,1,1, 0.3)

   end

   if uiState.show then
      love.graphics.setFont(font)
      local toggleString = function(state, str)
	 if state then
	    return '(x) '..str
	 else
	    return '(o) '..str
	 end
      end
      local buttonMarginSide = 16
      local str = "show numbers"
      str = toggleString(uiState.showNumbers, str)
      local w = font:getWidth(str)+buttonMarginSide
      local h = font:getHeight(str)

      love.graphics.scale(1,1)
      if labelbutton(str, str, 0, 10, w , h, buttonMarginSide/2).clicked then
	 uiState.showNumbers = not uiState.showNumbers
      end

      str = "show FPS"
      str = toggleString(uiState.showFPS, str)
      w = font:getWidth(str)+buttonMarginSide
      h = font:getHeight(str)

      love.graphics.scale(1,1)
      if labelbutton(str, str, 0, 45, w , h, buttonMarginSide/2).clicked then
	 uiState.showFPS = not uiState.showFPS
      end


      str = "show walkbuttons"
      str = toggleString(uiState.showWalkButtons, str)
      w = font:getWidth(str)+buttonMarginSide
      h = font:getHeight(str)

      love.graphics.scale(1,1)
      if labelbutton(str, str, 0, 80, w , h, buttonMarginSide/2).clicked then
	 uiState.showWalkButtons = not uiState.showWalkButtons
      end

      str = "show bouncey"
      str = toggleString(uiState.showBouncy, str)
      w = font:getWidth(str)+buttonMarginSide
      h = font:getHeight(str)

      love.graphics.scale(1,1)
      if labelbutton(str, str, 0, 115, w , h, buttonMarginSide/2).clicked then
	 uiState.showBouncy = not uiState.showBouncy
      end



      local sl =  h_slider('gravronics', 20, 200, 300, uiState.gravityValue, -10000, 10000)
      if sl.value ~= nil then
	 uiState.gravityValue = sl.value
      end
      shadedText(round2(uiState.gravityValue), 340, 200)
   end


   if false then
   love.graphics.setColor(1,1,1)
   love.graphics.circle('fill', W-25, 25, 25)
   end

   if uiState.showWalkButtons then
      love.graphics.circle('fill', 50, (H/2)-25, 50)
      love.graphics.circle('fill', W-50, (H/2)-25, 50)

   end


   love.graphics.circle('fill', W-25, 25, 25)
end


function love.draw()
   handleMouseClickStart()
   renderCount = {normal=0, optimized=0, groundMesh=0}

   counter = counter +1
   local W, H = love.graphics.getDimensions()
   love.graphics.clear(.6, .3, .7)
   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   if (true) then
      farther:push()
      -- love.graphics.setColor( 1, 0, 0, .25 )
      -- tlx, tly = cam:getWorldCoordinates(cam.x - cam.w, cam.y - cam.h, 'farther')
      -- brx, bry = cam:getWorldCoordinates(cam.x + cam.w*2, cam.y + cam.h*2, 'farther')

      --for _, v in pairs(stuff) do
      --    if v.x >= tlx and v.x <= brx and v.y >= tly and v.y <= bry then
      --       love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
      --       love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
      --    end
      ---end
      --renderThings(root)
      renderThings(fartherLayer)

      farther:pop()
   end

   drawGroundPlaneLines()
   love.graphics.setLineWidth(1)

   if (false) then
      sortOnDepth(stuff)
      for _, v in pairs(stuff) do

         hack.scale = mapInto(v.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
         hack.relativeScale = (1.0/ hack.scale) * hack.scale
         hack.push()

         love.graphics.setColor(v.color)
         love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
         love.graphics.setColor(.1, .1, .1)
         love.graphics.rectangle('line', v.x, v.y, v.width, v.height)

         hack:pop()
      end
   end

   cam:push()

   --https://stackoverflow.com/questions/168891/is-it-faster-to-sort-a-list-after-inserting-items-or-adding-them-to-a-sorted-lis
   -- spoiler use a heap
   --sortOnDepth(root.children)
   -- rendering needs some sort of culling
   -- i'd say a bbox per folder
   --love.graphics.push()
   --love.graphics.translate(0,-100)

   --local offset = H - 768
   --root.transforms.l[2] = offset/2.225

   renderThings(middleLayer)
   --love.graphics.pop()

   if testCameraViewpointRects then
      drawCameraViewPointRectangles(cameraPoint)
   end

   if (false) then
      close:push()
      love.graphics.setColor( 1, 0, 0, .25 )
      for _, v in pairs(stuff) do
         love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
         love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
         love.graphics.setColor(.1, .1, .1)
         love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
      end
      renderThings(middleLayer)
      close:pop()
   end

   cam:pop()


   handlePressedItemsOnStage(W, H)

   love.graphics.setColor(1,1,1,1)

   local touches = love.touch.getTouches()

    for i, id in ipairs(touches) do
       local x, y = love.touch.getPosition(id)
       love.graphics.setColor(1,1,1,1)

        love.graphics.circle("fill", x, y, 20)
        love.graphics.setColor(1,0,0)
        love.graphics.print(tostring(id), x, y)

    end

   love.graphics.setColor(1,1,1,1)

   drawUI()
   --if not ui.show then drawCameraBounds(cam, 'line' ) end
   drawDebugStrings()
   --love.graphics.print(translateCache.value.."|"..translateCache.tweenValue, 10, 40)

   if uiState.showBouncy then
   if translateCache.value ~= 0 then
      love.graphics.line(W/2,100,W/2+translateCache.value, 0)
   else
      love.graphics.line(W/2,100,W/2+translateCache.tweenValue, 0)
   end
   end

--   love.graphics.print('make a mousehit test for the layered objects\n (bbox works already) just do it after that hits ', 30, 50)
   --love.graphics.print('then optimize nested object drawing too.', 30, 100)

end

function love.wheelmoved( dx, dy )
   cam:scaleToPoint(  1 + dy / 10)
end

function love.resize(w, h)
   cam:update(w,h)
end

function love.filedropped(file)
   local tab = getDataFromFile(file)
   middleLayer.children = tab -- TableConcat(root.children, tab)
   parentize(middleLayer)
   meshAll(middleLayer)
   renderThings(middleLayer)
end
