

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
   local found = false
   for i = #gestureList, 1, -1 do
      if gestureList[i] == gesture then
         table.remove(gestureList, i)
         found = true
      end
   end
   if found == false then
      print('didnt find gesture to delete',gesture.trigger, #gestureList)
   else
      --print('deleted gesture succesfully', gesture.trigger, #gestureList)
   end
end



function updateGestureCounter(dt)
   gestureUpdateResolutionCounter = gestureUpdateResolutionCounter + dt

   if gestureUpdateResolutionCounter > gestureUpdateResolution then
      gestureUpdateResolutionCounter = 0
      for i = 1, #gestureList do

         local g = gestureList[i]
         local x,y, success = getPointerPosition(g.trigger)    -- = love.mouse:getPosition()
	 if success then
	    addGesturePoint(g, love.timer.getTime( ), x, y)
	    --table.insert(g.positions, {x=x,y=y, time=love.timer.getTime( )})
	 end
      end

   end
end


function handlePressedItemsOnStage(W, H, dt)
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

            love.graphics.setColor(1,1,1,.5)
            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)



	    -- this renders the pivot point
	    love.graphics.setColor(1,1,1,1)
	    local px, py = c._globalTransform:transformPoint( c.transforms.l[6], c.transforms.l[7])
	    local hack =  {}
	    hack.scale = mapInto(c.depth, depthMinMax.min, depthMinMax.max,
				 depthScaleFactors.min, depthScaleFactors.max)
	    hack.relativeScale = (1.0/ hack.scale) * hack.scale
	    local pivx, pivy = cam:getScreenCoordinates(px, py, hack)

	    love.graphics.line(pivx-5, pivy, pivx+5, pivy)
	    love.graphics.line(pivx, pivy-5, pivx, pivy+5)

	    --love.graphics.rectangle('fill', pivx-5, pivy-5, 10, 10)
	    -- end



         end

	 if  c.mouseOver or uiState.showBBoxes then
	    local mx, my = getPointerPosition('mouse')
	    local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c)
	    love.graphics.setColor(1,1,1,.5)
            love.graphics.rectangle('line', tlx, tly, brx-tlx, bry-tly)
	 end
      end
   end
end





--[[

if false then
      local wx, wy = cam:getMouseWorldCoordinates()
      local foundOne = false
      if testCameraViewpointRects then
         for _, v in pairs(cameraPoints) do
            if pointInRect(wx,wy, v.x, v.y, v.width, v.height) and not foundOne then
               foundOne = true
               v.selected = true
               local cw, ch = cam:getContainerDimensions()
               local targetScale = math.min(cw/v.width, ch/v.height)
               cam:setScale(targetScale)
               cam:setTranslation(v.x + v.width/2, v.y + v.height/2)
            else
               v.selected = false
            end

         end--
      end

   end
]]--


function pointerPressed(x,y, id)

   local W, H = love.graphics.getDimensions()

   ------------ begin ui
   local leftdis = getDistance(x,y, 50, (H/2)-25)
   local rightdis = getDistance(x,y, W-50, (H/2)-25)
   local toprightdis = getDistance(x,y, W-25, 25)

   if uiState.showWalkButtons then
   if leftdis < 50 then
      moving = 'left'
   end
   if rightdis < 50 then
      moving = 'right'
   end
   end
   if toprightdis < 50 then
      --showNumbersOnScreen = not showNumbersOnScreen
      uiState.show = not uiState.show
   end
   ------------- end ui


   local itemPressed = false
   for i = #middleLayer.children,1,-1 do
      local c = middleLayer.children[i]
      if c.bbox and c._localTransform and c.depth and not itemPressed then

	 local mouseover, invx, invy = mouseIsOverItemBBox(x,y, c)

	 if mouseover then

	    local justBBoxCheck = false

	    if (justBBoxCheck == true or ( mouseIsOverObjectInCamLayer(x, y, c))) then
	       c.pressed = {dx=invx, dy=invy, id=id}
	       itemPressed = c
	       c.poep = true
	       c.groundTileIndex = nil
               local indices = c.originalIndices
               -- i dont want to readd this item
               -- the generated polygons arent in this list
               -- there wll be more and more lists I imagine
               if indices and plantData[indices[1]] and plantData[indices[1]][indices[2]] then
                  plantData[indices[1]][indices[2]].hasBeenPressed = true
               end

            end
	 end

      end
   end

   if not itemPressed  then
      if not cameraFollowPlayer then
         --print('do a stage gesture')
         -- maybe i need to take out the other stage gestures
         --for i = #gestureList, 1, -1 do
         --   if (gestureList[i].target == 'stage') then
         --      removeGestureFromList(gestureList[i])
         --   end
         --end
         -- maybe only allow stage gesture when no are present ?
         local hasOneAlready = false
         for i =1, #gestureList do
            if gestureList[i].target == 'stage' then
               hasOneAlready = true
            end
         end


         if not hasOneAlready then

            local g = {positions={}, target='stage', trigger=id}
            table.insert(gestureList, g)
            addGesturePoint(g, love.timer.getTime( ),x,y)
         end
      end
   else
      resetCameraTween()

      local g = {positions={}, target=itemPressed, trigger=id}
      table.insert(gestureList, g)
      addGesturePoint(g, love.timer.getTime( ),x,y)
   end

end


function pointerMoved(x,y,dx,dy, id)
   -- it only makes sense to check mouseOver with mouse
   if id == 'mouse' then
      for i = 1, #middleLayer.children do
	 local c = middleLayer.children[i]
	 if c.bbox and c._localTransform and c.depth then
	    local mouseover, invx, invy = mouseIsOverItemBBox(x, y, c)
	    c.mouseOver = mouseover
	 end
      end
   end

   -- in the case of mouse i only allow pannin the stage when its pressed, touch is always down when moved
   if (id == 'mouse' and love.mouse.isDown(1) ) or id ~= 'mouse' then

      --if (id == 'mouse') then
      resetCameraTween()
      --end

      --if cameraTween then
--	 print( 'there migjt be an issue here!')
  --    end

      for i = 1, #gestureList do
	 local g = gestureList[i]
	 if g.target == 'stage' and g.trigger == id then
	    local scale = cam:getScale()
	    cameraTranslateScheduler(-dx/scale, 0)
	 end
      end
   end
end


function pointerReleased(x,y, id)
   moving = nil
   for i = 1, #middleLayer.children do
      local c =middleLayer.children[i]
      if c.pressed and c.pressed.id == id then
         c.pressed = nil
      end
   end

   for i = 1, #gestureList do
      local g = gestureList[i]
      -- todo why the fuc is there a nil gesture in here?
      if g then
	 if g.trigger == id then
	    --print('do ii ever get her?')
	    addGesturePoint(g, love.timer.getTime( ), x, y)
	    gestureRecognizer(g)
	    removeGestureFromList(g)
	 end
      else
         print('why did this happen ? a nil gesture!?')
      end


   end


end
