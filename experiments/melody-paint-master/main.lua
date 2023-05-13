require 'palette'
inspect = require "inspect"

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
end

function love.load()
   bpm = 90
   octave = 0
   tuning = 0
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


   local minorBlues = { 0, 3, 5, 6, 7, 10, 12 }
   local soundforest = { 0, 2, 5, 9, 12, 16 }
   local naturalMinor = { 0, 2, 3, 5, 7, 8, 10, 12 }
   local koalaMinor = { 0, 2, 3, 5, 7, 8, 11, 12 }
   local koalaPenta = { 0, 3, 5, 7, 10, 12 }
   local koalaHexa = { 0, 3, 4, 7, 8, 11, 12 }
   local koalaChroma = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
   scale = koalaHexa --soundforest --minorBlues



   vertical = #scale
   horizontal = 16

   leftmargin = 30
   rightmargin = 30

   cellHeight = 48
   cellWidth = (screenWidth - leftmargin - rightmargin) / horizontal

   bitmapSize = 100

   pictureInnerMargin = 4

   pictureTopMargin = pictureInnerMargin / 2
   pictureInCellScale = (cellHeight - pictureInnerMargin) / bitmapSize
   pictureLeftMargin = 6

   topmargin = 48
   bottommargin = screenHeight - (cellHeight * vertical) - topmargin
   inbetweenmargin = 10
   pictureInBottomScale = .6

   head = love.graphics.newImage('resources/herman.png')
   color = colors.dark_green
   drawingValue = 1
   page = initPage()




   local sample_data = {
       { 'clam',       'babirhodes/ba' },
       { 'owl',        'babirhodes/bi' },
       { 'panda-bear', 'babirhodes/rhodes' },
       --{'clam', 'tpl-dnb/bongos'},
       -- {'clam', 'synth11'},
       -- {'owl', 'tpl-dnb/clap'},
       --  {'panda-bear', 'tpl-dnb/crash'},
       { 'antelope',   'tpl-dnb/drum' },
       { 'flamingo',   'tpl-dnb/hihat' },
       { 'fox',        'tpl-dnb/hihat-open' },
       { 'bee',        'tpl-dnb/kick_01' },
       { 'crab',       'tpl-dnb/kick_02' },
       { 'elephant',   'tpl-dnb/snare_01' },
       { 'crocodile',  'tpl-dnb/snare_02' },
       { 'kangaroo',   'cr78/HiHat Metal' },
       { 'pig',        'cr78/Conga Low' },
       { 'starfish',   'sf1-015' },
       { 'snake',      'cr78/Bongo High' },
       { 'snake2',     'cr78/Guiro 1' }
   }

   -- local sample_data = {
   --    {'clam', 'marimba'},
   --    {'owl', 'bd'},
   --    {'panda-bear', 'cb'},
   --    {'antelope', 'hihat-metal'},
   --    {'flamingo', 'analog3c'},
   --    {'fox', 'brass5c'},
   --    {'bee', 'epiano2-1c'},
   --    {'crab', 'prophet1c'},
   --    {'elephant', 'guiro'},
   --    {'crocodile', 'BASS-BigFM'},
   --    {'kangaroo', 'EPIANO-LomarzOneNote'},
   --    {'pig', 'BASS-1VCOacidic2'},
   --    {'starfish', 'CHORD-4OSCSofttone'},
   --    {'snake', 'mallet-c2'},
   --    {'snake2', 'mallet-c4'},
   --    {'badger', 'glockensp-c4'}
   -- }
   sprites = {}
   samples = {}
   for i = 1, #sample_data do
      table.insert(sprites, love.graphics.newImage('resources/' .. sample_data[i][1] .. '.png'))
      local data = love.sound.newSoundData('instruments/' .. sample_data[i][2] .. '.wav')
      table.insert(samples, love.audio.newSource(data, 'static'))
   end

   channel.main2audio:push({ type = "samples", data = samples });
   channel.main2audio:push({ type = "bpm", data = bpm });
   channel.main2audio:push({ type = "scale", data = scale })
   channel.main2audio:push({ type = "tuning", data = tuning })
   channel.main2audio:push({ type = "swing", data = swing })
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

function love.mousepressed(x, y)
   if (x > leftmargin and x < screenWidth - rightmargin) then
      if (y > topmargin and y < screenHeight - bottommargin) then
         local cx = 1 + math.floor((x - leftmargin) / cellWidth)
         local cy = 1 + math.floor((y - topmargin) / cellHeight)
         page[cx][cy].value = (page[cx][cy].value > 0) and 0 or drawingValue
         page[cx][cy].octave = octave
         channel.main2audio:push({ type = "pattern", data = page });
      end
   end

   if (y > screenHeight - bottommargin + inbetweenmargin) then
      if (x > leftmargin and x < screenWidth - rightmargin) then
         local index = 1 + math.floor((x - leftmargin) / (bitmapSize * pictureInBottomScale))
         index = math.min(#sprites, index)
         octave = 0
         local s = samples[index]:clone()
         love.audio.play(s)
         drawingValue = index
      end
   end
end

function love.draw()
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
      end
   end

   for i = 1, #sprites do
      local img = sprites[i]
      local size = pictureInBottomScale * bitmapSize
      if (i == drawingValue) then
         love.graphics.setColor(palette[color][1] - .1,
             palette[color][2] - .1,
             palette[color][3] - .1)
         love.graphics.rectangle('fill',
             leftmargin + size * (i - 1), screenHeight - bottommargin + inbetweenmargin,
             size, size)
      end
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(img,
          leftmargin + size * (i - 1), screenHeight - bottommargin + inbetweenmargin, 0,
          pictureInBottomScale, pictureInBottomScale)
   end

   if playing then
      love.graphics.draw(head, leftmargin + (playhead * cellWidth), 0, 0, .5, .5)
   end
   love.graphics.print('bpm: ' .. bpm .. ', octave: ' .. octave .. ', tuning: ' .. tuning .. ', swing: ' .. swing, 0, 0)
end
