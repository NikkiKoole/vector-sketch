local numbers = require 'lib.numbers'
local hit = require 'lib.hit'

function getPointerPosition(id)
   local x, y
   if id == 'mouse' then
      x, y = love.mouse.getPosition()
      return x,y,true
   else
      local touches =  love.touch.getTouches()
      for i = 1, #touches do
	 if touches[i] == id then
	    x,y = love.touch.getPosition( id )
	    return x,y, true
	 end
      end
   end
   return nil,nil,false
end


function addGesturePoint(gesture, time, x,y)
   assert(gesture)
   table.insert(gesture.positions, {time=time, x=x, y=y})
end


function removeGestureFromList(gesture)
   --local found = false
   for i = #gestureState.list, 1, -1 do
      if gestureState.list[i] == gesture then
         table.remove(gestureState.list, i)
         --found = true
      end
   end
end



function updateGestureCounter(dt)
   gestureState.updateResolutionCounter = gestureState.updateResolutionCounter + dt

   if gestureState.updateResolutionCounter > gestureState.updateResolution then
      gestureState.updateResolutionCounter = 0
      for i = 1, #gestureState.list do
         local g = gestureState.list[i]
         local x,y, success = getPointerPosition(g.trigger)
	 if success then
	    addGesturePoint(g, love.timer.getTime( ), x, y)
	 end
      end
   end
end



function drawBBoxAroundItems(layer, parallaxData)
   for i = 1, #layer.children do
      local c = layer.children[i]


      if c.bbox and c.transforms._l and c.depth ~= nil then

         if c.pressed then
            local mx, my = getPointerPosition(c.pressed.id)
	    local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my,c, parallaxData)
            --print(tlx, tly, brx, bry)
            love.graphics.setColor(1,1,1,.5)

            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)

	    love.graphics.setColor(1,1,1,1)
	    local px, py = c.transforms._g:transformPoint( c.transforms.l[6], c.transforms.l[7])

            local camData = createCamData(c, parallaxData)
	    local pivx, pivy = cam:getScreenCoordinates(px, py, camData)
	    love.graphics.line(pivx-5, pivy, pivx+5, pivy)
	    love.graphics.line(pivx, pivy-5, pivx, pivy+5)

            local checkAgainst = getItemsInLayerThatHaveMeta(layer, c)

            for j =1, #checkAgainst do
               for k = 1, #checkAgainst[j].metaTags do
                  local tag = checkAgainst[j].metaTags[k]
                  local pos = tag.points[1] -- there is just one point in this collection
                  local kx, ky = checkAgainst[j].transforms._g:transformPoint(pos[1], pos[2])
                  local camData = createCamData(checkAgainst[j], parallaxData)
                  local kx2, ky2 = cam:getScreenCoordinates(kx, ky, camData)
		  love.graphics.setColor(1,1,1,.2)
                  love.graphics.line(pivx, pivy, kx2, ky2)
               end
            end

         end

	 if c.mouseOver or uiState.showBBoxes then
	    local mx, my = getPointerPosition('mouse')
	    local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c, parallaxData)
	    love.graphics.setColor(1,1,1,.5)
            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)
	 end
      end
   end
end


function pointerPressed(x,y, id, layers)

   -- local W, H = love.graphics.getDimensions()

   -- ------------ begin ui
   -- local leftdis = getDistance(x,y, 50, (H/2)-25)
   -- local rightdis = getDistance(x,y, W-50, (H/2)-25)
   -- local toprightdis = getDistance(x,y, W-25, 25)

   -- if uiState.showWalkButtons then
   -- if leftdis < 50 then
   --    moving = 'left'
   -- end
   -- if rightdis < 50 then
   --    moving = 'right'
   -- end
   -- end
   -- if toprightdis < 50 then
   --    --showNumbersOnScreen = not showNumbersOnScreen
   --    uiState.show = not uiState.show
   -- end
   -- ------------- end ui


   local itemPressed = false

   for j =#layers, 1 , -1 do
      local l = layers[j]

      for i = #l.layer.children,1,-1 do
         local c = l.layer.children[i]


         if c.bbox and c.transforms._l and c.depth and not itemPressed then

            local mouseover, invx, invy = mouseIsOverItemBBox(x,y, c, l.p)
            if mouseover then
               local justBBoxCheck = false
	       local hitcheck =  mouseIsOverObjectInCamLayer(x, y, c, l.p)
               if (justBBoxCheck == true or hitcheck) then

--                  c.groundTileIndex = nil
--                  local indices = c.originalIndices
                  local first = c.assetBookIndex
		  -- todo ouch i dunno about this
                  if first and l.assets[first]  then
                     --l.assets[indices[1]][indices[2]].hasBeenPressed = true

                     local index = 0
                     for k =1 , #l.assets[first] do
                        if l.assets[first][k] == c.assetBookRef then
                           index = k
                        end
                     end
                     if index > 0 then
                        table.remove(l.assets[first], index)
                        c.assetBookRef = nil
                     end
                     
                     
                  end
		  if type(hitcheck) == 'string' then
		     eventBus(hitcheck)
		     return
		     --print('what kind of magic -hitarea action we want? ', hitcheck)
		  else

		     c.pressed = {dx=invx, dy=invy, id=id}
		     itemPressed = c
		  end

               end
            end

         end
      end

   end

   if not itemPressed  then
      if not cameraFollowPlayer then

         local hasOneAlready = false
         for i =1, #gestureState.list do
            if gestureState.list[i].target == 'stage' then
               hasOneAlready = true
            end
         end

         if not hasOneAlready then
            local g = {positions={}, target='stage', trigger=id}
            table.insert(gestureState.list, g)
            addGesturePoint(g, love.timer.getTime( ),x,y)
         end
      end
   else
      resetCameraTween()

      local g = {positions={}, target=itemPressed, trigger=id}
      table.insert(gestureState.list, g)
      addGesturePoint(g, love.timer.getTime( ),x,y)
   end
end


function checkForItemMouseOver(x,y, layer, parallaxData)
   for i = 1, #layer.children do
      local c = layer.children[i]
      if c.bbox and c.transforms._l and c.depth then
         local mouseover, invx, invy = mouseIsOverItemBBox(x, y, c, parallaxData)
         c.mouseOver = mouseover
      end
   end
end



function pointerMoved(x,y,dx,dy, id, layers)

   if (id == 'mouse') then
      for i =1 , #layers do
         local l = layers[i]
         checkForItemMouseOver(x,y,l.layer, l.p)
      end
   end


   if (id == 'mouse' and love.mouse.isDown(1) ) or id ~= 'mouse' then

      resetCameraTween()

      for i = 1, #gestureState.list do
	 local g = gestureState.list[i]
	 if g.target == 'stage' and g.trigger == id then
	    local scale = cam:getScale()

	    local xAxisAllowed = true
	    local xAxis =xAxisAllowed and  -dx/scale or 0
	    local yAxisAllowed = false
	    local yAxis =yAxisAllowed and  -dy/scale or 0

	    cameraTranslateScheduler(xAxis, yAxis)
	 end
      end
   end
end


function pointerReleased(x,y, id, layers)
   moving = nil

   for j =1, #layers do
      for i = 1, #layers[j].layer.children do
         local c =layers[j].layer.children[i]
         if c.pressed and c.pressed.id == id then
            c.pressed = nil
         end
      end
   end

   for i = #gestureState.list, 1, -1 do
      local g = gestureState.list[i]
      if g then
	 if g.trigger == id then
	    addGesturePoint(g, love.timer.getTime( ), x, y)
	    gestureRecognizer(g)
	    removeGestureFromList(g)
	 end
      end
   end
end




function getItemsInLayerThatHaveMeta(layer, me)
   local result = {}
   for i = 1, #layer.children do
      local child = layer.children[i]
      if child.metaTags and child ~= me then
         table.insert(result, child)
      end
   end
   return result
end



function handlePressedItemsOnStage(dt, layers)
   local W, H = love.graphics.getDimensions()
   for j = 1, #layers do
      local l=layers[j]
      for i = 1, #l.layer.children do
         local c = l.layer.children[i]

	
	 if c.pressed then
	    c.dirty = true
	    if c._parent then 
	       c._parent.dirty = true
	    end

	     --print(c.folder)
	 end
	 
	 
         if c.bbox and c.transforms._l and c.depth ~= nil then
            if c.pressed  then


               --print(inspect(c.bbox))

               local mx, my = getPointerPosition(c.pressed.id)
               local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c, l.p)
               if c.pressed then
		  c.dirty = true
                  -- todo make these thing parameters

                  if c.hasDraggableChildren then -- aka feet
                     if c.actorRef then

                     end

                  end

                  if c.wheelCircumference then
                     -- todo calculate the amount of rotating

                     local rotateStep = ( (invx - c.pressed.dx) )
		     local rx, ry = c.transforms._g:transformPoint( rotateStep, 0)
		     local rx2, ry2 = c.transforms._g:transformPoint( 0, 0)
		     local rxdelta = rx - rx2

                     if math.abs(rotateStep) > 0.00001 then

                        c.children[1].transforms.l[3] =  c.children[1].transforms.l[3] + (rxdelta/c.wheelCircumference)*(math.pi*2)
                     end

                     c.transforms.l[1] = c.transforms.l[1] + (invx - c.pressed.dx)

                  else
                     c.transforms.l[1] = c.transforms.l[1] + (invx - c.pressed.dx)
                     c.transforms.l[2] = c.transforms.l[2] + (invy - c.pressed.dy)

                  end





                  --end
                  local speed = 300
                  if ((brx + offset) > W) then
                     resetCameraTween()
                     cameraTranslateScheduler(speed*dt, 0)
                  end
                  if ((tlx - offset) < 0) then
                     resetCameraTween()
                     cameraTranslateScheduler(-speed*dt, 0)
                  end



               end
            end
         end
      end
   end
end



function getScreenBBoxForItem(c, camData)

   -- todo allways create a new bbox to be sure
   -- local bbox = getBBoxRecursive(c)
   -- local tlx, tly = c.transforms._g:inverseTransformPoint(bbox[1], bbox[2])
   -- local brx, bry = c.transforms._g:inverseTransformPoint(bbox[3], bbox[4])

   -- c.bbox = {tlx, tly, brx, bry }--bbox



   local tx, ty = c.transforms._g:transformPoint(c.bbox[1],c.bbox[2])
   local tlx, tly = cam:getScreenCoordinates(tx, ty, camData)
   local bx, by = c.transforms._g:transformPoint(c.bbox[3],c.bbox[4])
   local brx, bry = cam:getScreenCoordinates(bx, by, camData)

   return tlx,tly,brx,bry

   --return math.min(tlx, brx), math.min(tly, bry),
   --   math.max(brx, tlx), math.max(bry, tly)
end

function createCamData(item, parallaxData)
   local camData = nil -- its important to be nil at start
   -- that way i can feed the nil to brady and get default behaviours
   if parallaxData and parallaxData.factors then

      camData = {}
      camData.scale = numbers.mapInto(item.depth,
                              parallaxData.minmax.min,
                              parallaxData.minmax.max,
                              parallaxData.factors.far,
                              parallaxData.factors.near)
      camData.relativeScale = 1--(1.0/ hack.scale) * hack.scale
   end
   if camData == nil then
      print('hope you know')
   end

   return camData
end


-- this function is only for nested children of a thing, as for FEET
function mouseIsOverItemChildBBox(mx, my, item, child, parallaxData)
   local camData = createCamData(child, parallaxData)
   local tlx, tly, brx, bry = getScreenBBoxForItem(child, camData)
   local wx, wy = cam:getWorldCoordinates(mx, my, camData)
   local invx, invy = item.transforms._g:inverseTransformPoint(wx, wy)

   return hit.pointInRect(mx, my, tlx, tly, brx-tlx, bry-tly), invx, invy, tlx, tly, brx, bry
end

function mouseIsOverItemBBox(mx, my, item, parallaxData)

   local camData = createCamData(item, parallaxData)
   local tlx, tly, brx, bry = getScreenBBoxForItem(item, camData)
   local wx, wy = cam:getWorldCoordinates(mx, my, camData)
   local invx, invy = item.transforms._g:inverseTransformPoint(wx, wy)

   return hit.pointInRect(mx, my, tlx, tly, brx-tlx, bry-tly), invx, invy, tlx, tly, brx, bry
end

function mouseIsOverObjectInCamLayer(mx, my, item, parallaxData)
   local camData = createCamData(item, parallaxData)
   local mx2, my2 = cam:getWorldCoordinates(mx, my, camData)
   local hit = recursiveHitCheck(mx2, my2, item)
   return hit
end


function gestureRecognizer(gesture)
   if #gesture.positions > 1 then
      local startP = gesture.positions[1]
      local endP = gesture.positions[#gesture.positions]
      local gestureLength = 3
      if (#gesture.positions > gestureLength) then
	 startP = gesture.positions[#gesture.positions - gestureLength]
      end

      local dx = endP.x - startP.x
      local dy = endP.y - startP.y
      local distance = math.sqrt(dx*dx+dy*dy)
      local deltaTime = endP.time - startP.time
      local speed = distance / deltaTime

      if gesture.target == 'stage' then
	 local minSpeed = 200
	 local maxSpeed = 15000
	 local minDistance = 6
	 local minDuration = 0.005

	 local xAxisAllowed = true
	 local yAxisAllowed = false

	 if deltaTime > minDuration then
	    local doTween = false
	    local cx,cy = cam:getTranslation()
	    local xAxis = cx
	    local yAxis = cy

	    if xAxisAllowed then
	       if math.abs(dx) > minDistance then
		  if math.abs(dx/deltaTime) >= minSpeed and  math.abs(dx/deltaTime) < maxSpeed then
		     doTween = true
		     local mx = dx < 0 and -1 or 1
		     xAxis = cx -((dx) + (mx* speed/7.5) )
		  end
	       end
	    end

	    if yAxisAllowed then
	       if math.abs(dy) > minDistance then
		  if math.abs(dy/deltaTime) >= minSpeed and  math.abs(dy/deltaTime) < maxSpeed then
		     doTween = true
		     local my = dy < 0 and -1 or 1
		     yAxis = cy -((dy) + (my* speed/7.5) )
		  end
	       end
	    end

	    if doTween then
	       cameraTween = {
		  goalX=xAxis,
		  goalY=yAxis,
		  smoothValue=3.5,
		  originalGesture=gesture
	       }
	    end
	 else
	    --print('failed at distance')
	 end
      else -- this is gesture target something else, items basically!

	 if distance < 0.00001 then
	    distance = 0.00001
	 end
	 local  dxn = dx / distance
	 local  dyn = dy / distance

	 gesture.target.inMotion = makeMotionObject()
         local mass = gesture.target.inMotion.mass

	 local throwStrength = 1
         if mass < 0 then throwStrength = throwStrength / 100 end

         local impulse = Vector(dxn * speed * throwStrength ,
                                dyn * speed * throwStrength )

	 applyForce(gesture.target.inMotion, impulse)
      end
   end
end
