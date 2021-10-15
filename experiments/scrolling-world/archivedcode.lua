   if (false) then
      sortOnDepth(stuff)
      for _, v in pairs(stuff) do

         hack.scale = mapInto(v.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
         hack.relativeScale = (1.0/ hack.scale) * hack.scale
         hack.push()

         love.graphics.setColor(v.color)
         love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
         love.graphics.setColor(.1, .1, .1)
         love.graphics.rectangle('line', v.x, v.y, v.width, v.height)

         hack:pop()
      end
   end


function stuff()
   betterShader = love.graphics.newShader( [[
         extern mat4 view;
         extern mat4 m2;
         vec4 position(mat4 m, vec4 p) {
             return view  * TransformMatrix * m2 *  p;
         }
   ]])


   local v = {x=0, y=0}

   if love.keyboard.isDown('left') or moving == 'left' then
      v.x = v.x - 1
   end
   if love.keyboard.isDown('right') or moving == 'right' then
      v.x = v.x + 1
   end
   if love.keyboard.isDown('up') then
      v.y = v.y - 1
   end
   if love.keyboard.isDown('down') then
      v.y = v.y + 1
   end

   local mag = math.sqrt((v.x * v.x) + (v.y * v.y))
   if mag > 0 then
      v.x = (v.x/mag) * player.speed * dt
      v.y = (v.y/mag) * player.speed * dt
      player.x = player.x + v.x
      player.depth = player.depth + (v.y)/100
      newPlayer.transforms.l[1] = newPlayer.transforms.l[1] + v.x
      newPlayer.depth =player.depth

      if testCar then
         -- doing the depth
         local otherScale = mapInto(carbody.depth, depthMinMax.min, depthMinMax.max, depthScaleFactors.min, depthScaleFactors.max)
         carbody.depth = player.depth
         carbodyVoor.depth = player.depth + carThickness * otherScale
         voor2.transforms.l[1] =  newPlayer.transforms.l[1]
         voor2.depth = player.depth + carThickness * otherScale -- to get a perspective going
         local dir = v.x > 0 and 1 or -1

         -- rotating the wheels
         newPlayer.children[1].children[2].transforms.l[3] =  newPlayer.children[1].children[2].transforms.l[3] +  10 * dt * dir
         newPlayer.children[1].children[3].transforms.l[3] =  newPlayer.children[1].children[3].transforms.l[3] +  10 * dt * dir
      end

   end
end

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

if false then
if cameraFollowPlayer then
      local delta = cam:setTranslationSmooth(
            player.x + player.width/2 ,
            player.y - 300,
            dt,
            10
                                   )
      followPlayerCameraDelta = delta.x + delta.y
   end
end


function drawCameraViewPointRectangles(cameraPoint)
   for _, v in pairs(cameraPoint) do
      love.graphics.setColor(1,0,1,.5)
      if v.selected then
         love.graphics.setColor(1,0,0,.6)
      end

      love.graphics.rectangle('line', v.x, v.y, v.width, v.height)
   end
end

function drawCameraCross(W,H)
   love.graphics.setColor(1,1,1,.2)
   love.graphics.line(0,0,W,H)
   love.graphics.line(0,H,W,0)
end
