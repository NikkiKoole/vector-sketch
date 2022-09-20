local text = {}

text.starts_with= function(str, start)
   return str:sub(1, #start) == start
end


text.ends_with= function(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

text.split = function(str, pos)
   local offset = utf8.offset(str, pos) or 0
   return str:sub(1, offset-1), str:sub(offset)
end


return text
