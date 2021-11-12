local scene = {}
local hasBeenLoaded = false

-- local Entity     = Concord.entity
-- local Component  = Concord.component
-- local System     = Concord.system
-- local World      = Concord.world

-- Containers
-- local Components  = Concord.components

-- look at some
-- https://www.istockphoto.com/nl/portfolio/Sashatigar?mediatype=illustration

local myWorld = Concord.world()


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

         local pressed = false
         --print(inspect(parallaxLayersData[1]))

         if false then
         for i = #parallaxLayersData, 1 do
            local layer = parallaxLayersData[i]
            --
            --print('adsf')
            pointerPressed(x,y, 'mouse', layer, pressed)
           -- print('sd', pressed)

         end
         end

         pointerPressed(x,y, 'mouse', parallaxLayersData, pressed)
         --print(pressed)
      end

   end
   function love.touchpressed(id, x, y, dx, dy, pressure)
--      pointerPressed(x,y, id, parallaxLayersData)
     -- for i = 1, #parallaxLayersData do
       --  local layer = parallaxLayersData[i]
         pointerPressed(x,y, id, parallaxLayersData)
      --end

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
      lastDraggedElement = nil
      if not istouch then
         pointerReleased(x,y, 'mouse', parallaxLayersData)
      end
   end
   function love.touchreleased(id, x, y, dx, dy, pressure)
      pointerReleased(x,y, id, parallaxLayersData)
   end
   function eventBus(event)
      if event == 'door-hitarea' then
	 -- tween camera to cave opening
	 -- go into cave
	 SM.load("cave")
      end


   end

end

-- duplication from removeAddItems
function makeObject(url, x, y, depth, allowOptimized)
   if allowOptimized == nil then allowOptimized = true end
   local read = readFileAndAddToCache(url)
   local doOptimized = read.optimizedBatchMesh ~= nil

   local child = {
      folder = true,
      transforms = copy3(read.transforms),
      name = 'generated '..url,
      children = (allowOptimized and doOptimized) and {} or copy3(read.children)
   }
   if allowOptimized and doOptimized then
      child.url = url
   end

   child.depth = depth
   child.transforms.l[1] = x
   child.transforms.l[2] = y
   child.bbox = read.bbox
   child.metaTags = read.metaTags

   --meshAll(child)
   return child
end

function makeWheel(thing, circumference)
   thing.wheelCircumference = circumference
   return thing
end


Concord.component(
   'transforms',
   function(c, value)
      c.transforms = value
   end
)
Concord.component(
   'biped',
   function(c, body, left, right)
      c.body = body
      c.left = left
      c.right = right
   end
)

local TransformSystem = Concord.system({pool={'transforms'}})
function TransformSystem:update(dt)
   local count = 0
   for _, e in ipairs(self.pool) do
   end
   --print('transformsystem, ', #self.pool)

end


--local AssetBookSystem = Concord.system({pool={'assetbook', 'parallaxlayer'}})
--function AssetBookSystem:update(dt)
   -- atm I think the best route would be:
   -- have this system that contains all the items in assetbooks (not on screen or in scene graph)
   -- make it do the arrangeParallaxLayerVisibility, so it probably needs the layer too
   -- in the add and remove from layer code, have it add or remove components from the entity
   -- which in turn will make it be used by the appropriate other systems

--end



local BipedSystem = Concord.system({pool={'biped'}})
function BipedSystem:update(dt)
   for _, e in ipairs(self.pool) do
--      myWorld:removeEntity(e)
  --    print('jo', e.biped.left, e.biped.right)
   end
end

myWorld:addSystems(BipedSystem, TransformSystem)



function scene.load()

   local timeIndex = math.floor(1 + love.math.random()*24)

   skygradient = gradientMesh(
      "vertical",
      gradients[timeIndex].from, gradients[timeIndex].to
   )




   if not hasBeenLoaded then

      --print('world:', World)

      depthMinMax =       {min=-1.0, max=1.0}
      foregroundFactors = { far=.8, near=1}
      backgroundFactors = { far=.4, near=.7}
      tileSize = 100

      cam = createCamera()


      backgroundFar = generateCameraLayer('backgroundFar', backgroundFactors.far)
      backgroundNear = generateCameraLayer('backgroundNear', backgroundFactors.near)
      foregroundFar = generateCameraLayer('foregroundFar', foregroundFactors.far)
      foregroundNear = generateCameraLayer('foregroundNear', foregroundFactors.near)

      dynamic = generateCameraLayer('dynamic', 1)

      backgroundAssetBook = generateAssetBook({
            urls= createAssetPolyUrls({'doosgroot'}),
            index={min=-100, max= 100},
            amountPerTile=1,
            depth=depthMinMax,
      })

      backgroundLayer = makeContainerFolder('backgroundLayer')

      foregroundAssetBook = generateAssetBook({
            urls= createAssetPolyUrls(
               { 'plant1','plant2','plant3','plant4',
                 'plant5','plant6','plant7','plant8',
                 'plant9','plant10','plant11','plant12',
                 'plant13','bunnyhead'
            }),
            index={min=-100, max= 100},
            amountPerTile=1,
            depth=depthMinMax,
      })
      foregroundLayer = makeContainerFolder('foregroundLayer')


      groundPlanes = makeGroundPlaneBook(createAssetPolyUrls({'fit1', 'fit2', 'fit3', 'fit4', 'fit5'}))


      --generateRandomPolysAndAddToContainer(30, foregroundFactors, foregroundLayer)

      -- todo alot of duplication from removeAddItems


      table.insert(
         foregroundLayer.children,
         makeObject('assets/cavething.polygons.txt', 1000,0, 0)
      )
      table.insert(
         backgroundLayer.children,
         makeWheel(makeObject('assets/wiel.polygons.txt', 1100,0, -1), 282)
      )
      table.insert(
         foregroundLayer.children,
         makeWheel(makeObject('assets/wiel.polygons.txt', 1100,0, 1), 282)
      )
      table.insert(
         foregroundLayer.children,
         makeWheel(makeObject('assets/wiel.polygons.txt', 1100,0, -1), 282)
      )

      -- table.insert(
      --    foregroundLayer.children,
      --    makeObject('assets/walterhappyfeetleft_.polygons.txt', 0,0, 0)
      -- )
      -- table.insert(
      --    foregroundLayer.children,
      --    makeObject('assets/walterhappyfeetright_.polygons.txt', 0,0, 0)
      -- )

      actors  = {}
      for i = 1, 10 do
         walterBody =  makeObject('assets/walterbody.polygons.txt', 0,0,love.math.random(), false)
	 walterLFoot =  makeObject('assets/walterhappyfeetleft_.polygons.txt', 0,0, 0)
	 walterRFoot =  makeObject('assets/walterhappyfeetright_.polygons.txt', 0,0, 0)

         walterBody.hasDraggableChildren = true
         walterLFoot.isDraggableChild = true
         walterRFoot.isDraggableChild = true

	 walterActor = Actor:create({body=walterBody, lfoot=walterLFoot, rfoot=walterRFoot})


         Concord.entity(myWorld)
            :give('transforms', walterBody.transforms)
            :give('biped', walterBody, walterLFoot, walterRFoot)


	 table.insert(
	    foregroundLayer.children,
	    walterActor.body
	 )


	 table.insert(actors, walterActor)
      end


      parallaxLayersData = {
	 {
            layer=backgroundLayer,
            p={factors=backgroundFactors, minmax=depthMinMax},
            assets=backgroundAssetBook,
            tileBounds={math.huge, -math.huge},
	 },{
            layer=foregroundLayer,
            p={factors=foregroundFactors, minmax=depthMinMax},
            assets=foregroundAssetBook,
            tileBounds={math.huge, -math.huge},
	   }
      }



   end
   perspectiveContainer = preparePerspectiveContainers({'foreground', 'background'})

   setCameraViewport(cam, 400,400)
   hasBeenLoaded = true
   attachPointerCallbacks()

end


function scene.update(dt)

   myWorld:emit("update", dt)

   if love.keyboard.isDown('p') then
      print(inspect(walter.metaTags))
   end

   manageCameraTween(dt)
   cam:update()

   cameraApplyTranslate(dt, foregroundLayer)

   if bouncetween then
      bouncetween:update(dt)
   end

   updateMotionItems(foregroundLayer, dt)
   updateMotionItems(backgroundLayer, dt)

   for i = 1 , #parallaxLayersData do
      handlePressedItemsOnStage(dt, parallaxLayersData[i])
   end

   for i=1, #actors do
      actors[i]:update(dt)
   end

end

function scene.draw()

   love.graphics.clear(1,1,1)
   love.graphics.setColor(1,1,1)

   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   drawGroundPlaneWithTextures(cam, 'backgroundFar', 'backgroundNear' ,'background')
   drawGroundPlaneWithTextures(cam, 'foregroundFar', 'foregroundNear', 'foreground')

   arrangeParallaxLayerVisibility('backgroundFar', parallaxLayersData[1], myWorld)
   cam:push()
   renderThings(backgroundLayer, {camera=dynamic, p=parallaxLayersData[1].p})
   cam:pop()

   arrangeParallaxLayerVisibility('foregroundFar', parallaxLayersData[2], myWorld)
   cam:push()
   renderThings( foregroundLayer, {camera=dynamic, p=parallaxLayersData[2].p })
   cam:pop()

   love.graphics.setColor(1,1,1)
   --drawUI()
   drawDebugStrings()
   drawBBoxAroundItems(foregroundLayer, parallaxLayersData[2].p)
   drawBBoxAroundItems(backgroundLayer, parallaxLayersData[1].p)

end

return scene
