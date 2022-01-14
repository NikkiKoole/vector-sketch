


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
      plusoctave = 1
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


function love.load()
   d1 = love.sound.newSoundData("cycles/AKWF_cheeze_0001.wav")
   d2 = love.sound.newSoundData("cycles/AKWF_ebass_0001.wav")
   
   blended = love.sound.newSoundData(d1:getSampleCount(),  d1:getSampleRate(), d1:getBitDepth(), d1:getChannelCount())

   qs = love.audio.newQueueableSource(d1:getSampleRate(), d1:getBitDepth(), d1:getChannelCount(), 8)

   pitch = 1

   
   lfo = {cyclesPerSecond=8, thing=13, kind='sinus', value=0, output=0}
end



function love.update(dt)

   lfo.value = lfo.value + (dt *  lfo.cyclesPerSecond )
   lfo.output = ((math.sin(lfo.value * math.pi*2 )/lfo.thing + 1)/2)
   if lfo.output < 0 then
      lfo.output = 0 --lfo.output + math.pi*2
   end
   
   
   local mx,my =love.mouse.getPosition()
   local w,h = love.graphics.getDimensions()

   local b = mapInto(mx, 0,w, 0, 1)
   local p = mapInto(my, 0, h, .7, 5)
   lfo.cyclesPerSecond = p
   lfo.thing = 1 +  b 
   local count = qs:getFreeBufferCount()
   
   for i =1, count do
      blendSoundDatas(d1,d2, b, blended)
      qs:queue(blended)
      qs:play()
      
      qs:setPitch(pitch )
      qs:setVolume(.5 + (lfo.output*.5))
   end
   
end

--[[
function populateDataScales() {
        // Defines scales input is key, name, also known as, tags(array), notes(array)
        populateDataScale("harmonicMinor", "Harmonic Minor", "", [], [0,2,3,5,7,8,11]);
        populateDataScale("major", "Major", "Ionian Scale", [], [0,2,4,5,7,9,11]);
        populateDataScale("melodicMinorAscending", "Melodic Minor (Ascending)", "", [], [0,2,3,5,7,9,11]);
        populateDataScale("melodicMinorDescending", "Melodic Minor (Descending)", "", [], [0,2,3,5,7,8,10]);
        populateDataScale("wholeTone", "Whole Tone", "", [], [0,2,4,6,8,10]);
        populateDataScale("pentatonicMajor", "Pentatonic Major", "", [], [0,2,4,7,9]);
        populateDataScale("pentatonicMinor", "Pentatonic Minor", "", [], [0,3,5,7,10]);
        populateDataScale("pentatonicBlues", "Pentatonic Blues", "", [], [0,3,5,6,7,10]);
        populateDataScale("pentatonicNeutral", "Pentatonic Neutral", "", [], [0,2,5,7,10]);
        populateDataScale("dorian", "Dorian", "", [], [0,2,3,5,7,9,10]);
        populateDataScale("phrygian", "Phrygian", "", [], [0,2,3,5,7,8,10]);
        populateDataScale("lydian", "Lydian", "", [], [0,2,4,6,7,9,11]);
        populateDataScale("mixolydian", "Mixolydian", "", [], [0,2,4,5,7,9,10]);
        populateDataScale("aeolian", "Aeolian", "", [], [0,2,3,5,7,8,10]);
        populateDataScale("locrian", "Locrian", "", [], [0,2,3,5,6,8,10]);
        populateDataScale("arabianA", "Arabian (a)", "", ["Exotic"], [0,2,3,5,6,8,9,11]);
        populateDataScale("arabianB", "Arabian (b)", "", ["Exotic"], [0,2,4,5,6,8,10]);
        populateDataScale("augmented", "Augmented", "", ["Exotic"], [0,3,4,6,8,11]);
        populateDataScale("auxiliaryDiminishedBlues", "Auxiliary Diminished Blues", "", ["Exotic"], [0,2,3,4,6,7,9,10]);
        populateDataScale("blues", "Blues", "", ["Exotic"], [0,3,5,6,7,10]);
        populateDataScale("chinese", "Chinese", "", ["Exotic"], [0,4,6,7,11]);
        populateDataScale("chineseMongolian", "Chinese Mongolian", "", ["Exotic"], [0,2,4,7,9]);
        populateDataScale("diatonic", "Diatonic", "", ["Exotic"], [0,2,4,7,9]);
        populateDataScale("diminished", "Diminished", "", ["Exotic"], [0,2,3,5,6,8,9,11]);
        populateDataScale("doubleHarmonic", "Double Harmonic", "", ["Exotic"], [0,2,4,5,7,8,11]);
        populateDataScale("egyptian", "Egyptian", "", ["Exotic"], [0,2,5,7,10]);
        populateDataScale("eightToneSpanish", "Eight Tone Spanish", "", ["Exotic"], [0,2,3,4,5,6,8,10]);
        populateDataScale("ethiopian", "Ethiopian (Geez & Ezel)", "", ["Exotic"], [0,2,3,5,7,8,10]);
        populateDataScale("hawaiian", "Hawaiian", "", ["Exotic"], [0,2,3,5,7,9,11]);
        populateDataScale("hindu", "Hindu", "", ["Exotic"], [0,2,4,5,7,8,10]);
        populateDataScale("hungarianGypsy", "Hungarian Gypsy", "", ["Exotic"], [0,2,3,6,7,8,11]);
        populateDataScale("japaneseA", "Japanese (A)", "", ["Exotic"], [0,2,5,7,8]);
        populateDataScale("japaneseB", "Japanese (B)", "", ["Exotic"], [0,2,5,7,8]);
        populateDataScale("jewishAdonaiMalakh", "Jewish (Adonai Malakh)", "", ["Exotic"], [0,2,2,3,5,7,9,10]);
        populateDataScale("neopolitan", "Neopolitan", "", ["Exotic"], [0,2,3,5,7,8,11]);
        populateDataScale("neopolitanMinor", "Neopolitan Minor", "", ["Exotic"], [0,2,3,5,7,8,10]);
        populateDataScale("orientalA", "Oriental (A)", "", ["Exotic"], [0,2,4,5,6,8,10]);
        populateDataScale("orientalB", "Oriental (B)", "", ["Exotic"], [0,2,4,5,6,9,10]);
        populateDataScale("persian", "Persian", "", ["Exotic"], [0,2,4,5,6,8,11]);
        populateDataScale("pureMinor", "Pure Minor", "", ["Exotic"], [0,2,3,5,7,8,10]);
    }

]]--


function love.keypressed(k)
   if k=='escape' then
      love.event.quit()
   end

   local onScreenKeys = {'a', 'w', 's',
                         'e', 'd', 'f',
                         't', 'g', 'y',
                         'h', 'u', 'j'}
   for i=1, #onScreenKeys do
      if k==onScreenKeys[i] then
--         print(i-1)
         pitch = getPitch(i-1, 1)
         pitch = pitch* (1+( love.math.random() * 0.02 -0.01))

         --lfo.value = 0  --sync
      end
      
   end
   
   
end

