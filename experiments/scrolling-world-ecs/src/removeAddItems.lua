function removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   for i = #parallaxData.layer.children, 1, -1 do
      local child = parallaxData.layer.children[i]
      local groundTileIndex= math.floor(child.transforms.l[1]/tileSize)
      
      --if child.groundTileIndex ~= nil then
      if groundTileIndex < startIndex or
         groundTileIndex > endIndex then

         

         
         if not child.inMotion then
            
            table.remove(parallaxData.layer.children, i)
            
            local first, second = findSecondIndexInAssets(parallaxData.assets, child.ref, groundTileIndex)

            if first == nil and second ==nil then
               print('whats goingoj here', inspect(child.transforms.l), groundTileIndex)
            else

            
            parallaxData.assets[first][second].x = child.transforms.l[1]
            parallaxData.assets[first][second].y = child.transforms.l[2]

            
            -- this is repositioning in the structure
            if first ~= groundTileIndex then

               -- also if position has changed from the asset one
               table.remove(parallaxData.assets[first], second)

               --only add at valid location
               if  groundTileIndex >= parallaxData.assets.min and
                  groundTileIndex <= parallaxData.assets.max then
                  table.insert(parallaxData.assets[groundTileIndex],objToAssetBookType(child) )
               end
               
            end

            end
            --end

         end
         
      end
      --end
   end
end


-- i need more ways of interacting with the 2d assets that is created at generateAssetBook
-- i want to remove and add items
-- the first index in the 2d array is a 1d space, a line , i imagine horizontally
-- so lets say the first index= x , the next index is its position in the list over there

function findSecondIndexInAssets(assets, item, firstIndex)
   --print(assets.min, assets.max, firstIndex)
   if firstIndex >= assets.min and firstIndex <= assets.max then
   for i = 1, #assets[firstIndex] do
      if assets[firstIndex][i] == item then
         return firstIndex, i
      end
   end
   end
   for i = assets.min, assets.max do
      for j = 1, #assets[i] do
         if assets[i][j] == item then
            return i, j
         end
      end
   end
   
   print('getting in third leg why?')
   
   return nil, nil
   
end


function addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   local count = 0
   local assets = parallaxData.assets

   for i = startIndex, endIndex do
      if (assets[i]) then
         for j = 1, #assets[i] do

            local thing = assets[i][j]
            -- if an item has been pressed and moved it shouldnt be readded (it not removed either)
            --          if not thing.hasBeenPressed then


            local child = makeObject(thing.url, thing.x, thing.y, thing.depth, true)
            
            child.transforms.l[4] = thing.scaleX
            child.transforms.l[5] = thing.scaleY

            --child.originalIndices = {i,j}
            child.ref = thing
            --child.groundTileIndex = i --thing.groundTileIndex
            --               print('adding ', child.url)
            table.insert(parallaxData.layer.children, child)
            --print('adding')


            --        end
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
