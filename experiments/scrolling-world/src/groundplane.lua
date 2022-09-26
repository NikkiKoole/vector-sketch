local numbers = require 'lib.numbers'
local formats = require 'lib.formats'

local groundTiles = {}

local minground = -200
local maxground = 200

for i = minground, maxground do
   groundTiles[i] = { tileIndex = math.ceil(math.random() * 5) }
   if math.random() < .5 then
      groundTiles[i].tileIndex = -1
   end

end


function drawGroundPlaneLinesSimple(cam, far, near)

   love.graphics.setColor(1, 1, 1)
   love.graphics.setLineWidth(2)
   local W, H = love.graphics.getDimensions()

   local x1, y1 = cam:getWorldCoordinates(0, 0, far)
   local x2, y2 = cam:getWorldCoordinates(W, 0, far)

   local s = math.floor(x1 / tileSize) * tileSize
   local e = math.ceil(x2 / tileSize) * tileSize

   for i = s, e, tileSize do
      local groundIndex = (i / tileSize)
      local tileIndex = (groundIndex % 5) + 1
      local index = (i - s) / tileSize
      local height1 = 0
      local height2 = 0
      local x1, y1 = cam:getScreenCoordinates(i + 0.0001, height1, far)
      local x2, y2 = cam:getScreenCoordinates(i + 0.0001, 0, near)
      local x3, y3 = cam:getScreenCoordinates(i + tileSize + .0001, height2, far)
      local x4, y4 = cam:getScreenCoordinates(i + tileSize + .0001, 0, near)

      love.graphics.setColor(0.25, 1 - (0.05 * tileIndex), 0.25, .5)
      love.graphics.polygon("fill", { x1, y1, x3, y3, x4, y4, x2, y2 })
      love.graphics.setColor(0.25, .5, 0.25)

      love.graphics.line(x1, y1, x2, y2)
      love.graphics.line(x1, y1, x3, y3)

   end
end

function drawGroundPlaneWithTextures(cam, far, near, layerName)

   local W, H = love.graphics.getDimensions()

   local x1, y1 = cam:getWorldCoordinates(0, 0, far)
   local x2, y2 = cam:getWorldCoordinates(W, 0, far)

   local s = math.floor(x1 / tileSize) * tileSize
   local e = math.ceil(x2 / tileSize) * tileSize

   local bounds = perspectiveContainer[layerName].cameraBounds
   local boundsAreSame = (bounds.x[1] == x1 and bounds.x[2] == x2 and bounds.y[1] == y1 and bounds.y[2] == y2)


   for i = s, e, tileSize do
      local groundIndex = (i / tileSize)
      if groundIndex > minground and groundIndex < maxground then
         local tileIndex = groundTiles[groundIndex].tileIndex -- (groundIndex % 5) + 1
         local index = (i - s) / tileSize

         if tileIndex > -1 then
            if boundsAreSame then
               if index >= 0 and index <= 100 then
                  drawGroundPlanesSameSame(index, tileIndex, layerName)
               end
            else
               local height1 = 0
               local height2 = 0
               local x1, y1 = cam:getScreenCoordinates(i + 0.0001, height1, far)
               local x2, y2 = cam:getScreenCoordinates(i + 0.0001, 0, near)
               local x3, y3 = cam:getScreenCoordinates(i + tileSize + .0001, height2, far)
               local x4, y4 = cam:getScreenCoordinates(i + tileSize + .0001, 0, near)
               local dest = { { x1, y1 }, { x3, y3 }, { x4, y4 }, { x2, y2 } }
               --print(inspect(dest))
               if index >= 0 and index <= 100 then

                  drawGroundPlaneInPosition(dest, index, tileIndex, layerName)
               end

            end
         else
            -- this basically is just the drawsimple from above
            local height1 = 0
            local height2 = 0
            local x1, y1 = cam:getScreenCoordinates(i + 0.0001, height1, far)
            local x2, y2 = cam:getScreenCoordinates(i + 0.0001, 0, near)
            local x3, y3 = cam:getScreenCoordinates(i + tileSize + .0001, height2, far)
            local x4, y4 = cam:getScreenCoordinates(i + tileSize + .0001, 0, near)

            love.graphics.setColor(0.25, 1 - (0.05 * tileIndex), 0.25, .5)
            love.graphics.polygon("fill", { x1, y1, x3, y3, x4, y4, x2, y2 })
            --love.graphics.setColor(0.25,.5,0.25)

            --love.graphics.line(x1,y1, x2,y2)
            --love.graphics.line(x1,y1, x3,y3)
         end
      end
   end

   perspectiveContainer[layerName].cameraBounds.x = { x1, x2 }
   perspectiveContainer[layerName].cameraBounds.y = { y1, y2 }


end

function drawGroundPlanesSameSame(index, tileIndex, layerName)
   local thing = groundPlanes[tileIndex].thing
   for j = 1, #thing.optimizedBatchMesh do
      love.graphics.setColor(thing.optimizedBatchMesh[j].color)
      love.graphics.draw(perspectiveContainer[layerName][index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1
   end
   love.graphics.setColor(1, 1, 1)

end

function drawGroundPlaneInPosition(dest, index, tileIndex, layerName)
   local thing = groundPlanes[tileIndex].thing
   local bbox = groundPlanes[tileIndex].bbox
   local source = { bbox.tl.x, bbox.tl.y, bbox.br.x, bbox.br.y }

   for j = 1, #thing.optimizedBatchMesh do
      local count = thing.optimizedBatchMesh[j].mesh:getVertexCount()
      local result = {}

      for v = 1, count do
         local x, y = thing.optimizedBatchMesh[j].mesh:getVertex(v)
         local r = numbers.transferPoint(x, y, source, dest)
         table.insert(result, { r.x, r.y })
      end

      if perspectiveContainer[layerName][index][j].perspMesh and
          perspectiveContainer[layerName][index][j].perspMesh:getVertexCount() == #result then
         perspectiveContainer[layerName][index][j].perspMesh:setVertices(result, 1, #result)
      else
         perspectiveContainer[layerName][index][j] = {
            perspMesh = love.graphics.newMesh(formats.simple_format, result, "triangles", "stream")
         }
      end

      love.graphics.setColor(thing.optimizedBatchMesh[j].color)
      love.graphics.draw(perspectiveContainer[layerName][index][j].perspMesh)
      renderCount.groundMesh = renderCount.groundMesh + 1

   end
   love.graphics.setColor(1, 1, 1)

end
