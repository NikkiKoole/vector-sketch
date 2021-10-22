
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

function drawGroundPlaneWithTextures(cam, far, near, layerName)

   local W, H = love.graphics.getDimensions()

   local x1,y1 = cam:getWorldCoordinates(0,0, far)
   local x2,y2 = cam:getWorldCoordinates(W,0, far)

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   --print(layerName, inspect(perspectiveContainer))
   local bounds = perspectiveContainer[layerName].cameraBounds

   if (bounds.x[1] == x1 and bounds.x[2] == x2
       and bounds.y[1] == y1 and bounds.y[2] == y2) then
      for i = s, e, tileSize do
         local groundIndex = (i/tileSize)
         local tileIndex = (groundIndex % 5) + 1
         local index = (i - s)/tileSize
         if index >= 0 and index <= 100 then
            drawGroundPlanesSameSame(index, tileIndex, layerName)
         end
      end
   else
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
         local dest = {{x1,y1}, {x3,y3}, {x4,y4}, {x2,y2}}
         if index >= 0 and index <= 100 then
            drawGroundPlaneInPosition(dest, index, tileIndex, layerName)
         end
      end
      perspectiveContainer[layerName].cameraBounds.x = {x1,x2}
      perspectiveContainer[layerName].cameraBounds.y = {y1,y2}
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
