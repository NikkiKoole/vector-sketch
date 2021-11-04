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
      if rootPath == '' then
         path = v
      end
      
      local file = lfs.getInfo(path)
      if file.type == 'file' and
	 ends_with(path, 'polygons.txt') then
	 local pngPath = path:gsub('polygons.txt', 'polygons.png')
	 local png = love.filesystem.getInfo(pngPath)
--         print(path, string.sub(path, 2))
	 if file and png then
	    tree[#tree+1] = {
               path=path,--string.sub(path, 2),
               txt=file,
               pngPath=pngPath,--,string.sub(pngPath, 2),
               png=png,
            }
	 end
      elseif file.type == 'directory'  then
	 fileTree = getPolygonFiles(path, tree)
      end

   end
   return tree
end

function renderOpenFileScreen()

   love.graphics.setFont(small)

   love.graphics.clear(backdrop.bg_color[1], backdrop.bg_color[2], backdrop.bg_color[3])
   love.graphics.setColor(1,1,1)
   
   local w, h = love.graphics.getDimensions( )
   local smallsize = (1024/2) / 8
   local columns = math.ceil(w/smallsize)
   local mx, my = love.mouse.getPosition()
   local overIndex = -1
   local usedIndex = 1
   local gatheredPaths = {}
   --print(#gatheredData)
   for i=1, #gatheredData do
      local index = stringFindLastSlash(gatheredData[i].path) or 0
      if index > 0 then
         local dir = gatheredData[i].path:sub(1, index-1)
         --print(dir)
         gatheredPaths[dir] = (gatheredPaths[dir] or 0 ) + 1 
      end
   end

   local index = 2
   local pathArray = {}
   for k in pairs(gatheredPaths) do
      pathArray[index] = k
      index = index + 1
   end
   pathArray[1] = '< back'

   


   local dirX = 0
   local dirY = 0
   local margin = 10

   for i = 1, #pathArray do
      local k = pathArray[i]
      local labelW = small:getWidth(k) + margin
      local labelH = small:getHeight(k) + margin

      if k == '< back' then
         love.graphics.setColor(1,0,1, 0.5)
         love.graphics.rectangle('fill', dirX, dirY, labelW, labelH )
      end
      
      if pointInRect(mx, my, dirX,dirY, labelW, labelH ) then
         love.graphics.setColor(1,0,0)
         love.graphics.rectangle('fill', dirX, dirY, labelW, labelH )
         if love.mouse.isDown(1) then
            if k == '< back' then
               gatherData('')
            else
               gatherData(k)
            end
         end
      end

      love.graphics.setColor(0,0,0)
      love.graphics.print(k,dirX, dirY)
      love.graphics.setColor(1,1,1)
      love.graphics.print(k, dirX+1, dirY+1)

      if dirX + labelW  < w then
         dirX = dirX + labelW
      else
         dirX = 0
         dirY = dirY + labelH
      end
   end
   
   local yOffset = dirY + 30 
   
   for i =1, #gatheredData do
      local index = stringFindLastSlash(gatheredData[i].path) or 0
      if (gatheredData[i].img ) then
         local x = (usedIndex % columns) - 1
         local y = (math.ceil(usedIndex / columns)) - 1
         
         love.graphics.draw(gatheredData[i].img,x * smallsize, yOffset+ y * smallsize, 0, .125, .125)
         if pointInRect(mx, my, x*smallsize,yOffset+ y*smallsize, smallsize, smallsize) then
            overIndex = i
            if love.mouse.isDown(1) then
               local contents, size = love.filesystem.read(gatheredData[i].path)

               local tab = readStrAsShape(contents, 'vector-sketch/'..gatheredData[i].path)
               root.children = tab -- TableConcat(root.children, tab)
               parentize(root)

               --local bbox  = getBBoxRecursive(root)
               --print(inspect(bbox))
               --local middle = {bbox[3] - bbox[1], bbox[4] - bbox[2]}
               --print(root.transforms.l[1], root.transforms.l[2])
               
               root.transforms.l[1] = 0
               root.transforms.l[2] = 0

               scrollviewOffset = 0
               editingMode = nil
               editingModeSub = nil
               currentNode = nil
               meshAll(root)
               fileDropPopup = nil
               openFileScreen = false
            end
            
         end

         usedIndex = usedIndex + 1
      end
   end
   
   if overIndex > -1 then
      love.graphics.draw(gatheredData[overIndex].img, w-512, h-512, 0, 1, 1)
      love.graphics.setColor(0,0,0)
      love.graphics.print(gatheredData[overIndex].path, w-512, h-512)
      love.graphics.setColor(1,1,1)
      love.graphics.print(gatheredData[overIndex].path, w-512+1, h-512+1)
   end
end


function gatherData(path)

   gatheredData = getPolygonFiles(path)
   for i = 1, #gatheredData do
      local folderPath = ''
      local p = gatheredData[i].path
      local index = stringFindLastSlash(p)
      if index then
         folderPath = (string.sub(p, 0, index-1))
      end
      
      local check =  folderPath == path

      if check then
         gatheredData[i].img = love.graphics.newImage(gatheredData[i].pngPath)
      end
   end

end

