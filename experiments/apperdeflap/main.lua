
function love.load()
  image = love.graphics.newImage( 'flapje.png')
  osString = love.system.getOS( )
  
end

function love.draw()
   
   love.graphics.clear()
   love.graphics.setColor(1,1,1)
   local w,h = love.graphics.getDimensions()
   local imgw,imgh = image:getDimensions()

   local scale = math.min(w/imgw, h/imgh)
   love.graphics.draw(image, 0, 0, 0, scale,scale)


   if osString == 'iOS' then
      -- have 3 buttons at the bottom
      local iapButtonSize = (w/3)
      love.graphics.setColor(1,1,0)
      love.graphics.rectangle('fill', 0, h-iapButtonSize, iapButtonSize,iapButtonSize)
      love.graphics.setColor(0,0,0)
      love.graphics.print('restore purchases', 0, h-iapButtonSize)

      love.graphics.setColor(0,1,1)
      love.graphics.rectangle('fill', iapButtonSize, h-iapButtonSize, iapButtonSize,iapButtonSize)
      love.graphics.setColor(0,0,0)
      love.graphics.print('has purchase', iapButtonSize, h-iapButtonSize)

      love.graphics.setColor(1,0,1)
      love.graphics.rectangle('fill', iapButtonSize*2, h-iapButtonSize, iapButtonSize,iapButtonSize)
      love.graphics.setColor(0,0,0)
      love.graphics.print('make purchase', iapButtonSize*2, h-iapButtonSize)
   end
   
end

function love.keypressed(k)
   if k == 'escape' then
      love.event.quit()
   end
end

function love.mousepressed(x,y)
   --love.system.restorePurchases()
   if osString == 'iOS' then
      local w,h = love.graphics.getDimensions()
      local iapButtonSize = (w/3)
      if (y > h-iapButtonSize) then
         if (x >0 and x<iapButtonSize) then
            love.system.restorePurchases()
         end
         if (x>iapButtonSize and x<iapButtonSize*2 ) then
            print(love.system.hasPurchase('test_purchase_001'))
         end
         if (x>iapButtonSize*2 and x<w ) then
            print(love.system.makePurchase('test_purchase_001'))
         end
      end
   end
end 
