function parseFile(url)
   local contents, size = love.filesystem.read( url)
   local parsed = (loadstring("return ".. contents)())
   return parsed
end
