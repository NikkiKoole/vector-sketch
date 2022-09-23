local pointer = require 'lib.pointer'

local gestureState = {
    list = {},
    updateResolutionCounter = 0,
    updateResolution = 0.0167
}


local lib = {}

-- todo @ global singleton gestureState

lib.getState = function()
    return gestureState
end

function addGesturePoint(gest, time, x, y)
    assert(gest)

    table.insert(gest.positions, { time = time, x = x, y = y })
 end

 function addGesture(target, trigger, time, x, y)

   local g = { positions = {}, target = target, trigger = trigger }
   table.insert(gestureState.list, g)
   addGesturePoint(g, time, x, y)
end

function hasGestureWithTarget(target)
   for i = 1, #gestureState.list do 
      if gestureState.list[i].target == target then
        return true
      end
   end
   return false
end

 function removeGestureFromList(gesture)
    
    for i = #gestureState.list, 1, -1 do
       if gestureState.list[i] == gesture then
        print('removing gesture')
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
         local x, y, success = pointer.getPosition(g.trigger)
         --print(g.trigger)
         if success then
            addGesturePoint(g, love.timer.getTime(), x, y)
         end
      end
   end
end

function maybeTriggerGesture(id, x, y, cx, cy, throw)
   for i = #gestureState.list, 1, -1 do
      local g = gestureState.list[i]
      if g then
         if g.trigger == id then
            addGesturePoint(g, love.timer.getTime(), x, y)
            gestureRecognizer(g, cx, cy, throw)
            removeGestureFromList(g)
         end
      end
   end
end

function gestureRecognizer(gesture, cx, cy, throwfunc)
   if #gesture.positions > 1 then
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
         local xAxisAllowed = true  -- todo set this somehwere esle
         local yAxisAllowed = true  -- todo same
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
               setCameraTween({
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
         --if ecsWorld then
         --   ecsWorld:emit("itemThrow", gesture.target, dxn, dyn, speed)
         --end

      end
   end
end


return lib
