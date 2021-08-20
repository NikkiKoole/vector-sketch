local Camera = require 'brady'
local inspect = require 'inspect'
ProFi = require 'ProFi'

-- four corner distort!!!!
--https://stackoverflow.com/questions/12919398/perspective-transform-of-svg-paths-four-corner-distort
--https://drive.google.com/file/d/0B7ba4SLdzCRuU05VYnlfcHNkSlk/view?resourcekey=0-N6EpbKvpvLA9wt6YpW9_5w

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

-- utility function that ought to be somewehre else

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
      table.insert(result, items[love.math.random()*#items])
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

   depthMinMax = {min=-2, max=2}
   depthScaleFactors = { min=.95, max=1.05}

   carThickness = 12.5
   testCar = false
   testCameraViewpointRects = false
   renderCount = 0

   for i = 1, 140 do
      local rndHeight = love.math.random(100, 200)
      local rndDepth =  mapInto(love.math.random(), 0,1,depthMinMax.min,depthMinMax.max )
      table.insert(
         stuff,
         {
            x = love.math.random(-W*5, W*5 ),
            y = -rndHeight,
            width = 10, --love.math.random(30, 50),
            height = rndHeight,
            color = {.6,
                     mapInto(rndDepth, depthMinMax.min,depthMinMax.max,  .6, .5),
                     mapInto(rndDepth, depthMinMax.min,depthMinMax.max, 0.4, .6) ,
                     love.math.random(.3,.9)},
            depth = rndDepth
         }
      )
   end

   table.insert(stuff, player)



   sortOnDepth(stuff)

   cameraPoints = {}
   for i = 1, 10 do
      table.insert(
         cameraPoints,
         {
            x = love.math.random(-W*2, W*2 ),
            y = love.math.random(-H*2, H*2),
            width = love.math.random(200, 500),
            height = love.math.random(200, 500),
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

   hack = generateCameraLayer('hack', 1)
   hackFar = generateCameraLayer('hackFar', depthScaleFactors.min)
   hackClose = generateCameraLayer('hackClose', depthScaleFactors.max)
   farther = generateCameraLayer('farther', .3)
   close = generateCameraLayer('close', 1.5)

   root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {}
   }

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

   function initGrass()


      local grass = {}
      local g0 = parseFile('assets/grassx5_.polygons.txt')
      local g1 = parseFile('assets/dong_single.polygons.txt')
      local g2 = parseFile('assets/dong_single2.polygons.txt')
      for i = 1, 50 do
         local grass1 = copy3(g0)
	 local grass2 = copy3(g1)
	 local grass3 = copy3(g2)
         grass = TableConcat(grass,grass1)
	 grass = TableConcat(grass,grass1)
	 grass = TableConcat(grass,grass1)
	 grass = TableConcat(grass,grass2)
	 grass = TableConcat(grass,grass3)
      end

      for i= 1, #grass do
         if grass[i].transforms then
            grass[i].transforms.l[1] = love.math.random() * 2000
            grass[i].transforms.l[2] = 0
            grass[i].transforms.l[4] = 1.0 + love.math.random()*.2
            grass[i].transforms.l[5] = 1.0 + love.math.random()* 2

            local rndDepth = mapInto(love.math.random(), 0,1, depthMinMax.min, depthMinMax.max )
            grass[i].depth = rndDepth
            grass[i].aabb =  grass[i].transforms.l[1]
         end

      end

      root.children = grass
   end
   initGrass()

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

   for j = 1, 10 do
      local generated = generatePolygon(0,0, 4 + love.math.random()*6, .05, .02 , 10)
      local points = {}
      for i = 1, #generated, 2 do
         table.insert(points, {generated[i], generated[i+1]})
      end

      local tlx, tly, brx, bry = getPointsBBox(points)
      local pointsHeight = math.floor((bry - tly)/2)

      local r,g,b = hex2rgb('4D391F')
      r = love.math.random()*255
      local rndDepth =  mapInto(love.math.random(), 0,1,depthMinMax.min,depthMinMax.max )
      local xPos = love.math.random()*12000
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

      table.insert(root.children, randomShape)
   end

   parentize(root)
   meshAll(root)
   renderThings(root)
   avgRunningAhead = 0
   sortOnDepth(root.children)

   for i =1, #root.children do
      if (root.children[i].folder) then
	 makeOptimizedBatchMesh(root.children[i])
      end

   end


end

function love.update(dt)
   local v = {x=0, y=0}

   if love.keyboard.isDown('left') then
      v.x = v.x - 1
   end
   if love.keyboard.isDown('right') then
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
         player.y  - 350,
         dt,
         2
      )
   end
   cam:update()
end

function love.mousepressed(x,y)
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

      end
   end
end

function drawGroundPlaneLines()
   love.graphics.setColor(1,1,1)
   love.graphics.setLineWidth(2)
   local x1,y1 = cam:getWorldCoordinates(0,0, 'hackFar')
   local x2,y2 = cam:getWorldCoordinates(W,0, 'hackFar')
   local s = math.ceil(x1/100)*100
   local e = math.ceil(x2/100)*100

   if s < 0 then s = s -100 end
   if e < 0 then e = e -100 end
   for i = s, e, 100 do
      local x1,y1 = cam:getScreenCoordinates(i,0, 'hackFar')
      local x2,y2 = cam:getScreenCoordinates(i,0, 'hackClose')
      love.graphics.line(x1,y1,x2,y2)
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
   love.graphics.scale(2)
   love.graphics.print('fps: '..love.timer.getFPS(), 0, 10)
   --love.graphics.print('renderCount: '..renderCount, 0, 30)

   love.graphics.setColor(1,1,1,.8)
   love.graphics.print('fps: '..love.timer.getFPS(),1,11)
   --love.graphics.print('renderCount: '..renderCount, 1, 31)
   --love.graphics.print('todo: sorting needs to be better, atm sorting continousy is turned off', 1, 41)
   love.graphics.scale(1)
end

function love.draw()
   renderCount = 0
   counter = counter +1
   W, H = love.graphics.getDimensions()
   love.graphics.clear(.6, .3, .7)
   drawCameraBounds(cam, 'line' )

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
   drawDebugStrings()
end


function love.wheelmoved( dx, dy )
   cam:scaleToPoint(  1 + dy / 10)
end


function love.filedropped(file)

   local tab = getDataFromFile(file)
   root.children = tab -- TableConcat(root.children, tab)
   parentize(root)
   meshAll(root)
   renderThings(root)


end
