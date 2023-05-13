require('love.timer')
require('love.sound')
require('love.audio')
require('love.math')

local min, max = ...
local now = love.timer.getTime()
local time = 0
local lastTick = 0
local lastBeat = -1
local bpm = 0
local scale = {}
local pattern = {}
local samples = {}

channel 	= {};
channel.audio2main	= love.thread.getChannel ( "audio2main" ); -- from thread
channel.main2audio	= love.thread.getChannel ( "main2audio" ); --from main





--local mytick = 0


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


while(true) do

   --local scale = {0,2,5,9,12, 16, 17,18,19,20,21,22}

   local n = love.timer.getTime()
   local delta = n - now
   local result = ((delta * 1000))

   now = n
   time = time + delta
   local beat = time * (bpm / 60) * 4    
   local tick = ((beat % 1) * (96))
   if math.floor(tick) - math.floor(lastTick) > 1 then
      print('thread: missed ticks:', math.floor(beat), math.floor(tick), math.floor(lastTick))
   end



   if (math.floor(lastBeat)   ~= math.floor(beat)) then
   --if (math.floor(beat) % 2 == 1 and math.floor(tick) == 96/6) or
   --(math.floor(beat) % 2 == 0 and math.floor(tick) == 0)  then
      --print(math.floor(lastBeat), math.floor(beat))
      --print(beat, lastBeat)
      channel.audio2main:push ({type="playhead", data=math.floor(beat)})
      local index = 1+ math.floor(beat) % 16
      if pattern[index] then
      	 for i = 1, #scale do
            
      	    local v = pattern[index][i].value
      	    local o = pattern[index][i].octave
      	    if v > 0 then
      	       local s
      	       if (v <= #samples) then
      		      s = samples[v]:clone()
      	       end
               --- the stuff about scale

               local semi = scale[(#scale+1) - i]
               while semi < 0 do
                  semi = semi + 12
                  o = o-1
               end
               --print(i, semi, o)
               --- 
      	       local p = getPitch(semi, o)
               --local percent10 = p/25
               --p = p + love.math.random()*percent10   - percent10/2
      	       s:setPitch(p)
      	       love.audio.play(s)
      	    end
      	 end
      end

   end
   lastBeat = beat
   lastTick = tick

   love.timer.sleep(0.001)

   local v = channel.main2audio:pop();
   if v then
      if (v.type == 'pattern') then
	   pattern = v.data
      end
      if (v.type == 'samples') then
	   samples = v.data
      end
      if (v.type == 'bpm') then
	   bpm = v.data
	   print('bpm: ', bpm)
      end
      if (v.type == 'scale') then
         scale = v.data
         print('scale: ', scale)
         end
   
   end

end
