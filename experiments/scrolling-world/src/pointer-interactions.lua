local numbers = require 'lib.numbers'
local hit = require 'lib.hit'
local cam = getCamera()
local gesture = require 'lib.gesture'
local gestureState = gesture.getState()
local pointer = require 'lib.pointer'



function drawBBoxAroundItems(layer, parallaxData)
   for i = 1, #layer.children do
      local c = layer.children[i]


      if c.bbox and c.transforms._l and c.depth ~= nil then

         if c.pressed then
            local mx, my = pointer.getPosition(c.pressed.id)
            local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c, parallaxData)
            --print(tlx, tly, brx, bry)
            love.graphics.setColor(1, 1, 1, .5)

            love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)

            love.graphics.setColor(1, 1, 1, 1)
            local px, py = c.transforms._g:transformPoint(c.transforms.l[6], c.transforms.l[7])

            local camData = createCamData(c, parallaxData)
            local pivx, pivy = cam:getScreenCoordinates(px, py, camData)
            love.graphics.line(pivx - 5, pivy, pivx + 5, pivy)
            love.graphics.line(pivx, pivy - 5, pivx, pivy + 5)

            local checkAgainst = getItemsInLayerThatHaveMeta(layer, c)

            for j = 1, #checkAgainst do
               for k = 1, #checkAgainst[j].metaTags do
                  local tag = checkAgainst[j].metaTags[k]
                  local pos = tag.points[1] -- there is just one point in this collection
                  local kx, ky = checkAgainst[j].transforms._g:transformPoint(pos[1], pos[2])
                  local camData = createCamData(checkAgainst[j], parallaxData)
                  local kx2, ky2 = cam:getScreenCoordinates(kx, ky, camData)
                  love.graphics.setColor(1, 1, 1, .2)
                  love.graphics.line(pivx, pivy, kx2, ky2)
               end
            end

         end

         if c.mouseOver or uiState.showBBoxes then
            local mx, my = pointer.getPosition('mouse')
            local mouseover, invx, invy, tlx, tly, brx, bry = mouseIsOverItemBBox(mx, my, c, parallaxData)
            love.graphics.setColor(1, 1, 1, .5)
            love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)
         end
      end
   end
end

function pointerPressed(x, y, id, layers)

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

   for j = #layers, 1, -1 do
      local l = layers[j]

      for i = #l.layer.children, 1, -1 do
         local c = l.layer.children[i]


         if c.bbox and c.transforms._l and c.depth and not itemPressed then

            local mouseover, invx, invy = mouseIsOverItemBBox(x, y, c, l.p)
            if mouseover then
               local justBBoxCheck = false
               local hitcheck = mouseIsOverObjectInCamLayer(x, y, c, l.p)
               if (justBBoxCheck == true or hitcheck) then

                  --                  c.groundTileIndex = nil
                  --                  local indices = c.originalIndices
                  local first = c.assetBookIndex
                  -- todo ouch i dunno about this
                  if first and l.assets[first] then
                     --l.assets[indices[1]][indices[2]].hasBeenPressed = true

                     local index = 0
                     for k = 1, #l.assets[first] do
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

                     c.pressed = { dx = invx, dy = invy, id = id }
                     itemPressed = c
                  end

               end
            end

         end
      end

   end

   if not itemPressed then
      if not cameraFollowPlayer then
         local hasOneAlready = hasGestureWithTarget('stage')
         if not hasOneAlready then
            addGesture('stage', id, love.timer.getTime(), x, y)
         end
      end
   else
      resetCameraTween()
      addGesture(itemPressed, id, love.timer.getTime(), x, y)
   end

   
end

function checkForItemMouseOver(x, y, layer, parallaxData)
   for i = 1, #layer.children do
      local c = layer.children[i]
      if c.bbox and c.transforms._l and c.depth then
         local mouseover, invx, invy = mouseIsOverItemBBox(x, y, c, parallaxData)
         c.mouseOver = mouseover
      end
   end
end

function pointerMoved(x, y, dx, dy, id, layers)

   if (id == 'mouse') then
      for i = 1, #layers do
         local l = layers[i]
         checkForItemMouseOver(x, y, l.layer, l.p)
      end
   end


   if (id == 'mouse' and love.mouse.isDown(1)) or id ~= 'mouse' then

      resetCameraTween()

      for i = 1, #gestureState.list do
         local g = gestureState.list[i]
         if g.target == 'stage' and g.trigger == id then
            local scale = cam:getScale()

            local xAxisAllowed = true
            local xAxis = xAxisAllowed and -dx / scale or 0
            local yAxisAllowed = false
            local yAxis = yAxisAllowed and -dy / scale or 0

            cameraTranslateScheduler(xAxis, yAxis)
         end
      end
   end
end

function pointerReleased(x, y, id, layers)
   moving = nil

   for j = 1, #layers do
      for i = 1, #layers[j].layer.children do
         local c = layers[j].layer.children[i]
         if c.pressed and c.pressed.id == id then
            c.pressed = nil
         end
      end
   end

   local function throw(gesture, dxn, dyn, speed)
      gesture.target.inMotion = makeMotionObject()
      local mass = gesture.target.inMotion.mass

      local throwStrength = 1
      if mass < 0 then throwStrength = throwStrength / 100 end

      local impulse = Vector(dxn * speed * throwStrength,
         dyn * speed * throwStrength)

      applyForce(gesture.target.inMotion, impulse)

   end
   local cx, cy = cam:getTranslation()
   maybeTriggerGesture(id, x, y, cx, cy, throw)

  
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
      local l = layers[j]
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
            if c.pressed then


               --print(inspect(c.bbox))

               local mx, my = pointer.getPosition(c.pressed.id)
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

                     local rotateStep = ((invx - c.pressed.dx))
                     local rx, ry = c.transforms._g:transformPoint(rotateStep, 0)
                     local rx2, ry2 = c.transforms._g:transformPoint(0, 0)
                     local rxdelta = rx - rx2

                     if math.abs(rotateStep) > 0.00001 then

                        c.children[1].transforms.l[3] = c.children[1].transforms.l[3] +
                            (rxdelta / c.wheelCircumference) * (math.pi * 2)
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
                     cameraTranslateScheduler(speed * dt, 0)
                  end
                  if ((tlx - offset) < 0) then
                     resetCameraTween()
                     cameraTranslateScheduler(-speed * dt, 0)
                  end



               end
            end
         end
      end
   end
end

function getScreenBBoxForItem(c, camData)


   local tx, ty = c.transforms._g:transformPoint(c.bbox[1], c.bbox[2])
   local tlx, tly = cam:getScreenCoordinates(tx, ty, camData)
   local bx, by = c.transforms._g:transformPoint(c.bbox[3], c.bbox[4])
   local brx, bry = cam:getScreenCoordinates(bx, by, camData)
   --print(tlx, tly, brx, bry)
   return tlx, tly, brx, bry

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
      camData.relativeScale = 1 --(1.0/ hack.scale) * hack.scale
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

   return hit.pointInRect(mx, my, tlx, tly, brx - tlx, bry - tly), invx, invy, tlx, tly, brx, bry
end

function mouseIsOverItemBBox(mx, my, item, parallaxData)

   local camData = createCamData(item, parallaxData)
   local tlx, tly, brx, bry = getScreenBBoxForItem(item, camData)
   local wx, wy = cam:getWorldCoordinates(mx, my, camData)
   local invx, invy = item.transforms._g:inverseTransformPoint(wx, wy)

   return hit.pointInRect(mx, my, tlx, tly, brx - tlx, bry - tly), invx, invy, tlx, tly, brx, bry
end

function mouseIsOverObjectInCamLayer(mx, my, item, parallaxData)
   local camData = createCamData(item, parallaxData)
   local mx2, my2 = cam:getWorldCoordinates(mx, my, camData)
   local hit = hit.recursiveHitCheck(mx2, my2, item)
   return hit
end


