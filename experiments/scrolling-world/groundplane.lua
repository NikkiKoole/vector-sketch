function drawGroundPlaneLines()
   local thing = groundPlanes.assets[1].thing
   local W, H = love.graphics.getDimensions()
   love.graphics.setColor(1,1,1)
   love.graphics.setLineWidth(2)
   local x1,y1 = cam:getWorldCoordinates(0,0, 'hackFar')
   local x2,y2 = cam:getWorldCoordinates(W,0, 'hackFar')
   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   arrangeWhatIsVisible(x1, x2, tileSize)

   local useCPU = false 

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
     
      betterShader:send('view', {
                     1.3,  0,    0, -150,
                     0,    0, -1.7, -120,
                     0,    1,    0,   50,
                     0,    1,    0,   50,
      })

      for i = s, e, tileSize do
         local groundIndex = (i/tileSize)
         local tileIndex = (groundIndex % 5) + 1
            local optimized = groundPlanes.assets[tileIndex].thing.optimizedBatchMesh
            local scale = cam:getScale()*0.225
            local tx, ty = cam:getViewportPosition()
            local x1,y1 = cam:getScreenCoordinates(i+0.0001, H, 'hackFar')
            for  j=1, #optimized do
               love.graphics.setColor(optimized[j].color)
               love.graphics.draw(optimized[j].mesh,
                                  x1*scale,
                                  100 ,
                                  0,
                                  1*scale,
                                  -1*scale*1.4)
               renderCount.groundMesh = renderCount.groundMesh + 1

            end

      end
      love.graphics.setShader()
   end
end

function drawGroundPlanesSameSame(index, tileIndex)
   local thing = groundPlanes.assets[tileIndex].thing
   for j = 1, #thing.optimizedBatchMesh do
      love.graphics.setColor(thing.optimizedBatchMesh[j].color)
      love.graphics.draw(groundPlanes.perspectiveContainer[index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1
      love.graphics.setColor(1,1,1)
   end
end

function drawGroundPlaneInPosition(dest, index, tileIndex)
   local thing = groundPlanes.assets[tileIndex].thing
   local bbox = groundPlanes.assets[tileIndex].bbox
   local source = {bbox.tl.x, bbox.tl.y, bbox.br.x, bbox.br.y }

   for j = 1, #thing.optimizedBatchMesh do
      local count = thing.optimizedBatchMesh[j].mesh:getVertexCount()
      local result = {}

      for v = 1, count do
	 local x, y = thing.optimizedBatchMesh[j].mesh:getVertex(v)
	 local r = transferPoint (x, y, source, dest)
	 table.insert(result, {r.x, r.y})
      end

      if groundPlanes.perspectiveContainer[index][j].perspMesh and
	 groundPlanes.perspectiveContainer[index][j].perspMesh:getVertexCount() == #result then
	 groundPlanes.perspectiveContainer[index][j].perspMesh:setVertices(result, 1, #result)
      else
	 groundPlanes.perspectiveContainer[index][j] = {
	    perspMesh = love.graphics.newMesh(simple_format, result , "triangles", "stream")
	 }
      end

      love.graphics.setColor(thing.optimizedBatchMesh[j].color)

      love.graphics.draw(groundPlanes.perspectiveContainer[index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1

      love.graphics.setColor(1,1,1)
   end
end
