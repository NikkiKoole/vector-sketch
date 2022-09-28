local mesh = require 'lib.mesh'
local parentize = require 'lib.parentize'
local parallax = require 'lib.parallax'
local render = require 'lib.render'
local hit = require 'lib.hit'
local gradient = require 'lib.gradient'
local ui = require 'lib.ui'
local generator = require 'lib.generateWorld'
local scene = {}
local hasBeenLoaded = false
--local cam = getCamera()
local cam = require('lib.cameraBase').getInstance()
-- look at some
-- https://www.istockphoto.com/nl/portfolio/Sashatigar?mediatype=illustration

-- this is spring code migh be useful for cars
-- https://gist.github.com/Fraktality/1033625223e13c01aa7144abe4aaf54d

-- what about this for cars ?
-- https://github.com/DonHaul/2DCar/blob/master/carController.cs

-- this has a nice simple example
-- https://gamedev.stackexchange.com/questions/170271/math-needed-to-create-a-very-simple-2d-side-view-car-game

--[[

   de wielen draaien door als je ze los laat en rollen van een bergje af

]] --

-- this is about water partic;es
-- https://blog.habrador.com/2019/04/fluid-simulations-unity-sprinkle-game.html

local Components = {}
local Systems = {}
local myWorld = Concord.world()

Concord.utils.loadNamespace("src/components", Components)
Concord.utils.loadNamespace("src/systems", Systems)

myWorld:addSystems(
   Systems.AssetBookSystem,
   Systems.GravitySystem,
   Systems.InMotionSystem,
   Systems.DraggableSystem,
   Systems.BipedSystem,
   Systems.WheelSystem,
   Systems.VehicleSystem,
   Systems.HitAreaEventSystem,
   Systems.StackSystem,
   Systems.RotateOnMoveSystem

)

function scene.modify(data)
end

function attachPointerCallbacks()
   function love.keypressed(key, unicode)
      if key == 'escape' then
         resetCameraTween()
         SM.load('intro')
      end
      if key == 'up' then
         resetCameraTween()

         cam:translate(0, -5)

      end
      if key == 'down' then
         resetCameraTween()

         cam:translate(0, 5)
      end
      love.keyboard.setKeyRepeat(true)
   end

   function love.mousepressed(x, y, button, istouch, presses)
      if (ui.mouseHovered()) then return end
      if not istouch then
         pointerPressed(x, y, 'mouse', parallaxLayersData, myWorld)
      end
   end

   function love.touchpressed(id, x, y, dx, dy, pressure)
      pointerPressed(x, y, id, parallaxLayersData, myWorld)
   end

   function love.mousemoved(x, y, dx, dy, istouch)
      if not istouch then
         pointerMoved(x, y, dx, dy, 'mouse', parallaxLayersData, myWorld)
      end
   end

   function love.touchmoved(id, x, y, dx, dy, pressure)
      pointerMoved(x, y, dx, dy, id, parallaxLayersData, myWorld)
   end

   function love.mousereleased(x, y, button, istouch)
      lastDraggedElement = nil
      if not istouch then
         pointerReleased(x, y, 'mouse', parallaxLayersData, myWorld)
      end
   end

   function love.touchreleased(id, x, y, dx, dy, pressure)
      pointerReleased(x, y, id, parallaxLayersData, myWorld)
   end

   function eventBus(event)
      if event == 'door-hitarea' then
         -- tween camera to cave opening
         -- go into cave
         SM.load("cave")
      end


   end

   function retrieveLayerAndParallax(index)
      if (index == 1) then
         return foregroundLayer, parallaxLayersData[1].p, parallaxLayersData[1]
      end
      if (index == 2) then
         return backgroundLayer, parallaxLayersData[2].p, parallaxLayersData[2]
      end
   end


end

local ecsWorld = myWorld
function makeObject(url, x, y, depth, allowOptimized)
   local child, optimize = generator.makeThing(url, allowOptimized)

   if optimize then
      child.url = url
   end

   child.depth = depth
   child.transforms.l[1] = x
   child.transforms.l[2] = y

   mesh.meshAll(child)

   if ecsWorld then
      local myEntity = Concord.entity()
      myEntity
          :give('transforms', child.transforms)
          :give('bbox', child.bbox)
          :give('vanillaDraggable')
      ecsWorld:addEntity(myEntity)
      child.entity = myEntity
   end


   return child
end

function scene.load()


   local timeIndex = math.floor(1 + love.math.random() * 24)
   skygradient = gradient.makeSkyGradient(timeIndex)

   if not hasBeenLoaded then

      --cam = createCamera()

      -- these values should be loaded agian and again,
      depthMinMax = { min = -1.0, max = 1.0 }
      foregroundFactors = { far = .5, near = 1 }
      backgroundFactors = { far = .2, near = .5 }
      tileSize = 100


      backgroundFar = generateCameraLayer('backgroundFar', backgroundFactors.far)
      backgroundNear = generateCameraLayer('backgroundNear', backgroundFactors.near)
      foregroundFar = generateCameraLayer('foregroundFar', foregroundFactors.far)
      foregroundNear = generateCameraLayer('foregroundNear', foregroundFactors.near)

      dynamic = generateCameraLayer('dynamic', 1)

      backgroundAssetBook = generateAssetBook({
         urls = createAssetPolyUrls({ 'doosgroot' }),
         index = { min = -100, max = 100 },
         amountPerTile = 10,
         depth = depthMinMax,
      })
      backgroundLayer = makeContainerFolder('backgroundLayer')

      foregroundAssetBook = generateAssetBook({
         urls = createAssetPolyUrls(
            { 'plant1', 'plant2', 'plant3', 'plant4',
               'plant5', 'plant6', 'plant7', 'plant8',
               'plant9', 'plant10', 'plant11', 'plant12',
               'doosgroot', 'doosgroot', 'doosgroot',
               'doosgroot', 'doosgroot', 'doosgroot',
               'plant13', 'bunnyhead', 'walrus', 'teckel_', 'teckel_', 'teckelagain', 'mouse_', 'mouse_', 'vosje_',
               'verken', 'deurpaars', 'deurpaars'
            }),
         index = { min = -400, max = 400 },
         amountPerTile = 1,
         depth = depthMinMax,
      })
      foregroundLayer = makeContainerFolder('foregroundLayer')
      groundPlanes = makeGroundPlaneBook(createAssetPolyUrls({ 'fit1', 'fit2', 'fit3', 'fit4', 'fit5' }))

      if true then

         local cave = makeObject('assets/cavething.polygons.txt', 1000, 0, 0)

         if hit.findHitArea(cave) then
            cave.entity:give('hitAreaEvent')
         end
         -- todo why is this 1 and not somethign dynamic?
         cave.entity:give('layer', 1)
         table.insert(
            foregroundLayer.children,
            cave
         )

         --recusiveLookForHitArea(node)

         local carbod = makeObject('assets/carbody.polygons.txt', 100, 0, 0, false)
         local wheel1 = makeObject('assets/wielsimpler.polygons.txt', 100, 0, 0)
         local wheel2 = makeObject('assets/wielsimpler.polygons.txt', 100, 0, 0)

         carbod.transforms.l[2] = getGlobalHeight(carbod.transforms.l[1])

         local wheel1Pos = carbod.metaTags[1].points[1]
         wheel1.transforms.l[1] = wheel1Pos[1]
         wheel1.transforms.l[2] = wheel1Pos[2]
         table.insert(carbod.children, wheel1)

         local wheel2Pos = carbod.metaTags[2].points[1]
         wheel2.transforms.l[1] = wheel2Pos[1]
         wheel2.transforms.l[2] = wheel2Pos[2]
         table.insert(carbod.children, wheel2)

         table.insert(foregroundLayer.children, carbod)
         carbod.entity:give('vehicle', carbod, wheel1, wheel2)


         actors = {}


         for i = 1, 10 do
            local depth = love.math.random()
            walterBody = makeObject('assets/walterbody.polygons.txt', 0, 0, depth, false)
            walterLFoot = makeObject('assets/walterhappyfeetleft_.polygons.txt', 0, 0, depth)
            walterRFoot = makeObject('assets/walterhappyfeetright_.polygons.txt', 0, 0, depth)

            walterActor = Actor:create({ body = walterBody, lfoot = walterLFoot, rfoot = walterRFoot })

            walterBody.entity:give('actor', walterActor)
            walterBody.entity:give('biped', walterBody, walterLFoot, walterRFoot)
            walterBody.entity:give('layer', 1)

            table.insert(
               foregroundLayer.children,
               walterActor.body
            )
            table.insert(actors, walterActor)
         end
      end


      parentize.parentize(foregroundLayer)
      parallax.sortOnDepth(foregroundLayer.children)
      mesh.recursivelyAddOptimizedMesh(foregroundLayer)

      parallaxLayersData = {
         {
            layer = foregroundLayer,
            p = { factors = foregroundFactors, minmax = depthMinMax },
            assets = foregroundAssetBook,
            tileBounds = { math.huge, -math.huge },
            layerIndex = 1
         },
         {
            layer = backgroundLayer,
            p = { factors = backgroundFactors, minmax = depthMinMax },
            assets = backgroundAssetBook,
            tileBounds = { math.huge, -math.huge },
            layerIndex = 2
         }
      }
   end
   perspectiveContainer = preparePerspectiveContainers({ 'foreground', 'background' })

   setCameraViewport(cam, 400, 400)
   hasBeenLoaded = true
   attachPointerCallbacks()

end

function scene.update(dt)
   if love.keyboard.isDown('p') then
      print(inspect(walter.metaTags))
   end

   manageCameraTween(dt)
   cam:update()

   cameraApplyTranslate(dt, foregroundLayer)

   if bouncetween then
      bouncetween:update(dt)
   end

   handlePressedItemsOnStage(dt, parallaxLayersData, myWorld)

   myWorld:emit("update", dt)

end

function scene.draw()

   love.graphics.clear(1, 1, 1)
   love.graphics.setColor(1, 1, 1)
   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   drawGroundPlaneWithTextures(cam, 'backgroundFar', 'backgroundNear', 'background')
   drawGroundPlaneWithTextures(cam, 'foregroundFar', 'foregroundNear', 'foreground')


   parallax.setDynamicThing(parallaxLayersData[2].p)
   arrangeParallaxLayerVisibility('backgroundFar', parallaxLayersData[2], myWorld)
   cam:push()
   render.renderThings(backgroundLayer)
   cam:pop()


   parallax.setDynamicThing(parallaxLayersData[1].p)
   arrangeParallaxLayerVisibility('foregroundFar', parallaxLayersData[1], myWorld)
   cam:push()
   render.renderThings(foregroundLayer)
   cam:pop()

   love.graphics.setColor(1, 1, 1)

   drawDebugStrings()
   drawBBoxAroundItems(foregroundLayer, parallaxLayersData[1].p)
   drawBBoxAroundItems(backgroundLayer, parallaxLayersData[2].p)

   --  myWorld:emit("draw")



end

return scene
