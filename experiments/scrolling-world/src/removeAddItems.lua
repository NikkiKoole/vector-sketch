local parentize = require 'lib.parentize'
local mesh = require 'lib.mesh'
local parallax = require 'lib.parallax'
local generator = require 'lib.generateWorld'
--local cam = getCamera()
local cam = require('lib.cameraBase').getInstance()
function removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData)
   for i = #parallaxData.layer.children, 1, -1 do
      local child = parallaxData.layer.children[i] ---map[layerName][i]
      if child.assetBookRef then -- only allowed to r
         local groundTileIndex = math.floor(child.transforms.l[1] / tileSize)
         --print(math.floor(child.transforms.l[1]/tileSize), child.groundTileIndex)
         if groundTileIndex < startIndex or
             groundTileIndex > endIndex then
            table.remove(parallaxData.layer.children, i)
         end
      end
   end
end

function addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData)
   local data = parallaxData.assets

   for i = startIndex, endIndex do
      if (data[i]) then
         for j = 1, #data[i] do
            local thing = data[i][j]
            -- if an item has been pressed and moved it shouldnt be readded (it not removed either)
            --if not thing.hasBeenPressed then
            --local urlIndex = (thing.urlIndex)



            local child = generator.makeThing(thing.url)

            child.transforms.l[1] = thing.x
            child.transforms.l[2] = thing.y
            child.transforms.l[4] = thing.scaleX
            child.transforms.l[5] = thing.scaleY

            child.depth = thing.depth
            child.url = thing.url


            child.dirty = true

            child.assetBookRef = thing
            child.assetBookIndex = i
            print('setting assetbookindex', i)
            table.insert(parallaxData.layer.children, child)
            --end

         end
      end
   end

   parentize.parentize(parallaxData.layer)
   parallax.sortOnDepth(parallaxData.layer.children)
   mesh.recursivelyAddOptimizedMesh(parallaxData.layer)

end

function arrangeParallaxLayerVisibility(far, layer)

   local W, H = love.graphics.getDimensions()

   local x1, y1 = cam:getWorldCoordinates(0, 0, far)
   local x2, y2 = cam:getWorldCoordinates(W, 0, far)
   local s = math.floor(x1 / tileSize) * tileSize
   local e = math.ceil(x2 / tileSize) * tileSize

   arrangeWhatIsVisible(x1, x2, tileSize, layer)
end

function arrangeWhatIsVisible(x1, x2, tileSize, parallaxData)
   local bounds = parallaxData.tileBounds

   local s = math.floor(x1 / tileSize) * tileSize
   local e = math.ceil(x2 / tileSize) * tileSize
   local startIndex = s / tileSize
   local endIndex = e / tileSize

   if bounds[1] == math.huge and bounds[2] == -math.huge then
      addTheContentsOfGroundTiles(startIndex, endIndex, parallaxData)
   else
      if startIndex ~= bounds[1] or
          endIndex ~= bounds[2] then
         removeTheContenstOfGroundTiles(startIndex, endIndex, parallaxData)
      end

      if startIndex < bounds[1] then
         addTheContentsOfGroundTiles(startIndex, bounds[1] - 1, parallaxData)
      end

      if endIndex > bounds[2] then
         addTheContentsOfGroundTiles(bounds[2] + 1, endIndex, parallaxData)
      end
   end
   parallaxData.tileBounds = { startIndex, endIndex }
end
