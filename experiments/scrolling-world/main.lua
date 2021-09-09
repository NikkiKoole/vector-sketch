local Camera = require 'brady'
local inspect = require 'inspect'
ProFi = require 'ProFi'
require 'generateWorld'
require 'gradient'
require 'groundplane'
local random = love.math.random
flux = require "flux"

--[[
TODO:

the bbox functions have 2 ways of returning the data
{tlx, tly, brx, bry} and {tl={x,y}, br={x,y}}
make that just one way

look at some touch throw, swipe flick stuff
https://forum.unity.com/threads/flicking-shooting-throwing-tossing-lobbing-slicing-script.91726/

https://cloud.netlifyusercontent.com/assets/344dbf88-fdf9-42bb-adb4-46f01eedd629/c0061c8d-2295-4c87-8340-2fb3613c9a35/touch-chart-preview-opt.jpg
]]--




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

   W, H = love.graphics.getDimensions()
   offset = 20
   counter = 0
   player = {
      x = - 25,
      y = 0,
      width = 50,
      height = -180,
      speed = 200,
      color = { 1,0,0 }
   }
   player.depth = 0
   cameraFollowPlayer = true
   stuff = {} -- this is the testlayer with just some rectangles and the red player

   meshCache = {}

   depthMinMax = {min=-2, max=2}
   depthScaleFactors = { min=.9, max=1.1}

   carThickness = 12.5
   testCar = false
   testCameraViewpointRects = false
   renderCount = {normal=0, optimized=0, groundMesh=0}

   moving = nil

   local timeIndex = 17
   skygradient = gradientMesh("vertical", gradients[timeIndex].from, gradients[timeIndex].to)

   if false then
      for i = 1, 140 do
	 local rndHeight = random(100, 200)
	 local rndDepth =  mapInto(random(), 0,1,depthMinMax.min,depthMinMax.max )
	 table.insert(
	    stuff,
	    {
	       x = random(-W*5, W*5 ),
	       y = -rndHeight,
	       width = 10, --love.math.random(30, 50),
	       height = rndHeight,
	       color = {.6,
			mapInto(rndDepth, depthMinMax.min,depthMinMax.max,  .6, .5),
			mapInto(rndDepth, depthMinMax.min,depthMinMax.max, 0.4, .6) ,
			random(.3,.9)},
	       depth = rndDepth
	    }
	 )
      end
      table.insert(stuff, player)
      sortOnDepth(stuff)
   end

   cameraPoints = {}
   for i = 1, 10 do
      table.insert(
         cameraPoints,
         {
            x = random(-W*2, W*2 ),
            y = random(-H*2, H*2),
            width = random(200, 500),
            height = random(200, 500),
            color = { 1, 1, 1 },
            selected = false
         }
      )
   end

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

   root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {}
   }

   betterShader = love.graphics.newShader( [[
         extern mat4 view;
         vec4 position(mat4 m, vec4 p) {
             return view  * TransformMatrix * p;
         }
   ]])

   function initCarParts()
      carparts = {}
      carparts.children = parseFile('assets/carparts_.polygons.txt')

      carbody = copy3(findNodeByName(carparts, 'carbody'))
      carbody.children[1].color[4] = 1.0
      carbody.transforms.l[1]=0
      carbody.transforms.l[2]=0
      carbody.depth = 0

      carbodyVoor = copy3(findNodeByName(carparts, 'carbody'))
      carbodyVoor.children[1].color[4] = 0.3
      carbodyVoor.children[2].children[1].color[4] = 0.6
      carbodyVoor.children[2].children[2].color[4] = 0.6
      carbodyVoor.transforms.l[1]=0
      carbodyVoor.transforms.l[2]=0
      carbodyVoor.depth = carThickness
   end
   --initCarParts()



   plantUrls = {
      'assets/grassagain_.polygons.txt',
      'assets/plant1.polygons.txt',
      'assets/plant2.polygons.txt',
      'assets/plant3.polygons.txt',
      'assets/plant4.polygons.txt',
      'assets/plant5.polygons.txt',
      'assets/plant6.polygons.txt',
      'assets/plant7.polygons.txt',
      'assets/plant8.polygons.txt',
      'assets/plant9.polygons.txt',
      'assets/plant10.polygons.txt',
      'assets/plant11.polygons.txt',
      'assets/plant12.polygons.txt',
      'assets/plant13.polygons.txt',
   }

   --[[

      ok my plan to make the loading faster and huge worlds possible
      - make the initted list just a big list of groundindexes ? -100 -> 100 or something
      - at each list add a bunch of random things
      - then try and display this thing.
      - from there we are ion a good location to improve

   ]]--

   tileSize = 100
   plantData = {}
   for i = -100, 100 do

      plantData[i] = {}
      for p = 1, 1 do
         table.insert(
            plantData[i],
            {
               x=random()*tileSize,
               groundTileIndex = i,
               depth=mapInto(random(),
                             0,1,
                             depthMinMax.min, depthMinMax.max ),
               scaleX = 1.0 + random(),
               scaleY = 1.0 + random()*1.5,

               urlIndex=math.ceil(random()* #plantUrls)
            }
         )
      end
   end

   -- function initGrass()
   --    local all = {}
   --    for j = 1, #plantUrls do
   --       local url = plantUrls[j]
   --       local read = readFileAndAddToCache(url)
   --       local grass = {}

   --       for i= 1, 5 do
   --          grass[i]= {
   --             folder = true,
   --             transforms =  copy3(read.transforms),
   --             name="generated",
   --             children ={}
   --          }
   --          if grass[i].transforms then
   --             grass[i].transforms.l[1] = -1000 + random() * 2000
   --             grass[i].transforms.l[2] = 0
   --             grass[i].transforms.l[4] = 1.0 + random()*.2
   --             grass[i].transforms.l[5] = 1.0 + random()* 2

   --             local rndDepth = mapInto(random(), 0,1, depthMinMax.min, depthMinMax.max )
   --             grass[i].depth = rndDepth
   --             grass[i].aabb =  grass[i].transforms.l[1]
   --             grass[i].url = url
   --          end
   --       end
   --       all = TableConcat(all, grass)
   --    end
   --    root.children = all
   -- end
   --initGrass()

   groundPlanes = {
      assets = {
	 --{url = 'assets/grasssquare_.polygons.txt'},
         {url = 'assets/fit1.polygons.txt'},
	 {url = 'assets/fit2.polygons.txt'},
	 {url = 'assets/fit3.polygons.txt'},
	 {url = 'assets/fit4.polygons.txt'},
	 {url = 'assets/fit5.polygons.txt'}
      },
      perspectiveContainer = {
	 -- all perspective groundmeshes drawn on screen will end up in here
      }
   }

   for i = 1, #groundPlanes.assets do
      local url = groundPlanes.assets[i].url
      groundPlanes.assets[i].thing = readFileAndAddToCache(url)
      groundPlanes.assets[i].bbox = getBBoxOfChildren(groundPlanes.assets[i].thing.children)
   end
   for i = 0, 100 do  -- maximum of 100 groundplanes visible onscreen
      groundPlanes.perspectiveContainer[i] = {}
      for j =0, 10 do -- maximum of 10 'layers/children/optimized layers' in a thing
	 groundPlanes.perspectiveContainer[i][j] = {}
      end
   end



   -- new player
   newPlayer = {
      folder = true,
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      name="player",
      depth = 0,
      x=0,
      children ={
         {
            name="yellow shape:"..1,
            color = {1,1,0, 0.8},
            points = {{-50,-250},{50,-250},{50,0},{-50,0}},
         },
      }
   }
   if testCar then
      table.insert(newPlayer.children, 1, carbody)
   end

   table.insert(root.children, newPlayer)
   meshAll(newPlayer)

   if testCar then
      voor2 = {
         folder = true,
         transforms =  {l={0,0,0,1,1,0,0,0,0}},
         name="voor2",
         depth = 12,
         x=0,
         children ={
            carbodyVoor
         }
      }
      table.insert(root.children, voor2)
   end

   for j = 1, 100 do
      local generated = generatePolygon(0,0, 4 + random()*16, .05 + random()*.01, .02 , 8 + random()*8)
      local points = {}
      for i = 1, #generated, 2 do
         table.insert(points, {generated[i], generated[i+1]})
      end

      local tlx, tly, brx, bry = getPointsBBox(points)
      local pointsHeight = math.floor((bry - tly)/2)

      local r,g,b = hex2rgb('4D391F')
      r = random()*255
      local rnd = random()
      local rndDepth =  mapInto(rnd, 0,1,depthMinMax.min,depthMinMax.max )
      local xPos = -600 + random()*1200
      local randomShape = {
         folder = true,
         transforms =  {l={xPos,0,0,1,1,0,pointsHeight,0,0}},
         name="rood",
         depth = rndDepth,
         aabb = xPos,
         bbox= {tlx, tly, brx, bry},
         children ={
            {
               name="roodchild:"..1,
               color = {rnd,g/255,b/255, 1.0},
               points = points,
            },
         }
      }
      meshAll(randomShape)

      table.insert(root.children, randomShape)
   end

   parentize(root)

   renderThings(root)
   avgRunningAhead = 0
   sortOnDepth(root.children)

   -- set camera direct to where it wants to be
   cam:setTranslation(
      player.x + player.width/2 ,
      player.y - 350
   )

   --ProFi:stop()
   --ProFi:writeReport( 'profilingLoadReport.txt' )

   recursivelyAddOptimizedMesh(root)
   print(string.format("load took %.3f millisecs.", (love.timer.getTime() - loadStart) * 1000))

   gesture = nil

   gestureUpdateResolution = 0.016
   gestureUpdateResolutionCounter = 0
   dt = 0
end


function love.update(dt)
   dt = dt
   flux.update(dt)
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

   if cameraFollowPlayer then
      local distanceAhead = math.floor(300*v.x)
      cam:setTranslationSmooth(
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
	 table.insert(gesture.positions, {x=x,y=y, time=love.timer.getTime( )})
      end
   end



   --print(dt)
end

function love.mousepressed(x,y, button, istouch, presses)
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

   if leftdis < 50 then
      moving = 'left'
   end
   if rightdis < 50 then
      moving = 'right'
   end

   local itemPressed = false
   for i = 1, #root.children do
      local c = root.children[i]
      if c.bbox and c._localTransform and c.depth then
         local hack = {}
         hack.scale = mapInto(c.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
         hack.relativeScale = (1.0/ hack.scale) * hack.scale

         if c.mouseOver then
            local mx, my = love.mouse.getPosition()
            local wx2, wy2 = cam:getWorldCoordinates(mx, my, hack)
            local ix, iy = c._localTransform:inverseTransformPoint(wx2, wy2)

            c.pressed = {dx=ix, dy=iy}
	    itemPressed = true
         end
      end
   end

   if not itemPressed then
      print('no item pressed, could check and start fro a drag/ flick.throw gesture on the stage')
      gesture = {startTime=love.timer.getTime( ), startPos={x=x, y=y}, positions={}}
   else
      print('item is pressed, this might become a throw of that item who knows!?')
      gesture = nil
   end

end


--https://stackoverflow.com/questions/47856682/how-to-get-the-delta-of-swipe-draging-touch

function gestureRecognizer(gesture)
   -- todo make a few types of gesture here now its just one
   local minSpeed = 1000
   local maxSpeed = 5000
   local minDistance = 25
   local minDuration = 0.05


    local dx = gesture.endPos.x - gesture.startPos.x
    local dy = gesture.endPos.y - gesture.startPos.y
    local distance = math.sqrt(dx*dx+dy*dy)

    if distance > minDistance then
       local deltaTime = gesture.endTime - gesture.startTime
       if deltaTime > minDuration then
	  local speed = distance / deltaTime
	  if speed >= minSpeed and speed < maxSpeed then

	     local durp = {s=0}
	     flux.to(durp, deltaTime*1.5, { s = 1 }):ease("elasticout"):onupdate(function() cam:translate(-dx/(speed/minSpeed)/30,0) end)
	  else
	     print('failed at speed', minSpeed, speed, maxSpeed)
	  end
       else
	  print('failed at duratoin', deltaTime, minDuration)
       end


    else
       print('failed at distance')
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
      gesture.endTime = love.timer.getTime( )
      gesture.endPos = {x=x, y=y}
      gestureRecognizer(gesture)
   end
end

function love.mousemoved(mx, my)
   for i = 1, #root.children do
      local c = root.children[i]
      if c.bbox and c._localTransform and c.depth then
         local hack = {}
         hack.scale = mapInto(c.depth,
                              depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
         hack.relativeScale = (1.0/ hack.scale) * hack.scale

         local tx, ty = c._localTransform:transformPoint(c.bbox[1],c.bbox[2])
         local tlx, tly = cam:getScreenCoordinates(tx, ty, hack)
         local bx, by = c._localTransform:transformPoint(c.bbox[3],c.bbox[4])
         local brx, bry = cam:getScreenCoordinates(bx, by, hack)

         if pointInRect(mx, my, tlx, tly, brx-tlx, bry-tly) then
            c.mouseOver = true
         else
            c.mouseOver = false
         end
      end
   end

end


function removeTheContenstOfGroundTiles(startIndex, endIndex)
   for i = #root.children, 1, -1 do
      local child = root.children[i]
      if child.groundTileIndex ~= nil then
         if child.groundTileIndex < startIndex or
            child.groundTileIndex > endIndex then
            table.remove(root.children, i)
         end
      end
   end
end
function addTheContentsOfGroundTiles(startIndex, endIndex)
   for i = startIndex, endIndex do
      if (plantData[i]) then
         for j = 1, #plantData[i] do
            local thing = plantData[i][j]
            local urlIndex = (thing.urlIndex)
            local url = plantUrls[urlIndex]
            local read = readFileAndAddToCache(url)
            local grass = {
               folder = true,
               transforms = copy3(read.transforms),
               name = 'generated',
               children = {}
            }
            grass.transforms.l[1] = (i*tileSize) + thing.x
            grass.transforms.l[2] = 0
            grass.transforms.l[4] = thing.scaleX
            grass.transforms.l[5] = thing.scaleY

            grass.depth = thing.depth
            grass.url = url
            grass.groundTileIndex = thing.groundTileIndex
            grass.bbox = read.bbox
            table.insert(root.children, grass)
         end
      end
   end
   parentize(root)
   sortOnDepth(root.children)
   recursivelyAddOptimizedMesh(root)
end

function arrangeWhatIsVisible(x1, x2, tileSize)
   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   local startIndex = s/tileSize
   local endIndex = e/tileSize

   -- initial adding
   if lastGroundBounds[1] == math.huge and lastGroundBounds[2] == -math.huge then
      addTheContentsOfGroundTiles(startIndex, endIndex)
   else
      -- look to add at start or end
      if startIndex ~= lastGroundBounds[1] or
         endIndex ~= lastGroundBounds[2] then
         removeTheContenstOfGroundTiles(startIndex, endIndex)
      end

      if startIndex < lastGroundBounds[1] then
         addTheContentsOfGroundTiles(startIndex, lastGroundBounds[1]-1)
      end

      if endIndex > lastGroundBounds[2] then
         addTheContentsOfGroundTiles(lastGroundBounds[2]+1, endIndex)
      end
   end
   lastGroundBounds = {startIndex, endIndex}
end



function drawCameraViewPointRectangles()
   for _, v in pairs(cameraPoints) do
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
   love.graphics.scale(2,2)
   love.graphics.print('fps: '..love.timer.getFPS(), 20, 10)
   love.graphics.print('renderCount.optimized: '..renderCount.optimized, 20, 30)
   love.graphics.print('renderCount.normal: '..renderCount.normal, 20, 50)
   love.graphics.print('renderCount.groundMesh: '..renderCount.groundMesh, 20, 70)
   love.graphics.print('childCount: '..#root.children, 20, 90)

   love.graphics.setColor(1,1,1,.8)
   love.graphics.print('fps: '..love.timer.getFPS(),21,11)
   love.graphics.print('renderCount.optimized: '..renderCount.optimized, 21, 31)
   love.graphics.print('renderCount.normal: '..renderCount.normal, 21, 51)
   love.graphics.print('renderCount.groundMesh: '..renderCount.groundMesh, 21, 71)
   love.graphics.print('childCount: '..#root.children, 21, 91)

   love.graphics.scale(1,1)
end

function drawUI()
   local W, H = love.graphics.getDimensions()
   love.graphics.setColor(1,1,1)

   love.graphics.circle('fill', 50, (H/2)-25, 50)
   love.graphics.circle('fill', W-50, (H/2)-25, 50)
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
   -- see if i can do it

      -- draw the hitboxes

   for i =1 ,#root.children do
      local c = root.children[i]
      if c.bbox and c._localTransform and c.depth ~= nil then

         local hack = {}
         hack.scale = mapInto(c.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
         hack.relativeScale = (1.0/ hack.scale) * hack.scale

         local tx, ty = c._localTransform:transformPoint(c.bbox[1],c.bbox[2])
         local tlx, tly = cam:getScreenCoordinates(tx, ty, hack)

         local bx, by = c._localTransform:transformPoint(c.bbox[3],c.bbox[4])
         local brx, bry = cam:getScreenCoordinates(bx, by, hack)

         if c.mouseOver == true or c.pressed then
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my, hack)
            local ix, iy = c._localTransform:inverseTransformPoint(wx, wy)

            if c.pressed then
               c.transforms.l[1] = c.transforms.l[1] + (ix - c.pressed.dx)
               c.transforms.l[2] = c.transforms.l[2] + (iy - c.pressed.dy)
            end

            love.graphics.setColor(1,1,1,.5)
            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)
         end
      end

   end
      love.graphics.setColor(1,1,1,1)


   --drawCameraCross()
   drawUI()

   drawCameraBounds(cam, 'line' )

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
