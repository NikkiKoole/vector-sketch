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

Concord.component("foregroundObject")
Concord.component("backgroundObject")
Concord.component("vanillaDraggable")
Concord.component("hitAreaEvent")

Concord.component(
   'biped',
   function(c, body, lfoot, rfoot)
      c.body = body
      c.lfoot = lfoot
      c.rfoot = rfoot
   end
)

Concord.component(
   'actor',
   function(c, value)
      c.value = value
   end
)

Concord.component(
   'transforms',
   function(c, value)
      c.transforms = value
   end
)
Concord.component(
   'bbox',
   function(c, value)
      c.bbox = value
   end
)

Concord.component(
   'assetBook',
   function(c, ref, index)
      c.ref = ref
      c.index = index
   end
)

Concord.component(
   'inMotion',
   function(c, mass, velocity, acceleration)
      c.mass = mass
      c.velocity = velocity or Vector(0,0)
      c.acceleration = acceleration or Vector(0,0)
   end
)

local GravitySystem = Concord.system({pool={'inMotion'}})
function GravitySystem:update(dt)
   for _, e in ipairs(self.pool) do
      local gy = uiState.gravityValue * e.inMotion.mass * dt
      local gravity = Vector(0, gy)
      applyForce(e.inMotion, gravity)
   end
end

local InMotionSystem = Concord.system({pool={'inMotion', 'transforms'}})
function InMotionSystem:update(dt)
   -- applying half the velocity before position
   -- other half after positioning
   --https://web.archive.org/web/20150322180858/http://www.niksula.hut.fi/~hkankaan/Homepages/gravity.html

   for _, e in ipairs(self.pool) do

      local transforms = e.transforms.transforms

      e.inMotion.velocity = e.inMotion.velocity + e.inMotion.acceleration/2

      transforms.l[1] = transforms.l[1] + (e.inMotion.velocity.x * dt)
      transforms.l[2] = transforms.l[2] + (e.inMotion.velocity.y * dt)

      e.inMotion.velocity = e.inMotion.velocity + e.inMotion.acceleration/2
      e.inMotion.acceleration = e.inMotion.acceleration * 0

      -- temp do the floor
      local bottomY = 0
      if e.actor then
--         print(inspect(e.actor.value.leglength))
         bottomY = -e.actor.value.body.leglength
      end

      if transforms.l[2] >= bottomY then
         transforms.l[2] = bottomY
         e:remove('inMotion')

         if e.actor then
            e.actor.value.originalX = transforms.l[1]
            e.actor.value.originalY = transforms.l[2]
         end

      end


   end
end

function InMotionSystem:itemThrow(target, dxn, dyn, speed)
  -- print('item throw')
   --print(target.entity)
   target.entity
      :ensure('inMotion', 1)

   local mass = target.entity.inMotion.mass

   local throwStrength = 1
   if mass < 0 then throwStrength = throwStrength / 100 end

   local impulse = Vector(dxn * speed * throwStrength ,
                          dyn * speed * throwStrength )

--   print('impulse', inspect(impulse))

   applyForce(target.entity.inMotion, impulse)
   --applyForce(target.inMotion, impulse)

end
------------------------

local BipedSystem = Concord.system({pool={'biped', 'actor'}})

function BipedSystem:update(dt)
   -- todo
   -- what exactly is that originalX originalY ?
   -- try and just use biped or actor, not both
   -- get rid of all functions on Actor

   for _, e in ipairs(self.pool) do


      if(not e.biped.body.pressed and e.actor.value.wasPressed) then
	 e.actor.value.wasPressed = false
         local oldLeftFootY = e.biped.lfoot.transforms.l[2]
         local oldLeftFootX = e.biped.lfoot.transforms.l[1]

	 e.actor.value:straightenLegs()

         local newLeftFootY = e.biped.lfoot.transforms.l[2]
         local newLeftFootX = e.biped.lfoot.transforms.l[1]

         local dy = oldLeftFootY- newLeftFootY
         local dx = oldLeftFootX- newLeftFootX


         if dy ~= 0 or dx ~= 0 then
	    myWorld:emit("itemThrow", e.biped.body, dx, dy, 11)
         end

      end

      if (e.biped.body.pressed) then
	 e.actor.value.wasPressed = true
	 setTransforms(e.biped.body)

	 local pivx = e.biped.body.transforms.l[6]
	 local pivy = e.biped.body.transforms.l[7]
	 local px,py = e.biped.body.transforms._g:transformPoint(pivx, pivy)

	 local dist = (math.sqrt((px - e.actor.value.originalX)^2 + (py - e.actor.value.originalY)^2   ))

	 local tooFar = dist > (e.actor.value.leglength / e.actor.value.magic)
	 if tooFar then
	    e.actor.value.originalX = e.biped.body.transforms.l[1]
	    e.actor.value.originalY = e.biped.body.transforms.l[2]
	 end


	 if py <= -e.biped.body.leglength then
	    --print('oo!')
	 else
	    --print('need to do the rubbering!')

	    e.biped.lfoot.transforms.l[2] = e.actor.value.leg1_connector.points[1][2] - py --+ self.originalY
	    e.biped.lfoot.transforms.l[1] = e.actor.value.leg1_connector.points[1][1] - px + e.actor.value.originalX

	    e.biped.rfoot.transforms.l[2] = e.actor.value.leg2_connector.points[1][2] - py --+ self.originalY
	    e.biped.rfoot.transforms.l[1] = e.actor.value.leg2_connector.points[1][1] - px + e.actor.value.originalX



	    e.biped.body.generatedMeshes = {}

	    e.actor.value:oneLeg(e.actor.value.leg1_connector, e.biped.lfoot.transforms, -1)
	    e.actor.value:oneLeg(e.actor.value.leg2_connector, e.biped.rfoot.transforms, 1)

	 end

      end

   end

end

-----------------------
Concord.component(
   'wheelCircumference',
    function(c, value)
      c.value = value
   end
)

Concord.component(
   'rotatingPart',
    function(c, value)
      c.value = value
   end

)

local WheelSystem = Concord.system({pool = {'wheelCircumference', 'rotatingPart'}})
function WheelSystem:itemDrag( c, l, x, y, invx, invy)
   --print(c.entity and c.entity.wheelCircumference)
   if (c.entity and c.entity.wheelCircumference and c.pressed) then

      local rotateStep = invx - c.pressed.dx
      --print(invx - c.pressed.dx)
	local rx, ry = c.transforms._g:transformPoint( rotateStep, 0)
	local rx2, ry2 = c.transforms._g:transformPoint( 0, 0)
	local rxdelta = rx - rx2


	c.entity.rotatingPart.value.transforms.l[3] = c.entity.rotatingPart.value.transforms.l[3]  +
	   (rxdelta/c.entity.wheelCircumference.value)*(math.pi*2)


	c.transforms.l[1] = c.transforms.l[1] + rotateStep
	--print('the new one')

   end


end



local TransformSystem = Concord.system({pool = {'transforms'}})
function TransformSystem:update(dt)
   --print(#self.pool)
   --for _, e in ipairs(self.pool) do
   --end
end


local DraggableSystem = Concord.system({pool = {'transforms', 'bbox', 'vanillaDraggable'}})
function DraggableSystem:update(dt)
   --print(#self.pool)
   --for _, e in ipairs(self.pool) do
   --end
end
function DraggableSystem:itemDrag( c, l, x, y, invx, invy)

   if (c.entity and c.entity.vanillaDraggable and c.pressed) then
      --print('vanilla drag')
      c.transforms.l[1] = c.transforms.l[1] + (invx - c.pressed.dx)
      c.transforms.l[2] = c.transforms.l[2] + (invy - c.pressed.dy)
   end
end

function DraggableSystem:pressed(x,y)
   --print('pressed', x, y, #self.pool)
   --for _, e in ipairs(self.pool) do
   --end
end

local HitAreaEventSystem = Concord.system({pool={'hitAreaEvent'}})
function HitAreaEventSystem:itemPressed(item, l, x,y, hitcheck)
   if item.entity and item.entity.hitAreaEvent then
      eventBus(hitcheck)
   end
end


local AssetBookSystem = Concord.system({pool = {'assetBook'}})
function AssetBookSystem:itemPressed(item, l, x,y)
   if item.entity and item.entity.assetBook then
         local first = item.entity.assetBook.index
         if first ~= nil and l.assets[first]  then
            local index = 0
            for k =1 , #l.assets[first] do
               if l.assets[first][k] == item.entity.assetBook.ref then
                  index = k
               end
            end
            if index > 0 then
               table.remove(l.assets[first], index)
               item.entity:remove('assetBook')
            end
         end
   end
end

myWorld:addSystems(
   AssetBookSystem,
   GravitySystem,
   InMotionSystem,
   TransformSystem,
   DraggableSystem,
   BipedSystem,
   WheelSystem,
   HitAreaEventSystem
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
         pointerPressed(x,y, 'mouse', parallaxLayersData, myWorld)
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
      lastDraggedElement = nil
      if not istouch then
         pointerReleased(x,y, 'mouse', parallaxLayersData, myWorld)
      end
   end
   function love.touchreleased(id, x, y, dx, dy, pressure)
      pointerReleased(x,y, id, parallaxLayersData, myWorld)
   end
   function eventBus(event)
      if event == 'door-hitarea' then
	 -- tween camera to cave opening
	 -- go into cave
	 SM.load("cave")
      end


   end

end

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
            amountPerTile=0,
            depth=depthMinMax,
      })
      backgroundLayer = makeContainerFolder('backgroundLayer')

      foregroundAssetBook = generateAssetBook({
            urls= createAssetPolyUrls(
               { 'plant1','plant2','plant3','plant4',
                  'plant5','plant6','plant7','plant8',
                  'plant9','plant10','plant11','plant12',
                 'plant13','bunnyhead', 'deurpaars', 'deurpaars'
            }),
            index={min=-100, max= 100},
            amountPerTile=2,
            depth=depthMinMax,
      })
      foregroundLayer = makeContainerFolder('foregroundLayer')


      groundPlanes = makeGroundPlaneBook(createAssetPolyUrls({'fit1', 'fit2', 'fit3', 'fit4', 'fit5'}))


      --generateRandomPolysAndAddToContainer(30, foregroundFactors, foregroundLayer)

      -- todo alot of duplication from removeAddItems
      local ecsWorld = myWorld
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
        -- print(inspect(child.bbox),x,y)
         meshAll(child)

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

      function makeWheel(thing, circumference)
         thing.wheelCircumference = circumference
	 return thing
      end



      local cave = makeObject('assets/cavething.polygons.txt', 1000,0, 0)

      if recusiveLookForHitArea(cave) then
	 cave.entity:give('hitAreaEvent')
      end

      table.insert(
         foregroundLayer.children,
         cave
      )

      --recusiveLookForHitArea(node)


      local wheel = makeObject('assets/wiel.polygons.txt', 100,0, 0)
      wheel.entity:give('wheelCircumference', 282)
      wheel.entity:give('rotatingPart', wheel.children[1])
      wheel.entity:remove('vanillaDraggable')

      table.insert(foregroundLayer.children, wheel)
      --table.insert(
      --   backgroundLayer.children,
      --   makeWheel(makeObject('assets/wiel.polygons.txt', 100,0, -1), 282)
     -- )
      --table.insert(
      --   foregroundLayer.children,
      --   makeWheel(makeObject('assets/wiel.polygons.txt', 100,0, 1), 282)
     -- )
      --table.insert(
       --  foregroundLayer.children,
       --  makeWheel(makeObject('assets/wiel.polygons.txt', 100,0, -1), 282)
     -- )

      -- table.insert(
      --    foregroundLayer.children,
      --    makeObject('assets/walterhappyfeetleft_.polygons.txt', 0,0, 0)
      -- )
      -- table.insert(
      --    foregroundLayer.children,
      --    makeObject('assets/walterhappyfeetright_.polygons.txt', 0,0, 0)
      -- )

      actors  = {}
      for i = 1, 1 do
         walterBody =  makeObject('assets/walterbody.polygons.txt', 0,0,love.math.random(), false)
	 walterLFoot =  makeObject('assets/walterhappyfeetleft_.polygons.txt', 0,0, 0)
	 walterRFoot =  makeObject('assets/walterhappyfeetright_.polygons.txt', 0,0, 0)

         print(walterBody.entity)

         walterBody.hasDraggableChildren = true
         walterLFoot.isDraggableChild = true
         walterRFoot.isDraggableChild = true
--         walterBody.transforms.l[2]=-100

	 walterActor = Actor:create({body=walterBody, lfoot=walterLFoot, rfoot=walterRFoot})

         walterBody.entity:give('actor', walterActor)

         walterBody.entity:give('biped', walterBody, walterLFoot, walterRFoot)

--         walterActor.body.actorRef = walterActor
	 table.insert(
	    foregroundLayer.children,
	    walterActor.body
	 )
	 -- table.insert(
	 --    foregroundLayer.children,
	 --    walterLFoot
	 -- )

	 table.insert(actors, walterActor)
      end

      parentize(foregroundLayer)
      sortOnDepth(foregroundLayer.children)
      recursivelyAddOptimizedMesh(foregroundLayer)

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


   --print(inspect(foregroundLayer.children[1]))
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

   --updateMotionItems(foregroundLayer, dt)
   --updateMotionItems(backgroundLayer, dt)

   handlePressedItemsOnStage(dt, parallaxLayersData, myWorld)

   --for i = 1, #foregroundLayer.children do
      --if not foregroundLayer.children[i].pressed then
      --foregroundLayer.children[i].transforms.l[3] = foregroundLayer.children[i].transforms.l[3] + 0.01
      --end
   --end
   --for i=1, #actors do
   --   actors[i]:update(dt)
   --end


   myWorld:emit("update", dt)

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
