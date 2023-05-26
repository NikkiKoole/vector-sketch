package.path = package.path .. ";../../?.lua"


require 'palette'
inspect = require "inspect"

local ui = require 'lib.ui'

function love.keypressed(key)
   if key == "escape" then
      love.event.quit()
   end
   if key == "left" then
      bpm = bpm - 10
      bpm = math.max(10, bpm)
      channel.main2audio:push({ type = "bpm", data = bpm });
   end
   if key == "right" then
      bpm = bpm + 10
      bpm = math.min(300, bpm)
      channel.main2audio:push({ type = "bpm", data = bpm });
   end
   if key == "up" then
      octave = octave + 1
      octave = math.min(5, octave)
   end
   if key == "down" then
      octave = octave - 1
      octave = math.max( -5, octave)
   end
   if key == "z" then
      tuning = tuning - 1
      channel.main2audio:push({ type = "tuning", data = tuning });
   end
   if key == "x" then
      tuning = tuning + 1
      channel.main2audio:push({ type = "tuning", data = tuning });
   end
   if key == "c" then
      swing = swing - 1
      if swing < 50 then swing = 50 end
      channel.main2audio:push({ type = "swing", data = swing });
   end
   if key == "v" then
      swing = swing + 1
      if swing > 75 then swing = 75 end
      channel.main2audio:push({ type = "swing", data = swing });
   end
   if key == "space" then
      paused = not paused

      channel.main2audio:push({ type = "paused", data = paused });
   end
   if key == "1" then
      page = page1
      channel.main2audio:push({ type = "pattern", data = page });
   end
   if key == "2" then
      page = page2
      channel.main2audio:push({ type = "pattern", data = page });
   end
end



function findScaleByName(name)
   for i = 1, #scales do
      if scales[i].name == name then
         return scales[i], i
      end
   end
   return nil, -1
end


function love.load()
   bpm = 90
   octave = 0
   tuning = 0
   paused = false
   swing = 50
   thread = love.thread.newThread('audio.lua')
   thread:start()
   channel            = {};
   channel.audio2main = love.thread.getChannel("audio2main")
   channel.main2audio = love.thread.getChannel("main2audio")

   playing            = true
   playhead           = 0

   screenWidth        = 1024
   screenHeight       = 768
   --love.window.setMode(screenWidth, screenHeight)




   scales = {
      {name='minorBlues' , notes={ 0, 3, 5, 6, 7, 10, 12 }},
      {name='whole' , notes={	0,2,4,6,8,10}},
      {name='bebop' , notes={ 	0,2,4,5,7,9,10,11 }},
      {name='soundforest', notes={ 0, 2, 5, 9, 12, 16 }},
      {name='naturalMinor' , notes={ 0, 2, 3, 5, 7, 8, 10, 12 }},
      {name='koalaMinor' , notes= { 0, 2, 3, 5, 7, 8, 11, 12 }},
      {name='koalaPenta' , notes= { 0, 3, 5, 7, 10, 12 }},
      {name='koalaHexa' , notes={ 0, 3, 4, 7, 8, 11, 12 }},
      {name='koalaChroma' , notes={ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }},
      {name='pentaMinor ' , notes={ 0, 2, 3, 4, 6}},
      {name='gypsy', notes={0,2,3,6,7,8,10}},
      {name='dorian', notes={0,2,3,5,7,9,10}},
      {name='augmented', notes={0,3,4,7,8,11}},
      {name='tritone', notes={0,1,4,6,7,10}},
      {name='debug', notes={0,11,23,35,47}},
   }

   
   scale = findScaleByName('koalaChroma') 
   notesInScale = scale.notes
 

   vertical = #notesInScale
   horizontal = 16

   leftmargin = 30
   rightmargin = 30

   cellHeight = 48
   cellWidth = (screenWidth - leftmargin - rightmargin) / horizontal

   bitmapSize = 100

   pictureInnerMargin = 4

   pictureTopMargin = pictureInnerMargin / 2
   pictureInCellScale = (math.min(cellHeight, cellWidth) - pictureInnerMargin) / bitmapSize
   pictureLeftMargin = 6

   topmargin = 48
   bottommargin = screenHeight - (cellHeight * vertical) - topmargin
   inbetweenmargin = 10
   pictureInBottomScale = .6

   head = love.graphics.newImage('resources/theo.png')
   color = colors.dark_green
   drawingValue = 1

   page1 = initPage()
   page2 = initPage()
   page1[1][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page1[5][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page1[9][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page1[13][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }

   page2[1][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page2[5][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page2[9][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page2[13][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }


   page = page1

   page[1][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page[5][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page[9][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }
   page[13][1] = { value = 1, octave = 0, semitone = notesInScale[(#notesInScale + 1) - 1] }


   paintModes = { 'note on/off', 'note chance', 'note repeat', 'note pitch rnd', 'velocity' }
   paintModesIndex = 1

   noteChances = { 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0 }

   noteRepeats = { 1, 2, 3, 4 }
   -- noteRepeatIndex = 4

   notePitchRandoms = { 0, 1, 2 }
   noteVelocities = { 0, 0.2, 0.4, 0.6, 0.8, 1.0 }

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

   local cr78 = {
       { 'lemur',       'cr78/Tamb 1' },
       { 'sheep',       'cr78/Rim Shot' },
       { 'panther',     'cr78/Bongo High' },
       { 'kiwi',        'cr78/Bongo Low' },
       { 'hummingbird', 'cr78/Conga Low' },
       { 'beetle',      'cr78/Guiro 1' },
       { 'cow',         'cr78/Cowbell' },
       { 'scorpion',    'cr78/HiHat Metal' }
   }

   local sample_data = {
       { 'zebra',       'mipo/mi' },
       { 'octopus',     'mipo/po' },
       { 'goldfish',    'mipo/pi' },
       { 'bat',         'mipo/mo' },
       { 'goldfish',    'mipo/mi2' },
       { 'bat',         'mipo/po2' },
       { 'goldfish',    'mipo/mi3' },
       { 'bat',         'mipo/po3' },
       { 'polar',       'guirojuno/1' },
       { 'porcupine',   'guirojuno/2' },
       { 'walrus',      'guirojuno/3' },
       { 'sea',         'guirojuno/11' },
       { 'toucan',      'guirojuno/21' },
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
       { 'cow',         'cr78/Cowbell' },
       { 'scorpion',    'cr78/HiHat Metal' },
       { 'scorpion',    'cr78/Cymbal' },
       { 'scorpion',    'cr78/Snare' },
       { 'gorilla',     'macdm/bassmac1' },
       { 'rhinoceros',  'macdm/bassmac2' },
       { 'hamster',     'guirojuno/rijstei' },

   }


   sprites = {}
   samples = {}
   for i = 1, #sample_data do
      table.insert(sprites, love.graphics.newImage('resources/' .. sample_data[i][1] .. '.png'))

      local data = love.sound.newSoundData('instruments/' .. sample_data[i][2] .. '.wav')
      table.insert(samples, love.audio.newSource(data, 'static'))
   end

   channel.main2audio:push({ type = "samples", data = samples });
   channel.main2audio:push({ type = "bpm", data = bpm });
   channel.main2audio:push({ type = "scale", data = notesInScale })
   channel.main2audio:push({ type = "tuning", data = tuning })
   channel.main2audio:push({ type = "swing", data = swing })
   channel.main2audio:push({ type = "pattern", data = page });
end

function love.update(dt)
   local v = channel.audio2main:pop();
   if v then
      if (v.type == 'playhead') then
         playhead = v.data % horizontal
      end
   end
   local error = thread:getError()
   assert(not error, error)
end

function indexOf(array, value)
   for i, v in ipairs(array) do
      if v == value then
         return i
      end
   end
   return nil
end

function initPage()
   local result = {}
   for x = 1, horizontal do
      local row = {}
      for y = 1, vertical do
         table.insert(row, { x = x, y = y, value = 0 })
      end
      table.insert(result, row)
   end
   return result
end

function love.mousepressed(x, y, button)
   if (x > leftmargin and x < screenWidth - rightmargin) then
      if (y > topmargin and y < screenHeight - bottommargin) then
         local cx = 1 + math.floor((x - leftmargin) / cellWidth)
         local cy = 1 + math.floor((y - topmargin) / cellHeight)
         if (paintModesIndex == 1) then -- note on off
            page[cx][cy].value = (page[cx][cy].value > 0) and 0 or drawingValue
            page[cx][cy].octave = octave
            page[cx][cy].semitone = notesInScale[(#notesInScale + 1) - cy]
         end

         if (paintModesIndex == 2) then -- note chance
            local current = page[cx][cy].chance
            local index = indexOf(noteChances, current) or 1
            index = index + 1
            index = index % #noteChances


            page[cx][cy].chance = noteChances[index]
         end
         if (paintModesIndex == 3) then -- note repeats
            local current = page[cx][cy].noteRepeat
            local index = indexOf(noteRepeats, current) or 1
            index = (index % #noteRepeats) + 1
            page[cx][cy].noteRepeat = noteRepeats[index]
         end
         if (paintModesIndex == 4) then -- note pitch rnd
            local current = page[cx][cy].notePitchRandomizer
            local index = indexOf(notePitchRandoms, current) or 1
            index = (index % #notePitchRandoms) + 1
            page[cx][cy].notePitchRandomizer = notePitchRandoms[index]
         end
         if (paintModesIndex == 5) then -- note velocity
            local current = page[cx][cy].noteVelocity
            local index = indexOf(noteVelocities, current) or 1
            index = (index % #noteVelocities) + 1
            page[cx][cy].noteVelocity = noteVelocities[index]
         end

         channel.main2audio:push({ type = "pattern", data = page });
      end
   end

   if (y > screenHeight - bottommargin + inbetweenmargin) then
      if (x > leftmargin and x < screenWidth - rightmargin) then
         --local x = leftmargin + ((i - 1) % 16) * size
         --local y = screenHeight - bottommargin + inbetweenmargin + math.floor((i - 1) / 16) * size
         local size = pictureInBottomScale * bitmapSize
         local rowNumber = math.floor((y - (screenHeight - bottommargin + inbetweenmargin)) / size)


         local index = 1 + math.floor((x - leftmargin) / (bitmapSize * pictureInBottomScale)) + (rowNumber * 16)
         index = math.min(#sprites, index)
         octave = 0
         local s = samples[index]:clone()
         love.audio.play(s)
         drawingValue = index
         paintModesIndex = 1
      end
   end
end

function bool2str(bool)
   return bool and 'true' or 'false'
end

function love.draw()
   local w, h = love.graphics.getDimensions()
   ui.handleMouseClickStart()
   love.graphics.clear(palette[color])
   love.graphics.setColor(palette[color][1] - .1,
       palette[color][2] - .1,
       palette[color][3] - .1)
   love.graphics.rectangle('fill',
       leftmargin, topmargin,
       cellWidth * 4, cellHeight * vertical)
   love.graphics.rectangle('fill',
       leftmargin + cellWidth * 8,
       topmargin, cellWidth * 4, cellHeight * vertical)

   if (true) then
      love.graphics.setColor(palette[color][1] + .05,
          palette[color][2] + .05,
          palette[color][3] + .05)
      for y = 0, vertical do
         love.graphics.line(leftmargin, topmargin + y * cellHeight,
             screenWidth - rightmargin, topmargin + y * cellHeight)
      end

      for x = 0, horizontal do
         love.graphics.line(leftmargin + x * cellWidth, topmargin,
             leftmargin + x * cellWidth, screenHeight - bottommargin)
      end
   end

   love.graphics.setColor(1, 1, 1)

   for x = 1, horizontal do
      for y = 1, vertical do
         local index = page[x][y].value
         if (index > 0) then
            love.graphics.draw(sprites[index],
                leftmargin + pictureLeftMargin + (cellWidth * (x - 1)),
                topmargin + pictureTopMargin + (cellHeight * (y - 1)),
                0,
                pictureInCellScale, pictureInCellScale)
         end
         local chance = page[x][y].chance
         if chance ~= nil then
            love.graphics.print(chance,
                leftmargin + pictureLeftMargin + (cellWidth * (x - 1)),
                topmargin + pictureTopMargin + (cellHeight * (y - 1)))
         end
         local noteRepeat = page[x][y].noteRepeat
         if noteRepeat and noteRepeat > 1 then
            love.graphics.print(noteRepeat,
                leftmargin + pictureLeftMargin + (cellWidth * (x - 1)),
                topmargin + pictureTopMargin + (cellHeight * (y - 1)))
         end
         local notePitchRandomizer = page[x][y].notePitchRandomizer
         if notePitchRandomizer and notePitchRandomizer > 0 then
            love.graphics.print(notePitchRandomizer,
                leftmargin + pictureLeftMargin + (cellWidth * (x - 1)),
                topmargin + pictureTopMargin + (cellHeight * (y - 1)))
         end
         local noteVelocity = page[x][y].noteVelocity
         if noteVelocity and noteVelocity > 0 then
            love.graphics.print(noteVelocity,
                leftmargin + pictureLeftMargin + (cellWidth * (x - 1)),
                topmargin + pictureTopMargin + (cellHeight * (y - 1)))
         end
      end
   end

   for i = 1, #sprites do
      local img = sprites[i]
      local size = pictureInBottomScale * bitmapSize
      local x = leftmargin + ((i - 1) % 16) * size
      local y = screenHeight - bottommargin + inbetweenmargin + math.floor((i - 1) / 16) * size

      if (i == drawingValue) then
         love.graphics.setColor(palette[color][1] - .1,
             palette[color][2] - .1,
             palette[color][3] - .1)
         love.graphics.rectangle('fill',
             x, y,
             size, size)
      end
      love.graphics.setColor(1, 1, 1)


      love.graphics.draw(img,
          x, y, 0,
          pictureInBottomScale, pictureInBottomScale)
   end

   if playing then
      love.graphics.draw(head, leftmargin + (playhead * cellWidth), 0, 0, .5, .5)
   end



   if labelbutton('chance', paintModes[paintModesIndex], w - 100, 00, 100, 20).clicked then
      paintModesIndex = (paintModesIndex % #paintModes) + 1
   end

   if labelbutton('scale', scale.name, w - 200, 00, 100, 20).clicked then
      local name, index = findScaleByName(scale.name)

      local newIndex = (index % #scales) + 1
      
      scale = scales[newIndex]
      notesInScale = scale.notes

       vertical = #notesInScale
       bottommargin = screenHeight - (cellHeight * vertical) - topmargin
      channel.main2audio:push({ type = "scale", data = notesInScale })
      --paintModesIndex = (paintModesIndex % #paintModes) + 1
   end


   love.graphics.print(
       'bpm: ' ..
       bpm .. ', octave: ' .. octave .. ', tuning: ' .. tuning .. ', swing: ' .. swing .. ', paused: ' ..
       bool2str(paused), 0, 0)
end
