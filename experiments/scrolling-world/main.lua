local Camera = require 'brady'

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

   player = {
      x = - 25,
      y = - 25,
      width = 50,
      height = 50,
      speed = 300,
      color = { 1,0,0 }
   }
   cameraFollowPlayer = true
   stuff = {}
   
   for i = 1, 200000 do
      table.insert(
         stuff,
         {
            x = love.math.random(-W*120, W*120 ),
            y = love.math.random(-H*120, H*120),
            width = love.math.random(100, 300),
            height = love.math.random(100, 300),
            color = { 1, 1, 1 }
         }
      )
   end

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
   far = cam:addLayer( 'far', .95, { relativeScale = (1.0/.95) * .95 } )

   close = cam:addLayer( 'close', 1.05, { relativeScale = (1.0/1.05) * 1.05 } )
   local generated = generatePolygon(0,0, 40, .05, .02 , 6)
   local points = {}
   for i = 1, #generated, 2 do
      table.insert(points, {generated[i], generated[i+1]})
   end
   root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {

         {
            folder = true,
            transforms =  {l={0,0,0,1,1,100,0,0,0}},
            name="rood",
            children ={
               {
                  name="roodchild:"..1,
                  color = {.5,1,0, 0.8},
                  points = points,

               },
               {
                  folder = true,
                  transforms =  {l={200,200,0,1,1,100,0,0,0}},
                  name="yellow",
                  children ={
                     {
                        name="chi22ld:"..1,
                        color = {1,1,0, 0.8},
                        points = {{0,0},{200,0},{200,200},{0,200}},

                     },
                     {
                        folder = true,
                        transforms =  {l={200,200,0,1,1,100,0,0,0}},
                        name="blue",
                        children ={



                           {
                              name="bluechild:"..1,
                              color = {0,0,1, 0.8},
                              points = {{0,0},{200,0},{200,200},{0,200}},

                           },
                           {
                              folder = true,
                              transforms =  {l={200,200,0,1,1,0,0,0,0}},
                              name="endhandle",
                              children ={

                                 {
                                    name="endhandlechild:"..1,
                                    color = {0,1,0, 0.8},
                                    points = {{0,0},{20,0},{20,20},{0,20}},

                                 }

                              }
                           }



                        }
                     }
                  }
               }
            },
         },
      }
   }
   
   parentize(root)
   meshAll(root)
   renderThings(root)
  
        
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
      player.y = player.y + v.y
   end

   if cameraFollowPlayer then
      cam:setTranslationSmooth(
         player.x + player.width/2,
         player.y + player.height/2,
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
   W, H = love.graphics.getDimensions()
   love.graphics.clear(.3, .3, .7)
   drawCameraBounds(cam, 'line' )
   cam:push()

   far:push()
   -- the parallax layer behind
   love.graphics.setColor( 1, 0, 0, .25 )
    tlx, tly = cam:getWorldCoordinates(cam.x - cam.w, cam.y - cam.h, 'far')
   brx, bry = cam:getWorldCoordinates(cam.x + cam.w*2, cam.y + cam.h*2, 'far')

   for _, v in pairs(stuff) do
      if v.x >= tlx and v.x <= brx and v.y >= tly and v.y <= bry then
         love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
         love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
      end
   end
   renderThings(root)
   far:pop()
   

   
   tlx, tly = cam:getWorldCoordinates(cam.x - cam.w, cam.y - cam.h, 'main')
   brx, bry = cam:getWorldCoordinates(cam.x + cam.w*2, cam.y + cam.h*2, 'main')


   for _, v in pairs(stuff) do
      if v.x >= tlx and v.x <= brx and v.y >= tly and v.y <= bry then
         love.graphics.setColor(v.color)
         love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
      end
      

   end

   renderThings(root)

   for _, v in pairs(cameraPoints) do
      love.graphics.setColor(1,0,1,.5)
      if v.selected then
         love.graphics.setColor(1,0,0,.6)

      end
      
      love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
   end

   love.graphics.setColor(player.color)
   love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)



   -- close:push()
   -- -- the parallax layer before
   -- love.graphics.setColor( 1, 0, 0, .25 )
   -- for _, v in pairs(stuff) do
   --    love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
   --    love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
   -- end
   -- renderThings(root)
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

