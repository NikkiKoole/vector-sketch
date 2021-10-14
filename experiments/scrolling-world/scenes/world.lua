local scene = {}


local hasBeenLoaded = false
function scene.modify(data)
end




function scene.load()
   
   local timeIndex = math.floor(1 + love.math.random()*24)
   
   skygradient = gradientMesh(
      "vertical",
      gradients[timeIndex].from, gradients[timeIndex].to
   )

   if not hasBeenLoaded then
      --stuff = {}
      depthMinMax = {min=-1, max=1.0}

      depthScaleFactors = { min=.8, max=1}
      depthScaleFactors2 = { min=.4, max=.7}

      tileSize = 100
      cam = createCamera()
      
      layerBounds = {
         hack = {math.huge, -math.huge},
         farther = {math.huge, -math.huge}
      }

      farthest = generateCameraLayer('farthest', .4)

      farther = generateCameraLayer('farther', .7)
      hackFar = generateCameraLayer('hackFar', depthScaleFactors.min)
      hack = generateCameraLayer('hack', 1)
      hackClose = generateCameraLayer('hackClose', depthScaleFactors.max)

      fartherLayer = makeContainerFolder('fartherLayer')
      middleLayer = makeContainerFolder('middleLayer')
      
      createStuff()

      setCameraViewport(600,600)

      updateMotionItems(middleLayer, dt)
   end
   hasBeenLoaded = true
end

function setCameraViewport(w, h)
   local cw, ch = cam:getContainerDimensions()
   local targetScale = math.min(cw/w, ch/h)
   cam:setScale(targetScale)
   cam:setTranslation(0, -1 * h/2)
end



function scene.update(dt)
   function love.keypressed(key, unicode)
      if key == 'escape' then
         resetCameraTween()
         SM.load('intro')
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

   
   manageCameraTween(dt)
   cam:update()
   cameraApplyTranslate(dt)
   function handlePressedItemsOnStage(dt)
   local W, H = love.graphics.getDimensions()

   for i = 1, #middleLayer.children do
      local c = middleLayer.children[i]
      if c.bbox and c._localTransform and c.depth ~= nil then

         if c.pressed then
	    local mx, my = getPointerPosition(c.pressed.id)
	    local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c)
            if c.pressed then
               c.transforms.l[1] = c.transforms.l[1] + (invx - c.pressed.dx)
               c.transforms.l[2] = c.transforms.l[2] + (invy - c.pressed.dy)

               if ((brx + offset) > W) then
                  resetCameraTween()
		  cameraTranslateScheduler(1000*dt, 0)
               end
               if ((tlx - offset) < 0) then
                  resetCameraTween()
		  cameraTranslateScheduler(-1000*dt, 0)
               end
            end
         end

      end
   end
end

   if bouncetween then
      bouncetween:update(dt)
   end

   updateMotionItems(middleLayer, dt)

   handlePressedItemsOnStage(dt)
   
end

function scene.draw()

   local W, H = love.graphics.getDimensions()

   love.graphics.clear(1,1,1)
   love.graphics.setColor(1,1,1)
   
   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   drawGroundPlaneLinesSimple(cam, 'farthest', 'farther')

   drawGroundPlaneLinesSimple(cam, 'hackFar', 'hackClose')


   arrangeParallaxLayerVisibility('farthest', 'farther')
   farther:push()
   renderThings(fartherLayer, {
                   camera=hack,
                   factors=depthScaleFactors2,
                   minmax=depthMinMax
   })
   farther:pop()

   arrangeParallaxLayerVisibility('hackFar', 'hack')
   cam:push()
   renderThings( middleLayer, {
                    camera=hack,
                    factors=depthScaleFactors,
                    minmax=depthMinMax
   })
   --renderThings(middleLayer)
   cam:pop()

   
   love.graphics.setColor(1,1,1)

   drawUI()
   drawDebugStrings()
   drawBBoxAroundItems()
   


end

return scene



