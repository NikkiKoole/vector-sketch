local Camera = require 'brady'
local inspect = require 'inspect'
ProFi = require 'ProFi'
require 'generateWorld'
require 'gradient'
local random = love.math.random

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

function hex2rgb(hex)
   hex = hex:gsub("#","")
   return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
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

function findAllFolderNodesRecursively(root)
   if root.folder then
      if root.url then
         root.optimizedBatchMesh = meshCache[root.url].optimizedBatchMesh
      end
   end

   if root.children then
      for i=1, #root.children do
         if root.children[i].folder then
            findAllFolderNodesRecursively(root.children[i])
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

function readFileAndAddToCache(url)
   if not meshCache[url] then
      local g2 = parseFile(url)[1]
      assert(g2)
      meshAll(g2)
      makeOptimizedBatchMesh(g2)
      meshCache[url] = g2
   else
      --print(url, 'was already in the cache you fool')
   end

   return meshCache[url]
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

   -- https://codepen.io/bork/pen/wJhEm
   local timeIndex = 17
   skygradient = gradientMesh("vertical", gradients[timeIndex].from, gradients[timeIndex].to)

   if true then
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

   transform = love.math.newTransform( )
   transform = transform:setTransformation( 123, 456)
   print(transform:getMatrix())
   -- this is crap
   -- o dont want to use the pixel shader
   -- i need to just use teh vertex shader, thats all i have

--https://love2d.org/forums/viewtopic.php?f=4&t=88253

--    perspShader = love.graphics.newShader [[
-- vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc){
-- return color;
-- }
-- ]]

-- effect = love.graphics.newShader [[
--         extern number time;
--         vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
--         {
--             return vec4((1.0+sin(time))/2.0, abs(cos(time)), abs(sin(time)), 1.0);
--         }
--     ]]

--     local pixel = [[
-- varying vec4 vpos;
-- vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc){
-- return color * vpos;
-- }
-- ]]

-- local vertex = [[
-- varying vec4 vpos;

-- vec4 position( mat4 transform_projection, vec4 vertex_position )
-- {
--     vpos = vertex_position;
--     //return transform_projection * vertex_position;
-- float angle = 0;
-- transform_projection *= mat4(
-- 			1, 0, 0, 0,
-- 			0, cos(angle), -sin(angle), 0,
-- 			0, sin(angle), cos(angle), 0,
-- 			1, 1, 1, 1
-- 		);
-- float z = 1-(vertex_position.y/1);
-- transform_projection *= mat4(
-- 	z, 0, 0, 0,
-- 	0, z, 0, 0,
-- 	0, 0, 1, 0,
-- 	1, 1, 1, 1
-- );
-- return transform_projection * vertex_position;
-- }
-- ]]

        angle = .3 * math.pi
	cosAngle, sinAngle = math.sin(angle), math.cos(angle)
	groundShader = love.graphics.newShader( [[
		//uniform vec2 size;
		uniform float cosAngle, sinAngle;
                uniform float xOff;
		vec4 position(mat4 m, vec4 p) {
                        vec2 size = love_ScreenSize.xy / 2;
                        p.x =  (p.x) + (xOff*0);
			p.z = 1.0 - p.y / size.y * cosAngle;
			p.y *= sinAngle / p.z;
			p.x = 0.5 * (size.x) + (p.x - 0.5 * (size.x)) / p.z;
			return m * p ;
		}
	]])

        image = love.graphics.newImage("images.jpeg")
        --quad = love.graphics.newQuad(0, 0, 128, 64, image:getWidth(), image:getHeight())

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
   initCarParts()

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
   testData = {}
  for i = -100, 100 do
     --print(i)
     testData[i] = {}
     for p = 1, 1 do
	table.insert(
           testData[i],
           {
              x=random()*tileSize,
              groundTileIndex = i,
              depth=mapInto(random(),
                            0,1,
                            depthMinMax.min, depthMinMax.max ),
              scaleX = 1.0 + random()*.2,
              scaleY = 1.0 + random()*1.2,

              urlIndex=math.ceil(random()* #plantUrls)
           }
        )
     end
  end
   --print(inspect(testData))
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

   for j = 1, 1 do
      local generated = generatePolygon(0,0, 4 + random()*16, .05 + random()*.01, .02 , 8 + random()*8)
      local points = {}
      for i = 1, #generated, 2 do
         table.insert(points, {generated[i], generated[i+1]})
      end

      local tlx, tly, brx, bry = getPointsBBox(points)
      local pointsHeight = math.floor((bry - tly)/2)

      local r,g,b = hex2rgb('4D391F')
      r = random()*255
      local rndDepth =  mapInto(random(), 0,1,depthMinMax.min,depthMinMax.max )
      local xPos = random()*1200
      local randomShape = {
         folder = true,
         transforms =  {l={xPos,0,0,1,1,0,pointsHeight,0,0}},
         name="rood",
         depth = rndDepth,
         aabb = xPos,
         children ={
            {
               name="roodchild:"..1,
               color = {r/255,g/255,b/255, 1.0},
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
   test()
   --ProFi:stop()
   --ProFi:writeReport( 'profilingLoadReport.txt' )
   arrangeWhatIsVisibleStartup()

   findAllFolderNodesRecursively(root)
   print(string.format("load took %.3f millisecs.", (love.timer.getTime() - loadStart) * 1000))
end


function love.update(dt)
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
end

function love.mousereleased()
   moving = nil
end

function drawGroundPlanesSameSame(index, tileIndex)
   local thing = groundPlanes.assets[tileIndex].thing
   for j = 1, #thing.optimizedBatchMesh do
      love.graphics.setColor(thing.optimizedBatchMesh[j].color)
      love.graphics.draw(groundPlanes.perspectiveContainer[index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1
      love.graphics.setColor(1,1,1)
   end
end

function drawGroundPlaneInPosition(dest, index, tileIndex)
   local thing = groundPlanes.assets[tileIndex].thing
   local bbox = groundPlanes.assets[tileIndex].bbox
   local source = {bbox.tl.x, bbox.tl.y, bbox.br.x, bbox.br.y }

   for j = 1, #thing.optimizedBatchMesh do
      local count = thing.optimizedBatchMesh[j].mesh:getVertexCount()
      local result = {}

      for v = 1, count do
	 local x, y = thing.optimizedBatchMesh[j].mesh:getVertex(v)
	 local r = transferPoint (x, y, source, dest)
	 table.insert(result, {r.x, r.y})
      end

      if groundPlanes.perspectiveContainer[index][j].perspMesh and
	 groundPlanes.perspectiveContainer[index][j].perspMesh:getVertexCount() == #result then
	 groundPlanes.perspectiveContainer[index][j].perspMesh:setVertices(result, 1, #result)
      else
	 groundPlanes.perspectiveContainer[index][j] = {
	    perspMesh = love.graphics.newMesh(simple_format, result , "triangles", "stream")
	 }
      end

      love.graphics.setColor(thing.optimizedBatchMesh[j].color)

      love.graphics.draw(groundPlanes.perspectiveContainer[index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1

      love.graphics.setColor(1,1,1)
   end
end


function removeTheContenstOfGroundTiles(startIndex, endIndex)
   -- everything out of this range ought to be removed
--   print('remove outside', startIndex, endIndex)
   for i = #root.children, 1, -1 do
      local child = root.children[i]
      if child.groundTileIndex ~= nil then
         if child.groundTileIndex < startIndex or
            child.groundTileIndex > endIndex then
            --print('found a thing to remove', child.groundTileIndex)

            table.remove(root.children, i)
         end
      end
   end

end


function addTheContentsOfGroundTiles(startIndex, endIndex)
   -- there is a risk of ading thing more then once, should i cehck that her or in the outside ?
   --print("adding called", startIndex, endIndex)
   for i = startIndex, endIndex do
      if (testData[i]) then
      for j = 1, #testData[i] do
         local thing = testData[i][j]
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
         table.insert(root.children, grass)
       --  print('added', (i*100)+thing.x)
      end
      end
      --print(i, testData[i], 'should be added')
   end
   parentize(root)
   sortOnDepth(root.children)
   findAllFolderNodesRecursively(root)

end


function arrangeWhatIsVisibleStartup()
   local x1,y1 = cam:getWorldCoordinates(0,0, 'hackFar')
   local x2,y2 = cam:getWorldCoordinates(W,0, 'hackFar')
   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   local startIndex = s/tileSize
   local endIndex = e/tileSize

   --print('pretend i did a lot of init positonioning here')
   addTheContentsOfGroundTiles(startIndex, endIndex)
   lastGroundBounds = {startIndex, endIndex}
   --print(inspect(root))
end



function arrangeWhatIsVisible(x1, x2, tileSize)

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   local startIndex = s/tileSize
   local endIndex = e/tileSize



   if startIndex ~= lastGroundBounds[1] or
      endIndex ~= lastGroundBounds[2] then

      removeTheContenstOfGroundTiles(startIndex, endIndex)
   end






   if (startIndex ~= lastGroundBounds[1]) then
      -- here i shoul dget some items to start displaying probably
      if startIndex < lastGroundBounds[1] then
	 --print("going left, more becomes visible at start, i need more")
         --for i = startIndex,lastGroundBounds[1]-1 do
         --   print(i, testData[i], 'should be added')
         --end
         addTheContentsOfGroundTiles(startIndex, lastGroundBounds[1]-1)
      elseif startIndex > lastGroundBounds[1] then
	 --print("going right, less becomes visible at start, i need less")
         --for i = startIndex,lastGroundBounds[1]+1, -1 do
         --   print(i, testData[i], 'should be removed')
         --end
      end
   end
   if (endIndex ~= lastGroundBounds[2]) then
      -- here i shoul dget some items to start displaying probably
--      print('change at end')
      if endIndex < lastGroundBounds[2] then
	 --print("going left, less becomes visible at end, i need less")
         --for i = endIndex,lastGroundBounds[2]-1 do
         --   print(i, testData[i], 'should be removed')
         --end

      elseif endIndex > lastGroundBounds[2] then
	 --print("going right, more becomes visible at end, i need more")
         --for i = endIndex,lastGroundBounds[2]+1, -1 do
         --   print(i, testData[i], 'should be added')
         --end
         addTheContentsOfGroundTiles(lastGroundBounds[2]+1, endIndex)

      end
   end
   lastGroundBounds = {startIndex, endIndex}
end




function drawGroundPlaneLines()
   local thing = groundPlanes.assets[1].thing
   local W, H = love.graphics.getDimensions()
   love.graphics.setColor(1,1,1)
   love.graphics.setLineWidth(2)
   local x1,y1 = cam:getWorldCoordinates(0,0, 'hackFar')
   local x2,y2 = cam:getWorldCoordinates(W,0, 'hackFar')
   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   arrangeWhatIsVisible(x1, x2, tileSize)

   local usePerspective = false

   if usePerspective then

      if ((lastCameraBounds[1]) == (x1) and (lastCameraBounds[2]) == (x2) and (lastCameraBounds[3]) == (y1)) then
	 for i = s, e, tileSize do
	    local groundIndex = (i/tileSize)
	    local tileIndex = (groundIndex % 5) + 1
	    local index = (i - s)/tileSize
	    if index >= 0 and index <= 100 then
	       drawGroundPlanesSameSame(index, tileIndex)
	    end
	 end
      else
	 for i = s, e, tileSize do
	    local groundIndex = (i/tileSize)
	    local tileIndex = (groundIndex % 5) + 1
	    local index = (i - s)/tileSize
	    local height1 = 0
	    local height2 = 0
	    local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, 'hackFar')
	    local x2,y2 = cam:getScreenCoordinates(i+0.0001, 0, 'hackClose')
	    local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height2, 'hackFar')
	    local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, 0, 'hackClose')
	    local dest = {{x1,y1}, {x3,y3}, {x4,y4}, {x2,y2}}
	    if index >= 0 and index <= 100 then
	       drawGroundPlaneInPosition(dest, index, tileIndex)
	    end
	 end
	 lastCameraBounds= {x1,x2,y1, y2}
      end
   else
      -- here we draw the ground tiles without any perpspective
      -- it might be better, its gonna be faster atleast, lets see
      -- its a shiot ton faster, i dont know what i think about it



      love.graphics.setShader(groundShader)
     -- groundShader:send("size", {W, H})
      groundShader:send("cosAngle", cosAngle)
      groundShader:send("sinAngle", sinAngle)

     -- hackFar:push()
      for i = s, e, tileSize do
      --for i = 0, W, 100 do
         local groundIndex = (i/tileSize)
         local tileIndex = (groundIndex % 5) + 1
         local x1,y1 = cam:getScreenCoordinates(i+0.0001, 0, 'hackFar')
         love.graphics.setColor(1,1,1,0.5)
         groundShader:send("xOff", x1)

         --love.graphics.setColor(love.math.random(),1,1)
         --love.graphics.rectangle("fill", x1, 0,100,100)
         love.graphics.draw(image, x1, 300)

         local  optimized = groundPlanes.assets[tileIndex].thing.optimizedBatchMesh
         --print(i)
         for  j=1, #optimized do
            love.graphics.setColor(optimized[j].color)
            love.graphics.draw(optimized[j].mesh, x1, 700)
         end
      end
      --hackFar:pop()
      love.graphics.setShader()

   end


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
   --drawCameraCross()
   love.graphics.setColor(1,1,1)
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
