
groundTiles = {}

local minground = -2000
local maxground = 2000

for i = minground, maxground do
   groundTiles[i] = {tileIndex = math.ceil(math.random()*5)}
   if math.random() < .5 then
      groundTiles[i].tileIndex = -1
   end


   local cool = 1.78
   
   local amplitude = 1000 * cool
   local frequency = 33
   local h = love.math.noise(i/frequency, 1,1)*amplitude
   h = h - (amplitude/2)


   local amplitude = 200* cool
   local frequency = 3
   local h2 = love.math.noise(i/frequency, 1,1)*amplitude
   h2 = h2 - (amplitude/2)

   print(h)

   

   groundTiles[i].height = (h + (h2/2))/1.5


   groundTiles[i].pathTop = 0.125 + love.math.random()* .25
   groundTiles[i].pathBottom = 1 - 0.125 - love.math.random()* .25
   
   -- groundTiles[i].height = h
   
end


function isClockwise(vertices)
   local sum = 0.0;
   for i =1, #vertices do
      local v1 = vertices[i]
      local v2 = vertices[((i + 1) % #vertices)+1]
      sum = sum + (v2[1] - v1[1]) * (v2[2] + v1[2])
   end
   return sum > 0
   
end


function drawGroundPlaneWithTextures(cam, far, near, layerName)

   local W, H = love.graphics.getDimensions()

   local x1,y1 = cam:getWorldCoordinates(0,0, far)
   local x2,y2 = cam:getWorldCoordinates(W,0, far)

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   local bounds = perspectiveContainer[layerName].cameraBounds
   local boundsAreSame =  (bounds.x[1] == x1 and bounds.x[2] == x2 and bounds.y[1] == y1 and bounds.y[2] == y2)


   for i = s, e, tileSize do
      local groundIndex = (i/tileSize)
      if groundIndex > minground and groundIndex < maxground then
         
         local tileIndex = groundTiles[groundIndex].tileIndex
         local index = (i - s)/tileSize


         --         print()

         local height1 = groundTiles[groundIndex].height
         local height2 = groundTiles[groundIndex].height
         local height3 = groundTiles[groundIndex + 1].height
         local height4 = groundTiles[groundIndex + 1].height


         local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, far)
         local x2,y2 = cam:getScreenCoordinates(i+0.0001, height2, near)
         local x3, y3 = cam:getScreenCoordinates(
            i+tileSize + .0001, height3, far)
         local x4, y4 = cam:getScreenCoordinates(
            i+tileSize+ .0001, height4, near)


         local useNew = true

         
         
         if useNew then
            local tileIndex = 1

	    love.graphics.setColor(0.25,.5-(0.01*tileIndex),0.25,.85)

            -- backface check, needs 3 vertices to determine
            local cw = isClockwise({{x1,y1},{x3,y3},{x4,y4}})
            --print(cw)
            if not cw then
               love.graphics.setColor(1, .5, .3, 1)
            end

            
	    love.graphics.polygon("fill", {x1,y1, x3,y3,x4,y4,x2,y2})
	    local scale= cam:getScale()

            
            local pt = .25 --groundTiles[groundIndex].pathTop
            local pb = .75 --groundTiles[groundIndex].pathBottom

            -- draw path   -- broken crap
            local topY = lerp(y1, y2, pt)
            local topX = lerp(x1, x2, pt)
            local bottomY = lerp(y2, y1, 1.0-pb)
            local bottomX = lerp(x2, x1, 1.0-pb)

            local topY3 = lerp(y3, y4, pt)
            local topX3 = lerp(x3, x4, pt)
            local bottomY3 = lerp(y4, y3, 1.0-pb)
            local bottomX3 = lerp(x4, x3, 1.0-pb)

            
            love.graphics.setColor(1,1,1, .5)
            love.graphics.polygon("fill", {topX,topY, topX3,topY3,bottomX3,bottomY3,bottomX,bottomY})

            
            -- draw side triangle
            love.graphics.setColor(0.25,.5-(0.01*tileIndex),0.25,.5)

            if true then
               if (y2 > y4) then
                  love.graphics.polygon("fill", {x2,y2, x4,y4, x4, math.max(y2,y4)})
               else
                  love.graphics.polygon("fill", {x2,y2, x4,y4, x2, math.max(y2,y4)})
               end
            end
            
            love.graphics.setColor(1, .5, .3)
            love.graphics.setColor(0.25,.5-(0.01*tileIndex),0.25,.5)
	    love.graphics.polygon("fill", {x2,math.max(y2,y4) , x4,math.max(y2,y4) , x4, math.max(y2,y4) + 1000*scale, x2, math.max(y2,y4) + 1000*scale})

            
	    
	    love.graphics.setColor(0,0,0,.85)
	    love.graphics.line(x1,y1, x2,y2)
	    --love.graphics.line(x3,y3, x2,y2)
         end
         

         
         if not useNew then
            if tileIndex > -1 then
               if boundsAreSame then
                  if index >= 0 and index <= 100 then
                     drawGroundPlanesSameSame(index, tileIndex, layerName)
                  end
               else
                  local height1 = 0
                  local height2 = 0
                  local height3 = 0
                  local height4 = 0

                  local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, far)
                  local x2,y2 = cam:getScreenCoordinates(i+0.0001, height2, near)
                  local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height3, far)
                  local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, height4, near)
                  local dest = {{x1,y1}, {x3,y3}, {x4,y4}, {x2,y2}}
                  if index >= 0 and index <= 100 then
                     -- THIS IS THE GUY
                     drawGroundPlaneInPosition(dest, index, tileIndex, layerName)
                  end

               end
            else
               -- this basically is just the drawsimple from above
               local height1 = 30
               local height2 = 30
               local height3 = 0
               local height4 = 0
               local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, far)
               local x2,y2 = cam:getScreenCoordinates(i+0.0001, height2, near)
               local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height3, far)
               local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, height4, near)

               love.graphics.setColor(0.25,.5-(0.05*tileIndex),0.25,.85)
               love.graphics.polygon("fill", {x1,y1, x3,y3,x4,y4,x2,y2})
               --love.graphics.setColor(0.25,.5,0.25)

               --love.graphics.line(x1,y1, x2,y2)
               --love.graphics.line(x1,y1, x3,y3)
            end
         end
      end
      
   end

   perspectiveContainer[layerName].cameraBounds.x = {x1,x2}
   perspectiveContainer[layerName].cameraBounds.y = {y1,y2}

   -- if false then
   -- if (bounds.x[1] == x1 and bounds.x[2] == x2
   --     and bounds.y[1] == y1 and bounds.y[2] == y2) then
   --    for i = s, e, tileSize do
   --       local groundIndex = (i/tileSize)

   --       local tileIndex = groundTiles[groundIndex].tileIndex --(groundIndex % 5) + 1
   --       local index = (i - s)/tileSize
   --       if index >= 0 and index <= 100 then
   --          drawGroundPlanesSameSame(index, tileIndex, layerName)
   --       end
   --    end
   -- else
   --    for i = s, e, tileSize do
   --       local groundIndex = (i/tileSize)
   --       local tileIndex = groundTiles[groundIndex].tileIndex-- (groundIndex % 5) + 1
   --       local index = (i - s)/tileSize
   --       local height1 = 0
   --       local height2 = 0
   --       local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, far)
   --       local x2,y2 = cam:getScreenCoordinates(i+0.0001, 0, near)
   --       local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height2, far)
   --       local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, 0, near)
   --       local dest = {{x1,y1}, {x3,y3}, {x4,y4}, {x2,y2}}
   --       if index >= 0 and index <= 100 then
   --          drawGroundPlaneInPosition(dest, index, tileIndex, layerName)
   --       end
   --    end
   --    perspectiveContainer[layerName].cameraBounds.x = {x1,x2}
   --    perspectiveContainer[layerName].cameraBounds.y = {y1,y2}
   -- end
   -- end


end


function drawGroundPlaneLinesSimple(cam, far, near)

   love.graphics.setColor(1,1,1)
   love.graphics.setLineWidth(2)
   local W, H = love.graphics.getDimensions()

   local x1,y1 = cam:getWorldCoordinates(0,0, far)
   local x2,y2 = cam:getWorldCoordinates(W,0, far)

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   for i = s, e, tileSize do
      local groundIndex = (i/tileSize)
      local tileIndex = (groundIndex % 5) + 1
      local index = (i - s)/tileSize
      local height1 = 0
      local height2 = 0
      local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, far)
      local x2,y2 = cam:getScreenCoordinates(i+0.0001, 0, near)
      local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height2, far)
      local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, 0, near)

      love.graphics.setColor(0.25,1-(0.05*tileIndex),0.25,.5)
      love.graphics.polygon("fill", {x1,y1, x3,y3,x4,y4,x2,y2})
      love.graphics.setColor(0.25,.5,0.25)

      love.graphics.line(x1,y1, x2,y2)
      love.graphics.line(x1,y1, x3,y3)

   end
end


function drawGroundPlanesSameSame(index, tileIndex, layerName)
   local thing = groundPlanes[tileIndex].thing
   for j = 1, #thing.optimizedBatchMesh do
      love.graphics.setColor(thing.optimizedBatchMesh[j].color)
      love.graphics.draw(perspectiveContainer[layerName][index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1
   end
   love.graphics.setColor(1,1,1)

end

function drawGroundPlaneInPosition(dest, index, tileIndex, layerName)
   print('assuming groundplanes')
   local thing = groundPlanes[tileIndex].thing
   local bbox = groundPlanes[tileIndex].bbox
   local source = {bbox.tl.x, bbox.tl.y, bbox.br.x, bbox.br.y }

   for j = 1, #thing.optimizedBatchMesh do
      local count = thing.optimizedBatchMesh[j].mesh:getVertexCount()
      local result = {}

      for v = 1, count do
	 local x, y = thing.optimizedBatchMesh[j].mesh:getVertex(v)
	 local r = transferPoint (x, y, source, dest)
	 table.insert(result, {r.x, r.y})
      end

      if perspectiveContainer[layerName][index][j].perspMesh and
	 perspectiveContainer[layerName][index][j].perspMesh:getVertexCount() == #result then
	 perspectiveContainer[layerName][index][j].perspMesh:setVertices(result, 1, #result)
      else
	 perspectiveContainer[layerName][index][j] = {
	    perspMesh = love.graphics.newMesh(simple_format, result , "triangles", "stream")
	 }
      end

      love.graphics.setColor(thing.optimizedBatchMesh[j].color)
      love.graphics.draw(perspectiveContainer[layerName][index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1

   end
   love.graphics.setColor(1,1,1)

end






--[[
   function drawGroundPlaneLines(cam)
   local thing = groundPlanes.assets[1].thing
   local W, H = love.graphics.getDimensions()
   love.graphics.setColor(1,1,1)
   love.graphics.setLineWidth(2)


   local W, H = love.graphics.getDimensions()

   local x1,y1 = cam:getWorldCoordinates(0,0, 'hackFar')
   local x2,y2 = cam:getWorldCoordinates(W,0, 'hackFar')

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   local useCPU = true

   local simplerPolies = false

   if simplerPolies then
   for i = s, e, tileSize do
   local groundIndex = (i/tileSize)
   local tileIndex = (groundIndex % 5) + 1
   local index = (i - s)/tileSize
   local height1 = 0
   local height2 = 0
   local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, 'hackFar')
   local x2,y2 = cam:getScreenCoordinates(i+0.0001, 0, 'hackClose')
   local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height2, 'hackFar')
   local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, 0, 'hackClose')

   love.graphics.setColor(0.25,1-(0.05*tileIndex),0.25,.5)
   love.graphics.polygon("fill", {x1,y1, x3,y3,x4,y4,x2,y2})
   love.graphics.setColor(0.25,.5,0.25)

   love.graphics.line(x1,y1, x2,y2)
   love.graphics.line(x1,y1, x3,y3)

   end


   return
   end



   if useCPU then

   if ((lastCameraBounds[1]) == (x1) and (lastCameraBounds[2]) == (x2) and (lastCameraBounds[3]) == (y1)) then
   for i = s, e, tileSize do
   local groundIndex = (i/tileSize)
   local tileIndex = (groundIndex % 5) + 1
   local index = (i - s)/tileSize
   if index >= 0 and index <= 100 then
   drawGroundPlanesSameSame(index, tileIndex)
   end
   end
   else
   for i = s, e, tileSize do
   local groundIndex = (i/tileSize)
   local tileIndex = (groundIndex % 5) + 1
   local index = (i - s)/tileSize
   local height1 = 0
   local height2 = 0
   local x1,y1 = cam:getScreenCoordinates(i+0.0001, height1, 'hackFar')
   local x2,y2 = cam:getScreenCoordinates(i+0.0001, 0, 'hackClose')
   local x3, y3 = cam:getScreenCoordinates(i+tileSize + .0001, height2, 'hackFar')
   local x4, y4 = cam:getScreenCoordinates(i+tileSize+ .0001, 0, 'hackClose')
   local dest = {{x1,y1}, {x3,y3}, {x4,y4}, {x2,y2}}
   if index >= 0 and index <= 100 then
   drawGroundPlaneInPosition(dest, index, tileIndex)
   end
   end
   lastCameraBounds= {x1,x2,y1, y2}
   end
   else
   love.graphics.setShader(betterShader)


   local ratio = W/H
   local ratio1024 = 1024/768
   local ratio1869 = 1869/1027
   local first = mapInto(ratio, ratio1024, ratio1869, 1.15, .65)

   betterShader:send('view', {
   first,    0,    0, -150,
   0,    0,    -1.7, -120,
   0,    1,    0,   50,
   0,    1,    0,   50,
   })

   local offset = H - 768
   --      offset/2.225

   --local weirdOffset = (H-768)
   betterShader:send('m2', {
   1,    0,    0,   0,
   0,    1,    0,   -(offset/2.225),
   0,    0,    1,   0,
   0,    0,    0,   1,
   })
   --	return camera.projection_matrix * camera.view_matrix * model.matrix * TransformMatrix  * initial_vertex_position ;


   for i = s, e, tileSize do
   local groundIndex = (i/tileSize)
   local tileIndex = (groundIndex % 5) + 1
   local optimized = groundPlanes.assets[tileIndex].thing.optimizedBatchMesh
   local scale = cam:getScale()*0.225
   --print('ratio', cam:getContainerDimensions())
   local scale2 = cam:getScale()*.5
   local tx, ty = cam:getViewportPosition()
   local x1,y1 = cam:getScreenCoordinates(i+0.0001, 0, 'hackFar')
   for  j=1, #optimized do
   love.graphics.setColor(optimized[j].color[1],optimized[j].color[2],optimized[j].color[3],0.5 )
   love.graphics.draw(optimized[j].mesh,
   x1/4,
   100 ,
   0,
   1*scale,
   -1*scale*1.55)
   renderCount.groundMesh = renderCount.groundMesh + 1

   end

   end
   love.graphics.setShader()
   end
   end
--]]
