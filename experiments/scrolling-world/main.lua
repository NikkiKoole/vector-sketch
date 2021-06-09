local Camera = require 'brady'




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
   love.window.setMode(1024, 768, {resizable=true,  msaa=4})
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
   
   for i = 1, 20 do
      table.insert(
         stuff,
         {
            x = love.math.random(-W*2, W*2 ),
            y = love.math.random(-H*2, H*2),
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
   far = cam:addLayer( 'far', .85, { relativeScale = (1.0/.85) * 1.05 } )
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
   for _, v in pairs(stuff) do
      love.graphics.setColor(v.color[1], v.color[2],  v.color[3], 0.3)
      love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
   end
   far:pop()

   
   for _, v in pairs(stuff) do
      love.graphics.setColor(v.color)
      love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
   end

   for _, v in pairs(cameraPoints) do
      love.graphics.setColor(v.color)
      if v.selected then
         love.graphics.setColor(1,0,0,1)

      end
      
      love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
   end

   love.graphics.setColor(player.color)
   love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)
   
   
   cam:pop()

   love.graphics.setColor(1,1,1,.2)
   love.graphics.line(0,0,W,H)
   love.graphics.line(0,H,W,0)

end

function love.wheelmoved( dx, dy )

   cam:scaleToPoint( 1 + dy / 10 )
end
