local numbers = require 'lib.numbers'
local parentize = require 'lib.parentize'
local mesh = require 'lib.mesh'
local parallax = require 'lib.parallax'
--local cam = getCamera()
local cam = require('lib.cameraBase').getInstance()

function removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   for i = #parallaxData.layer.children, 1, -1 do
      local child = parallaxData.layer.children[i] 
      if child.entity and child.entity.assetBook then -- only allowed to r

         local groundTileIndex = math.floor(child.transforms.l[1] / tileSize)

         if groundTileIndex < startIndex or
             groundTileIndex > endIndex then
            table.remove(parallaxData.layer.children, i)
            if ecsWorld then
               ecsWorld:removeEntity(child.entity)
               --print('removing entity', child.entity)
            end
         end
      end
   end
end

function getGlobalHeight(xPos)
   local tileX = (math.floor(xPos / tileSize))

   if (groundTiles[tileX] and groundTiles[tileX + 1]) then
      local offsetX = (xPos % tileSize)
      local t = offsetX / tileSize
      local h = numbers.lerp(groundTiles[tileX].height, groundTiles[tileX + 1].height, t)
      return h
   else
      return 0
   end

end

function addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   local data = parallaxData.assets
   local layerIndex = parallaxData.layerIndex
   for i = startIndex, endIndex do
      if (data[i]) then
         for j = 1, #data[i] do
            local thing = data[i][j]
            local url = thing.url
            local read = mesh.readFileAndAddToCache(url)
            local doOptimized = read.optimizedBatchMesh ~= nil
            local child = {
               folder = true,
               transforms = copy3(read.transforms),
               name = 'generated ' .. url,
               children = doOptimized and {} or copy3(read.children)
            }

            child.transforms.l[1] = thing.x
            child.transforms.l[2] = getGlobalHeight(thing.x) --thing.y
            child.transforms.l[4] = thing.scaleX
            child.transforms.l[5] = thing.scaleY
            child.metaTags = read.metaTags
            child.depth = thing.depth
            child.url = thing.url
            child.bbox = read.bbox



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

            table.insert(parallaxData.layer.children, child)
         end
      end
   end

   parentize.parentize(parallaxData.layer)
   parallax.sortOnDepth(parallaxData.layer.children)
   mesh.recursivelyAddOptimizedMesh(parallaxData.layer)

end

function arrangeParallaxLayerVisibility(far, layer, ecsWorld)

   local W, H = love.graphics.getDimensions()

   local x1, y1 = cam:getWorldCoordinates(0, 0, far)
   local x2, y2 = cam:getWorldCoordinates(W, 0, far)
   local s = math.floor(x1 / tileSize) * tileSize
   local e = math.ceil(x2 / tileSize) * tileSize

   arrangeWhatIsVisible(x1, x2, tileSize, layer, ecsWorld)
end

function arrangeWhatIsVisible(x1, x2, tileSize, parallaxData, ecsWorld)
   local bounds = parallaxData.tileBounds

   local s = math.floor(x1 / tileSize) * tileSize
   local e = math.ceil(x2 / tileSize) * tileSize
   local startIndex = s / tileSize
   local endIndex = e / tileSize

   if bounds[1] == math.huge and bounds[2] == -math.huge then
      addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
   else
      if startIndex ~= bounds[1] or
          endIndex ~= bounds[2] then
         removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData, ecsWorld)
      end

      if startIndex < bounds[1] then
         addTheContentsOfGroundTiles(startIndex, bounds[1] - 1, parallaxData, ecsWorld)
      end

      if endIndex > bounds[2] then
         addTheContentsOfGroundTiles(bounds[2] + 1, endIndex, parallaxData, ecsWorld)
      end
   end
   parallaxData.tileBounds = { startIndex, endIndex }
end
