require('love.timer')
require('love.sound')
require('love.audio')
require('love.math')

require('inspect')
local min, max     = ...
local now          = love.timer.getTime()
local time         = 0
local lastTick     = 0
local lastBeat     = -1
local bpm          = 0
local scale        = {}
local voices       = {}
local tuning       = 0
local swing        = 50
local paused       = false

local pattern      = {}
local samples      = {}

channel            = {};
channel.audio2main = love.thread.getChannel("audio2main"); -- from thread
channel.main2audio = love.thread.getChannel("main2audio"); --from main


function mapInto(x, in_min, in_max, out_min, out_max)
   return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

function getPitch(semitone, octave)
   local plusoctave = 0
   --local octave = 2
   if semitone > 10 then
      plusoctave = 1
      semitone = semitone % 11
   end

   --print('getpitch', semitone, octave + plusoctave)
   local freqs = { 261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88, 523.25 }
   local n = mapInto(freqs[semitone + 1], 261.63, 523.25, 0, 1)
   local o = octave + plusoctave

   if o == -7 then return (0.015625 - (0.0078125 - n / 128)) end
   if o == -6 then return (0.03125 - (0.015625 - n / 64)) end
   if o == -5 then return (0.0625 - (0.03125 - n / 32)) end
   if o == -4 then return (0.125 - (0.0625 - n / 16)) end
   if o == -3 then return (0.25 - (0.125 - n / 8)) end
   if o == -2 then return (0.5 - (0.25 - n / 4)) end
   if o == -1 then return (1 - (0.5 - n / 2)) end
   if o == 0 then return (1 + n) end
   if o == 1 then return (2 + 2 * n) end
   if o == 2 then return (4 + 4 * n) end
   if o == 3 then return (8 + 8 * n) end
   if o == 4 then return (16 + 16 * n) end
   if o == 5 then return (32 + 32 * n) end
   if o == 6 then return (64 + 64 * n) end
   if o == 7 then return (128 + 128 * n) end
   if o == 8 then return (256 + 256 * n) end
end

local sources = {}

function chokeGroup(index)
   for i = 1, #sources do
      if sources[i].index == index then
         sources[i].source:stop()
      end
   end
end

local queue = {}
local beat = 0


while (true) do
   if not paused then
      local n = love.timer.getTime()
      local delta = n - now

      now = n
      time = time + delta
      -- local beat = time * (bpm / 60) * 4
      --print(beat)

      beat = beat + (delta * (bpm / 60) * 4)
      local tick = ((beat % 1) * (96))
      local missedTicks = {}

      if math.floor(tick) - math.floor(lastTick) > 1 then
         --print('thread: missed ticks:', math.floor(beat), math.floor(tick), math.floor(lastTick))
         -- im assuming we never loose a beat (that would mean 96 consequetive ticks missed)
         for i = math.floor(lastTick) + 1, math.floor(tick) - 1 do
            --print(i)
            table.insert(missedTicks, i)
         end
      end

      --print(tick)

      -- i want to be able to swing, so instead of checking every beat we need to check more.

      --https://melodiefabriek.com/sound-tech/mpc-swing-reason/

      --print(math.floor(lastBeat), math.floor(beat), math.floor(lastTick), math.floor(tick))
      if (math.floor(lastBeat) ~= math.floor(beat)) then
         -- removes sources that are done from a table, this table is tehre for choking
         --beat = beat+1
         for i = #sources, 1, -1 do
            if not sources[i].source:isPlaying() then
               table.remove(sources, i)
            end
         end

         channel.audio2main:push({ type = "playhead", data = math.floor(beat) })

         local index = 1 + math.floor(beat) % #pattern


         -- todo I kinda need a different index per voice, so i can have differnt loop lengths per voice and introduce polyrithm.
         -- this also calls for a maximum of voices in a part, my guess is 8, or maybe 16 ?

         -- before this i want to be able to swicth scales while working, i havent decided what todo with notes that arent oin the scale no more ...


         if pattern[index] then
            for i = 1, #scale do
               local v = pattern[index][i].value -- this is now a voiceindex
               local o = pattern[index][i].octave

               if pattern[index][i].chance ~= nil then
                  local rnd = (love.math.random() * 100)

                  if rnd > pattern[index][i].chance then
                     v = 0
                  end
               end


               if v > 0 then
                  local vi = voices[v].voiceIndex -- this is now an index into the whole sample library
                  local vt = voices[v].voiceTuning
                  local vv = math.min(1, math.max(0, voices[v].voiceVolume))
                  local semi = pattern[index][i].semitone


                  local notePitchRandom = pattern[index][i].notePitchRandomizer

                  if notePitchRandom ~= nil and notePitchRandom ~= 0 then
                     local i = math.ceil(love.math.random() * #scale)
                     semi = scale[i]
                  end


                  -- todo paraetrize
                  --local i = math.ceil(love.math.random()* #scale)

                  --semi = scale[i]

                  --o = love.math.random()*
                  semi = semi + tuning + vt




                  while semi < 0 do
                     semi = semi + 12
                     o = o - 1
                  end

                  while semi > 12 do
                     semi = semi - 12
                     o = o + 1
                  end

                  --print('after', semi, o)
                  --print(semi, o)
                  local note_repeat = pattern[index][i].noteRepeat or 1

                  for j = 1, note_repeat do
                     local s
                     if (vi <= #samples) then
                        s = samples[vi].s:clone()
                     end



                     local p = getPitch(semi, o)

                     -- todo parametrize micropicth randomizer
                     -- p = p + ( -0.0125 + love.math.random() * 0.025)

                     s:setPitch(p)

                     local velocity     = 1
                     local noteVelocity = pattern[index][i].noteVelocity

                     if noteVelocity ~= nil and noteVelocity ~= 0 then
                        velocity = noteVelocity
                     end
                     --print(vv)
                     s:setVolume(velocity * vv)
                     -- i only swing the even beats
                     local offset = math.floor(beat) % 2 == 0

                     local _swing = ((swing - 50) / 50) * 96

                     local note_repeat_offset = (96 / note_repeat)

                     local tickOffset = (offset and _swing or 0) + ((j - 1) * note_repeat_offset)

                     table.insert(queue,
                         {
                             beat = beat,
                             tick = tick + tickOffset,
                             source = s,
                             index = v
                         })
                  end
               end
            end
         end
      end

      if (#missedTicks) then
         for ti = 1, #missedTicks do
            local t = missedTicks[ti]
            --print(t)
         end
         --print('I am in a place where i need todo aomething with missingticks!')
         --print(inspect(missedTicks))

         --print(inspect(queue))
      end
      for ti = 1, #missedTicks do
         t = missedTicks[ti]

         for i = #queue, 1, -1 do
            local q = queue[i]
            if math.floor(q.beat) == math.floor(beat) and math.floor(q.tick) == math.floor(t) then
               print('actually missed a tick that i needed!!!!')
               --print(inspect(q))
               --print(inspect(t))
            end
         end
      end


      for i = #queue, 1, -1 do
         local q = queue[i]



         if math.floor(q.beat) == math.floor(beat) and math.floor(q.tick) == math.floor(tick) then
            table.remove(queue, i)
            table.insert(sources, { source = q.source, index = q.index })
            -- todo parametrize
            --chokeGroup(q.index)

            love.audio.play(q.source)
         end
      end



      lastBeat = beat
      lastTick = tick
   end
   love.timer.sleep(.001)

   local v = channel.main2audio:pop();
   if v then
      if (v.type == 'pattern') then
         pattern = v.data
      end
      if (v.type == 'voices') then
         voices = v.data
      end
      if (v.type == 'swing') then
         swing = v.data
      end
      if (v.type == 'tuning') then
         tuning = v.data
      end
      if (v.type == 'samples') then
         samples = v.data
      end
      if (v.type == 'bpm') then
         bpm = v.data
      end
      if (v.type == 'scale') then
         scale = v.data
      end
      if (v.type == 'paused') then
         paused = v.data
         now    = love.timer.getTime()
      end
      if (v.type == 'stop') then
         love.audio.stop()
         return love.event.quit()
      end
      --print(v.type, v.data)
   end
end
