local lib                     = {}

local scales                  = {
    { name = 'koalaMinor',   notes = { 0, 2, 3, 5, 7, 8, 11 } },
    { name = 'koalaHexa',    notes = { 0, 3, 4, 7, 8, 11 } },
    { name = 'minorBlues',   notes = { 0, 3, 5, 6, 7, 10, 11 } },
    { name = 'naturalMinor', notes = { 0, 2, 3, 5, 7, 8, 10, 11 } },
    { name = 'whole',        notes = { 0, 2, 4, 6, 8, 10 } },
    { name = 'bebop',        notes = { 0, 2, 4, 5, 7, 9, 10, 11 } },
    { name = 'soundforest',  notes = { 0, 2, 5, 9, 11, 16 } },
    { name = 'koalaPenta',   notes = { 0, 3, 5, 7, 10, 11 } },
    { name = 'chromatic',    notes = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } },
    { name = 'pentaMinor ',  notes = { 0, 2, 3, 4, 6 } },
    { name = 'gypsy',        notes = { 0, 2, 3, 6, 7, 8, 10 } },
    { name = 'dorian',       notes = { 0, 2, 3, 5, 7, 9, 10 } },
    { name = 'augmented',    notes = { 0, 3, 4, 7, 8, 11 } },
    { name = 'tritone',      notes = { 0, 1, 4, 6, 7, 10 } },
    { name = 'soundforest2', notes = { 0 - 12, 2 - 12, 5 - 12, 9 - 12, 0, 2, 5, 9, 11, 13, 16 } },
    -- { name = 'debug',        notes = { 0, 11, 23, 35, 47 } },
}

lib.defaultBpm                = 90
lib.defaultSwing              = 50
lib.defaultTuning             = 0
lib.voiceMax                  = 16

local _thread
local channel                 = {};
channel.audio2main            = love.thread.getChannel("audio2main")
channel.main2audio            = love.thread.getChannel("main2audio")

lib.getMessageFromAudioThread = function()
   local v = channel.audio2main:pop();

   local error = _thread:getError()
   assert(not error, error)
   return v
end
lib.sendMessageToAudioThread  = function(msg)
   channel.main2audio:push(msg)
end

lib.startAudioThread          = function()
   -- this tries to be 'smart' about loading the thread code..
   function getFileContents(path)
      print(path, '../..' .. path)
      local f = io.open(path, "rb") or io.open('../../' .. path, "rb")
      local content
      if f then
         --assert(f)
         content = f:read("*all")
         f:close()
      end

      return content
   end

   local os = love.system.getOS()
   --print(os)
   if os == 'iOS' or os == 'Android' then
      _thread = love.thread.newThread('audio.lua')
      _thread:start()
   else
      local code = getFileContents('lib/audio.lua')
      _thread = love.thread.newThread(code or 'audio.lua')
      _thread:start()
   end

   --
end


lib.findScaleByName = function(name)
   for i = 1, #scales do
      if scales[i].name == name then
         return scales[i], i
      end
   end
   return nil, -1
end

lib.getNextScale    = function(current)
   local name, index = lib.findScaleByName(current.name)
   local nextIndex = (index % #scales) + 1
   return scales[nextIndex]
end

lib.initPage        = function(horizontal, vertical)
   local result = {}
   for x = 1, horizontal do
      local row = {}
      for y = 1, vertical do
         table.insert(row, { value = 0 })
      end
      table.insert(result, row)
   end
   return result
end

local function optimizePage(p)
   local r = lib.initPage(#p, #p[1])
   for x = 1, #p do
      for y = 1, #p[x] do
         if p[x][y].value > 0 then
            r[x][y] = p[x][y]
         else
            r[x][y] = 0
         end
      end
   end
   return r
end

local function filloutOptimizedPage(p)
   local r = lib.initPage(#p, #p[1])
   for x = 1, #p do
      for y = 1, #p[x] do
         if p[x][y] ~= 0 and p[x][y].value > 0 then
            r[x][y] = p[x][y]
         else
            --r[x][y] = 0
         end
      end
   end
   return r
end

local function filloutOptimizedPages(pages)
   local result = {}
   for i = 1, #pages do
      result[i] = filloutOptimizedPage(pages[i])
   end
   return result
end

local function optimizeAllPages(pages)
   local result = {}
   for i = 1, #pages do
      result[i] = optimizePage(pages[i])
   end
   return result
end





lib.initSong = function(horizontal)
   local voices = {}
   for i = 1, lib.voiceMax do
      voices[i] = nil
   end
   local result = {
       voices = voices,
       bpm = lib.defaultBpm,
       tuning = lib.defaultTuning,
       swing = lib.defaultSwing,
       pages = { lib.initPage(horizontal, 12) },
       scale = lib.findScaleByName('chromatic')
   }
   return result
end

lib.saveMelodyPaintFile = function(song)
   local str = os.date("%Y%m%d%H%M")
   local path = str .. '.melodypaint.txt'
   local indexToSamplePath = {}

   for i = 1, #song.voices do
      if song.voices[i] then
         indexToSamplePath[i] = {
             index = song.voices[i].voiceIndex,
             path = samples[song.voices[i].voiceIndex].p,
         }
      end
   end

   local data = {
       index = indexToSamplePath,
       voices = song.voices,
       pages = optimizeAllPages(song.pages),
       tuning = song.tuning,
       swing = song.swing,
       bpm = song.bpm
   }

   love.filesystem.write(path, inspect(data, { indent = "" }))
   local openURL = "file://" .. love.filesystem.getSaveDirectory()
   love.system.openURL(openURL)
end

local function removeBrokenSampleFromAllPages(sampleIdx, pages)
   for pi = 1, #pages do
      for x = 1, #pages[pi] do
         for y = 1, #pages[pi][x] do
            --print(pi, x, y)
            if (pages[pi][x][y].value == sampleIdx) then
               pages[pi][x][y] = { value = 0 }
            end
         end
      end
   end
   return pages
end




lib.loadMelodyPaintTab = function(tab, samples)
   local result = {}

   result.pages = filloutOptimizedPages(tab.pages)
   result.voices = tab.voices

   for i = 1, #tab.index do
      local idx = tab.index[i].index
      -- bcause i can add and remove and reorder samples at will from the program.
      -- I need a way to find the correct index again
      -- this path should be the same as the sample at index
      local path = tab.index[i].path
      print(path)
      if (not samples[idx] or samples[idx].p ~= path) then
         local foundAlternative = false
         -- we have to find the new index this sample lives at
         for si = 1, #samples do
            if samples[si].p == path then
               local newIndex = si
               result.voices[i].voiceIndex = si

               foundAlternative = true
            end
         end
         -- because we could be missing the sample alltogether, I need a way to just not use that sample in this song anymore..
         if foundAlternative == false then
            print('missing sample: ', path)
            result.voices[i] = nil

            removeBrokenSampleFromAllPages(i, result.pages)
         end
      end
   end


   result.bpm = tab.bpm or lib.defaultBpm
   result.tuning = tab.tuning or lib.defaultTuning
   result.swing = tab.swing or lib.defaultSwing
   result.scale = tab.scale or lib.findScaleByName('chromatic')
   return result
end

lib.loadMelodyPaintFile = function(file, samples)
   -- this assumes this file exists and is of the right type
   file:open("r")
   local data = file:read()
   local tab = (loadstring("return " .. data)())
   return lib.loadMelodyPaintTab(tab, samples)
end

return lib
