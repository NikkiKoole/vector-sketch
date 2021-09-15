local Camera = require 'vendor.brady'
local inspect = require 'vendor.inspect'
local ProFi = require 'vendor.ProFi'
--flux = require "vendor.flux"
local Vector = require "vendor.brinevector"

require 'generateWorld'
require 'gradient'
require 'groundplane'
require 'fillstuf'
require 'removeAddItems'

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

if os.setlocale(nil) ~= 'C' then
   print('wrong locale:', os.setlocale(nil))
   os.setlocale("C")
end

function require_all(path, opts)
   local items = love.filesystem.getDirectoryItems(path)
   for _, item in pairs(items) do
      if love.filesystem.getInfo(path .. '/' .. item, 'file') then
         require(path .. '/' .. item:gsub('.lua', ''))
      end
   end
   if opts and opts.recursive then
      for _, item in pairs(items) do
         if love.filesystem.getInfo(path .. '/' .. item, 'directory') then
            require_all(path .. '/' .. item, {recursive = true})
         end
      end
   end
end

require_all "vecsketch"


local TESTING__ = true
if TESTING__ then
   local old_print = print
   print = function(...)
      local info = debug.getinfo(2, "Sl")
      local source = info.source
      if source:sub(-4) == ".lua" then source = source:sub(1, -5) end
      if source:sub(1,1) == "@" then source = source:sub(2) end
      local msg = ("%s:%i"):format(source, info.currentline)
      old_print(msg, ...)
   end
else
   print = function() end
end

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

function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end

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
      makeOptimizedBatchMesh(g2)
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
   --stuff = {} -- this is the testlayer with just some rectangles and the red player

   meshCache = {}

   depthMinMax = {min=-2, max=2}
   depthScaleFactors = { min=.9, max=1.1}

   --carThickness = 12.5
   --testCar = false
   testCameraViewpointRects = false
   renderCount = {normal=0, optimized=0, groundMesh=0}

   moving = nil

   local timeIndex = 17
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
   lastGroundBounds = {math.huge, -math.huge}  -- this one is just talking about indices

   hack = generateCameraLayer('hack', 1)
   hackFar = generateCameraLayer('hackFar', depthScaleFactors.min)
   hackClose = generateCameraLayer('hackClose', depthScaleFactors.max)
   farther = generateCameraLayer('farther', .7)
   close = generateCameraLayer('close', 1.5)



   betterShader = love.graphics.newShader( [[
         extern mat4 view;
         vec4 position(mat4 m, vec4 p) {
             return view  * TransformMatrix * p;
         }
   ]])


   createStuff()
   parentize(root)
   renderThings(root)
   recursivelyAddOptimizedMesh(root)

   --avgRunningAhead = 0
   sortOnDepth(root.children)

   cam:setTranslation(
      player.x + player.width/2 ,
      player.y - 350
   )
   --dt = 0
   --ProFi:stop()
   --ProFi:writeReport( 'profilingLoadReport.txt' )


   print(string.format("load took %.3f millisecs.", (love.timer.getTime() - loadStart) * 1000))

   gesture = nil

   gestureUpdateResolutionCounter = 0
   gestureUpdateResolution = 0.0167  -- aka 60 fps

   cameraTween = nil

   tweenCameraDelta = 0
   followPlayerCameraDelta = 0

   showNumbersOnScreen = false

   lastDT = 0

   font = love.graphics.newFont( "assets/adlib.ttf", 32)
   smallfont = love.graphics.newFont( "assets/adlib.ttf", 20)

   love.graphics.setFont(font)
   ui = {show=false}
end


function love.update(dt)
   --  dt = dt
   lastDT = dt
   local W, H = love.graphics.getDimensions()

   --print(dt)
   --flux.update(dt)
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
	 if delta == 0 then
	    if cameraTween.originalGesture == gesture then
	       gesture = nil
	    end
	    cameraTween = nil

	 end
	 tweenCameraDelta = delta
      end
   end

   if cameraFollowPlayer then
      followPlayerCameraDelta = cam:setTranslationSmooth(
         player.x + player.width/2 ,
         player.y - 350,
         dt,
         10
      )
   end


   cam:update()

   gestureUpdateResolutionCounter = gestureUpdateResolutionCounter + dt
   if gestureUpdateResolutionCounter > gestureUpdateResolution then
      gestureUpdateResolutionCounter = 0
      if gesture then
	 local x,y = love.mouse:getPosition()
	 if not gesture.positions then
	    gesture.positions = {}
	 end
	 --print('adding gesture position')
    	 table.insert(gesture.positions, {x=x,y=y, time=love.timer.getTime( )})
      end
   end

   for i=1, #root.children do
      local thing = root.children[i]
      if thing.inMotion and not thing.pressed then

         local gy = 6*980 * thing.inMotion.mass * dt
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



   --print(dt)
end




function love.mousepressed(x,y, button, istouch, presses)
   print('mouse pressed')
   if false then
      local wx, wy = cam:getMouseWorldCoordinates()
      local foundOne = false
      if testCameraViewpointRects then
         for _, v in pairs(cameraPoints) do
            if pointInRect(wx,wy, v.x, v.y, v.width, v.height) and not foundOne then
               foundOne = true
               v.selected = true
               local cw, ch = cam:getContainerDimensions()
               local targetScale = math.min(cw/v.width, ch/v.height)
               cam:setScale(targetScale)
               cam:setTranslation(v.x + v.width/2, v.y + v.height/2)
            else
               v.selected = false
            end

         end--
      end
      local W, H = love.graphics.getDimensions()

      local leftdis = getDistance(x,y, 50, (H/2)-25)
      local rightdis = getDistance(x,y, W-50, (H/2)-25)

      local toprightdis = getDistance(x,y, W-50, 25)

      if leftdis < 50 then
         moving = 'left'
      end
      if rightdis < 50 then
         moving = 'right'
      end
      if toprightdis < 50 then
         showNumbersOnScreen = not showNumbersOnScreen
         ui.show = not ui.show
      end
   end
   

   
   local itemPressed = false
   for i = #root.children,1,-1 do
      local c = root.children[i]
      if c.bbox and c._localTransform and c.depth and not itemPressed then

	 local mouseover, invx, invy = mouseIsOverItemBBox(x,y, c)

	 if mouseover then
	    c.pressed = {dx=invx, dy=invy}
	    itemPressed = c
	    c.poep = true
	    c.groundTileIndex = nil
	 end

      end
   end

   if not itemPressed  then
      if not cameraFollowPlayer then
	 gesture = {positions={}, target='stage'}
	 addGesturePoint(gesture, love.timer.getTime( ),x,y)
      end
   else
      gesture = nil
      gesture = {positions={}, target=itemPressed}
      addGesturePoint(gesture, love.timer.getTime( ),x,y)
   end

end

function addGesturePoint(gesture, time, x,y)
   assert(gesture)
   table.insert(gesture.positions, {time=time, x=x, y=y})
end


function love.touchpressed(id, x, y, dx, dy, pressure)
   print('touch pressed, ',id, x, y, dx, dy, pressure)
end
function love.touchreleased(id, x, y, dx, dy, pressure)
   print('touch released, ',id, x, y, dx, dy, pressure)

end
function love.touchmoved(id, x,y, dx, dy, pressure)
   print('touch moved, ',id, x, y, dx, dy, pressure)

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
	 local minDistance = 10
	 local minDuration = 0.005

	 if distance > minDistance then
	    if deltaTime > minDuration then
	       if speed >= minSpeed and speed < maxSpeed then
		  local cx,cy = cam:getTranslation()
		  local m = dx < 0 and -1 or 1

		  cameraTween = {goalX=cx-((dx) + (m* speed/7.5) ), goalY=cy, smoothValue=3.5, originalGesture=gesture}
	       else
		  print('failed at speed', minSpeed, speed, maxSpeed)
	       end
	    else
	       print('failed at duration', deltaTime, minDuration)
	    end
	 else
	    print('failed at distance')
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
         

         print('impulse', impulse)
	 applyForce(gesture.target.inMotion, impulse)
   end
   else
      gesture = nil
   end
end




function love.mousereleased(x,y)
   moving = nil
   for i = 1, #root.children do
      local c =root.children[i]
      if c.pressed then
         c.pressed = nil
      end
   end
   if gesture  then
      addGesturePoint(gesture, love.timer.getTime( ), x, y)
      gestureRecognizer(gesture)
      gesture = nil
   end
end


function getScreenBBoxForItem(c, hack)
   local tx, ty = c._localTransform:transformPoint(c.bbox[1],c.bbox[2])
   local tlx, tly = cam:getScreenCoordinates(tx, ty, hack)
   local bx, by = c._localTransform:transformPoint(c.bbox[3],c.bbox[4])
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
   local invx, invy = item._localTransform:inverseTransformPoint(wx, wy)

   return pointInRect(mx, my, tlx, tly, brx-tlx, bry-tly), invx, invy, tlx, tly, brx, bry
end


function love.mousemoved(mx, my,dx,dy)
   for i = 1, #root.children do
      local c = root.children[i]
      if c.bbox and c._localTransform and c.depth then
	 local mouseover, invx, invy = mouseIsOverItemBBox(mx, my, c)
         c.mouseOver = mouseover
      end
   end

   if cameraTween and gesture then
      if (cameraTween.originalGesture ~= gesture) then
--	 print('camera is still tweening, another new gesture is being started figure out if i have todo something')

      end
   end

   if love.mouse.isDown(1) then
      if cameraTween then
         cameraTween = nil
         tweenCameraDelta = 0
      end

      if gesture then
         if gesture.target == 'stage' then
            cam:translate(-dx,0)
         end
      end
   end
end


function drawCameraViewPointRectangles()
   for _, v in pairs(cameraPoint) do
      love.graphics.setColor(1,0,1,.5)
      if v.selected then
         love.graphics.setColor(1,0,0,.6)
      end

      love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
   end
end

function drawCameraCross()
   love.graphics.setColor(1,1,1,.2)
   love.graphics.line(0,0,W,H)
   love.graphics.line(0,H,W,0)
end

function drawDebugStrings()
   love.graphics.setColor(0,0,0,.2)
--   love.graphics.scale(2,2)
   love.graphics.setFont(smallfont)
   love.graphics.print('fps: '..love.timer.getFPS(), 20, 20)
   love.graphics.setColor(1,1,1,.8)
   love.graphics.print('fps: '..love.timer.getFPS(),21,21)
   love.graphics.setFont(font)

   love.graphics.setColor(0,0,0,.2)
   
   if showNumbersOnScreen then
      love.graphics.print('renderCount.optimized: '..renderCount.optimized, 20, 40)
      love.graphics.print('renderCount.normal: '..renderCount.normal, 20, 70)
      love.graphics.print('renderCount.groundMesh: '..renderCount.groundMesh, 20, 100)
      love.graphics.print('childCount: '..#root.children, 20, 130)
      if (tweenCameraDelta ~= 0 or followPlayerCameraDelta ~= 0) then
	 love.graphics.print('d1 '..round2(tweenCameraDelta, 2)..' d2 '..round2(followPlayerCameraDelta,2), 20, 160)
      end

      love.graphics.setColor(1,1,1,.8)

      love.graphics.print('renderCount.optimized: '..renderCount.optimized, 21, 41)
      love.graphics.print('renderCount.normal: '..renderCount.normal, 21, 71)
      love.graphics.print('renderCount.groundMesh: '..renderCount.groundMesh, 21, 101)
      love.graphics.print('childCount: '..#root.children, 21, 131)
      if (tweenCameraDelta ~= 0 or followPlayerCameraDelta ~= 0) then
	 love.graphics.print('d1 '..round2(tweenCameraDelta, 2)..' d2 '..round2(followPlayerCameraDelta,2), 21, 161)

      end

   end

   love.graphics.setColor(1,1,1,1)
--   love.graphics.scale(1,1)
end

function drawUI()

   local W, H = love.graphics.getDimensions()

   if ui.show then
      love.graphics.setColor(1,1,1, 0.3)
      love.graphics.rectangle('fill', 0,0, W, 50)

      love.graphics.setColor(0,0,0,.2)
      love.graphics.setFont(smallfont)
      love.graphics.print('tweaks', 120, 20)
      love.graphics.setFont(font)

      love.graphics.setColor(1,1,1, 0.3)

   end


   love.graphics.setColor(1,1,1)
   love.graphics.circle('fill', 50, (H/2)-25, 50)
   love.graphics.circle('fill', W-50, (H/2)-25, 50)
   love.graphics.circle('fill', W-25, 25, 25)
end


function love.draw()
   renderCount = {normal=0, optimized=0, groundMesh=0}

   counter = counter +1
   local W, H = love.graphics.getDimensions()
   love.graphics.clear(.6, .3, .7)

   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   if (false) then
      farther:push()
      love.graphics.setColor( 1, 0, 0, .25 )
      tlx, tly = cam:getWorldCoordinates(cam.x - cam.w, cam.y - cam.h, 'farther')
      brx, bry = cam:getWorldCoordinates(cam.x + cam.w*2, cam.y + cam.h*2, 'farther')

      for _, v in pairs(stuff) do
         if v.x >= tlx and v.x <= brx and v.y >= tly and v.y <= bry then
            love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
            love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
         end
      end
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
   renderThings(root)

   if testCameraViewpointRects then
      drawCameraViewPointRectangles()
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
      renderThings(root)
      close:pop()
   end

   cam:pop()

   -- draw hitboxes around things with bbox

   local mx, my = love.mouse.getPosition()

   for i =1 ,#root.children do
      local c = root.children[i]
      if c.bbox and c._localTransform and c.depth ~= nil then

         if c.mouseOver or c.pressed  then
	    local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c)
            if c.pressed then
               c.transforms.l[1] = c.transforms.l[1] + (invx - c.pressed.dx)
               c.transforms.l[2] = c.transforms.l[2] + (invy - c.pressed.dy)

               if ((brx + offset) > W) then
                  cam:translate(1000*lastDT, 0)
                  c.transforms.l[1] = c.transforms.l[1] + 1000*lastDT
               end
               if ((tlx - offset) < 0) then
                  cam:translate(-1000*lastDT, 0)
                  c.transforms.l[1] = c.transforms.l[1] + -1000*lastDT
               end
            end

            love.graphics.setColor(1,1,1,.5)
            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)
         end
      end
   end

   love.graphics.setColor(1,1,1,1)
   drawUI()
   if not ui.show then drawCameraBounds(cam, 'line' ) end
   drawDebugStrings()
end

function love.wheelmoved( dx, dy )
   cam:scaleToPoint(  1 + dy / 10)
end

function love.resize(w, h)
   --print('need to decide howmany ground meshes')
   --print(("Window resized to width: %d and height: %d."):format(w, h))
   --print(inspect(cam))
   --cam:update(w,h)
end

function love.filedropped(file)
   local tab = getDataFromFile(file)
   root.children = tab -- TableConcat(root.children, tab)
   parentize(root)
   meshAll(root)
   renderThings(root)
end
