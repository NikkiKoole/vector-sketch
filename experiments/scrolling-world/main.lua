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

function love.load()

   W, H = love.graphics.getDimensions()
   offset = 20
   counter = 0
   player = {
      x = - 25,
      y = 0,
      width = 50,
      height = -180,
      speed = 700,
      color = { 1,0,0 }
   }
   player.depth = 0-- -2 , 2
   cameraFollowPlayer = true
   stuff = {}

   depthMinMax = {min=-1, max=1}
   depthScaleFactors = { min=.75, max=1.25} 

   
   -- for i = 1, 140 do
   --    local rndHeight = 200--love.math.random(100, 900)
   --    local rndDepth =  mapInto(love.math.random(), 0,1,depthMinMax.min,depthMinMax.max )
   --    table.insert(
   --       stuff,
   --       {
   --          x = love.math.random(-W*5, W*5 ),
   --          y = 0, --love.math.random(-H*12, 0),
   --          width = 10, --love.math.random(30, 50),
   --          height = rndHeight,
   --          color = {.6,
   --                   mapInto(rndDepth, depthMinMax.min,depthMinMax.max,  .6, .5),
   --                   mapInto(rndDepth, depthMinMax.min,depthMinMax.max, 0.4, .6) ,
   --                   love.math.random(.3,.9)},
   --          depth = rndDepth
   --       }
   --    )
   -- end
   
   table.insert(stuff, player)
   
   table.sort( stuff, function(a,b) return a.depth <  b.depth end)

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
   
   hack = cam:addLayer('hack', 1, {relativeScale=1})

   hackFar = cam:addLayer(
      'hackFar',
      depthScaleFactors.min ,
      {relativeScale=(1.0/depthScaleFactors.min) *depthScaleFactors.min }
   )

   hackClose = cam:addLayer(
      'hackClose',
      depthScaleFactors.max ,
      {relativeScale=(1.0/depthScaleFactors.max) *depthScaleFactors.max }
   )
   
   
   --hackClose = cam:addLayer('hackClose', 1, {relativeScale=depthScaleFactors.max})
   
   --farther = cam:addLayer( 'farther', .65, { relativeScale = (1.0/.65) * .65 } )
   --far = cam:addLayer( 'far', .95, { relativeScale = (1.0/.95) * .95 } )
   --close = cam:addLayer( 'close', 1.05, { relativeScale = (1.0/1.05) * 1.05 } )
   
   root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {}
   }

   --local tab = getDataFromFilePath('assets/grassypatches.polygons.txt')
   --root.children = tab -- TableConcat(root.children, tab)
   
   --boei = parseFile('assets/grassx5_.polygons.txt')
   boei = parseFile('assets/grassypatches.polygons.txt')

   for i = 1, 2 do
      local boei2 = parseFile('assets/grassypatches.polygons.txt')
      boei = TableConcat(boei,boei2)
   end
   
   
   for i= 1, #boei do
      if boei[i].transforms then
         --print(boei[i].transforms)
         boei[i].transforms.l[1] = love.math.random() * 2000
         boei[i].transforms.l[2] = 0--love.math.random() * 200
         boei[i].transforms.l[4] = 1.0
         boei[i].transforms.l[5] = 1.0 --love.math.random()*5

         local rndDepth = mapInto(love.math.random(), 0,1,depthMinMax.min,depthMinMax.max )
         --print(rndDepth)
         boei[i].depth = rndDepth
      else
         print('rea;;u')
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
            name="chi22ld:"..1,
            color = {1,1,0, 0.8},
            points = {{-50,-250},{50,-250},{50,0},{-50,0}},

         }
      }
   }
   
   root.children = boei
   table.insert(root.children, newPlayer)
   --table.insert(root.children, boei)


   for j = 1, 100 do
      local generated = generatePolygon(0,0, love.math.random()*14, .05, .02 , 10)
      local points = {}
      for i = 1, #generated, 2 do
         table.insert(points, {generated[i], generated[i+1]})
      end
      local r,g,b = hex2rgb('4D391F')
      r = love.math.random()*255
      local rndDepth =  mapInto(love.math.random(), 0,1,depthMinMax.min,depthMinMax.max )
      local randomShape = {
         folder = true,
         transforms =  {l={love.math.random()*2000,0,0,1,1,0,0,0,0}},
         name="rood",
         depth = rndDepth,
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
  
        
end

function hex2rgb(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

function shuffleAndMultiply(items, mul)
   local result = {}
   for i = 1, (#items * mul) do
      print(i)
      table.insert(result, items[love.math.random()*#items])
   end
   return result
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
      newPlayer.depth =player.depth-- newPlayer.depth + (v.y)/100
      
   end

   if cameraFollowPlayer then
      --print(v.x*200)
      cam:setTranslationSmooth(
         player.x + player.width/2 ,
         player.y  - 200,
         dt,
         2
      )
   end
   cam:update()
end

function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end

function love.mousepressed(x,y)
   local wx, wy = cam:getMouseWorldCoordinates()
   local foundOne = false
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


function love.draw()
   counter = counter +1
   W, H = love.graphics.getDimensions()
   love.graphics.clear(.6, .3, .7)
   drawCameraBounds(cam, 'line' )
  

   -- farther:push()
   -- -- the parallax layer behind
   -- love.graphics.setColor( 1, 0, 0, .25 )
   --  tlx, tly = cam:getWorldCoordinates(cam.x - cam.w, cam.y - cam.h, 'far')
   -- brx, bry = cam:getWorldCoordinates(cam.x + cam.w*2, cam.y + cam.h*2, 'far')

   -- for _, v in pairs(stuff) do
   --    if v.x >= tlx and v.x <= brx and v.y >= tly and v.y <= bry then
   --       love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
   --       love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
   --    end
   -- end
   -- renderThings(root)
   -- farther:pop()

   
--    far:push()
--    -- the parallax layer behind
--    --print(cam:getTranslation()) 
-- --   local tx, ty = far:getTranslation()
   
--   -- love.graphics.translate( -tx * far.relativeScale, -ty * far.relativeScale )
   
--    love.graphics.setColor( 1, 0, 0, .25 )
--     tlx, tly = cam:getWorldCoordinates(cam.x - cam.w, cam.y - cam.h, 'far')
--    brx, bry = cam:getWorldCoordinates(cam.x + cam.w*2, cam.y + cam.h*2, 'far')

--    for _, v in pairs(stuff) do
--       if v.x >= tlx and v.x <= brx and v.y >= tly and v.y <= bry then
--          love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
--          love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
--       end
--    end
--    renderThings(root)
--    far:pop()


  
   --.65, { relativeScale = (1.0/.65) * .65 } )
   
   

   --local p = ((math.sin(counter / 100)) )
   --p = mapInto(p, -1, 1, -0.125, 0.125)
   --print(p)
   
 
   -- the ground plane hwo to do it?
   love.graphics.setColor(1,1,1)
   love.graphics.setLineWidth(2)
   local x1,y1 = cam:getWorldCoordinates(0,0, 'hackFar')
   local x2,y2 = cam:getWorldCoordinates(W,0, 'hackFar')
   --print(x1,x2,math.ceil(x1/100)*100, math.ceil(x2/100)*100)
   local s = math.ceil(x1/100)*100
   local e = math.ceil(x2/100)*100
   if s < 0 then s = s -100 end
   --if s > 0 then s = s +100 end
   if e < 0 then e = e -100 end
   --if e > 0 then e = e +100 end


   for i = s, e, 100 do
      --print(i)
       local x1,y1 = cam:getScreenCoordinates(i,0, 'hackFar')
       local x2,y2 = cam:getScreenCoordinates(i,0, 'hackClose')
       --print(x1,y1, x2,y2)
       love.graphics.line(x1,y1,x2,y2)
       
   end
   
   love.graphics.setLineWidth(1)
  
  
   table.sort( stuff, function(a,b) return a.depth <  b.depth end)
   for _, v in pairs(stuff) do


      
      hack.scale = mapInto(v.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)

         hack.relativeScale = (1.0/ hack.scale) * hack.scale
         hack.push()

            love.graphics.setColor(v.color)
            love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
            love.graphics.setColor(.1, .1, .1)
            love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
         --end
         hack:pop()
   end
    cam:push()

   --love.graphics.setColor(player.color)
   --love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)

    --print(#root.children)
    table.sort(root.children, function(a,b) return a.depth <  b.depth end)
    renderThings(root)

   for _, v in pairs(cameraPoints) do
      love.graphics.setColor(1,0,1,.5)
      if v.selected then
         love.graphics.setColor(1,0,0,.6)

      end
      
      love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
   end

  
   --love.graphics.setColor(player.color)
   --love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)



   -- close:push()
   -- -- the parallax layer before
   -- love.graphics.setColor( 1, 0, 0, .25 )
   -- for _, v in pairs(stuff) do
   --    love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
   --    love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
   -- end
   --renderThings(root)
   -- close:pop()
   
   cam:pop()

   love.graphics.setColor(1,1,1,.2)
   love.graphics.line(0,0,W,H)
   love.graphics.line(0,H,W,0)

   love.graphics.setColor(0,0,0,.2)
   love.graphics.print(love.timer.getFPS())
   love.graphics.setColor(1,1,1,.8)

   love.graphics.print(love.timer.getFPS(),1,1)


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

