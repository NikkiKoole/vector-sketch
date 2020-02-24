require 'util'
require 'poly'
--flux = require "flux"


function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
   if key == 'left' then
      boat_velocity = boat_velocity - 1
   end
   if key == 'right' then
      boat_velocity = boat_velocity + 1
   end
end

function love.load()
   local screenwidth = 1204
   love.window.setMode(screenwidth, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
   boat_velocity = 0
   boat_world_pos = 0

   local endI = ((screenwidth+ 80)/20)
   wave_offsets = {}
   for i=1, endI do
      table.insert(wave_offsets, love.math.random() * 4 - 2)
   end

end


local waveCounter = 0
function love.update(dt)
   flux.update(dt)
   waveCounter = waveCounter + dt
   boat_world_pos =  boat_world_pos + (boat_velocity * dt)
end


function anotherWaveFunction(waveCounter, middleY, waves, amplitude)
   local screenWidth = love.graphics.getWidth()
   local coords = {}
   local endI = ((screenWidth+ 80)/20)

   for i =1, endI do
      local x = (i*20) - 40
      local x2 = ( x + (waveCounter * 100))
      local y =  boat_world_pos + ((x2 / screenWidth) * math.pi * waves)
      local y2 = middleY + math.sin(y) * amplitude
      coords[i*2 - 1] = x + wave_offsets[i]
      coords[i*2 ] = y2
   end

   --- drawing the filled wave
   local lastX = coords[#coords-1]
   local lastY = coords[#coords]
   table.insert(coords, lastX)
   table.insert(coords, lastY+1200)
   table.insert(coords, coords[1])
   table.insert(coords, lastY+1200)
   table.insert(coords, coords[1])
   table.insert(coords, coords[2])
   love.graphics.setColor(0,0.4,0.58, 0.9)
   local polys = decompose_complex_poly(coords, {})
    for i=1 , #polys do
       local p = polys[i]
       local triangles = love.math.triangulate(p)
       for j = 1, #triangles do
	  love.graphics.polygon('fill', triangles[j])
       end
    end
   --- end drawing the filled wave


end


function love.draw()
   love.graphics.clear(180/255, 211/255, 230/255)
   love.graphics.print(boat_world_pos, 10,10)
   anotherWaveFunction(waveCounter, 350, 28, 6)
   love.graphics.setColor(1,1,1,1)
   love.graphics.rectangle("fill", 200,300 + math.sin(boat_world_pos  + waveCounter * 2) * 5,500,200)
   anotherWaveFunction(waveCounter, 400, 24, 10)
end
