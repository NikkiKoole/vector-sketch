require 'util'
require 'poly'
flux = require "flux"
require 'main-utils'
inspect = require 'inspect'



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
   local screenwidth = 1024
   --love.window.setMode(screenwidth, 768, {resizable=true, vsync=false, minwidth=400, minheight=300})
   boat = {
      velocity = 0,
      world_pos = 0
   }
   local endI = ((screenwidth+ 80)/20)
   wave_offsets = {}
   for i=1, endI do
      table.insert(wave_offsets, love.math.random() * 6 - 3)
   end


   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={1024/2,700,0,1.25,1.25,0,0}},
      children ={}
   }
   justboat = parseFile('justboat.txt')[1]
   table.insert(root.children, justboat)
   parentize(root)
   meshAll(root)

end


local waveCounter = 0
function love.update(dt)

   waveCounter = waveCounter + dt
   boat.world_pos =  boat.world_pos + (boat.velocity * dt)
   flux.update(dt)
end


function anotherWaveFunction(waveCounter, middleY, waves, amplitude, alpha)
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
   love.graphics.setColor(0,0.4,0.58, alpha)
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

   love.graphics.setLineWidth((200-width)/50)
   love.graphics.line(coords)
   love.graphics.setLineWidth(2)

end



function love.draw()
   local waveAmplitude = 1
   local extraY = math.sin(boat.world_pos  + waveCounter * 2) * 2
   local startY = 500
   love.graphics.clear(180/255, 211/255, 230/255)


   anotherWaveFunction(waveCounter, startY + 50 + extraY/2, 32, .9 * waveAmplitude, 0.9)
   anotherWaveFunction(waveCounter, startY + 65 + extraY/1.25, 29, 1.15 * waveAmplitude, 0.8)
   anotherWaveFunction(waveCounter, startY + 85 + extraY/1.15, 28, 1.25 * waveAmplitude, 0.7)

   foamFunction(waveCounter, startY + 70+ extraY, 26, 2 * waveAmplitude , 0, 200, boat.velocity/20, 30 )
   foamFunction(waveCounter, startY + 80+ extraY, 25.5, 2 * waveAmplitude, 0, 250, boat.velocity/10, 20 )
   foamFunction(waveCounter, startY + 90+ extraY, 25, 2 * waveAmplitude, 0, 300, boat.velocity/6, 5)


   --love.graphics.setColor(4/255,0,90/255,1)
   --love.graphics.rectangle("fill", 200,300 + extraY,700,200)
   root.children[1].transforms.l[2] = 0 +  extraY
   renderThings(root)

   anotherWaveFunction(waveCounter, startY+105+ extraY/0.9, 26, 1.5 * waveAmplitude, 0.4)
   anotherWaveFunction(waveCounter, startY+135+ extraY/0.8, 24, 2.0 * waveAmplitude, 0.4)
   anotherWaveFunction(waveCounter, startY+165+ extraY/0.7, 21, 2.5 * waveAmplitude, 0.4)

   foamFunction(waveCounter, startY+105+ extraY, 24, 2 * waveAmplitude, 0, 300, boat.velocity/6, -5)
   foamFunction(waveCounter, startY+115+ extraY, 24.5, 2 * waveAmplitude, 0, 250, boat.velocity/10, -20)
   foamFunction(waveCounter, startY+125+ extraY, 25, 2 * waveAmplitude, 0, 200, boat.velocity/20, -30)

   love.graphics.setColor(0,0,0)
   love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)

end
