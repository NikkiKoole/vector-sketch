local scene = {}

local Camera = require 'custom-vendor.brady'

function scene.modify(data)
end




function scene.load()
   local timeIndex = 18
   
   skygradient = gradientMesh(
      "vertical",
      gradients[timeIndex].from, gradients[timeIndex].to
   )

   stuff = {}
   depthMinMax = {min=-1, max=1}
   depthScaleFactors = { min=.8, max=1}
   tileSize = 100
   offset = 20
   local W, H = love.graphics.getDimensions()

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
   layerBounds = {
      hack = {math.huge, -math.huge},
      farther = {math.huge, -math.huge}

   }

   hack = generateCameraLayer('hack', 1)
   hackFar = generateCameraLayer('hackFar', depthScaleFactors.min)
   hackClose = generateCameraLayer('hackClose', depthScaleFactors.max)
   farther = generateCameraLayer('farther', .7)


   
   createStuff()

   --parentize(middleLayer)
   --renderThings(middleLayer)
   --recursivelyAddOptimizedMesh(middleLayer)
   --sortOnDepth(middleLayer.children)


   cam:setTranslation(
       player.x + player.width/2 ,
       player.y - 300

    )

   
end



function scene.update(dt)
   function love.keypressed(key, unicode)
      if key == 'escape' then
         resetCameraTween()
         SM.load('intro')
      end
   end

   function love.mousepressed(x,y, button, istouch, presses)
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



   

   manageCameraTween(dt)
   cam:update()
   updateMotionItems(middleLayer, dt)

   cameraApplyTranslate(dt)
   
   local W, H = love.graphics.getDimensions()
   if bouncetween then
      bouncetween:update(dt)
   end

   handlePressedItemsOnStage(W, H, dt)

end

function scene.draw()
   local W, H = love.graphics.getDimensions()

   love.graphics.clear(1,1,1)
   love.graphics.setColor(1,1,1)
   
   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())
   drawGroundPlaneLines(cam)
   
   farther:push()
   renderThings(fartherLayer)
   farther:pop()

   
   cam:push()
   renderThings(middleLayer)
   cam:pop()

   --if uiState.showBouncy then
   if translateCache.value ~= 0 then
      love.graphics.line(W/2,100,W/2+translateCache.value, 0)
   else
      love.graphics.line(W/2,100,W/2+translateCache.tweenValue, 0)
   end
   --end


end

return scene



