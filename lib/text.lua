local text = {}

text.starts_with = function(str, start)
   return str:sub(1, #start) == start
end


text.ends_with = function(str, ending)
   return ending == "" or str:sub(- #ending) == ending
end

text.split = function(str, pos)
   local offset = utf8.offset(str, pos) or 0
   return str:sub(1, offset - 1), str:sub(offset)
end

text.stringFindLastSlash = function(str)
   --return str:match'^.*()'..char
   local index = string.find(str, "/[^/]*$")
   if index == nil then -- windows ? i dunno?
      index = string.find(str, "\\[^\\]*$")
   end
   return index
   --index = string.find(your_string, "/[^/]*$")
end

local function stringSplit(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
      table.insert(result, each)
   end
   return result
end

return text
