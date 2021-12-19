function removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld, layerIndex)
   for i = #parallaxData.layer.children, 1, -1 do
      local child = parallaxData.layer.children[i]---map[layerName][i]
      if child.entity and child.entity.assetBook then -- only allowed to r
         --print(child.entity and child.entity.assetBook, child.assetBookRef)

         local groundTileIndex  = math.floor(child.transforms.l[1]/tileSize)
         --print(math.floor(child.transforms.l[1]/tileSize), child.groundTileIndex)
         if groundTileIndex < startIndex or
            groundTileIndex > endIndex then
            table.remove(parallaxData.layer.children, i)
            if ecsWorld then
               ecsWorld:removeEntity(child.entity)
            end
         end
      end
   end
end

function getGlobalHeight(xPos)
   local tileX = (math.floor(xPos/tileSize))
   local offsetX = (xPos % tileSize)
   local t = offsetX/tileSize
   assert(t >= 0 and t <= 1)
   local h = lerp(groundTiles[tileX].height, groundTiles[tileX+1].height, t)
   return h
end


function addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld, layerIndex)
   local data = parallaxData.assets

   for i = startIndex, endIndex do
      if (data[i]) then
         for j = 1, #data[i] do
            local thing = data[i][j]
            local url = thing.url
            local read = readFileAndAddToCache(url)
            local doOptimized = read.optimizedBatchMesh ~= nil
            local child = {
               folder = true,
               transforms = copy3(read.transforms),
               name = 'generated '..url,
               children = doOptimized and {} or copy3(read.children)
            }

            child.transforms.l[1] = thing.x
            child.transforms.l[2] = getGlobalHeight(thing.x) --thing.y
            
--            print(getGlobalHeight(thing.x))
            
            --child.transforms.l[3] = love.math.random()--thing.y

            child.transforms.l[4] = thing.scaleX
            child.transforms.l[5] = thing.scaleY
            child.metaTags = read.metaTags
            child.depth = thing.depth
            child.url = thing.url
            child.bbox = read.bbox

            table.insert(parallaxData.layer.children, child)

            if ecsWorld then
               local myEntity = Concord.entity()
               myEntity
                  :give('assetBook', thing, i)
                  :give('transforms', child.transforms)
                  :give('bbox', child.bbox)
		  :give('layer', layerIndex)
		  :give('vanillaDraggable')
                  :give("rotateOnMove")

	       if (child.metaTags and child.metaTags[1].name == 'connector') then
		  myEntity:give('stackable')
	       end
               ecsWorld:addEntity(myEntity)
               child.entity = myEntity
            end
         end
      end
   end

   parentize(parallaxData.layer)
   sortOnDepth(parallaxData.layer.children)
   recursivelyAddOptimizedMesh(parallaxData.layer)

end

function arrangeParallaxLayerVisibility(far, layer, ecsWorld, layerIndex)

   local W, H = love.graphics.getDimensions()

   local x1,y1 = cam:getWorldCoordinates(0,0, far)
   local x2,y2 = cam:getWorldCoordinates(W,0, far)
   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize

   arrangeWhatIsVisible(x1, x2, tileSize, layer, ecsWorld, layerIndex)
end

function arrangeWhatIsVisible(x1, x2, tileSize, parallaxData, ecsWorld, layerIndex)
   local bounds = parallaxData.tileBounds

   local s = math.floor(x1/tileSize)*tileSize
   local e = math.ceil(x2/tileSize)*tileSize
   local startIndex = s/tileSize
   local endIndex = e/tileSize

   if bounds[1] == math.huge and bounds[2] == -math.huge then
      addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld, layerIndex)
   else
      if startIndex ~= bounds[1] or
         endIndex ~= bounds[2] then
         removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld, layerIndex)
      end

      if startIndex < bounds[1] then
         addTheContentsOfGroundTiles(startIndex, bounds[1]-1, parallaxData, ecsWorld, layerIndex)
      end

      if endIndex > bounds[2] then
         addTheContentsOfGroundTiles(bounds[2]+1, endIndex, parallaxData, ecsWorld, layerIndex)
      end
   end
   parallaxData.tileBounds = {startIndex, endIndex}
end
