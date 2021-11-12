function removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   for i = #parallaxData.layer.children, 1, -1 do
      local child = parallaxData.layer.children[i]

      if child.groundTileIndex ~= nil then
         if child.groundTileIndex < startIndex or
            child.groundTileIndex > endIndex then
            table.remove(parallaxData.layer.children, i)
  --          print('removing')
            if not child.groundTileIndex == math.floor(child.transforms.l[1]/tileSize) then
               print('wnowedn')
            end
            

            local secondIndex = findSecondIndexInAssets(parallaxData.assets, child.ref, child.groundTileIndex)
--            print('findSecondIndexInAssets',secondIndex)

         end
      end
   end
end


-- i need more ways of interacting with the 2d assets that is created at generateAssetBook
-- i want to remove and add items
-- the first index in the 2d array is a 1d space, a line , i imagine horizontally
-- so lets say the first index= x , the next index is its position in the list over there

function findSecondIndexInAssets(assets, item, firstIndex)
   for i = 1, #assets[firstIndex] do
      if assets[firstIndex][i] == item then
         return i
      end
   end
   
   return -1
 
end


function addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   local count = 0
   local assets = parallaxData.assets

   for i = startIndex, endIndex do
      if (assets[i]) then
         for j = 1, #assets[i] do

            local thing = assets[i][j]
            -- if an item has been pressed and moved it shouldnt be readded (it not removed either)
            if not thing.hasBeenPressed then

               local url = thing.url
               local read = readFileAndAddToCache(url)
               local doOptimized = read.optimizedBatchMesh ~= nil  -- <<<<<<<<<<<<<<<<<<<<<<<<  HERE IT IS
               local child = {
                  folder = true,
                  transforms = copy3(read.transforms),
                  name = 'generated '..url,
                  children = doOptimized and {} or copy3(read.children)
               }

               child.transforms.l[1] =  thing.x
               child.transforms.l[2] = -200
               child.transforms.l[4] = thing.scaleX
               child.transforms.l[5] = thing.scaleY
               child.originalIndices = {i,j}
               child.ref = thing
               child.metaTags = read.metaTags
               child.depth = thing.depth

               child.url = thing.url
 --              print(thing.groundTileIndex, i)
               child.groundTileIndex = thing.groundTileIndex
               child.bbox = read.bbox
               table.insert(parallaxData.layer.children, child)
               --print('adding')


            end
         end
      end
   end
--   print('total in assets here: ', count)
   parentize(parallaxData.layer)
   sortOnDepth(parallaxData.layer.children)
   recursivelyAddOptimizedMesh(parallaxData.layer)

end

function arrangeParallaxLayerVisibility(far, layer, ecsWorld)

   local W, H = love.graphics.getDimensions()

   local x1,y1 = cam:getWorldCoordinates(0,0, far)
   local x2,y2 = cam:getWorldCoordinates(W,0, far)
   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   arrangeWhatIsVisible(x1, x2, tileSize, layer, ecsWorld)
end

function arrangeWhatIsVisible(x1, x2, tileSize, parallaxData, ecsWorld)
   local bounds = parallaxData.tileBounds

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   local startIndex = s/tileSize
   local endIndex = e/tileSize

   if bounds[1] == math.huge and bounds[2] == -math.huge then
      addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   else
      if startIndex ~= bounds[1] or
         endIndex ~= bounds[2] then
         removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
      end

      if startIndex < bounds[1] then
         addTheContentsOfGroundTiles(startIndex, bounds[1]-1, parallaxData, ecsWorld)
      end

      if endIndex > bounds[2] then
         addTheContentsOfGroundTiles(bounds[2]+1, endIndex, parallaxData, ecsWorld)
      end
   end
   parallaxData.tileBounds = {startIndex, endIndex}
end
