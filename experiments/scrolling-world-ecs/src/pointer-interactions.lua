local numbers = require 'lib.numbers'
local hit = require 'lib.hit'

local cam = require('lib.cameraBase').getInstance()
local camera = require 'lib.camera'
local gesture = require 'lib.gesture'
local pointer = require 'lib.pointer'


function drawBBoxAroundItems(layer, parallaxData)
   local max = math.max
   local min = math.min

   for i = 1, #layer.children do
      local c = layer.children[i]


      if c.bbox and c.transforms._l and c.depth ~= nil then

         if c.pressed then
            local mx, my = pointer.getPosition(c.pressed.id)
            local mouseover, invx, invy, tlx, tly, brx, bry = camera.mouseIsOverItemBBox(mx, my, c, parallaxData)

            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)

            love.graphics.setColor(1, 0, 1, 1)
            local minx = min(tlx, brx)
            local miny = min(tly, bry)
            local maxx = max(tlx, brx)
            local maxy = max(tly, bry)
            --            print(minx, miny, maxx,maxy, maxx-minx, maxy-miny)
            love.graphics.rectangle('line', minx, miny, maxx - minx, maxy - miny)



            love.graphics.setColor(1, 0, 0, 1)
            local px, py = c.transforms._g:transformPoint(c.transforms.l[6], c.transforms.l[7])
            local pivx, pivy = camera.camDataToScreen(c, parallaxData, px, py)
            --local camData = createCamData(c, parallaxData)
            --local pivx, pivy = cam:getScreenCoordinates(px, py, camData)

            love.graphics.line(pivx - 5, pivy, pivx + 5, pivy)
            love.graphics.line(pivx, pivy - 5, pivx, pivy + 5)



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
            local mx, my = pointer.getPosition('mouse')
            local mouseover, invx, invy, tlx, tly, brx, bry = camera.mouseIsOverItemBBox(mx, my, c, parallaxData)
            love.graphics.setColor(1, 1, 1, .5)
            love.graphics.rectangle('line', tlx, tly, brx - tlx, bry - tly)
         end
      end
   end
end

function setItemsPressedInLayer(x, y, l, id, ecsWorld)

   local pressed = false
   for i = #l.layer.children, 1, -1 do
      local c = l.layer.children[i]

      if c.bbox and c.transforms._l and c.depth and not pressed then

         local mouseover, invx, invy = camera.mouseIsOverItemBBox(x, y, c, l.p)
         if mouseover then
            local justBBoxCheck = false
            local hitcheck = camera.mouseIsOverObjectInCamLayer(x, y, c, l.p)
            if (justBBoxCheck == true or hitcheck) then
               if ecsWorld then
                  ecsWorld:emit("itemPressed", c, l, x, y, hitcheck)
               end
               --
               --print('pressed')
               c.pressed = { id = id }
               pressed = c

            end
         end
      end
   end
   return pressed
end

function pointerPressed(x, y, id, layers, ecsWorld)
   local itemPressed = false

   for j = 1, #layers do
      local l = layers[j]

      itemPressed = itemPressed or setItemsPressedInLayer(x, y, l, id, ecsWorld)


   end




   --print(itemPressed)
   if not itemPressed then
      if not cameraFollowPlayer then
         local hasOneAlready = gesture.findWithTarget('stage')
         if not hasOneAlready then
            gesture.add('stage', id, love.timer.getTime(), x, y)
         end
      end
   else
      camera.resetCameraTween()
      gesture.add(itemPressed, id, love.timer.getTime(), x, y)
   end

end

function checkForItemMouseOver(x, y, layer, parallaxData)
   for i = 1, #layer.children do
      local c = layer.children[i]
      if c.bbox and c.transforms._l and c.depth then
         local mouseover, invx, invy = camera.mouseIsOverItemBBox(x, y, c, parallaxData)
         c.mouseOver = mouseover
      end
   end
end

function pointerMoved(x, y, dx, dy, id, layers, ecsWorld)

   if (id == 'mouse') then
      for i = 1, #layers do
         local l = layers[i]
         checkForItemMouseOver(x, y, l.layer, l.p)
      end
   end


   if (id == 'mouse' and love.mouse.isDown(1)) or id ~= 'mouse' then
      camera.maybePan(dx, dy, id)
   end

   -- if items are pressed i have the id that caused thta,
   -- in here i know the id of the moved pointer so that ought to be enouigh
   for j = 1, #layers do
      local l = layers[j]

      for i = #l.layer.children, 1, -1 do
         local child = l.layer.children[i]
         if child.pressed and child.pressed.id == id then
            -- this works correctly ( \0/ )  I just need to scale it
            if ecsWorld then
               local scale = cam:getScale()
               local lc = camera.createCamData(child, l.p)
               if (lc) then
                  print("item drag!")
                  ecsWorld:emit("itemDrag", child, l, x, y, dx / lc.scale / scale, dy / lc.scale / scale)
               end

            end
         end

      end
   end

end

function pointerReleased(x, y, id, layers, ecsWorld)
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
      ecsWorld:emit("itemThrow", gesture.target, dxn, dyn, speed)
   end

   gesture.maybeTrigger(id, x, y, throw)


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
      local l = layers[j]
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
            if c.pressed then

               local mx, my = pointer.getPosition(c.pressed.id)
               local mouseover, invx, invy, tlx, tly, brx, bry = camera.mouseIsOverItemBBox(mx, my, c, l.p)


               -- remove this from here, instead handle this is mousemvoe where i know the real dx and yd and dont need tyo rely on inverting the transformation which leds to issues

               -- before i was moving the item first, and afterwards mabe following with the camera
               -- that is no longer the case, this causes a little jittery effect


               local speed = 200
               -- this is so the zoom factor has an affect on the scroll factor
               local scale = cam:getScale()
               speed = speed / scale

               if ((brx + offset) > W) then
                  camera.resetCameraTween()
                  camera.cameraTranslateScheduler(speed * dt, 0)
                  if ecsWorld then
                     ecsWorld:emit("itemDrag", c, l, x, y, speed * dt, 0)
                  end

               end
               if ((tlx - offset) < 0) then
                  camera.resetCameraTween()
                  camera.cameraTranslateScheduler(-speed * dt, 0)
                  if ecsWorld then
                     ecsWorld:emit("itemDrag", c, l, x, y, -speed * dt, 0)
                  end
               end
            end
         end
      end
   end
end
