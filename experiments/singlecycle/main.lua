inspect = require 'inspect'
sone = require "sone"

-- some cheap filters, i am not using them though. sone is cleaner
--https://beammyselfintothefuture.wordpress.com/2015/02/16/simple-c-code-for-resonant-lpf-hpf-filters-and-high-low-shelving-eqs/

-- some logic about (polyphonic) glide, slide, legato, pizzicato etc
--http://www.nurykabe.com/dump/docs/bindingNotes/

-- a ringbuffer could be used for delay/echo
--https://dobrian.github.io/cmp/topics/delay-based-effects/circularbuffer.html
--https://blog.demofox.org/2015/03/17/diy-synth-delay-effect-echo/
--   https://music.arts.uci.edu/dobrian/maxcookbook/diy-ring-buffer

function printSoundData(d1)
   print('samples: '..d1:getSampleCount()..', rate: '..d1:getSampleRate()..', bits:  '..d1:getBitDepth()..', channels:  '..d1:getChannelCount())
end

function lerp(from, to, t)
   return t < 0.5 and from + (to-from)*t or to + (from-to)*(1-t)
end

function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end


function note_to_hz(note)
   return 440*math.pow(2,(note-33)/12)
end

function getPitch(semitone, octave)
   local plusoctave = 0
   --local octave = 2
   
   if semitone > 11 then
      plusoctave = math.floor(semitone / 12)
      --print(semitone, plusoctave )
      semitone = semitone % 12
   end

   local freqs = {261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88, 523.25}
   local n = mapInto(freqs[semitone+1], 261.63, 523.25, 0, 1)
   local o = octave + plusoctave
   if o < -5 then o = -5 end
   if o > 7 then  o = 7  end

--   print('octave', o)
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
   if o == 6 then return(64 + 64*n) end
   if o == 7 then return(128 + 128*n) end

end


function blendSoundDatas(d1, d2, t, blendInto)
   assert(d1:getSampleCount() == d2:getSampleCount())
   local size = d1:getSampleCount()
   for i = 0, size-1 do
      local v = lerp(d1:getSample(i), d2:getSample(i), t)
      blendInto:setSample(i, v)
   end
   
end


function love.load()

   waveFrames = {}
   if true then
      local indices = {1,13}
      for i =1, #indices do
         local index = indices[i]
         --local url = "cycles/sinharm/AKWF_sinharm_"..string.format("%04d",i)..".wav"
         --local url = "cycles/overtone/AKWF_overtone_"..string.format("%04d",i)..".wav"
         --local url = "cycles/fmsynth/AKWF_fmsynth_"..string.format("%04d",i)..".wav"
         local url = "cycles/bw_squrounded/rAsymSqu_"..string.format("%02d",i)..".wav"
         --local url = "cycles/bw_squrounded/rSymSqu_"..string.format("%02d",index)..".wav"

         print(url)
         local sd = love.sound.newSoundData(url)
         waveFrames[i] = sd
      end
   end

   --waveFrames[1] = love.sound.newSoundData("cycles/nes/AKWF_nes_square.wav")
   --waveFrames[2] = love.sound.newSoundData("cycles/nes/AKWF_nes_triangle.wav")
   --d1 = love.sound.newSoundData("cycles/bw_squrounded/rAsymSqu_01.wav")w
   --d2 = love.sound.newSoundData("cycles/bw_squrounded/rAsymSqu_26.wav")
  -- d2 = love.sound.newSoundData("cycles/AKWF_cheeze_0001.wav")
   --d1 = love.sound.newSoundData("cycles/AKWF_ebass_0001.wav")
   --d2 = love.sound.newSoundData("cycles/AKWF_ebass_0001.wav")

   local d1 = waveFrames[1]
   
   

   
   
   --blended = 

   local amountOfBuffers = 10

   lfo1 = {hz=.4,   depth=1, value=0, output=0, shape='pulse'}
   lfo2 = {hz=.3,  depth=1, value=0, output=0, shape='tri'}
   lfo3 = {hz=.4, depth=1, value=0, output=0, shape='pulse'}
   
   voices = {{
      sd = love.sound.newSoundData(d1:getSampleCount(),  d1:getSampleRate(), d1:getBitDepth(), d1:getChannelCount()),
      qs = love.audio.newQueueableSource(d1:getSampleRate(), d1:getBitDepth(), d1:getChannelCount(), amountOfBuffers),
      qsSub = love.audio.newQueueableSource(d1:getSampleRate(), d1:getBitDepth(), d1:getChannelCount(), amountOfBuffers)
   }}
   
   pitch = 1
   semitone = 0
   octave = 0
   
  

   onScreenKeys = {
      'a', 'w', 's',
      'e', 'd', 'f',
      't', 'g', 'y',
      'h', 'u', 'j',
      'k', 'o', 'l',
      'p', ';', "'"
   }
 
--   printSoundData(d1)
--   printSoundData(d2)

   font = love.graphics.newFont( 'Ac437_IBM_CGA.ttf', 16 )
   love.graphics.setFont(font)

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }
  
   
end

function makeSoundObject()
   
end



--lifted from https://github.com/picolove/picolove/blob/master/main.lua
lfoWaveShapes = {
   ['tri']=function(x)
      return (math.abs((x % 1) * 2 - 1) * 2 - 1) * 0.7
   end,
   ['uneven_tri']=function(x)
      local t = x % 1
      return (((t < 0.875) and (t * 16 / 7) or ((1 - t) * 16)) - 1) * 0.7
   end,
   ['saw']=function(x)
      return (x % 1 - 0.5) * 0.9
   end,
   ['square']=function(x)
      return (x % 1 < 0.5 and 1 or -1) * 1 / 3
   end,
   ['pulse']=function (x)
      return (x % 1 < 0.3125 and 1 or -1) * 1 / 3
   end,
   ['triOver2']=function(x)
      x = x * 4
      return (math.abs((x % 2) - 1) - 0.5 + (math.abs(((x * 0.5) % 2) - 1) - 0.5) / 2 - 0.1) * 0.7
   end,
    ['triOver3']=function(x)
      x = x * 4
      return (math.abs((x % 3) - 1.5) - 0.5 + (math.abs(((x * 0.33) % 3) - 1.5) - 0.5) / 2 - 0.1) * 0.5
   end,
   ['detunedTri']= function(x)
      x = x * 2
      return (math.abs((x % 2) - 1) - 0.5 + (math.abs(((x * 127 / 128) % 2) - 1) - 0.5) / 2) - 1 / 4
   end,
   ['sawLFO']=function(x)
      return x % 1
   end,
}
lfoWaveShapeNames = {
   'tri', 'uneven_tri', 'saw', 'square','pulse','triOver2','triOver3', 'detunedTri','sawLFO'
}

function updateLFO(lfo, dt)
   -- 
   
   
   lfo.value = lfo.value + (dt *  lfo.hz ) 
   lfo.output =  lfoWaveShapes[lfo.shape](lfo.value )

   
   
end


function love.update(dt)

--   print(1/44100, dt)
   updateLFO(lfo1, dt)
   updateLFO(lfo2, dt)
   updateLFO(lfo3, dt)

  
   local mx,my =love.mouse.getPosition()
   local w,h = love.graphics.getDimensions()

   local b = mapInto(mx, 0,w, 0, 1)
   --print(w, #waveFrames, math.ceil(mx/(w/#waveFrames)))
   local p = mapInto(my, 0, h, 0.001, 10)
   lfo1.hz = p
   --lfo.thing = 1 +  b 
  
  -- print(w, #waveFrames-1)




   local t = (mx/(w/(#waveFrames-1))) % 1
   local indx = math.max(math.ceil(mx/(w/(#waveFrames-1))), 1)
   local index1 = indx 
   local index2 = index1 + 1
   --print(index1, index2, t)
   blendSoundDatas(waveFrames[index1],waveFrames[index2], t, voices[1].sd)

   



   
   --local wet = blended
   
   
   local wet = sone.filter(sone.copy(voices[1].sd), {
			      type = "bandpass",
			      frequency = 1000,
			      Q = lfo2.value * .5,
			      gain = 2,
   })

   -- wet = sone.filter(sone.copy(blended), {
   --                      type = "highpass",
   --                      frequency = 150*lfo3.value,
   -- })

   
   -- local wet =  sone.filter(sone.copy(wet), {
   -- 			       type = "peakeq",
   -- 			       frequency = 1000,
   -- 			       gain = 9,
   -- })
   -- wet = sone.filter(sone.copy(wet), {
   --      		      type = "notch",
   --      		      frequency = 1000,
   --      		      Q = 3,
   --      		      gain = 6,
   -- })


   function handleSource(source, octaveOffset)
      local qs = source--voices[1].qs
      local count = qs:getFreeBufferCount()
      --   print('amount of buffers to add:', count)
      for i =1, count do
         qs:queue(wet)
      end
      
      qs:play()

      local p = getPitch(semitone, octave+(octaveOffset or 0))
      local np = p + (lfo2.output) * .1
      print(p, np)

      if np >= 0 then 
         qs:setPitch(np)
      end
      qs:setVolume(.5 + (lfo1.output))
   end
   

   handleSource(voices[1].qs)
   handleSource(voices[1].qsSub, -3)

end



--[[
   function populateDataScales() {
   
   }

]]--


function love.keypressed(k)
   if k=='escape' then
      love.event.quit()
   end


   for i=1, #onScreenKeys do
      if k==onScreenKeys[i] then
	 semitone = i-1
	 --arpIndex = 0
	 --arp.value = 0
	 lfo1.value = math.pi*5
         lfo2.value = math.pi*4
         lfo3.value = math.pi*1

	 --print(semitone, octave)
         pitch = getPitch(semitone, octave)
        
      end
   end
   
   if k == 'z' then
      octave = octave - 1
   end
   if k == 'x' then
      octave = octave + 1
   end
   
end

function love.keyreleased(k)

end


function drawScreenKeyboard(x,y)
   local whiteWidth = 30
   local whiteHeight = 100
   local blackWidth = 15
   local blackHeight = 50
   
   local function isBlack(semitone)
      local blackSemitones = {1,3,6,8,10,13,15}
      for j = 1, #blackSemitones do
	 if (blackSemitones[j] == semitone) then
	    return true
	 end
      end
      return false
   end

   local keyOffset = 0

   love.graphics.setColor(1,1,1)
   
   -- draw the keys
   for i =1, #onScreenKeys do
      if isBlack(i-1) then
	 love.graphics.rectangle('fill', x + keyOffset*whiteWidth - blackWidth/2, y, blackWidth, blackHeight)
      else
	 love.graphics.rectangle('line', x + keyOffset*whiteWidth, y, whiteWidth, whiteHeight)
	 keyOffset = keyOffset + 1
      end
   end
   
   keyOffset = 0
   -- draw the letters on top
   love.graphics.setColor(1,.5,.5)
   for i =1, #onScreenKeys do
--      print(semitone, i-1)
      if (semitone == (i-1)) then
	 love.graphics.setColor(.5,.5,.5)
      else
	 love.graphics.setColor(1,.5,.5)

      end
      
      if isBlack(i-1) then
	 local width = font:getWidth( onScreenKeys[i] )
	 love.graphics.print(onScreenKeys[i], x + (keyOffset*whiteWidth)- blackWidth/2 + (blackWidth-width)/2 , y)
      else
	 local width = font:getWidth( onScreenKeys[i] )
	 --love.graphics.setColor(1,.5,.5)
	 love.graphics.print(onScreenKeys[i],  x+keyOffset*whiteWidth  + (whiteWidth-width)/2, y + whiteHeight - 20)
	 keyOffset = keyOffset + 1
      end
   end
end

function renderLFO(index,lfo, x,y)
   love.graphics.setColor(1,.5,.5)
   love.graphics.circle('fill', x,y, 10)
   love.graphics.setColor(1,1,1)
   love.graphics.circle('line', x,y, 10 + lfo.output*16)


   local str = lfo.shape
   local w = font:getWidth(str)
   local h = font:getHeight(str)

   local rect = getUIRect('lfo'..index, x,y+20,w,h)
   if rect.clicked then
      local curIndex = nil
      for i=1, #lfoWaveShapeNames do
         if lfoWaveShapeNames[i]==str then
            curIndex = i
         end
      end
      local nextIndex = curIndex+1
      if nextIndex > #lfoWaveShapeNames then
         nextIndex = 1
      end
      local nextName = lfoWaveShapeNames[nextIndex]
      lfo.shape = nextName
     -- print('clicked the waveshape', str, nextName)
   end
   str = str
   love.graphics.print(str,x,y+20)
   love.graphics.print(string.format("%.2f",lfo.hz)..'Hz',x,y+50)

end

function handleMouseClickStart()
   mouseState.hoveredSomething = false
   mouseState.down = love.mouse.isDown(1 )
   mouseState.click = false
   mouseState.released = false
   --print('what!')
   if mouseState.down ~= mouseState.lastDown then
      if mouseState.down  then
         mouseState.click  = true
      else
	 mouseState.released = true
      end
   end
   mouseState.lastDown =  mouseState.down
end
function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end
function getUIRect(id, x,y,w,h)
  local result = false
  if mouseState.click then
     local mx, my = love.mouse.getPosition( )
     if pointInRect(mx,my,x,y,w,h) then
        result = true
     end
   end

   return {
      clicked=result
   }
end

function love.draw()
   -- draw the lfo graphically
   handleMouseClickStart()
   
   renderLFO(1,lfo1, 100,100)
   renderLFO(2,lfo2, 200,100)
   renderLFO(3,lfo3, 300,100)


   drawScreenKeyboard(400, 500)
  

   
end
