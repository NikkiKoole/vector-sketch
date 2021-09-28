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
         if lfs.getInfo(path).type == 'file' and
            ends_with(path, 'polygons.txt') then
            local pngPath = path:gsub('polygons.txt', 'polygons.png')
            local png = love.filesystem.getInfo(pngPath)
            --print(pngPath, png)

            tree[#tree+1] = {path=path, png=png, txt=lfs.getInfo(path)}
         elseif lfs.getInfo(path).type == 'directory' and ends_with(path, 'polygons.folder') then
            fileTree = getPolygonFiles(path, tree)
         else
            --print(path)
         end
         
      end
   return tree
end


function gatherData(path)
   
   local polygonFiles = {}

   local files = love.filesystem.getDirectoryItems(path)
   for _, file in ipairs(files) do
      local f = love.filesystem.getInfo(file)
      --print(file)
      if ends_with(file, 'polygons.txt') then
         local pngPath = file:gsub('polygons.txt', 'polygons.png')
         local png = love.filesystem.getInfo(pngPath)
         local txt = f
         if png then
            table.insert(polygonFiles, {png=png, txt=txt})
         end
      end
      
      if f.type == 'directory' and ends_with(file, 'polygons.folder') then
         print(inspect(f),file)
      end
      

   end

   print(inspect(getPolygonFiles(path)))
--   print(inspect(getPolygonFiles(path)))

end
