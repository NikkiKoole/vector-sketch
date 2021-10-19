local scene = {}


local hasBeenLoaded = false
function scene.modify(data)
end

function attachPointerCallbacks()
      function love.keypressed(key, unicode)
      if key == 'escape' then
         resetCameraTween()
         SM.load('intro')
      end
      if key == 'up' then
	 cam:translate(0, -10)
      end
       if key == 'down' then
	 cam:translate(0, 10)
      end
      love.keyboard.setKeyRepeat( true )
   end
   function love.mousepressed(x,y, button, istouch, presses)
      if (mouseState.hoveredSomething) then return end
      if not istouch then
         pointerPressed(x,y, 'mouse', parallaxLayersData)
      end
   end
   function love.touchpressed(id, x, y, dx, dy, pressure)
      pointerPressed(x,y, id, parallaxLayersData)
   end
   function love.mousemoved(x, y,dx,dy, istouch)
      if not istouch then

         pointerMoved(x,y,dx,dy, 'mouse', parallaxLayersData)
      end
   end
   function love.touchmoved(id, x,y, dx, dy, pressure)
      pointerMoved(x,y,dx,dy, id, parallaxLayersData)
   end
   function love.mousereleased(x,y, button, istouch)
      lastDraggedElement = nil --{id=id}
      if not istouch then
         pointerReleased(x,y, 'mouse', parallaxLayersData)
      end
   end
   function love.touchreleased(id, x, y, dx, dy, pressure)
      pointerReleased(x,y, id, parallaxLayersData)
   end

end

function preparePerspectiveContainers(layers)
   local result = {}
   for k =1, #layers do
      local layerName = layers[k]
      result[layerName] = {}

      for i = 0, 100 do
         -- maximum of 100 groundplanes visible onscreen
         result[layerName][i] = {}
         for j =0, 10 do
            -- maximum of 10 'layers/children/optimized layers' in a thing
            result[layerName][i][j] = {}
         end
      end
   end
   return result
end


function createAssetPolyUrls(strings)
   local result = {}
   for i = 1, #strings do
      table.insert(result, 'assets/'..strings[i]..'.polygons.txt')
   end
   return result
end

function makeGroundPlaneBook(urls)
   local result = {}
   for i =1, #urls do
      local url = urls[i]
      local thing = readFileAndAddToCache(url)
      result[i] = {
         url = url,
         thing = thing,
         bbox = getBBoxOfChildren(thing.children),
      }
   end
   return result
end


function generateAssetBook(recipe)
   local result = {}

   for i = recipe.index.min, recipe.index.max do
      result[i] = {}
      for p= 1, recipe.amountPerTile do
      table.insert(
         result[i],
         {
            x=random()*tileSize,
            groundTileIndex = i,
            depth = mapInto(random(),0,1,recipe.depth.min, recipe.depth.max),
            scaleX=1,
            scaleY=1,
            url=pickRandom(recipe.urls)
         }
      )
      end
   end
   return result
end


function scene.load()

   local timeIndex = math.floor(1 + love.math.random()*24)

   skygradient = gradientMesh(
      "vertical",
      gradients[timeIndex].from, gradients[timeIndex].to
   )

   if not hasBeenLoaded then

      depthMinMax =       {min=-1.0, max=1.0}
      foregroundFactors = { far=.8, near=1}
      backgroundFactors = { far=.4, near=.7}

      tileSize = 100
      cam = createCamera()
      setCameraViewport(cam, 1000,1000)

      -- used in deciding what items to add and remove to the 'ground tile'
      layerTileBounds = {
         foreground = {math.huge, -math.huge},
         background = {math.huge, -math.huge}
      }
      -- used in figuring out if i can re-use a perspective ground mesh
      -- this also take y in account, perspective change when y changes
      lastCameraBounds = {
         foreground = {x={math.huge, -math.huge}, y={math.huge, -math.huge}},
         background = {x={math.huge, -math.huge}, y={math.huge, -math.huge}},
      }



      backgroundFar = generateCameraLayer('backgroundFar', backgroundFactors.far)
      backgroundNear = generateCameraLayer('backgroundNear', backgroundFactors.near)

      foregroundFar = generateCameraLayer('foregroundFar', foregroundFactors.far)
      foregroundNear = generateCameraLayer('foregroundNear', foregroundFactors.near)

      dynamic = generateCameraLayer('dynamic', 1)


      fartherAssetBook = generateAssetBook({
            urls= createAssetPolyUrls({'doosgroot'}),
            index={min=-100, max= 100},
            amountPerTile=1,
            depth=depthMinMax,
      })

      fartherLayer = makeContainerFolder('fartherLayer')

      -- i keep some data in the asset book, basically that what i need to generate
      -- it fully when the time comes

      middleAssetBook = generateAssetBook({
            urls= createAssetPolyUrls(
               { 'plant1','plant2','plant3','plant4',
                 'plant5','plant6','plant7','plant8',
                 'plant9','plant10','plant11','plant12',
                 'plant13','deurpaarser2', 'doosgroot', 'doosgroot',
            }),
            index={min=-100, max= 100},
            amountPerTile=1,
            depth=depthMinMax,
      })
      middleLayer = makeContainerFolder('middleLayer')


      groundPlanes = makeGroundPlaneBook(createAssetPolyUrls({'fit1', 'fit2', 'fit3', 'fit4', 'fit5'}))
      perspectiveContainer = preparePerspectiveContainers({'foreground', 'background'})


      -- this will contain all the data, in an organized way
      -- from back to front
      parallaxLayersData = {
         {
            layer=fartherLayer,
            p={factors=backgroundFactors, minmax=depthMinMax},
            assets=fartherAssetBook
         },
         {
            layer=middleLayer,
            p={factors=foregroundFactors, minmax=depthMinMax},
            assets=middleAssetBook}
      }

      --createStuff()

   end

   hasBeenLoaded = true
   attachPointerCallbacks()

end



function scene.update(dt)

   manageCameraTween(dt)
   cam:update()
   cameraApplyTranslate(dt)

   if bouncetween then
      bouncetween:update(dt)
   end

   updateMotionItems(middleLayer, dt)
   updateMotionItems(fartherLayer, dt)

   handlePressedItemsOnStage(dt, parallaxLayersData)


end

function scene.draw()

   love.graphics.clear(1,1,1)
   love.graphics.setColor(1,1,1)

   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   drawGroundPlaneWithTextures(cam, 'backgroundFar', 'backgroundNear' ,'background')
   drawGroundPlaneWithTextures(cam, 'foregroundFar', 'foregroundNear', 'foreground')

   arrangeParallaxLayerVisibility('backgroundFar', 'background')

   cam:push()

   renderThings(fartherLayer, {
                   camera=dynamic,
                   factors=backgroundFactors,
                   minmax=depthMinMax
   })

   cam:pop()


   arrangeParallaxLayerVisibility('foregroundFar', 'foreground')
   cam:push()
   renderThings( middleLayer, {
                    camera=dynamic,
                    factors=foregroundFactors,
                    minmax=depthMinMax
   })
   --renderThings(middleLayer)
   cam:pop()


   love.graphics.setColor(1,1,1)

   --drawUI()
   drawDebugStrings()
   drawBBoxAroundItems(middleLayer, {factors=foregroundFactors, minmax=depthMinMax})
   drawBBoxAroundItems(fartherLayer, {factors=backgroundFactors, minmax=depthMinMax})



end

return scene
