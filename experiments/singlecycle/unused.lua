
function lowPassFilter(sound, cutoff)
   local lastOutput = 0
   local copy = love.sound.newSoundData(sound:getSampleCount(), sound:getSampleRate(), sound:getBitDepth(), sound:getChannels())
   local sampleCount = sound:getSampleCount() * sound:getChannels() - 1
   for i = 0, sampleCount do
      local input = sound:getSample(i) 
      local  distanceToGo = input - lastOutput;
      lastOutput = lastOutput +  distanceToGo * cutoff
      copy:setSample(i, lastOutput)
   end
   return copy
end

function resonantLowPassFilter(sound, cutoff, resonance)
   local lastOutput=0
   local momentum=0
   local copy = love.sound.newSoundData(sound:getSampleCount(), sound:getSampleRate(), sound:getBitDepth(), sound:getChannels())
   local sampleCount = sound:getSampleCount() * sound:getChannels() - 1
   for i = 0, sampleCount do
      --print(i)
      local input = sound:getSample(i)
      local distanceToGo = input - lastOutput
      momentum = momentum + distanceToGo * cutoff
      lastOutput = lastOutput + momentum + distanceToGo*resonance
      copy:setSample(i, lastOutput)
   end
   return copy

end


function resonantHighPassFilter(sound, cutoff, resonance)
   local lastOutput=0
   local lastInput=0
   local momentum=0
   local copy = love.sound.newSoundData(sound:getSampleCount(), sound:getSampleRate(), sound:getBitDepth(), sound:getChannels())
   local sampleCount = sound:getSampleCount() * sound:getChannels() - 1
   for i = 0, sampleCount do

      local input = sound:getSample(i)
      lastOutput = lastOutput + momentum - lastInput +input
      lastInput = input 
      

      momentum = momentum * resonance - lastOutput * cutoff
      copy:setSample(i, lastOutput)
   end
   return copy

end


local scales = {
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

