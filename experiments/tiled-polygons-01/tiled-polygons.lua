

local tp = {}

tp.maxValue = 5

function tp.newWorld (width, height, scale)
   local w = 0
   local weigths = {}
   local minX, maxX = 1, width
   local minY, maxY = 1, height

   for y = minY, maxY+1 do
      weigths[y] = {}
      for x = minX, maxX+1 do
         weigths[y][x] = love.math.random (tp.maxValue-1)+1
      end
   end
   
   tp.minX, tp.maxX = minX, maxX
   tp.minY, tp.maxY = minY, maxY
   tp.weigths = weigths
   tp.scale = scale
   
   local world = {}
   for y = minY, maxY do
      world[y] = {}
      for x = minX, maxX do
         local tile = {x=x, y=y, w=1, h=1, polygon = nil}
         world[y][x] = tile
      end
   end
   
   tp.world = world
   
   for y = minY, maxY do
      for x = minX, maxX do
         tp.updateTile (x, y)
      end
   end
end

function tp.drawWeights ()
   local weigths, scale = tp.weigths, tp.scale
   love.graphics.push()
   love.graphics.scale (scale)
   love.graphics.setLineWidth (1/scale)
   for y = tp.minY, tp.maxY+1 do
      for x = tp.minX, tp.maxX+1 do
         local value = weigths[y][x]
         love.graphics.circle ('line', x-1, y-1, 0.5*(value+1)/(tp.maxValue+1))
      end
   end
   love.graphics.pop()
end

function tp.getWorld()
   return tp.world
end

function tp.drawTiles ()
   local world, scale = tp.world, tp.scale
   love.graphics.push()
   love.graphics.scale (scale)
   love.graphics.setLineWidth (1/scale)
   for y = tp.minY, tp.maxY do
      for x = tp.minX, tp.maxX do
         local tile = world[y][x]
         --if tile.fill then
         -- love.graphics.polygon ('fill', {x-1,y-1, x,y-1, x,y, x-1,y})
         --love.graphics.rectangle ('line', x-1, y-1, 1, 1)
         if tile.polygon then
            --                           print(#tile.polygon)
            love.graphics.setColor(1,.5,.5,.5)
            love.graphics.polygon ('fill', tile.polygon)
            --				love.graphics.polygon ('line', tile.polygon)
         else
            --				love.graphics.rectangle ('line', x-1, y-1, 1, 1)
         end
      end
   end
   love.graphics.pop()
end

function tp.drawCursor ()
   local world, scale = tp.world, tp.scale
   local weigths = tp.weigths
   love.graphics.push()
   love.graphics.scale (scale)
   love.graphics.setLineWidth (4/scale)
   --	love.graphics.circle ('line', tp.cursor.x-1, tp.cursor.y-1, 0.5)
   local value = weigths[tp.cursor.y][tp.cursor.x]
   love.graphics.circle ('line', tp.cursor.x-1, tp.cursor.y-1, 0.5*(value+1)/(tp.maxValue+1))
   love.graphics.pop()
end

function tp.drawWorld (world, scale)
   --	tp.drawWeights ()
   tp.drawTiles ()
   tp.drawCursor ()
end


tp.cursor = {x=1, y=1}

function tp.getCursorPosition (x, y)
   local scale = tp.scale
   x = math.min (math.floor((x)/scale+0.5), tp.maxX)+1
   y = math.min (math.floor((y)/scale+0.5), tp.maxY)+1
   love.window.setTitle (x..' '..y)
   return x, y
end


local function calculateValue(x, y, base)
   local result
   if x < base then
      result = (base - x) / (base + 1)
   else
      result = (y + 1) / (base + 1)
   end
   return result
end


function tp.updateTile (x, y)
   local tile = tp.world and tp.world[y] and tp.world[y][x]
   if not tile then return end
   
   local weigths = tp.weigths
   local w1 = weigths[y][x]
   local w2 = weigths[y][x+1]
   local w3 = weigths[y+1][x+1]
   local w4 = weigths[y+1][x]
   local b1 = (w1 == tp.maxValue) and true or false
   local b2 = (w2 == tp.maxValue) and true or false
   local b3 = (w3 == tp.maxValue) and true or false
   local b4 = (w4 == tp.maxValue) and true or false
   
   
   if b1 and b2 and b3 and b4 then
      tile.polygon = nil
      tile.fill = true
      tile.polygon =  {x-1,y-1, x,y-1, x,y, x-1,y}
      return
   elseif not (b1 or b2 or b3 or b4) then
      tile.polygon = nil
      tile.fill = false
      return
   end
   
   local polygon = {}
   if b1 then
      table.insert (polygon, x-1)
      table.insert (polygon, y-1)
   end
   if (b1 and not b2) or (not b1 and b2) then
      table.insert (polygon, x-1+calculateValue(w1, w2, tp.maxValue))
      table.insert (polygon, y-1)
   end
   if b2 then
      table.insert (polygon, x)
      table.insert (polygon, y-1)
   end
   
   if (b2 and not b3) or (not b2 and b3) then
      table.insert (polygon, x)
      table.insert (polygon, y-1+calculateValue(w2, w3, tp.maxValue))
   end
   
   if b3 then
      table.insert (polygon, x)
      table.insert (polygon, y)
   end
   
   
   if (b3 and not b4) or (not b3 and b4) then
      table.insert (polygon, x-1+calculateValue(w4, w3, tp.maxValue))
      table.insert (polygon, y)
   end
   
   if b4 then
      table.insert (polygon, x-1)
      table.insert (polygon, y)
   end
   
   if (b1 and not b4) or (not b1 and b4) then
      table.insert (polygon, x-1)
      table.insert (polygon, y-1+calculateValue(w1, w4, tp.maxValue))
   end
   
   --	print (#polygon)
   tile.fill = false
   if #polygon > 5 then
      --		print (table.concat (polygon, ", "))
      tile.polygon = polygon
   else
      tile.polygon = nil
   end
end

function tp.updateWeight (x, y)
   tp.updateTile (x, y)
   tp.updateTile (x-1, y-1)
   tp.updateTile (x-1, y)
   tp.updateTile (x, y-1)
end

function tp.wheelmoved (wx, wy)
   local cx, cy = tp.cursor.x, tp.cursor.y
   local value = tp.weigths[cy][cx]
   tp.weigths[cy][cx] = math.max (0, math.min(tp.maxValue,value + wy))
   tp.updateWeight (cx, cy)
end

function tp.mousemoved (mx, my)
   local cx, cy = tp.getCursorPosition (mx, my)
   tp.cursor.x, tp.cursor.y = cx, cy
end

return tp
