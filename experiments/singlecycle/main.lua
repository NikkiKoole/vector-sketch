
sone = require "sone"

function printSoundData(d1)
   print('samples: '..d1:getSampleCount()..', rate: '..d1:getSampleRate()..', bits:  '..d1:getBitDepth()..', channels:  '..d1:getChannelCount())
end

function lerp(from, to, t)
  return t < 0.5 and from + (to-from)*t or to + (from-to)*(1-t)
end

function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function getPitch(semitone, octave)
   local plusoctave = 0
   --local octave = 2
  
   if semitone > 11 then
      plusoctave = math.floor(semitone / 12)
      print(semitone, plusoctave )
      semitone = semitone % 12
   end

   local freqs = {261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88, 523.25}
   local n = mapInto(freqs[semitone+1], 261.63, 523.25, 0, 1)
   local o = octave + plusoctave

--   print(o)
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


function blendSoundDatas(d1, d2, t, blendInto)
   assert(d1:getSampleCount() == d2:getSampleCount())
   local size = d1:getSampleCount()
   for i = 0, size-1 do
      local v = lerp(d1:getSample(i), d2:getSample(i), t)
      blendInto:setSample(i, v)
   end
   
end

scales = {
   ["harmonicMinor"] = {0,2,3,5,7,8,11},
   ["major"] = {0,2,4,5,7,9,11},
   ["melodicMinorAscending"] =  {0,2,3,5,7,9,11},
   ["melodicMinorDescending"]=  {0,2,3,5,7,8,10},
   ["wholeTone"]= {0,2,4,6,8,10},
   ["pentatonicMajor"] = {0,2,4,7,9},
   ["pentatonicMinor"]= {0,3,5,7,10},
   ["pentatonicBlues"]= {0,3,5,6,7,10},
   ["pentatonicNeutral"]= {0,2,5,7,10},
   ["dorian"]={0,2,3,5,7,9,10},
   ["phrygian"]={0,2,3,5,7,8,10},
   ["lydian"]= {0,2,4,6,7,9,11},
   ["mixolydian"]= {0,2,4,5,7,9,10},
   ["aeolian"]={0,2,3,5,7,8,10},
   ["locrian"]= {0,2,3,5,6,8,10},
   ["arabianA"]= {0,2,3,5,6,8,9,11},
   ["arabianB"]= {0,2,4,5,6,8,10},
   ["augmented"]= {0,3,4,6,8,11},
   ["auxiliaryDiminishedBlues"]= {0,2,3,4,6,7,9,10},
   ["blues"]= {0,3,5,6,7,10},
   ["chinese"]= {0,4,6,7,11},
   ["chineseMongolian"]= {0,2,4,7,9},
   ["diatonic"]={0,2,4,7,9},
   ["diminished"]= {0,2,3,5,6,8,9,11},
   ["doubleHarmonic"]= {0,2,4,5,7,8,11},
   ["egyptian"]= {0,2,5,7,10},
   ["eightToneSpanish"]= {0,2,3,4,5,6,8,10},
   ["ethiopian"]= {0,2,3,5,7,8,10},
   ["hawaiian"]= {0,2,3,5,7,9,11},
   ["hindu"]={0,2,4,5,7,8,10},
   ["hungarianGypsy"]={0,2,3,6,7,8,11},
   ["japaneseA"]= {0,2,5,7,8},
   ["japaneseB"]={0,2,5,7,8},
   ["jewishAdonaiMalakh"]= {0,2,2,3,5,7,9,10},
   ["neopolitan"]= {0,2,3,5,7,8,11},
   ["neopolitanMinor"]= {0,2,3,5,7,8,10},
   ["orientalA"]= {0,2,4,5,6,8,10},
   ["orientalB"]= {0,2,4,5,6,9,10},
   ["persian"]= {0,2,4,5,6,8,11},
   ["pureMinor"]={0,2,3,5,7,8,10}
}

function love.load()
   d1 = love.sound.newSoundData("cycles/AKWF_cheeze_0001.wav")
   d2 = love.sound.newSoundData("cycles/AKWF_ebass_0001.wav")
   
   blended = love.sound.newSoundData(d1:getSampleCount(),  d1:getSampleRate(), d1:getBitDepth(), d1:getChannelCount())

   qs = love.audio.newQueueableSource(d1:getSampleRate(), d1:getBitDepth(), d1:getChannelCount(), 24)

   pitch = 1
   semitone = 20

   
   lfo = {cyclesPerSecond=8, thing=13, kind='sinus', value=0, output=0}

   arp = {cyclesPerSecond=2, value=0, offsets=scales.pentatonicBlues}
end



function love.update(dt)

   lfo.value = lfo.value + (dt *  lfo.cyclesPerSecond )
   lfo.output = ((math.sin(lfo.value * math.pi*2 )/lfo.thing + 1)/2)
   if lfo.output < 0 then
      lfo.output = 0 --lfo.output + math.pi*2
   end

   arp.value = arp.value + (dt * arp.cyclesPerSecond)
   local arpIndex = math.floor(arp.value % (#arp.offsets)) + 1
   --print(arp.value, arp.offsets[arpIndex])
   
   local mx,my =love.mouse.getPosition()
   local w,h = love.graphics.getDimensions()

   local b = mapInto(mx, 0,w, 0, 1)
   local p = mapInto(my, 0, h, 0.01, 3)
   lfo.cyclesPerSecond = p
   lfo.thing = 1 +  b 
   local count = qs:getFreeBufferCount()


   blendSoundDatas(d1,d2, b, blended)
   

   local wet = sone.filter(sone.copy(blended), {
			       type = "bandpass",
			       frequency = 1000,
			       Q = p,
			       gain = 2,
   })

   -- local wet = sone.filter(sone.copy(blended), {
   --          type = "lowpass",
   --          frequency = 150,
   --      })

   
   -- wet =  sone.filter(sone.copy(wet), {
   -- 			       type = "peakeq",
   -- 			       frequency = 1000,
   -- 			       gain = 9,
   -- })
   -- wet = sone.filter(sone.copy(wet), {
   -- 			      type = "notch",
   -- 			      frequency = 1000,
   -- 			      Q = 0.8*p,
   -- 			      gain = 6*p,
   -- })

   for i =1, count do
      qs:queue(wet)
      qs:play()
      
      --qs:setPitch(pitch )
      qs:setPitch(getPitch(semitone +  arp.offsets[arpIndex], 1))
      qs:setVolume(.5 + (lfo.output*.5))
   end
   
end



--[[
function populateDataScales() {
        
    }

]]--


function love.keypressed(k)
   if k=='escape' then
      love.event.quit()
   end

   local onScreenKeys = {'a', 'w', 's',
                         'e', 'd', 'f',
                         't', 'g', 'y',
                         'h', 'u', 'j',
			 'k', 'o', 'l', 'p', ';', "'"}
   for i=1, #onScreenKeys do
      if k==onScreenKeys[i] then
	 semitone = i-1
	 arpIndex = 0
	 arp.value = 0
         pitch = getPitch(semitone, 1)
         pitch = pitch 


      end
      
   end
   
   
end

function love.draw()

   love.graphics.printf({{1,0,0},"red pill " , {0,0,1}, " blue pill"}, 25,25, 200)
end
