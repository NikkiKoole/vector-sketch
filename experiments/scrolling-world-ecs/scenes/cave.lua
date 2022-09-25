local scene = {}
local hasBeenLoaded = false

local render = require 'lib.render'
local gradient = require 'lib.gradient'
--local cam = getCamera()
local cam = require('lib.cameraBase').getInstance()
function scene.modify(obj)
end

function scene.load()
   font = love.graphics.newFont("assets/adlib.ttf", 32)

   love.graphics.setFont(font)
   local timeIndex = math.floor(1 + love.math.random() * 24)

   local timeIndex = math.floor(1 + love.math.random() * 24)
   skygradient = gradient.makeSkyGradient(timeIndex)


   if not hasBeenLoaded then
      depthMinMax = { min = -1.0, max = 1.0 }
      foregroundFactors = { far = .5, near = 1 }
      foregroundFar = generateCameraLayer('foregroundFar', foregroundFactors.far)
      foregroundNear = generateCameraLayer('foregroundNear', foregroundFactors.near)

      foregroundAssetBook2 = generateAssetBook({
         urls = createAssetPolyUrls(
            { 'plant1', 'plant2', 'plant3', 'plant4',
               'plant5', 'plant6', 'plant7', 'plant8',
               'plant9', 'plant10', 'plant11', 'plant12',
               'plant13', 'deurpaarser2', 'doosgroot', 'doosgroot',
            }),
         index = { min = -100, max = 100 },
         amountPerTile = 10,
         depth = depthMinMax,
      })
      foregroundLayer2 = makeContainerFolder('foregroundLayer')
      groundPlanes = makeGroundPlaneBook(createAssetPolyUrls({ 'fit1', 'fit2', 'fit3', 'fit4', 'fit5' }))

      parallaxLayersData2 = {
         {
            layer = foregroundLayer2,
            p = { factors = foregroundFactors, minmax = depthMinMax },
            assets = foregroundAssetBook2,
            tileBounds = { math.huge, -math.huge },
         }
      }

   end
   perspectiveContainer = preparePerspectiveContainers({ 'foreground' })


   setCameraViewport(cam, 300, 300)
   hasBeenLoaded = true
end

function scene.update(dt)
   function love.keypressed(key, unicode)
      if key == 'escape' then love.event.quit() end
      SM.load("world")
   end

   function love.touchpressed(key, unicode)
      --      if key == 'escape' then love.event.quit() end
      SM.load("world")
   end

   function love.mousepressed(key, unicode)
      --      if key == 'escape' then love.event.quit() end
      SM.load("world")
   end

end

function scene.draw()
   love.graphics.clear(1, 1, 1)
   love.graphics.setColor(1, 1, 1)

   love.graphics.draw(skygradient, 0, 0, 0, love.graphics.getDimensions())

   love.graphics.setColor(0, 0, 0)
   love.graphics.print("This is the cave, press any key to go back to the world.", 10, 10)

   drawGroundPlaneWithTextures(cam, 'foregroundFar', 'foregroundNear', 'foreground')
   arrangeParallaxLayerVisibility('foregroundFar', parallaxLayersData2[1])
   cam:push()
   GLOBALS.parallax = { camera = dynamic, p = parallaxLayersData2[1].p }
   render.renderThings(foregroundLayer2)
   cam:pop()

end

return scene
