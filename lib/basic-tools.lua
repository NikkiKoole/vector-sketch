function require_all(path, opts)
   local items = love.filesystem.getDirectoryItems(path)
   for _, item in pairs(items) do
      if love.filesystem.getInfo(path .. '/' .. item, 'file') then
         require(path .. '/' .. item:gsub('.lua', ''))
      end
   end
   if opts and opts.recursive then
      for _, item in pairs(items) do
         if love.filesystem.getInfo(path .. '/' .. item, 'directory') then
            require_all(path .. '/' .. item, { recursive = true })
         end
      end
   end
end

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

if os.setlocale(nil) ~= 'C' then
   printC({ fg = 'black', bg = 'yellow' }, 'wrong locale:', os.setlocale(nil))
   os.setlocale("C")
end
