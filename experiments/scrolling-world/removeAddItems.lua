function removeTheContenstOfGroundTiles(startIndex, endIndex, layerName)
   local map = {
      foreground = middleLayer.children,
      background = fartherLayer.children
   }

   for i = #map[layerName], 1, -1 do
      local child = map[layerName][i]
      if child.groundTileIndex ~= nil then
         if child.groundTileIndex < startIndex or
            child.groundTileIndex > endIndex then
            table.remove(map[layerName], i)
         end
      end
   end
end
function addTheContentsOfGroundTiles(startIndex, endIndex, layerName)
   local map = {
      foreground = {layer = middleLayer, data = middleAssetBook},
      background = {layer = fartherLayer, data = fartherAssetBook}
   }

   local data = map[layerName].data
   local urls = map[layerName].urls

   for i = startIndex, endIndex do
      if (data[i]) then
         for j = 1, #data[i] do
            local thing = data[i][j]
            -- if an item has been pressed and moved it shouldnt be readded (it not removed either)
            if not thing.hasBeenPressed then
               --local urlIndex = (thing.urlIndex)
               local url = thing.url --urls[urlIndex]
               local read = readFileAndAddToCache(url)
               local doOptimized = read.optimizedBatchMesh ~= nil  -- <<<<<<<<<<<<<<<<<<<<<<<<  HERE IT IS
               local child = {
                  folder = true,
                  transforms = copy3(read.transforms),
                  name = 'generated '..url,
                  children = doOptimized and {} or copy3(read.children)
               }

               child.transforms.l[1] = (i*tileSize) + thing.x
               child.transforms.l[2] = 0
               child.transforms.l[4] = thing.scaleX
               child.transforms.l[5] = thing.scaleY
               child.originalIndices = {i,j}
               child.depth = thing.depth
               --child.depthLayer = thing.depthLayer
               child.url = thing.url
               child.groundTileIndex = thing.groundTileIndex
               child.bbox = read.bbox
               table.insert(map[layerName].layer.children, child)
            end
         end
      end
   end

   parentize(map[layerName].layer)
   sortOnDepth(map[layerName].layer.children)
   recursivelyAddOptimizedMesh(map[layerName].layer)

end

function arrangeWhatIsVisible(x1, x2, tileSize, layerName)
   local bounds = layerTileBounds[layerName]

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   local startIndex = s/tileSize
   local endIndex = e/tileSize

   if bounds[1] == math.huge and bounds[2] == -math.huge then
      addTheContentsOfGroundTiles(startIndex, endIndex, layerName)
   else
      if startIndex ~= bounds[1] or
         endIndex ~= bounds[2] then
         removeTheContenstOfGroundTiles(startIndex, endIndex, layerName)
      end

      if startIndex < bounds[1] then
         addTheContentsOfGroundTiles(startIndex, bounds[1]-1, layerName)
      end

      if endIndex > bounds[2] then
         addTheContentsOfGroundTiles(bounds[2]+1, endIndex, layerName)
      end
   end
   layerTileBounds[layerName] = {startIndex, endIndex}

end
