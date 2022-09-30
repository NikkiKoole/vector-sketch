local pointer = require 'lib.pointer'

local gestureState = {
   list = {},
   updateResolutionCounter = 0,
   updateResolution = 0.0167
}
local xAxisAllowed = true
local yAxisAllowed = true

local cam = require('lib.cameraBase').getInstance()
local tween = require 'lib.cameraTween'
local lib = {}

local function addGesturePoint(gest, time, x, y)
   assert(gest)
   table.insert(gest.positions, { time = time, x = x, y = y })
end

lib.getAllowedAxis = function()
   return xAxisAllowed, yAxisAllowed
end

lib.add = function(target, trigger, time, x, y)
   local g = { positions = {}, target = target, trigger = trigger }
   table.insert(gestureState.list, g)
   addGesturePoint(g, time, x, y)
end

lib.findWithTarget = function(target)
   for i = 1, #gestureState.list do
      if gestureState.list[i].target == target then
         return true
      end
   end
   return false
end
lib.findWithTargetAndId = function(target, id)
   for i = 1, #gestureState.list do
      local g = gestureState.list[i]
      if g.target == target and g.trigger == id then
         return g
      end
   end
   return nil
end

lib.remove = function(gesture)
   for i = #gestureState.list, 1, -1 do
      if gestureState.list[i] == gesture then
         print('removing gesture')
         table.remove(gestureState.list, i)
      end
   end
end


--- updates the gesture counter behind the scenes and
--- _adds_ tp yhe gesture points when required
---@param dt number
lib.update = function(dt)
   gestureState.updateResolutionCounter = gestureState.updateResolutionCounter + dt

   if gestureState.updateResolutionCounter > gestureState.updateResolution then
      gestureState.updateResolutionCounter = 0
      for i = 1, #gestureState.list do
         local g = gestureState.list[i]
         local x, y, success = pointer.getPosition(g.trigger)
         --print(g.trigger)
         if success then
            addGesturePoint(g, love.timer.getTime(), x, y)
         end
      end
   end
end


local function gestureRecognizer(gesture, throwfunc)
   if #gesture.positions > 1 then
      local cx, cy = cam:getTranslation()
      local startP = gesture.positions[1]
      local endP = gesture.positions[#gesture.positions]
      local gestureLength = 5 --math.max(3,math.floor(#gesture.positions))

      if (#gesture.positions > gestureLength) then
         startP = gesture.positions[#gesture.positions - gestureLength]
      end
      --print('looking at gesture with', #gesture.positions)

      local dx = endP.x - startP.x
      local dy = endP.y - startP.y
      local distance = math.sqrt(dx * dx + dy * dy)
      local deltaTime = endP.time - startP.time
      local speed = distance / deltaTime

      if gesture.target == 'stage' then
         local minSpeed = 200
         local maxSpeed = 15000
         local minDistance = 6
         local minDuration = 0.005

         if deltaTime > minDuration then
            local doTween = false

            local xAxis = cx
            local yAxis = cy

            if xAxisAllowed and yAxisAllowed then
               if distance > minDistance then
                  if distance / deltaTime >= minSpeed and distance / deltaTime < maxSpeed then
                     doTween = true

                     if dx ~= 0 and dy ~= 0 then
                        if math.abs(dy) > 5 * math.abs(dx) then
                           dx = 0
                        end
                        if math.abs(dx) > 5 * math.abs(dy) then
                           dy = 0
                        end
                     end

                     if dx ~= 0 then
                        local mx = dx < 0 and -1 or 1
                        xAxis = cx - ((dx) + (mx * speed / 7.5))
                     end

                     if dy ~= 0 then
                        local my = dy < 0 and -1 or 1
                        yAxis = cy - ((dy) + (my * speed / 7.5))
                     end

                  end
               end

            else
               if xAxisAllowed then
                  if math.abs(dx) > minDistance then
                     if math.abs(dx / deltaTime) >= minSpeed and math.abs(dx / deltaTime) < maxSpeed then
                        doTween = true
                        local mx = dx < 0 and -1 or 1
                        xAxis = cx - ((dx) + (mx * speed / 7.5))
                     end
                  end
               end

               if yAxisAllowed then
                  if math.abs(dy) > minDistance then
                     if math.abs(dy / deltaTime) >= minSpeed and math.abs(dy / deltaTime) < maxSpeed then
                        doTween = true
                        local my = dy < 0 and -1 or 1
                        yAxis = cy - ((dy) + (my * speed / 7.5))
                     end
                  end
               end
            end

            if doTween then
               tween.setCameraTween({
                  goalX = xAxis,
                  goalY = yAxis,
                  smoothValue = 3.5,
                  originalGesture = gesture
               })

            end
         else
            --print('failed at distance')
         end
      else -- this is gesture target something else, items basically!

         if distance < 0.00001 then
            distance = 0.00001
         end
         local dxn = dx / distance
         local dyn = dy / distance
         throwfunc(gesture, dxn, dyn, speed)
      end
   end
end

lib.maybeTrigger = function(id, x, y, throw)
   for i = #gestureState.list, 1, -1 do
      local g = gestureState.list[i]
      if g then
         if g.trigger == id then
            addGesturePoint(g, love.timer.getTime(), x, y)
            gestureRecognizer(g, throw)
            lib.remove(g)
         end
      end
   end
end

return lib
