package.path = package.path .. ";../../?.lua"

inspect = require 'vendor.inspect'
flux = require "vendor.flux"

require 'lib.scene-graph'
require 'lib.toolbox'
require 'lib.main-utils'
poly = require 'lib.poly'

local numbers = require 'lib.numbers'

function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.draw()
   love.graphics.clear(0.52,0.56,0.28)
   renderThings(root)
end

function blinkEyes(index)
   local linkerOog = findNodeByName(tomatoes[index], 'linkeroog')
   local rechterOog = findNodeByName(tomatoes[index], 'rechteroog')
   local linkerPupil = findNodeByName(linkerOog, 'pupil')
   local rechterPupil = findNodeByName(rechterOog, 'pupil')

   flux.to(linkerPupil.transforms.l, 0.1, {[5]=0.01})
      :after(linkerPupil.transforms.l, 0.1, {[5]=1}):delay(0.1)
   flux.to(rechterPupil.transforms.l, 0.1, {[5]=0.01})
      :after(rechterPupil.transforms.l, 0.1, {[5]=1}):delay(0.1)
end

function growKroontje(index)
   local kroontje = findNodeByName(tomatoes[index], 'kroontje')
   flux.to(kroontje.transforms.l, 0.1, {[5]=1.2, [4]=1.2})
      :after(kroontje.transforms.l, 0.1, {[5]=1, [4]=1}):delay(0.1)
end



function onHitHead(index)
   local firstMouth = findNodeByName(tomatoes[index], 'mond')
   firstMouth.needsLerp = true
   local tween = flux.to(firstMouth, 0.1, {lerpValue=1})
      :after(firstMouth, 0.1, {lerpValue=0}):delay(0.1)
      :oncomplete(function() firstMouth.needsLerp = false end)

   blinkEyes(index)
   growKroontje(index)

end

function onHitXylofoonChild(index)
   local child = xylofoon.children[index]
   child.needsLerp = true

   local tween = flux.to(child.transforms.l, 0.05, {[4]=1.1, [5]=1.1})
      :after(child.transforms.l, 0.2, {[4]=1, [5]=1}):delay(0.05)
      :oncomplete(function() child.needsLerp = false end)
end



function love.update(dt)
   flux.update(dt)

   if love.math.random() < 0.05 then
      local index = math.floor((love.math.random() * #tomatoes + 1))
      local firstMouth = findNodeByName(tomatoes[index], 'mond')
      if firstMouth.needsLerp == false or firstMouth.needsLerp == nil then
	 firstMouth.needsLerp = true
	 local d1 = 0.1 + love.math.random()*0.2
	 local d2 = 0.1 + love.math.random()*0.2
	 local close = love.math.random() * 0.6 + 0.1
	 local open = love.math.random() * 0.6 + 0.1

	 local tween = flux.to(firstMouth, close, {lerpValue=0.7}):delay(d1)
	    :after(firstMouth, open, {lerpValue=0.3}):delay(d2)

	    :oncomplete(function() firstMouth.needsLerp = false end)
      end
   end

   if (love.math.random() < 0.1) then
      local index = math.floor((love.math.random() * #tomatoes + 1))
      blinkEyes(index)
   end
end


function love.mousemoved(x,y)
   for i =1, #tomatoes do
      local body = tomatoes[i]

      if body.transforms._g then

	 local linkerOog = findNodeByName(tomatoes[i], 'linkeroog')
	 local linkerPupil = findNodeByName(linkerOog, 'pupil')
	 local linkerWenkbrauw = findNodeByName(linkerOog, 'wenkbrauw')
	 if  (linkerWenkbrauw.transforms._g) then
	    local lx, ly =  (body.transforms._g):inverseTransformPoint(x, y)
	    local distance = math.sqrt((lx *lx) + (ly * ly))
	    local r2 = numbers.mapInto(distance, 0, 100,  -.03, .03)
	    linkerWenkbrauw.transforms.l[3] = r2
	 end

	 if (linkerPupil.transforms._g) then
	    local lx, ly =  (linkerPupil.transforms._g):inverseTransformPoint(x, y)
	    local r = math.atan2 (ly, lx)
	    local distance = math.sqrt((lx *lx) + (ly * ly))
	    if (distance > 2) then
	       local radius = math.min(2, distance)
	       local dx = radius * math.cos(r)
	       local dy = radius * math.sin(r)
	       linkerPupil.transforms.l[1] = startPos[i].leftEye[1]+dx
	       linkerPupil.transforms.l[2] = startPos[i].leftEye[2]+dy
	    end
	 end
	 local rechterOog = findNodeByName(tomatoes[i], 'rechteroog')
	 local rechterPupil = findNodeByName(rechterOog, 'pupil')
	 local rechterWenkbrauw = findNodeByName(rechterOog, 'wenkbrauw')
	 if  (rechterWenkbrauw.transforms._g) then
	    local lx, ly =  (rechterWenkbrauw.transforms._g):inverseTransformPoint(x, y)
	    local distance = math.sqrt((lx *lx) + (ly * ly))
	    local r2 = numbers.mapInto(distance, 0, 100,  .03, -.03)
	    rechterWenkbrauw.transforms.l[3] = r2
	 end
	 if (rechterPupil.transforms._g) then
	    local lx, ly =  (rechterPupil.transforms._g):inverseTransformPoint(x, y)
	    local r = math.atan2 (ly, lx)
	    local distance = math.sqrt((lx *lx) + (ly * ly))

	    if distance > 2 then
	       local radius = math.min(3, distance)
	       local dx = radius * math.cos(r)
	       local dy = radius * math.sin(r)
	       rechterPupil.transforms.l[1] = startPos[i].rightEye[1]+dx
	       rechterPupil.transforms.l[2] = startPos[i].rightEye[2]+dy
	    end
	 end
      end
   end
end

function love.mousepressed(x,y)
   for i = 1, #tomatoes do
      local body =  findNodeByName(tomatoes[i], 'lichaam')
      local mesh = body.children[1].mesh

      if isMouseInMesh(x,y, body, mesh) then
	 print('hit head')
	 onHitHead(i)
      end
   end

   for i= 3, #xylofoon.children do
      local body = xylofoon.children[i]
      local mesh = body.children[1].mesh
      if isMouseInMesh(x,y, body, mesh) then
	 print('hit', body.name)
	 onHitXylofoonChild(i)
      end
   end

end


function love.load()
   love.window.setMode(1024, 768, {resizable=true, vsync=true, minwidth=400, minheight=300, msaa=2, highdpi=true})

   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={650,800,0,4,4,0,0}},
      children ={}
   }

   tomatoes = parseFile('assets/tomatoes.txt')
   xylofoon = parseFile('assets/xylofoon.txt')[1]
   cr78 = parseFile('assets/cr78.txt')[1]

   table.insert(root.children, xylofoon)
   xylofoon.transforms.l[1] = - 90
   xylofoon.transforms.l[2] = - 150

   table.insert(root.children, cr78)
   cr78.transforms.l[1] = 50
   cr78.transforms.l[2] = - 165

   for i = 1, #tomatoes do
      table.insert(root.children, tomatoes[i])
   end

   startPos = {}
   for i =1, #tomatoes do
      local linkerOog = findNodeByName(tomatoes[i], 'linkeroog')
      local rechterOog = findNodeByName(tomatoes[i], 'rechteroog')

      local linkerPupil = findNodeByName(linkerOog, 'pupil')
      local rechterPupil = findNodeByName(rechterOog, 'pupil')

      --local linkerWenkbrauw = findNodeByName(linkerOog, 'wenkbrauw')
      --local rechterWenkbrauw = findNodeByName(rechterOog, 'wenkbrauw')
      --print(inspect(linkerWenkbrauw), inspect(rechterWenkbrauw))
      startPos[i] = {leftEye = {linkerPupil.transforms.l[1], linkerPupil.transforms.l[2]},
		     rightEye = {rechterPupil.transforms.l[1], rechterPupil.transforms.l[2]}}
   end

   parentize(root)
   meshAll(root)
   renderThings(root)

end
