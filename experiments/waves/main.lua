require 'util'
require 'poly'


function love.load()
   love.window.setMode(1024, 768)
end

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
end


local waveCounter = 0
function love.update(dt)
   waveCounter = waveCounter + dt
   
end


function drawWave(amplitude, period, middleY, cycles, offset, drawBackdrop)
   local coords = {}
   local counter = 0
   for x = 1+offset, (360*cycles)+offset do
      local y = middleY + math.sin(((x/period)*360 * math.pi/180)) * amplitude
      local x2 = x - offset
      
      if counter > 1 or counter == 0 then
	 table.insert(coords, x2)
	 table.insert(coords, y)
	 counter = 0
      end

      counter = counter + 1
   end
   -- now make it a closed shape please
   local lastX = coords[#coords-1]
   local lastY = coords[#coords]


   table.insert(coords, lastX)
   table.insert(coords, lastY+1200)
   table.insert(coords, coords[1])
   table.insert(coords, lastY+1200)
   table.insert(coords, coords[1])
   table.insert(coords, coords[2])
      
   love.graphics.setLineWidth(2)
   if (drawBackdrop) then
   love.graphics.setColor(0.145,0.6,0.670, 0.85)
   local polys = decompose_complex_poly(coords, {})
    for i=1 , #polys do
       local p = polys[i]
       local triangles = love.math.triangulate(p)
       for j = 1, #triangles do
	  --print(triangles[j])
	  love.graphics.polygon('fill', triangles[j])
       end
       
    end
     love.graphics.setColor(1,1,1,1)

       love.graphics.line(coords)
    else
   --print(#polys)
       love.graphics.setColor(1,1,1,1)

       love.graphics.line(coords)
   end
   
    --love.graphics.points(coords)
end


function love.draw()
   local speed = 1.0/2 
   
   drawWave(5, 100, 100 + math.cos(waveCounter)*8, 3, ((waveCounter * speed) % 1.0) * 100 , true)
   drawWave(6, 100, 200 + math.cos(waveCounter)*4, 3, 30 + ((waveCounter * speed) % 1.0) * 100 , false)
   drawWave(5, 100, 300 + math.cos(waveCounter)*8, 3, ((waveCounter * speed) % 1.0) * 100 , false)
   drawWave(6, 100, 400 + math.cos(waveCounter)*4, 3, 30 + ((waveCounter * speed) % 1.0) * 100 , false)

   drawWave(5, 100, 150 + math.cos(waveCounter)*8, 3, ((waveCounter * speed*1.5) % 1.0) * 100 , false)
   drawWave(6, 100, 250 + math.cos(waveCounter)*4, 3, 30 + ((waveCounter * speed*1.5) % 1.0) * 100 , false)
   drawWave(5, 100, 350 + math.cos(waveCounter)*8, 3, ((waveCounter * speed*1.5) % 1.0) * 100, false )
   drawWave(6, 100, 450 + math.cos(waveCounter)*4, 3, 30 + ((waveCounter * speed*1.5) % 1.0) * 100 , false)
   -- local amplitude = 10
   -- local period = 100 -- 360 px for 1 period
   -- local middleY = 100
   -- local cycles = 2
   -- local offset = 20
   -- for x = 1+offset, (360*cycles) do
   --    local y = middleY + math.sin(((x/period)*360 * math.pi/180)) * amplitude
   --    local x2 = x - offset
   --    love.graphics.rectangle('fill', x2,y,1,1)
   -- end

   --drawWave(10, 100, 100, 2, 0)
   --drawWave(10, 100, 200, 2, 120)
end

