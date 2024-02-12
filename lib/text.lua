local text = {}


text.replace = function(str, find, replace)
   local index = string.find(str, find)
   local result = nil
   if index ~= nil then
      local newString = str:sub(1, index - 1) .. replace
      result = newString
   end
   return result
end
text.starts_with = function(str, start)
   return str:sub(1, #start) == start
end


text.ends_with = function(str, ending)
   return ending == "" or str:sub( -#ending) == ending
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


text.countLines = function(str)
   local _, count = str:gsub('\n', '\n')
   return count + 1 -- Add 1 to account for the last line without a newline
end


text.stringSplit = function(str, sep)
   local result = {}
   local regex = ("([^%s]+)"):format(sep)
   for each in str:gmatch(regex) do
      table.insert(result, each)
   end
   return result
end

return text
