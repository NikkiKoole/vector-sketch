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
   --root.children[1].transforms.l[8] = boat.velocity/100
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
      transforms =  {g={0,0,0,1,1,0,0},l={1024/2,650,0,1.25,1.25,0,0}},
      children ={}
   }

   justboat = parseFile('justboat.txt')[1]
   table.insert(root.children, justboat)

   fishes = parseFile('visjes.txt')[1]
   for i = 1, #fishes.children do
      local dir = randomSign()
      fishes.children[i].velocity =  dir  * (0.25 + math.random() * 0.25)
      fishes.children[i].transforms.l[1] = love.math.random() * 500
      fishes.children[i].transforms.l[2] = 20 + love.math.random() * 40
      fishes.children[i].transforms.l[4] = dir * -1
   end

   table.insert(root.children, fishes)
   parentize(root)
   meshAll(root)

   schroef = findNodeByName(justboat, 'schroef')
   print(schroef)
end

function randomSign()
   return love.math.random() < 0.5 and 1 or -1

end

function updateFishes()

    for i = 1, #fishes.children do
       fishes.children[i].transforms.l[1] =  fishes.children[i].transforms.l[1] +  fishes.children[i].velocity

       if (fishes.children[i].transforms.l[1] > 1000 ) then
	  fishes.children[i].velocity =  -1 * (0.25 + math.random() * 0.25)
	  fishes.children[i].transforms.l[4] = 1
       end
       if (fishes.children[i].transforms.l[1] < -100) then
	  fishes.children[i].velocity =  1 * (0.25 + math.random() * 0.25)
	  fishes.children[i].transforms.l[4] = -1
       end
   end
end



local waveCounter = 0
function love.update(dt)

   waveCounter = waveCounter + dt
   boat.world_pos =  boat.world_pos + (boat.velocity * dt)
   flux.update(dt)

   schroef.transforms.l[3] = schroef.transforms.l[3] + (boat.velocity * dt * 2)
   updateFishes()
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
   end

   love.graphics.line(coords)
   love.graphics.setLineWidth(2)

end



function love.draw()
   local waveAmplitude = 1
   local extraY = math.sin(boat.world_pos  + waveCounter * 2) * 2
   local startY = 450
   love.graphics.clear(180/255, 211/255, 230/255)

   anotherWaveFunction(waveCounter, startY + 50 + extraY/2, 32, .9 * waveAmplitude, 0.9)
   anotherWaveFunction(waveCounter, startY + 65 + extraY/1.25, 29, 1.15 * waveAmplitude, 0.8)
   anotherWaveFunction(waveCounter, startY + 85 + extraY/1.15, 28, 1.25 * waveAmplitude, 0.7)

   foamFunction(waveCounter,   90+startY + 70+ extraY, 26, 2 * waveAmplitude , 0, 140, boat.velocity/20, 30 )
   foamFunction(waveCounter, 90+startY + 80+ extraY, 25.5, 2 * waveAmplitude, 0, 140, boat.velocity/10, 20 )
   foamFunction(waveCounter, 90+startY + 90+ extraY, 25, 2 * waveAmplitude, 0, 140, boat.velocity/6, 5)
   foamFunction(waveCounter, 90+startY+100+ extraY, 24, 2 * waveAmplitude, 0, 140, boat.velocity/6, -5)
   foamFunction(waveCounter, 90+startY+110+ extraY, 24.5, 2 * waveAmplitude, 0, 140, boat.velocity/10, -20)
   foamFunction(waveCounter, 90+startY+120+ extraY, 25, 2 * waveAmplitude, 0, 140, boat.velocity/20, -30)


   root.children[1].transforms.l[2] = 0 +  extraY
   renderThings(root)

   anotherWaveFunction(waveCounter, startY+105+ extraY/0.9, 26, 1.5 * waveAmplitude, 0.4)
   anotherWaveFunction(waveCounter, startY+135+ extraY/0.8, 24, 2.0 * waveAmplitude, 0.4)
   anotherWaveFunction(waveCounter, startY+165+ extraY/0.7, 21, 2.5 * waveAmplitude, 0.4)

   love.graphics.setColor(0,0,0)
   love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end
