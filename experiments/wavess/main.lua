require 'util'
require 'poly'
flux = require "flux"


function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
   if key == 'left' then
      local newV = boat.velocity - 1
      flux.to(boat, 1, {velocity=newV})
   end
   if key == 'right' then
      local newV = boat.velocity + 1
      flux.to(boat, 1, {velocity=newV})
   end
end

function love.load()
   local screenwidth = 1204
   love.window.setMode(screenwidth, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
   boat = {
      velocity = 0,
      world_pos = 0
   }
   local endI = ((screenwidth+ 80)/20)
   wave_offsets = {}
   for i=1, endI do
      table.insert(wave_offsets, love.math.random() * 6 - 3)
   end
end


local waveCounter = 0
function love.update(dt)

   waveCounter = waveCounter + dt
   boat.world_pos =  boat.world_pos + (boat.velocity * dt)
   flux.update(dt)
end


function anotherWaveFunction(waveCounter, middleY, waves, amplitude)
   local screenWidth = love.graphics.getWidth()
   local coords = {}
   local endI = ((screenWidth+ 80)/20)

   for i =1, endI do
      local x = (i*20) - 40
      local x2 = ( x + (waveCounter * 100))
      local y =  boat.world_pos + ((x2 / screenWidth) * math.pi * waves)
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
   love.graphics.setColor(0,0.4,0.58, 0.7)
   local polys = decompose_complex_poly(coords, {})
    for i=1 , #polys do
       local p = polys[i]
       local triangles = love.math.triangulate(p)
       for j = 1, #triangles do
	  love.graphics.polygon('fill', triangles[j])
       end
    end
    love.graphics.setColor(0, 0.3,0.48, 0.9)
    love.graphics.line(coords)
   --- end drawing the filled wave


end

function foamFunction(waveCounter, middleY, waves, amplitude, startX, endX, alpha, ydiff)
   local screenWidth = love.graphics.getWidth()
   local width = endX - startX
   local coords = {}
   local endI = ((width+ 80)/20)

   love.graphics.setColor(1,1,1, alpha)

   for i =1, endI do
      local x = (i*20) - 40 + startX
      local x2 = ( x + (waveCounter * 100))
      local y =  boat.world_pos + ((x2 / screenWidth) * math.pi * waves*1.5)
      local y2 = middleY + math.sin(y) * amplitude
      coords[i*2 - 1] = x + wave_offsets[i]
      coords[i*2 ] = y2 + ((i*ydiff*0.3)/endI)
      --love.graphics.rectangle("fill", x + wave_offsets[i], y2, 4,4)
   end

   -- local splits = {}
   -- local index = 1
   -- for i = 1, #coords-4,4 do
   --    splits[index] = {coords[i], coords[i+1], coords[i+2], coords[i+3]}
   --    if (coords[i+4] and coords[i+5]) then
   -- 	 splits[index+1] = {coords[i+2], coords[i+3], coords[i+4], coords[i+5]}
   --    end
   --    index = index + 2
   -- end
   -- for i = 1, #splits do
   --    love.graphics.setLineWidth(#splits/(i*1.3))
   --    love.graphics.line(splits[i])
   -- en

   love.graphics.setLineWidth((200-width)/50)
   love.graphics.line(coords)

end



function love.draw()
   local extraY = math.sin(boat.world_pos  + waveCounter * 2) * 2
   love.graphics.clear(180/255, 211/255, 230/255)
   love.graphics.print(boat.world_pos, 10,10)

   anotherWaveFunction(waveCounter, 350 + extraY/2, 28, 1.5)

   anotherWaveFunction(waveCounter, 375 + extraY/1.5, 26, 1.5)

   foamFunction(waveCounter, 370+ extraY, 26, 2, 0, 200, boat.velocity/20, 30 )
   foamFunction(waveCounter, 380+ extraY, 25.5, 2, 0, 250, boat.velocity/10, 20 )
   foamFunction(waveCounter, 390+ extraY, 25, 2, 0, 300, boat.velocity/6, 5)

   love.graphics.setColor(4/255,0,90/255,1)
   love.graphics.rectangle("fill", 200,300 + extraY,500,200)

   anotherWaveFunction(waveCounter, 400+ extraY, 24, 3)

   anotherWaveFunction(waveCounter, 425+ extraY, 21, 4)

   foamFunction(waveCounter, 405+ extraY, 24, 2, 0, 300, boat.velocity/6, -5)
   foamFunction(waveCounter, 415+ extraY, 24.5, 2, 0, 250, boat.velocity/10, -20)
   foamFunction(waveCounter, 425+ extraY, 25, 2, 0, 200, boat.velocity/20, -30)

end
