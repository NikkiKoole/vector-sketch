local Camera = require 'vendor.brady'
local gesture = require 'lib.gesture'
local gestureState = gesture.getState()

function createCamera()
   offset = 0
   local W, H = love.graphics.getDimensions()

   return Camera(
      W - 2 * offset,
      H - 2 * offset,
      {
         x = offset, y = offset, resizable = true, maintainAspectRatio = true,
         resizingFunction = function(self, w, h)
            resizeCamera(self, w, h)
            local W, H = love.graphics.getDimensions()
            self.x = offset
            self.y = offset
         end,
         getContainerDimensions = function()
            local W, H = love.graphics.getDimensions()
            return W - 2 * offset, H - 2 * offset
         end
      }
   )
end

-- todo @global singleton camera
local _c = createCamera()
function getCamera()
   return _c
end

local cam = getCamera()

-- todo @global cameratween
local _cameraTween = nil
local _tweenCameraDelta = nil

function setCameraTween(data)
   print(inspect(data))
   _cameraTween = data
end

local translateScheduler = {
   x = 0,
   y = 0,
   justItem = { x = 0, y = 0 },
   happenedByPressedItems = false,
   cache = { value = 0, cacheValue = 0, stopped = true, stoppedAt = 0, tweenValue = 0 }
}

function getTranslateSchedulerValues()
   if (translateScheduler.cache.value ~= 0) then
      return translateScheduler.cache.value
   else
      return translateScheduler.cache.tweenValue
   end

end

function resizeCamera(self, w, h)
   local scaleW, scaleH = w / self.w, h / self.h
   local scale = math.min(scaleW, scaleH)
   -- the line below keeps aspect
   --self.w, self.h = scale * self.w, scale * self.h
   -- the line below deosnt keep aspect
   self.w, self.h = scaleW * self.w, scaleH * self.h
   self.aspectRatio = self.w / w
   self.offsetX, self.offsetY = self.w / 2, self.h / 2
   offset = offset * scale
end

function setCameraViewport(cam, w, h)
   local cx, cy = cam:getTranslation()

   local cw, ch = cam:getContainerDimensions()
   local targetScale = math.min(cw / w, ch / h)
   cam:setScale(targetScale)
   cam:setTranslation(cx, -1 * h / 2)
   --print(_c)
end

function drawCameraBounds(cam, mode)
   love.graphics.rectangle(mode, cam.x, cam.y, cam.w, cam.h)
end
function resetCameraTween()
   if _cameraTween then
      _cameraTween = nil
      _tweenCameraDelta = 0
   end
end

function manageCameraTween(dt)
   --print(inspect(#gestureState.list))
   --[[
if cameraFollowPlayer then
      local distanceAhead = math.floor(300*v.x)
      followPlayerCameraDelta = cam:setTranslationSmooth(
         player.x + player.width/2 ,
         player.y - 350,
         dt,
         10
      )
   end
   ]]--

   if _cameraTween then
      local delta = cam:setTranslationSmooth(
         _cameraTween.goalX,
         _cameraTween.goalY,
         dt,
         _cameraTween.smoothValue
      )

      if delta.x ~= 0 then

         cameraTranslateScheduleJustItem(delta.x * _cameraTween.smoothValue * dt, 0)
      end
      -- todo @ get rid of this gesturestate here
      if (delta.x + delta.y) == 0 then

         print('yoyoyo')
         for i = #gestureState.list, 1, - 1 do
            print(_cameraTween.originalGesture, gestureState.list[i] )
            if _cameraTween.originalGesture == gestureState.list[i] then
               if gestureState.list[i] ~= nil then
                  print('removed gesture', inspect(gestureState.list[i]) )
                  removeGestureFromList(gestureState.list[i])
               end
            end
         end

         _cameraTween = nil

      end
      _tweenCameraDelta = (delta.x + delta.y)
   end

end

function generateCameraLayer(name, zoom)
   return cam:addLayer(name, zoom, { relativeScale = (1.0 / zoom) * zoom })
end

function cameraTranslateScheduleJustItem(dx, dy)
   -- this comes from just the cameraTween
   translateScheduler.justItem.x = dx
   translateScheduler.justItem.y = dy

end

function cameraTranslateScheduler(dx, dy)
   --   print(dx, 'try to average instead of adding')
   translateScheduler.x = translateScheduler.x + dx
   translateScheduler.y = translateScheduler.y + dy
end

function checkForBounceBack(dt)
   -- this thing is meant for the elastic bounce back of items
   -- ah right, its the elements that will bounce in opposite direction of a camera tween
   -- just the little line right now that displays that
   if translateScheduler.x ~= 0 then
      translateScheduler.cache.triggered = false
      translateScheduler.cache.stopped = false
      translateScheduler.cache.value = translateScheduler.cache.value + translateScheduler.x
      translateScheduler.cache.cacheValue = translateScheduler.cache.value
   else
      if translateScheduler.cache.stopped == false then
         translateScheduler.cache.stopped = true
         translateScheduler.cache.stoppedAt = translateScheduler.cache.value
      end
      local multiplier = (0.5 ^ (dt * 300))
      translateScheduler.cache.cacheValue = translateScheduler.cache.cacheValue * multiplier

      -- https://love2d.org/forums/viewtopic.php?f=3&t=82046&start=10
      if math.abs(translateScheduler.cache.cacheValue) < 0.01 and translateScheduler.cache.triggered == false then
         translateScheduler.cache.cacheValue = 0
         translateScheduler.cache.value = 0

         translateScheduler.cache.triggered = true
         translateScheduler.cache.tweenValue = translateScheduler.cache.stoppedAt
         bouncetween = tween.new(1, translateScheduler.cache, { tweenValue = 0 }, 'outElastic')
      end
   end
end

function cameraApplyTranslate(dt, layer)

   cam:translate(translateScheduler.x, translateScheduler.y)
   local translateByPressed = false


   if true then

      for i = 1, #layer.children do
         local c = layer.children[i]
         if c.pressed then
            -- this line cause the jerkyness, have to check it on multitouch
            -- c.transforms.l[1] =
            --    c.transforms.l[1] + translateScheduler.x + translateScheduler.justItem.x
            translateByPressed = (translateScheduler.x + translateScheduler.justItem.x) ~= 0
         end
      end


      --- this part is here for triggering a tween on ending item pressed drag
      if translateByPressed == true then
         translateScheduler.happenedByPressedItems = true
      end

      if translateScheduler.happenedByPressedItems == true and translateByPressed == false then
         translateScheduler.happenedByPressedItems = false
         local cx, cy = cam:getTranslation()
         local delta = (translateScheduler.x + translateScheduler.justItem.x) * 50
         setCameraTween({ goalX = cx + delta, goalY = cy, smoothValue = smoothValue or 3.5 })
         --cameraTween = 
      end
      ------ end that part

   end
   checkForBounceBack(dt)

   translateScheduler.x = 0
   translateScheduler.y = 0
   translateScheduler.justItem.x = 0
   translateScheduler.justItem.y = 0

end
