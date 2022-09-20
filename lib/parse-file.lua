local parse = {}


parse.parseFile = function(url)
   local contents, size = love.filesystem.read( url)
   if contents == nil then
      print(printC({fg='red'}, "file not found: ", url))
   end

   local parsed = (loadstring("return ".. contents)())

   local figuredItOut = false
   if (#parsed == 1 and parsed[1].folder) then
      parsed[1].origin = {path=url, index=-1}
      figuredItOut = true
   end
   if #parsed > 1 then
      -- first check if all descendants are folders
      local allAreFolders = true
      for i =1, #parsed do
         if (not parsed[i].folder) then
            allAreFolders = false
         end
      end
      if (allAreFolders) then
         for i =1, #parsed do
            parsed[i].origin = {path=url, index=i}
         end
         figuredItOut = true
      end
   end
   if (not figuredItOut) then
      print('I dont know what type of origin url to put in here', url)
   end
   return parsed
end


return parse
