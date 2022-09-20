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
   for i = #gestureState.list, 1, -1 do
      if gestureState.list[i] == gesture then
         table.remove(gestureState.list, i)
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
   local max = math.max
   local min = math.min

   for i = 1, #layer.children do
      local c = layer.children[i]


      if c.bbox and c.transforms._l and c.depth ~= nil then

         if c.pressed then
            local mx, my = getPointerPosition(c.pressed.id)
	    local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my,c, parallaxData)
	    
            love.graphics.setColor(1,0,0,1)
            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)

            love.graphics.setColor(1,0,1,1)
            local minx= min(tlx,brx)
            local miny= min(tly,bry)
            local maxx= max(tlx,brx)
            local maxy= max(tly,bry)
--            print(minx, miny, maxx,maxy, maxx-minx, maxy-miny)
            love.graphics.rectangle('line', minx, miny, maxx-minx, maxy-miny)

            
	    
	    love.graphics.setColor(1,1,1,1)
	    local px, py = c.transforms._g:transformPoint( c.transforms.l[6], c.transforms.l[7])
            local camData = createCamData(c, parallaxData)
	    local pivx, pivy = cam:getScreenCoordinates(px, py, camData)
	    love.graphics.line(pivx-5, pivy, pivx+5, pivy)
	    love.graphics.line(pivx, pivy-5, pivx, pivy+5)

	    

            -- local checkAgainst = getItemsInLayerThatHaveMeta(layer)

            -- for j =1, #checkAgainst do
            --    for k = 1, #checkAgain st[j].metaTags do
            --       local tag = checkAgainst[j].metaTags[k]

	    -- 	  if (tag.name == 'connector' and checkAgainst[j] ~= c) then
	    -- 	     local pos = tag.points[1] -- there is just one point in this collection
	    -- 	     local kx, ky = checkAgainst[j].transforms._g:transformPoint(pos[1], pos[2])
	    -- 	     local camData = createCamData(checkAgainst[j], parallaxData)
	    -- 	     local kx2, ky2 = cam:getScreenCoordinates(kx, ky, camData)
	    -- 	     love.graphics.setColor(1,1,1,.2)
	    -- 	     love.graphics.line(pivx, pivy, kx2, ky2)
	    -- 	  end
            --    end
            -- end

         end

	 if false and c.mouseOver or uiState.showBBoxes then
	    local mx, my = getPointerPosition('mouse')
	    local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c, parallaxData)
	    love.graphics.setColor(1,1,1,.5)
            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)
	 end
      end
   end
end


function pointerPressed(x,y, id, layers, ecsWorld)
   local itemPressed = false

   for j =1, #layers do
      local l = layers[j]

      for i = #l.layer.children,1,-1 do
         local c = l.layer.children[i]
         
         if c.bbox and c.transforms._l and c.depth and not itemPressed then

            local mouseover, invx, invy = mouseIsOverItemBBox(x,y, c, l.p)
            if mouseover then
               local justBBoxCheck = false
	       local hitcheck =  mouseIsOverObjectInCamLayer(x, y, c, l.p)
               if (justBBoxCheck == true or hitcheck) then
                  if ecsWorld then
                     ecsWorld:emit("itemPressed", c, l, x, y, hitcheck)
                  end
		  --
		  --print('pressed')
		  c.pressed = { id=id}
		  itemPressed = c

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



function pointerMoved(x,y,dx,dy, id, layers, ecsWorld)

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

	    --local xAxisAllowed = true
	    local xAxis =xAxisAllowed and  -dx/scale or 0
	    --local yAxisAllowed = true
	    local yAxis =yAxisAllowed and  -dy/scale or 0
	    cameraTranslateScheduler(xAxis, yAxis)
	 end
      end
   end

   -- if items are pressed i have the id that caused thta,
   -- in here i know the id of the moved pointer so that ought to be enouigh
   for j =1, #layers do
      local l = layers[j]

      for i = #l.layer.children,1,-1 do
         local c = l.layer.children[i]
	 if c.pressed and c.pressed.id == id then
	    -- this works correctly ( \0/ )  I just need to scale it 
	    if ecsWorld then
	       local scale = cam:getScale()
	       local lc = createCamData(c, l.p)
	       ecsWorld:emit("itemDrag", c, l, x, y, dx/lc.scale/scale, dy/lc.scale/scale)
	     end
	 end
	 
      end
   end
   
end


function pointerReleased(x,y, id, layers, ecsWorld)
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
	 if g.trigger == id  then
	    addGesturePoint(g, love.timer.getTime( ), x, y)
--            if g.target ~= 'stage' then    -----  ----------------  hackerdesnack
            gestureRecognizer(g, ecsWorld)
  --          end
            --print(g.target)
	    removeGestureFromList(g)
	 end
      end
   end
end




function getItemsInLayerThatHaveMeta(layer)
   local result = {}
   for i = 1, #layer.children do
      local child = layer.children[i]
      if child.metaTags then
         table.insert(result, child)
      end
   end
   return result
end
function getItemsInLayerThatHaveSpecificMeta(layer, metaName)
   local result = {}
   for i = 1, #layer.children do
      local child = layer.children[i]
      if child.metaTags then
	 for j = 1, #child.metaTags do
	    if child.metaTags[j].name == metaName then
	       table.insert(result, child)
	    end
	    
	 end
	 
      end
   end
   return result
end


function handlePressedItemsOnStage(dt, layers, ecsWorld)
   local W, H = love.graphics.getDimensions()
   for j = 1, #layers do
      local l=layers[j]
      for i = 1, #l.layer.children do
         local c = l.layer.children[i]

	 if c.pressed then
	    --print(c.name, c.url, c._parent)

	    c.dirty = true
	    --if c._parent then 
	    --   c._parent.dirty = true
	    --end
	    
	 end
	 --c.dirty = true
	 
         if c.bbox and c.transforms._l and c.depth ~= nil then
            if c.pressed  then

               local mx, my = getPointerPosition(c.pressed.id)
               local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c, l.p)


	       -- remove this from here, instead handle this is mousemvoe where i know the real dx and yd and dont need tyo rely on inverting the transformation which leds to issues
	       
	       -- before i was moving the item first, and afterwards mabe following with the camera
	       -- that is no longer the case, this causes a little jittery effect
	       

	       local speed = 200
	       -- this is so the zoom factor has an affect on the scroll factor
	       local scale = cam:getScale()
	       speed = speed / scale

	       if ((brx + offset) > W) then
		 

		  if ecsWorld then
		     --local scale = cam:getScale()
		     --local lc = createCamData(c, l.p)
		     --local cam = createCamData(c, l.p)
		     --ecsWorld:emit("itemDrag", c, l, x, y, dx*cam.scale, dy*cam.scale)
		     --ecsWorld:emit("itemDrag", c, l, x, y, 1, 0)
		     print('this is the thing i am after I believe')
		     ecsWorld:emit("itemDrag", c, l, x, y, speed*dt, 0)
		  end

		  resetCameraTween()
		  cameraTranslateScheduler(speed*dt, 0)
	       end
	       if ((tlx - offset) < 0) then
		  resetCameraTween()
		  cameraTranslateScheduler(-speed*dt, 0)
		  if ecsWorld then
		     ecsWorld:emit("itemDrag", c, l, x, y, -speed*dt, 0)
		  end
	       end
            end
         end
      end
   end
end



function getScreenBBoxForItem(c, camData)

   local bbox = c.bbox

   local stlx, stly = c.transforms._g:transformPoint(bbox[1],bbox[2])
   local strx, stry = c.transforms._g:transformPoint(bbox[3],bbox[2])
   local sblx, sbly = c.transforms._g:transformPoint(bbox[1],bbox[4])
   local sbrx, sbry = c.transforms._g:transformPoint(bbox[3],bbox[4])

   local tlx, tly = cam:getScreenCoordinates(stlx, stly, camData)
   local brx, bry = cam:getScreenCoordinates(sbrx, sbry, camData)
   local trx, try = cam:getScreenCoordinates(strx, stry, camData)
   local blx, bly = cam:getScreenCoordinates(sblx, sbly, camData)

   local smallestX = math.min(tlx, brx, trx, blx)
   local smallestY = math.min(tly, bry, try, bly)
   local biggestX = math.max(tlx, brx, trx, blx)
   local biggestY = math.max(tly, bry, try, bly)

   return smallestX, smallestY, biggestX, biggestY

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
-- function mouseIsOverItemChildBBox(mx, my, item, child, parallaxData)
--    local camData = createCamData(child, parallaxData)
--    local tlx, tly, brx, bry = getScreenBBoxForItem(child, camData)
--    local wx, =wy = cam:getWorldCoordinates(mx, my, camData)
--    local invx, invy = item.transforms._g:inverseTransformPoint(wx, wy)

--    return pointInRect(mx, my, tlx, tly, brx-tlx, bry-tly), invx, invy, tlx, tly, brx, bry
-- end

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


function gestureRecognizer(gesture, ecsWorld)
   if #gesture.positions > 1 then
      local startP = gesture.positions[1]
      local endP = gesture.positions[#gesture.positions]
      --      print(#gesture.positions)

      -- i odnt want long lists because you can shoot (literally below) yourself like that
      
      local gestureLength = 5--math.max(3,math.floor(#gesture.positions))
      if (#gesture.positions > gestureLength) then
	 startP = gesture.positions[#gesture.positions - gestureLength]
      end
      --print('looking at gesture with', #gesture.positions)

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

	 if deltaTime > minDuration then
	    local doTween = false
	    local cx,cy = cam:getTranslation()
	    local xAxis = cx
	    local yAxis = cy

            if xAxisAllowed and yAxisAllowed then
                  if distance > minDistance then
                     if distance/deltaTime >= minSpeed and  distance/deltaTime < maxSpeed then
                        doTween = true

                        --print(dx, dy)
                        --if dx == 0 then dx = 0.0001 end
                        --if dy == 0 then dy = 0.0001 end

                        if dx ~=0 and dy ~= 0 then

                           if math.abs(dy) > 5*math.abs(dx) then
                              --print('mostly vertical')
                              dx=0
                           end
                           if math.abs(dx) > 5*math.abs(dy) then
                              --print('mostly horizontal')
                              dy=0
                           end
                           

                           --local smallest = math.min(dx,dy)
                           --local biggest = math.max(dx,dy) 

                           --print(biggest/smallest, smallest/biggest)
                        end
                        
                        if dx ~= 0 then
                        local mx = dx < 0 and -1 or 1
                        xAxis = cx -((dx) + (mx* speed/7.5) )
                        end

                        if dy ~= 0 then
                        local my = dy < 0 and -1 or 1
                        yAxis = cy -((dy) + (my* speed/7.5) )
                        end

                     end
                  end
                  
            else
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
            end

	    if doTween then
	       cameraTween = {
		  goalX=xAxis,
		  goalY=yAxis,
		  smoothValue=smoothValue,
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

         if ecsWorld then
            ecsWorld:emit("itemThrow", gesture.target, dxn, dyn, speed)
         end

      end
   end
end
