function removeTheContenstOfGroundTiles(startIndex, endIndex)
   for i = #root.children, 1, -1 do

      local child = root.children[i]

      if child.groundTileIndex ~= nil then
         if child.groundTileIndex < startIndex or
            child.groundTileIndex > endIndex then
            table.remove(root.children, i)
         end
      end
   end
end
function addTheContentsOfGroundTiles(startIndex, endIndex)
   for i = startIndex, endIndex do
      if (plantData[i]) then
         for j = 1, #plantData[i] do
            local thing = plantData[i][j]
            local urlIndex = (thing.urlIndex)
            local url = plantUrls[urlIndex]
            local read = readFileAndAddToCache(url)
            local grass = {
               folder = true,
               transforms = copy3(read.transforms),
               name = 'generated',
               children = {}
            }
            grass.transforms.l[1] = (i*tileSize) + thing.x
            grass.transforms.l[2] = 0
            grass.transforms.l[4] = thing.scaleX
            grass.transforms.l[5] = thing.scaleY

            grass.depth = thing.depth
            grass.url = url
            grass.groundTileIndex = thing.groundTileIndex
            grass.bbox = read.bbox
            table.insert(root.children, grass)
         end
      end
   end
   parentize(root)
   sortOnDepth(root.children)
   recursivelyAddOptimizedMesh(root)
end

function arrangeWhatIsVisible(x1, x2, tileSize)
   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   local startIndex = s/tileSize
   local endIndex = e/tileSize

   -- initial adding
   if lastGroundBounds[1] == math.huge and lastGroundBounds[2] == -math.huge then
      addTheContentsOfGroundTiles(startIndex, endIndex)
   else
      -- look to add at start or end
      if startIndex ~= lastGroundBounds[1] or
         endIndex ~= lastGroundBounds[2] then
         removeTheContenstOfGroundTiles(startIndex, endIndex)
      end

      if startIndex < lastGroundBounds[1] then
         addTheContentsOfGroundTiles(startIndex, lastGroundBounds[1]-1)
      end

      if endIndex > lastGroundBounds[2] then
         addTheContentsOfGroundTiles(lastGroundBounds[2]+1, endIndex)
      end
   end
   lastGroundBounds = {startIndex, endIndex}
end

