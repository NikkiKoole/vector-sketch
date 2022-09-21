local parallax = {}

parallax.sortOnDepth = function(list)
   table.sort( list, function(a,b) return a.depth <  b.depth end)
end


return parallax
