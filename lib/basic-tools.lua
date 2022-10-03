local reset = "\x1B[m\x1B[K"
local fg_codes = {
   black = "\x1b[30m",
   white = "\x1b[37m",
   red = "\x1B[31m",
   green = "\x1B[32m",
   yellow = "\x1b[33m",
   blue = "\x1b[34m",
   magenta = "\x1b[35m",
   cyan = "\x1b[36m"
}

local bg_codes = {
   black = "\x1b[40m",
   red = "\x1b[41m",
   green = "\x1b[42m",
   yellow = "\x1b[43m",
   blue = "\x1b[44m",
   magenta = "\x1b[45m",
   cyan = "\x1b[46m",
   white = "\x1b[47m",
}
function printC(c, ...)

   if c.fg then
      io.write(fg_codes[c.fg])
   end
   if c.bg then
      io.write(bg_codes[c.bg])
   end

   print(...)
   io.write(reset)
end

local base = '/Users/nikkikoole/Projects/vector-sketch'
local function mountZip(filename, mountpoint)
   --print(filename) 
   local f = io.open(filename, 'r')
   if f then
      local filedata = love.filesystem.newFileData(f:read("*all"), filename)
      f:close()
      local result = love.filesystem.mount(filedata, mountpoint or 'zip')
      --print(inspect(result))
      return result
   else
      printC({fg = 'black', bg = 'red' }, "could not load resources file :"..filename)
   end
end

mountZip(base .. '/resources.zip', '')

-- you need require console. before the rpint overwrite below
console = require 'vendor.console'

local TESTING__ = true
if TESTING__ then
   local old_print = print
   print = function(...)
      local info = debug.getinfo(2, "Sl")
      local source = info.source
      if source:sub(-4) == ".lua" then source = source:sub(1, -5) end
      if source:sub(1, 1) == "@" then source = source:sub(2) end
      local msg = ("%s:%i"):format(source, info.currentline)
      old_print(msg, ...)
   end
else
   print = function() end
end



if os.setlocale(nil) ~= 'C' then
   printC({ fg = 'black', bg = 'yellow' }, 'wrong locale:', os.setlocale(nil))
   os.setlocale("C")
else
   printC({ fg = 'black', bg = 'yellow' }, 'good locale!')
end
