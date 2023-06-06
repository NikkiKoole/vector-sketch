package.path = package.path .. ";../../?.lua"

-- https://www.svgrepo.com/collection/atlas-variety-line-icons/
require 'palette'
inspect           = require "vendor.inspect"
local ui          = require 'lib.ui'
local text        = require 'lib.text'

local audioHelper = require 'lib.audio-helper'

audioHelper.startAudioThread()

local function createFittingScale(img, desired_w, desired_h)
   local w, h = img:getDimensions()
   local sx, sy = desired_w / w, desired_h / h
   return sx, sy
end

local function getScaleAndOffsetsForImage(img, desiredW, desiredH)
   local sx, sy = createFittingScale(img, desiredW, desiredH)
   local scale = math.min(sx, sy)
   local xOffset = 0
   local yOffset = 0
   if scale == sx then
      xOffset = -desiredW / 2 -- half the height
      local something = sx * img:getHeight()
      local something2 = sy * img:getHeight()
      yOffset = -desiredH / 2 - (something - something2) / 2
   elseif scale == sy then
      yOffset = -desiredH / 2 -- half the height
      local something = sx * img:getWidth()
      local something2 = sy * img:getWidth()
      xOffset = -desiredW / 2 + (something - something2) / 2
   end
   return scale, xOffset, yOffset
end

function love.keypressed(key)
   local voices = song.voices
   if key == "left" then
      song.bpm = song.bpm - 10
      song.bpm = math.max(10, song.bpm)
   end
   if key == "right" then
      song.bpm = song.bpm + 10
      song.bpm = math.min(300, song.bpm)
   end
   if key == "up" then
      octave = octave + 1
      octave = math.min(5, octave)
   end
   if key == "down" then
      octave = octave - 1
      octave = math.max( -5, octave)
   end
   if key == "a" then
      voices[drawingVoiceIndex].voiceTuning = voices[drawingVoiceIndex].voiceTuning - 1
   end
   if key == "s" then
      voices[drawingVoiceIndex].voiceTuning = voices[drawingVoiceIndex].voiceTuning + 1
   end
   if key == "d" then
      voices[drawingVoiceIndex].voiceVolume = voices[drawingVoiceIndex].voiceVolume - .1
   end
   if key == "f" then
      voices[drawingVoiceIndex].voiceVolume = voices[drawingVoiceIndex].voiceVolume + .1
   end
   if key == "z" then
      song.tuning = song.tuning - 1
   end
   if key == "x" then
      song.tuning = song.tuning + 1
   end
   if key == "c" then
      song.swing = song.swing - 1
      if song.swing < 50 then song.swing = 50 end
   end
   if key == "v" then
      song.swing = song.swing + 1
      if song.swing > 75 then song.swing = 75 end
   end

   if key == "1" then
      if (not song.pages[1]) then
         song.pages[1] = audioHelper.initPage(horizontal, 12)
      end
      song.page = song.pages[1]
   end
   if key == "2" then
      if (not song.pages[2]) then
         song.pages[2] = audioHelper.initPage(horizontal, 12)
      end
      song.page = song.pages[2]
   end
   if key == "3" then
      if (not song.pages[3]) then
         song.pages[3] = audioHelper.initPage(horizontal, 12)
      end
      song.page = song.pages[3]
   end
   audioHelper.sendMessageToAudioThread({ type = "song", data = song });
   if key == "space" then
      paused = not paused
      audioHelper.sendMessageToAudioThread({ type = "paused", data = paused });
   end
   if key == "escape" then
      love.audio.stop()
      audioHelper.sendMessageToAudioThread({ type = "stop" });
      love.event.quit()
   end
end

function love.load()
   song = audioHelper.initSong(16)
   makePatternFitOnscreen(song)
   song.page = song.pages[1]

   font = love.graphics.newFont('/resources/WindsorBT-Roman.otf', 16)
   love.graphics.setFont(font)

   octave   = 0
   paused   = false
   playing  = true
   playhead = 0


   local w, h           = love.graphics.getDimensions()
   numberOfSpritesInRow = 24

   head                 = love.graphics.newImage('resources/theo.png')
   color                = colors.cream
   drawingValue         = 1
   drawingVoiceIndex    = 1

   paintModes           = { 'note on/off', 'note chance', 'note repeat', 'note pitch rnd', 'velocity' }
   paintModesIndex      = 1
   noteChances          = { 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 5, 0 }
   noteRepeats          = { 1, 2, 3, 4 }
   notePitchRandoms     = { 0, 1, 2 }
   noteVelocities       = { 0, 0.2, 0.4, 0.6, 0.8, 1.0 }


   local names = {
       'badger',
       'bat',
       'beach',
       'bee',
       'beetle',
       'bird',
       'bison',
       'butterfly',
       'camel',
       'cat',
       'clam',
       'cow',
       'crab',
       'crocodile',
       'crow',
       'dog',
       'duck',
       'elephant',
       'fennec',
       'fish',
       'flamingo',
       'flying-fish',
       'fox',
       'frog',
       'goldfish',
       'gorilla',
       'hamster',
       'hen',
       'hippopotamus',
       'hummingbird',
       'hyena',
       'jellyfish',
       'kangaroo',
       'kiwi',
       'koala',
       'lemur',
       'lion',
       'lizard',
       'manta',
       'moose',
       'mole',
       'mussel',
       'octopus',
       'ostrich',
       'owl',
       'panda-bear',
       'panther',
       'parrot',
       'penguin',
       'pig',
       'polar',
       'porcupine',
       'puffer',
       'rabbit',
       'racoon',
       'rat',
       'red',
       'rhinoceros',
       'salamander',
       'scorpion',
       'sea',
       'sheep',
       'shrew',
       'snail',
       'snake',
       'snake2',
       'spider',
       'starfish',
       'tiger',
       'toucan',
       'turtle',
       'walrus',
       'whale',
       'wolf',
       'wolverine',
       'zebra',
   }


   local sample_data = {
       { 'zebra',       'mipo/mi' },
       { 'zebra',       'mipo/mi' },
       { 'zebra',       'mipo/mi' },
       { 'octopus',     'mipo/po' },
       { 'goldfish',    'mipo/pi' },
       { 'bat',         'mipo/mo' },
       { 'goldfish',    'mipo/mi2' },
       { 'bat',         'mipo/po2' },
       { 'goldfish',    'mipo/mi3' },
       { 'bat',         'mipo/po3' },
       { 'bat',         'mipo/blah1' },
       { 'bat',         'mipo/blah2' },
       { 'bat',         'mipo/blah3' },

       { 'polar',       'guirojuno/1' },
       { 'porcupine',   'guirojuno/2' },
       { 'walrus',      'guirojuno/3' },
       { 'sea',         'guirojuno/11' },
       { 'toucan',      'guirojuno/21' },
       { 'hamster',     'guirojuno/rijstei' },
       { 'clam',        'babirhodes/ba' }, -- clam
       { 'owl',         'babirhodes/bi' }, -- owl
       { 'crab',        'babirhodes/biep2' }, -- crab
       { 'elephant',    'babirhodes/biep3' },
       { 'panda-bear',  'babirhodes/rhodes2' }, -- panda
       { 'kangaroo',    'babirhodes/blok2' },
       { 'jellyfish',   'tpl-dnb/bongos' },
       { 'koala',       'synth11' },
       { 'flamingo',    'blokfluit' },
       { 'sea',         'synth06' },
       { 'flamingo',    'VibraphoneHi-MT70' },
       { 'lemur',       'tpl-dnb/clap' },
       { 'moose',       'tpl-dnb/crash' },
       { 'antelope',    'tpl-dnb/drum' },
       { 'manta',       'tpl-dnb/hihat' },
       { 'fox',         'tpl-dnb/hihat-open' },
       { 'bee',         'tpl-dnb/kick_01' },
       { 'lizard',      'tpl-dnb/kick_02' },
       { 'ostrich',     'tpl-dnb/snare_01' },
       { 'crocodile',   'tpl-dnb/snare_02' },
       { 'starfish',    'sf1-015' },

       { 'red',         'bass02' },
       { 'rabbit',      'bass04' },
       { 'polar',       'bass07' },
       { 'parrot',      'synth11p' },
       { 'porcupine',   'brass5c' },

       { 'badger',      'ElkaSolist505/bass-piano_distorto' },
       { 'puffer',      'ElkaSolist505/haw-O1' },
       { 'rat',         'ElkaSolist505/piano-clickO1' },

       { 'lemur',       'cr78/Tamb 1' },
       { 'sheep',       'cr78/Rim Shot' },
       { 'panther',     'cr78/Bongo High' },
       { 'kiwi',        'cr78/Bongo Low' },
       { 'hummingbird', 'cr78/Conga Low' },
       { 'beetle',      'cr78/Guiro 1' },
       { 'beetle',      'cr78/Guiro 2' },
       { 'penguin',     'cr78/Clave' },
       { 'penguin',     'cr78/Maracas' },
       { 'cow',         'cr78/Cowbell' },
       { 'scorpion',    'cr78/HiHat Accent' },
       { 'scorpion',    'cr78/HiHat Metal' },
       { 'zebra',       'cr78/HiHat' },
       { 'scorpion',    'cr78/Cymbal' },
       { 'scorpion',    'cr78/Snare' },
       { 'scorpion',    'cr78/Kick' },
       { 'scorpion',    'cr78/Kick Accent' },

       { 'gorilla',     'macdm/bassmac1' },
       { 'rhinoceros',  'macdm/bassmac2' },

       { 'rhinoceros',  'Triangles 103' },
       { 'hamster',     'Triangles 101' },
       { 'hamster',     'prophet1c' },
       { 'hamster',     'mp7/Quijada' },
       { 'hamster',     'mp7/Guira2' },
       { 'hamster',     'mp7/GuiraKick' },
       { 'hamster',     'mp7/Clave' },
       { 'kangaroo',    'legowelt/Synth Brassy Italo' },
       { 'kangaroo',    'legowelt/Synth Swimpy 3' },
       { 'kangaroo',    'legowelt/Synth SoftTooter' },
       { 'kangaroo',    'legowelt/SYNTH-Littleblip' },
       { 'kangaroo',    'legowelt/SYNTH-LittleblipLow' },
       { 'kangaroo',    'legowelt/Bass SimpleSloppy3' },
       { 'kangaroo',    'legowelt/BASS-JojabiBass' },


   }


   local sample_data22 = {

       { 'zebra',       'mipo/mi' },
       { 'zebra',       'mipo/mi' },
       { 'zebra',       'mipo/mi' },

       { 'octopus',     'mipo/po' },
       { 'goldfish',    'mipo/pi' },
       { 'bat',         'mipo/mo' },
       { 'goldfish',    'mipo/mi2' },
       { 'bat',         'mipo/po2' },
       { 'goldfish',    'mipo/mi3' },
       { 'bat',         'mipo/po3' },
       { 'bat',         'mipo/blah1' },
       { 'bat',         'mipo/blah2' },
       { 'bat',         'mipo/blah3' },

       { 'walrus',      'guirojuno/3' },

       { 'clam',        'babirhodes/ba' }, -- clam
       { 'owl',         'babirhodes/bi' }, -- owl
       { 'crab',        'babirhodes/biep2' }, -- crab
       { 'elephant',    'babirhodes/biep3' },
       { 'panda-bear',  'babirhodes/rhodes2' }, -- panda
       { 'kangaroo',    'babirhodes/blok2' },

       { 'red',         'bass02' },
       { 'rabbit',      'bass04' },
       { 'polar',       'bass07' },

       { 'lemur',       'cr78/Tamb 1' },
       { 'sheep',       'cr78/Rim Shot' },
       { 'panther',     'cr78/Bongo High' },
       { 'kiwi',        'cr78/Bongo Low' },
       { 'hummingbird', 'cr78/Conga Low' },
       { 'beetle',      'cr78/Guiro 1' },
       { 'beetle',      'cr78/Guiro 2' },
       { 'penguin',     'cr78/Clave' },
       { 'penguin',     'cr78/Maracas' },
       { 'cow',         'cr78/Cowbell' },
       { 'scorpion',    'cr78/HiHat Accent' },
       { 'scorpion',    'cr78/HiHat Metal' },
       { 'zebra',       'cr78/HiHat' },
       { 'scorpion',    'cr78/Cymbal' },
       { 'scorpion',    'cr78/Snare' },
       { 'scorpion',    'cr78/Kick' },
       { 'scorpion',    'cr78/Kick Accent' },

       { 'rhinoceros',  'Triangles 103' },
       { 'hamster',     'Triangles 101' },

   }

   spriteBackgroundMap = {
       { sw = 'babirhodes',    bg = colors.pink },
       { sw = 'tpl-dnb/',      bg = colors.orange },
       { sw = 'mipo',          bg = colors.peach },
       { sw = 'guirojuno',     bg = colors.brown },
       { sw = 'ElkaSolist505', bg = colors.blue },
       { sw = 'cr78/',         bg = colors.yellow },
       { sw = 'mp7',           bg = colors.green },
       { sw = 'legowelt',      bg = colors.dark_blue }
   }


   sprites = {}
   samples = {}
   for i = 1, #sample_data do
      table.insert(sprites, love.graphics.newImage('resources/' .. sample_data[i][1] .. '.png'))
      local data = love.sound.newSoundData('instruments/' .. sample_data[i][2] .. '.wav')
      table.insert(samples, { s = love.audio.newSource(data, 'static'), p = sample_data[i][2] })
   end


   save = love.graphics.newImage('resources/save.png')

   audioHelper.sendMessageToAudioThread({ type = "samples", data = samples });
   audioHelper.sendMessageToAudioThread({ type = "song", data = song })
end

function love.resize()
   local w, h = love.graphics.getDimensions()
   cellWidth = (w - leftmargin - rightmargin) / horizontal
   cellHeight = cellWidth / 1.5
   voicesHeight = cellHeight
   bottommargin = h - (cellHeight * vertical) - topmargin
end

function love.update(dt)
   local msg = audioHelper.getMessageFromAudioThread()
   if msg then
      if (msg.type == 'beat') then
         playhead = msg.data % horizontal
      end
      if (msg.type == 'played') then
         --  print('played', msg.data.path, msg.data.source, msg.data.pitch)
      end
   end
end

function indexOf(array, value)
   for i, v in ipairs(array) do
      if v == value then
         return i
      end
   end
   return nil
end

function love.mousepressed(x, y, button)
   local w, h = love.graphics.getDimensions()
   local voices = song.voices
   local notesInScale = song.scale.notes
   -- grid
   if (x > leftmargin and x < w - rightmargin) then
      if (y > topmargin and y < h - bottommargin) then
         local cx = 1 + math.floor((x - leftmargin) / cellWidth)
         local cy = 1 + math.floor((y - topmargin) / cellHeight)
         if (paintModesIndex == 1) then -- note on off
            if voices[drawingVoiceIndex] then
               song.page[cx][cy].value = (song.page[cx][cy].value > 0) and 0 or drawingVoiceIndex
               song.page[cx][cy].octave = octave
               song.page[cx][cy].semitone = notesInScale[(#notesInScale + 1) - cy]
            end
         end

         if (paintModesIndex == 2) then -- note chance
            local current = song.page[cx][cy].chance
            local index = indexOf(noteChances, current) or 1
            index = index + 1
            index = index % #noteChances
            song.page[cx][cy].chance = noteChances[index]
         end

         if (paintModesIndex == 3) then -- note repeats
            local current = song.page[cx][cy].noteRepeat
            local index = indexOf(noteRepeats, current) or 1
            index = (index % #noteRepeats) + 1
            song.page[cx][cy].noteRepeat = noteRepeats[index]
         end

         if (paintModesIndex == 4) then -- note pitch rnd
            local current = song.page[cx][cy].notePitchRandomizer
            local index = indexOf(notePitchRandoms, current) or 1
            index = (index % #notePitchRandoms) + 1
            song.page[cx][cy].notePitchRandomizer = notePitchRandoms[index]
         end

         if (paintModesIndex == 5) then -- note velocity
            local current = song.page[cx][cy].noteVelocity
            local index = indexOf(noteVelocities, current) or 1
            index = (index % #noteVelocities) + 1
            song.page[cx][cy].noteVelocity = noteVelocities[index]
         end

         audioHelper.sendMessageToAudioThread({ type = "pattern", data = song.page });
      end
   end


   local startVoicesAtY = h - bottommargin
   local startSpritesAtY = startVoicesAtY + voicesHeight + inbetweenmargin

   -- voices
   if y > startVoicesAtY and y < startSpritesAtY then
      if (x > leftmargin and x < w - rightmargin) then
         local d = audioHelper.voiceMax / horizontal
         local size = (cellWidth) / d
         local index = 1 + math.floor((x - leftmargin) / (size))
         if voices[index] then
            local sampleIndex = voices[index].voiceIndex
            local s = samples[sampleIndex].s:clone()

            love.audio.play(s)
         end
         drawingVoiceIndex = index
      end
   end

   -- samplebank
   if (y > startSpritesAtY) then
      if (x > leftmargin and x < w - rightmargin) then
         local d = numberOfSpritesInRow / horizontal
         local size = cellWidth / d
         local spritesInRow = numberOfSpritesInRow
         local rowNumber = math.floor((y - startSpritesAtY) / size)
         local index = 1 + math.floor((x - leftmargin) / (size)) +
             (rowNumber * spritesInRow)
         index = math.min(#sprites, index)
         octave = 0
         local s = samples[index].s:clone()
         love.audio.play(s)
         drawingValue = index



         if voices[drawingVoiceIndex] ~= nil then
            voices[drawingVoiceIndex].voiceIndex = index
         else
            voices[drawingVoiceIndex] = { voiceIndex = index, voiceTuning = 0, voiceVolume = 1 }
         end
         audioHelper.sendMessageToAudioThread({ type = "voices", data = voices });
         paintModesIndex = 1
      end
   end
end

function bool2str(bool)
   return bool and 'true' or 'false'
end

function makePatternFitOnscreen(song)
   local w, h = love.graphics.getDimensions()
   horizontal = #song.pages[1]
   vertical = #(song.scale.notes)

   topmargin = 48
   leftmargin = 30
   rightmargin = 30

   cellWidth = (w - leftmargin - rightmargin) / horizontal
   cellHeight = cellWidth / 1.5
   voicesHeight = cellHeight

   pictureInnerMargin = 4

   bottommargin = h - (cellHeight * vertical) - topmargin
   inbetweenmargin = 10
end

function love.filedropped(file)
   local filename = file:getFilename()
   --print(love.filesystem.read(filename))
   if text.ends_with(filename, 'melodypaint.txt') then
      local result = audioHelper.loadMelodyPaintFile(file, samples)
      if result then
         song = result
         -- horizontal = #song.pages[1]
         makePatternFitOnscreen(song)
         song.page = song.pages[1]
         audioHelper.sendMessageToAudioThread({ type = 'song', data = song })
      else
         print('no success loading meolypaint file')
      end
   else
      print('i only load files ending in .melodypaint.txt')
   end
end

function love.draw()
   local voices = song.voices
   local w, h = love.graphics.getDimensions()
   ui.handleMouseClickStart()
   -- grid lines
   love.graphics.clear(palette[color])
   love.graphics.setColor(palette[color][1] - .1,
       palette[color][2] - .1,
       palette[color][3] - .1)

   for i = 1, horizontal / 8 do
      love.graphics.rectangle('fill',
          leftmargin + ((i - 1) * (cellWidth * 8)), topmargin,
          cellWidth * 4, cellHeight * vertical)
   end

   if (true) then
      love.graphics.setColor(palette[color][1] + .05,
          palette[color][2] + .05,
          palette[color][3] + .05)
      for y = 0, vertical do
         love.graphics.line(leftmargin, topmargin + y * cellHeight,
             w - rightmargin, topmargin + y * cellHeight)
      end

      for x = 0, horizontal do
         love.graphics.line(leftmargin + x * cellWidth, topmargin,
             leftmargin + x * cellWidth, h - bottommargin)
      end
   end

   love.graphics.setColor(1, 1, 1)

   -- note grid
   for x = 1, horizontal do
      for y = 1, vertical do
         local index = song.page[x][y].value

         if (index > 0 and voices[index]) then
            local voiceIndex = voices[index].voiceIndex
            if (sprites[voiceIndex]) then
               local scale, xo, yo = getScaleAndOffsetsForImage(sprites[voiceIndex], cellWidth - pictureInnerMargin,
                       cellHeight - pictureInnerMargin)

               love.graphics.draw(sprites[voiceIndex],
                   leftmargin + xo + cellWidth / 2 + (cellWidth * (x - 1)),
                   topmargin + yo + cellHeight / 2 + (cellHeight * (y - 1)),
                   0,
                   scale, scale)
            end
         end
         local myX = leftmargin + pictureInnerMargin + (cellWidth * (x - 1))
         local myY = topmargin + pictureInnerMargin + (cellHeight * (y - 1))
         local chance = song.page[x][y].chance
         if chance ~= nil then
            love.graphics.print(chance, myX, myY)
         end
         local noteRepeat = song.page[x][y].noteRepeat
         if noteRepeat and noteRepeat > 1 then
            love.graphics.print(noteRepeat, myX, myY)
         end
         local notePitchRandomizer = song.page[x][y].notePitchRandomizer
         if notePitchRandomizer and notePitchRandomizer > 0 then
            love.graphics.print(notePitchRandomizer, myX, myY)
         end
         local noteVelocity = song.page[x][y].noteVelocity
         if noteVelocity and noteVelocity > 0 then
            love.graphics.print(noteVelocity, myX, myY)
         end
      end
   end
   local startSpritesAtY = h - bottommargin + voicesHeight + inbetweenmargin

   -- voices
   for i = 1, audioHelper.voiceMax do
      local d = audioHelper.voiceMax / horizontal

      local size = (cellWidth) / d

      local x = leftmargin + (i - 1) * size
      local y = startSpritesAtY - voicesHeight - inbetweenmargin
      local cw = size
      local ch = voicesHeight
      love.graphics.rectangle('line', x, y, cw, ch)

      local scale, xo, yo = getScaleAndOffsetsForImage(sprites[1], cw - pictureInnerMargin,
              ch - pictureInnerMargin)

      if drawingVoiceIndex == i then
         love.graphics.setColor(palette[color][1] - .1,
             palette[color][2] - .1,
             palette[color][3] - .1)
         love.graphics.rectangle('fill', x, y, cw, ch)
      end
      love.graphics.setColor(1, 1, 1)
      if voices[i] ~= nil then
         local index = voices[i].voiceIndex
         if (sprites[index]) then
            love.graphics.draw(sprites[index], x + xo + cw / 2, y + yo + ch / 2, 0, scale, scale)
         end
      end
   end

   -- sample bank
   for i = 1, #sprites do
      local img = sprites[i]
      local d = numberOfSpritesInRow / horizontal
      local size = cellWidth / d
      local spritesInRow = numberOfSpritesInRow
      local x = leftmargin + ((i - 1) % spritesInRow) * size
      local y = startSpritesAtY + math.floor((i - 1) / spritesInRow) * size

      if (i == drawingValue) then
         love.graphics.setColor(palette[color][1] - .1,
             palette[color][2] - .1,
             palette[color][3] - .1)
         love.graphics.rectangle('fill',
             x, y,
             size, size)
      end
      if (voices[drawingVoiceIndex]) then
         if i == voices[drawingVoiceIndex].voiceIndex then
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle('fill',
                x, y,
                size, size)
         end
      end
      love.graphics.setColor(1, 1, 1)


      local sx, sy = createFittingScale(img, size, size)

      for j = 1, #spriteBackgroundMap do
         if text.starts_with(samples[i].p, spriteBackgroundMap[j].sw) then
            local bg = palette[spriteBackgroundMap[j].bg]

            love.graphics.setColor(bg[1], bg[2], bg[3], 0.5)
            love.graphics.rectangle('fill', x, y, size, size)
         end
      end
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(img, x, y, 0, sx, sx)
   end

   -- playhead
   if playing then
      love.graphics.draw(head, leftmargin + (playhead * cellWidth), 0, 0, .5, .5)
   end


   -- top bar
   if labelbutton('chance', paintModes[paintModesIndex], w - 100 - 20, 00, 100, 20).clicked then
      paintModesIndex = (paintModesIndex % #paintModes) + 1
   end

   if labelbutton('scale', song.scale.name, w - 200 - 20, 00, 100, 20).clicked then
      song.scale = audioHelper.getNextScale(song.scale)
      makePatternFitOnscreen(song)
      audioHelper.sendMessageToAudioThread({ type = "scale", data = song.scale.notes })
   end

   if newImageButton(save, w - 20, 0, .2, .2).clicked then
      audioHelper.saveMelodyPaintFile(song)
   end

   -- on screen text
   love.graphics.print(
       'bpm: ' ..
       song.bpm .. ', octave: ' .. octave .. ', tuning: ' .. song.tuning .. ', swing: ' .. song.swing .. ', paused: ' ..
       bool2str(paused), 0, 0)
end
