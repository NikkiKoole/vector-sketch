package.path = package.path .. ";../../?.lua"

flux = require "vendor.flux"
inspect = require 'vendor.inspect'
ProFi = require 'vendor.ProFi'

require 'lib.scene-graph'
require 'lib.basics'
require 'lib.bbox'
require 'lib.toolbox'
require 'lib.editor-utils'
require 'lib.poly'
require 'lib.main-utils'


function elemIsAboveAnother(elem,  another)
   assert(another.children[1].points)

   local px,py = elem._globalTransform:transformPoint(0,0)
   local tlx, tly, brx, bry = getPointsBBox(another.children[1].points)
   local tlx2, tly2 = another._globalTransform:transformPoint(tlx, tly)
   local brx2, bry2 = another._globalTransform:transformPoint(brx, bry)

   if (px >= tlx2 and px < brx2) then
      if (py < bry2) then
         return true
      end

   end
   return false
end


function moveNodeBetweenParentsAndPosition(node, newParent)
   -- this will keep the position intact

   local x1,y1 = node._globalTransform:transformPoint(0,0)
   removeNodeFrom(node, node._parent)
   addNodeInGroup(node, newParent)
   renderThings(newParent)
   local x2,y2 = node._globalTransform:transformPoint(0,0)
   local dx, dy = x1-x2, y1-y2
   local x0,y0 = node._globalTransform:inverseTransformPoint(0,0)
   local dx1, dy1 =  node._globalTransform:inverseTransformPoint(dx,dy)
   node.transforms.l[1] = node.transforms.l[1] - (x0-dx1)
   node.transforms.l[2] = node.transforms.l[2] - (y0-dy1)

end

function getNamesForElementRecurive(node, tabs, str)
   local spaces = ""
   for i = 0, tabs do
      spaces = spaces.."   "
   end
   if node.children then
      str = str..(spaces..node.name).."\n"
   end
   if node.children then
      for i = 1, #node.children do
         str = getNamesForElementRecurive(node.children[i], tabs+1, str)
      end

   end
   return str
end



function herman()
   return  (boat.velocity/150)
end


function love.keypressed(key)

   if key == 'escape' then
      love.event.quit()
   end
   if key == 'left' then
      local newV = boat.velocity - 1
      rookspawntimerTick = 1.5/boat.velocity
      rookspawntimer = 0
      flux.to(boat, 3, {velocity=newV})
   end
   if key == 'right' then
      local newV = boat.velocity + 1
      rookspawntimerTick = 1.5/boat.velocity
      rookspawntimer = 0
      flux.to(boat, 3, {velocity=newV})
   end

 if (key == 'p') then
    if not profiling then
	 ProFi:start()
      else
	 ProFi:stop()
	 ProFi:writeReport( 'rofilingReport.txt' )
      end
      profiling = not profiling
   end

   justboat.transforms.l[8] = 0 + (herman())
   walter.transforms.l[8] = 0 - (herman()) * walter.transforms.l[4]  -- when mirrored it needs to be skewed the other way
   olivia.transforms.l[8] = 0 - (herman()) * olivia.transforms.l[4] -- "

end

function love.load()
   local screenwidth = 1024
   profiling = false

   renderInfoForElement = nil

   boat = {
      velocity = 0,
      world_pos = 0
   }
   font = love.graphics.newFont( "WindsorBT-Roman.otf", 16)
   love.graphics.setFont(font)

   local endI = ((screenwidth+ 80)/20)
   wave_offsets = {}
   for i=1, endI do
      table.insert(wave_offsets, love.math.random() * 6 - 3)
   end

   dragged = nil

   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={1024/2,650,0,1.25,1.25,0,0}},
      children ={}
   }

   overlayer = {
      folder = true,
      name = 'overLayer',
      transforms =  {g={0,0,0,1,1,0,0},l={1024/2,650,0,1.25,1.25,0,0}},
      children ={}
   }



   wolken = parseFile('assets/wolken.polygons.txt')
   for i = 1, #wolken do
      wolken[i].speedMultiplier = (1 + love.math.random()* 3) / 700
      wolken[i].transforms.l[1] = -500 + love.math.random() * 1024
      wolken[i].transforms.l[2] = -500 + love.math.random()*100
      wolken[i].children[1].color[4] = 0.25
      wolken[i].children[2].color[4] = 0.25
      table.insert(root.children, wolken[i])
   end

   justboat = parseFile('assets/justboat.polygons.txt')[1]
   table.insert(root.children, justboat)

   rook = parseFile('assets/rook.polygons.txt')
   rookEmitter = {}
   rookspawntimerTick = 0
   rookspawntimer = rookspawntimerTick


   for j = 1, 3 do
      for i = 1, #rook do
         table.insert(rookEmitter, deepcopy(rook[i]))
      end
   end
   for i = 1, #rookEmitter do
      rookEmitter[i].children[1].color[4] = 0
      table.insert(root.children, rookEmitter[i])
   end

   fishes = parseFile('assets/visjes.polygons.txt')[1]
   fishRefs = {}
   for i = 1, #fishes.children do
      fishRefs[i] = fishes.children[i]
      local dir = randomSign()
      fishes.children[i].type = 'fish'
      fishes.children[i].velocity =  dir  * (0.25 + math.random() * 0.25)
      fishes.children[i].transforms.l[1] = love.math.random() * 500
      fishes.children[i].transforms.l[2] = 20 + love.math.random() * 40
      fishes.children[i].children[1].transforms.l[4] = dir * -1
   end
   table.insert(root.children, fishes)

   boei = parseFile('assets/boei.polygons.txt')[1]
   table.insert(root.children, boei)

   hengel = parseFile('assets/hengel.polygons.txt')[1]
   table.insert(root.children, hengel)

   walter =  parseFile('assets/waltert.polygons.txt')[1]
   table.insert(root.children, walter)

   olivia = parseFile('assets/olivia.polygons.txt')[1]
   table.insert(root.children, olivia)

   parentize(root)
   meshAll(root)
   parentize(overlayer)

   schoorsteentje = findNodeByName(justboat, 'schoorsteentje')
   schroef = findNodeByName(justboat, 'schroef')
   kajuitdeur = findNodeByName(justboat, 'kajuitdeur')
   kajuitvoor = findNodeByName(justboat, 'kajuit voor')
   bootdak = findNodeByName(justboat, 'dak')
   bootdek = findNodeByName(justboat, 'dek')
   --

   local o = removeNodeFrom(olivia, root)
   o.transforms.l[1]= -100
   o.transforms.l[2]= 200
   addAfterNode(o, kajuitvoor)

   local w = removeNodeFrom(walter, root)
   w.transforms.l[1]= -200
   w.transforms.l[2]= 200
   addAfterNode(w, kajuitvoor)

end


function updateFishes()
   for i = 1, #fishes.children do
      if dragged ~= fishes.children[i] then
         fishes.children[i].transforms.l[1] =  fishes.children[i].transforms.l[1] +  fishes.children[i].velocity - (boat.velocity*0.1)
         if (fishes.children[i].transforms.l[1] > 1000 ) then
            if love.math.random() < 0.5 then
               fishes.children[i].transforms.l[1]  = -100
            else
               fishes.children[i].velocity =  -1 * (0.25 + math.random() * 0.25)
               fishes.children[i].children[1].transforms.l[4] = 1
            end
         end
         if (fishes.children[i].transforms.l[1] < -100) then
            if love.math.random() < 0.5 then
               fishes.children[i].transforms.l[1]  = 1000
            else
               fishes.children[i].velocity =  1 * (0.25 + math.random() * 0.25)
               fishes.children[i].children[1].transforms.l[4] = -1
            end
         end
      end
   end
end

function updateWolken()
   for i = 1, #wolken do
      wolken[i].transforms.l[1] =  wolken[i].transforms.l[1] - boat.velocity* wolken[i].speedMultiplier
      if ( wolken[i].transforms.l[1] < - 1000) then
         wolken[i].transforms.l[1] = 1300
      end
      if ( wolken[i].transforms.l[1] > 1300) then
         wolken[i].transforms.l[1] = -1000
      end
   end
end

function doRookspawn()

   flux.to(schoorsteentje.transforms.l, 0.2, {[5]=1.075}):after(schoorsteentje.transforms.l, 0.1, {[5]=1})
   local last = table.remove(rookEmitter)
   last.transforms.l[1] = -200 - (boat.velocity*2) -- the boat velocity and the skew of the boat cancel each other out
   last.transforms.l[2] = -425
   last.transforms.l[4] = 0.5
   last.transforms.l[5] = 0.5
   last.transforms.l[3] = 0
   last.children[1].color[4] = 0.25
   flux.to(last.transforms.l, 3, {
              [2]=-600 + love.math.random()*100,
              [4]=1.5, [5]=1.5, [3]=love.math.random() * math.pi}):ease("circout")

   flux.to(last.children[1].color, 3, {[4]=0}):ease("backinout")
   flux.to(last.transforms.l, 1, {[4]=.15, [5]=.15}):delay(1)
   table.insert(rookEmitter, 1, last)
end

function updateRookParticles(dt)
   for i = 1, #rookEmitter do
      rookEmitter[i].transforms.l[1] = rookEmitter[i].transforms.l[1] +  -30*(boat.velocity * dt)
   end
end


local waveCounter = 0
function love.update(dt)
   waveCounter = waveCounter + dt
   boat.world_pos =  boat.world_pos + (boat.velocity * dt)
   flux.update(dt)

   schroef.transforms.l[3] = schroef.transforms.l[3] + (boat.velocity * dt * 2)
   updateFishes()
   updateWolken()
   updateRookParticles(dt)
   if (rookspawntimerTick > 0) then
      rookspawntimer = rookspawntimer - dt
      if rookspawntimer <= 0 then
         doRookspawn()
         local leftover = math.abs(rookspawntimer)
         rookspawntimer = rookspawntimerTick - leftover
      end
   end
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
end


function love.mousemoved(x,y,dx,dy)
   if (dragged) then
      local dx2, dy2 = getLocalizedDelta(dragged, dx,dy)
      dragged.transforms.l[1] = dragged.transforms.l[1] + dx2
      dragged.transforms.l[2] = dragged.transforms.l[2] + dy2
   end
end

function love.mousereleased()
   if (dragged) then

      if elemIsAboveAnother(dragged, bootdak) then
         moveNodeBetweenParentsAndPosition(dragged, bootdak)
         local dist = math.abs(dragged.transforms.l[2] - 20)
         local d = dist/800
         flux.to(dragged.transforms.l, d, {[2]=20}):ease("circin")
      elseif elemIsAboveAnother(dragged, bootdek) then
         moveNodeBetweenParentsAndPosition(dragged, kajuitvoor)
         -- when the x < - 200 the deck is a bit lower
         local offset = 200
         if dragged.transforms.l[1] < - 200 then
            offset = 230
         end
         if dragged.transforms.l[1] < - 530 then
            offset = 200
         end

         local dist = math.abs(dragged.transforms.l[2] - 200)
         local d = dist/800
         flux.to(dragged.transforms.l, d, {[2]=offset}):ease("circin")
      else
         moveNodeBetweenParentsAndPosition(dragged, overlayer)
         local dist = math.abs(dragged.transforms.l[2] - 50)
         local d = dist/800
         flux.to(dragged.transforms.l, d, {[2]=50}):ease("backout")
      end

      dragged = nil
   end
end




function love.mousepressed(x,y)
   renderInfoForElement = nil
   local body = kajuitdeur.children[3]
   local mesh = kajuitdeur.children[3].mesh
   if isMouseInMesh(x,y, body._parent, mesh) then
      if (kajuitdeur.transforms.l[1]  < - 400) then
         flux.to(kajuitdeur.transforms.l, .3, {[1]=-390.81}):ease("circinout")
      else
         flux.to(kajuitdeur.transforms.l, .3, {[1]=-455}):ease("circinout")
      end
      renderInfoForElement = body
   end

   if recursiveHitCheck(x,y, boei) then
      dragged = boei
      moveNodeBetweenParentsAndPosition(boei, overlayer)
      renderInfoForElement = boei
   end
   if recursiveHitCheck(x,y, hengel) then
      dragged = hengel
      moveNodeBetweenParentsAndPosition(hengel, overlayer)
      renderInfoForElement = hengel
   end

   if recursiveHitCheck(x,y, walter) then
      dragged = walter
      moveNodeBetweenParentsAndPosition(walter, overlayer)
      renderInfoForElement = walter
   end

   if recursiveHitCheck(x,y, olivia) then
      dragged = olivia
      moveNodeBetweenParentsAndPosition(olivia, overlayer)
      renderInfoForElement = olivia
   end

   for i = 1, #fishRefs do
      if recursiveHitCheck(x,y, fishRefs[i]) then
         dragged = fishRefs[i]
         moveNodeBetweenParentsAndPosition(fishRefs[i]._parent.children[getIndex(fishRefs[i])], overlayer)
         renderInfoForElement = dragged
      end
   end

   for i =1, #overlayer.children do
      if #overlayer.children and overlayer.children[i] and  overlayer.children[i].type == 'fish' then
         if recursiveHitCheck(x,y, overlayer.children[i]) then
            dragged = nil
            moveNodeBetweenParentsAndPosition(overlayer.children[i], fishes)
            renderInfoForElement = overlayer.children[i]

         end
      end
   end
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


   justboat.transforms.l[2] = 0 +  extraY
   renderThings(root)

   anotherWaveFunction(waveCounter, startY+105+ extraY/0.9, 26, 1.5 * waveAmplitude, 0.4)
   renderThings(overlayer)
   anotherWaveFunction(waveCounter, startY+135+ extraY/0.8, 24, 2.0 * waveAmplitude, 0.4)


   anotherWaveFunction(waveCounter, startY+165+ extraY/0.7, 21, 2.5 * waveAmplitude, 0.4)

   love.graphics.setColor(0,0,0)
   love.graphics.print(tostring(love.timer.getFPS( )), 10, 10)


   if renderInfoForElement ~= nil then
      if renderInfoForElement._globalTransform then
         local str = getNamesForElementRecurive(renderInfoForElement, 0, "")
         local px, py = renderInfoForElement._globalTransform:transformPoint(0,0)
         love.graphics.print(str, px, 0)
         love.graphics.setColor(1,1,1)
         love.graphics.print(str, px+1, 0+1)
         love.graphics.setColor(1,0,0)
         love.graphics.circle("fill", px, py, 5)
      end
   end

end
