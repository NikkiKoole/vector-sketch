package.path = package.path .. ";../../?.lua"

inspect = require 'vendor.inspect'
flux = require "vendor.flux"

require 'lib.basic-tools'
require 'lib.scene-graph'
require 'lib.basics'
require 'lib.toolbox'
require 'lib.main-utils'
poly = require 'lib.poly'

Concord = require 'vendor.concord.init'


Concord.component("mousefollowing")
Concord.component("pupil")


local myWorld = Concord.world()

Concord.component(
   'transforms',
   function(c, value)
      c.transforms = value
   end
)
Concord.component(
   "startPos",
   function(c, x, y)
      c.x =x
      c.y =y
   end
)

Concord.component(
   "bodyFirstChildMeshHit",
   function(c,b)
      c.body = b
   end
)
Concord.component(
   "onHitFunc",
   function(c,f)
      c.hitFunc = f
   end
)
Concord.component(
   "blink2Eyes",
   function(c, left, right)
      c.left = left
      c.right = right
   end
)




local MovePupilToMouseSystem = Concord.system({pool = {'transforms', 'pupil', 'startPos'}})
function MovePupilToMouseSystem:update(dt)
   local mx,my =love.mouse.getPosition()
   for _, e in ipairs(self.pool) do
      local transforms = e.transforms.transforms
      if (transforms._g) then
         local lx, ly = transforms._g:inverseTransformPoint( mx , my )
         local r = math.atan2(ly, lx)
         local dx = 2 * math.cos(r)
         local dy = 2 * math.sin(r)
         transforms.l[1] = e.startPos.x + dx
         transforms.l[2] = e.startPos.y + dy
      end
   end

end
function MovePupilToMouseSystem:pressed(x,y, elem)
   --print('movepupil sytem receiving click', x,y)
   local newScale = love.math.random()*2 +0.5
   for _, e in ipairs(self.pool) do
      local transforms = e.transforms.transforms
      transforms.l[4] = newScale
      transforms.l[5] = newScale
   end
end

local HitMeshSystem = Concord.system({pool = {'bodyFirstChildMeshHit', 'onHitFunc'}})
function HitMeshSystem:pressed(x,y, elem)
   for _, e in ipairs(self.pool) do
      local body = e.bodyFirstChildMeshHit.body
      if isMouseInMesh(x,y, body, body.children[1].mesh) then
	 e.onHitFunc.hitFunc(body)
      end
   end
end

local BlinkEyesSystem = Concord.system({pool = {'blink2Eyes'}})
function BlinkEyesSystem:update(dt)
   for _, e in ipairs(self.pool) do
      local linkerPupil = e.blink2Eyes.left
      local rechterPupil = e.blink2Eyes.right
      if love.math.random() < 0.01 then
	 flux.to(linkerPupil.transforms.l, 0.1, {[5]=0.01})
	    :after(linkerPupil.transforms.l, 0.1, {[5]=1}):delay(0.1)
	 flux.to(rechterPupil.transforms.l, 0.1, {[5]=0.01})
	    :after(rechterPupil.transforms.l, 0.1, {[5]=1}):delay(0.1)
      end
   end
end



myWorld:addSystems(MovePupilToMouseSystem, HitMeshSystem, BlinkEyesSystem)



function love.keypressed(key)
   if key == "escape" then love.event.quit() end
end

function love.update(dt)
   myWorld:emit("update", dt)
   flux.update(dt)
end

function love.draw()
   love.graphics.clear(0.52,0.56,0.28)
   renderThings(root)
   love.graphics.print('Memory actually used (in kB): ' .. collectgarbage('count'), 10,10)

end

function love.mousepressed(x,y)
   myWorld:emit('pressed',x,y)
end





function getPitch(semitone, octave)
   local plusoctave = 0
   if semitone > 11 then
      plusoctave = 1
      semitone = semitone % 12
   end

   local freqs = {261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88, 523.25}
   local n = mapInto(freqs[semitone+1], 261.63, 523.25, 0, 1)
   local o = octave + plusoctave


   if o == -5 then return (0.0625 -(0.03125 -  n/32)) end
   if o == -4 then return (0.125 -(0.0625 -  n/16)) end
   if o == -3 then return (0.25 -(0.125 -  n/8)) end
   if o == -2 then return (0.5 -(0.25 -  n/4)) end
   if o == -1 then return(1 -(0.5 -  n/2)) end
   if o == 0 then return(1 + n) end
   if o == 1 then return(2 + 2*n) end
   if o == 2 then return(4 + 4*n) end
   if o == 3 then return(8 + 8*n) end
   if o == 4 then return(16 + 16*n) end
   if o == 5 then return(32 + 32*n) end

end


local function onHitHead(body)
   local index = love.math.random() < 0.5 and 1 or 2
   local s = voiceSamples[index]:clone()

   local semitones = {
      ['tomaat 1'] = 0,
      ['tomaat 2'] = 2,
      ['tomaat 3'] = 4,
      ['tomaat 4'] = 6,
      ['tomaat 5'] = 8,
      ['tomaat 6'] = 10
   }

   local pitch = getPitch(semitones[body._parent.name], -2)
   s:setPitch(pitch + love.math.random()*.02 -.01)
   love.audio.play(s)

   local firstMouth = findNodeByName(body._parent, 'mond')
   firstMouth.needsLerp = true
   flux.to(firstMouth, 0.5, {lerpValue=1})
      :after(firstMouth, 0.5, {lerpValue=0}):delay(0.5)
      :oncomplete(function() firstMouth.needsLerp = false end)

   local kroontje = findNodeByName(body._parent, 'kroontje')
   flux.to(kroontje.transforms.l, 0.1, {[5]=1.2, [4]=1.2})
      :after(kroontje.transforms.l, 0.1, {[5]=1, [4]=1}):delay(0.1)
end


local function onHitXylo(body)

   local semitones = {
      rood = 0,
      oranje = 3,
      geel = 5,
      groen = 7,
      blauw = 9,
      roze = 11
   }

   local s = glockSample:clone()
   local pitch = getPitch(semitones[body.name], 0)
   s:setPitch(pitch + love.math.random()*.02 -.01)
   love.audio.play(s)

   body.needsLerp = true

      local tween = flux.to(body.transforms.l, 0.05, {[4]=1.1, [5]=1.1})
	 :after(body.transforms.l, 0.2, {[4]=1, [5]=1}):delay(0.05)
	 :oncomplete(function() body.needsLerp = false end)
   end

function love.load()
   love.window.setTitle( 'ecs tomatoes')
   love.window.setMode(1024, 768, {resizable=true, vsync=true, minwidth=400, minheight=300, msaa=2, highdpi=true})

   samples = {}
   glockSample =   love.audio.newSource(love.sound.newSoundData( 'assets/glock1.wav' ), 'static')
   voiceSamples = {}

   for i = 1, 2 do
      local data = love.sound.newSoundData( 'assets/voice'..i..'.wav' )
      table.insert(voiceSamples, love.audio.newSource(data, 'static'))
   end

   root = {
      folder = true,
      name = 'root',
      transforms =  {l={650,800,0,4,4,0,0}},
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
   meshAll(root)

   startPos = {}
   for i =1, #tomatoes do
      local linkerOog = findNodeByName(tomatoes[i], 'linkeroog')
      local rechterOog = findNodeByName(tomatoes[i], 'rechteroog')
      local linkerPupil = findNodeByName(linkerOog, 'pupil')
      local rechterPupil = findNodeByName(rechterOog, 'pupil')

      Concord.entity(myWorld)
         :give('bodyFirstChildMeshHit',  findNodeByName(tomatoes[i], 'lichaam'))
	 :give('onHitFunc', onHitHead)


      Concord.entity(myWorld)
         :give('transforms', linkerPupil.transforms)
         :give('startPos', linkerPupil.transforms.l[1], linkerPupil.transforms.l[2])
         :give('pupil')

      Concord.entity(myWorld)
         :give('transforms', rechterPupil.transforms)
         :give('startPos', rechterPupil.transforms.l[1], rechterPupil.transforms.l[2])
         :give('pupil')

      Concord.entity(myWorld)
	 :give('blink2Eyes', linkerPupil, rechterPupil)
   end

   for i= 3, #xylofoon.children do
      Concord.entity(myWorld)
         :give('bodyFirstChildMeshHit',   xylofoon.children[i])
	 :give('onHitFunc', onHitXylo)
   end

   parentize(root)
   meshAll(root)
   renderThings(root)

end
