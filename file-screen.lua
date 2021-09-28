local function getFiles(rootPath, tree)
   tree = tree or {}
   local lfs = love.filesystem
   local filesTable = lfs.getDirectoryItems(rootPath)
   for i,v in ipairs(filesTable) do
         local path = rootPath.."/"..v
         if lfs.isFile(path) then
            tree[#tree+1] = path
         elseif lfs.isDirectory(path) then
            fileTree = getFiles(path, tree)
         end
      end
   return tree
end


local function getPolygonFiles(rootPath, tree)
   tree = tree or {}
   local lfs = love.filesystem
   local filesTable = lfs.getDirectoryItems(rootPath)
   for i,v in ipairs(filesTable) do
      local path = rootPath.."/"..v
      local file = lfs.getInfo(path)
      if file.type == 'file' and
	 ends_with(path, 'polygons.txt') then
	 local pngPath = path:gsub('polygons.txt', 'polygons.png')
	 local png = love.filesystem.getInfo(pngPath)

	 if file and png then
	    tree[#tree+1] = {path=string.sub(path, 2),       txt=file,
			     pngPath=string.sub(pngPath, 2), png=png, img= love.graphics.newImage(string.sub(pngPath, 2)) }
	 end
      elseif file.type == 'directory'  then
	 fileTree = getPolygonFiles(path, tree)
      end

   end
   return tree
end


function gatherData(path)
   return getPolygonFiles(path)
   --recursiveReadPolygonFiles('', )

end

function recursiveReadPolygonFiles(path, tree)
   for i =1, #tree do
      print(tree[i].path:sub(1,-14))
   end


end
