function test()
   local start = love.timer.getTime()
   for x = 1, 100 do
      for y = 1, 100 do
         love.math.noise((x/100) * 200, (y/100) * 200)
      end
   end
   local result = love.timer.getTime() - start
   print(string.format("generate world took %.9f millisecs.", result * 1000))
end


function preparePerspectiveContainers(layers)
   local result = {}
   for k =1, #layers do
      local layerName = layers[k]
      result[layerName] = {}
      result[layerName].cameraBounds = {
         x={math.huge, -math.huge},
         y={math.huge, -math.huge}
      }
      for i = 0, 100 do
         -- maximum of 100 groundplanes visible onscreen
         result[layerName][i] = {}
         for j =0, 10 do
            -- maximum of 10 'layers/children/optimized layers' in a thing
            result[layerName][i][j] = {}
         end
      end
   end
   return result
end


function createAssetPolyUrls(strings)
   local result = {}
   for i = 1, #strings do
      table.insert(result, 'assets/'..strings[i]..'.polygons.txt')
   end
   return result
end

function makeGroundPlaneBook(urls)
   local result = {}
   for i =1, #urls do
      local url = urls[i]
      local thing = readFileAndAddToCache(url)
      result[i] = {
         url = url,
         thing = thing,
         bbox = getBBoxOfChildren(thing.children),
      }
   end
   return result
end

function makeObject(url, x, y, depth, allowOptimized)
--   print(url, allowOptimized)
   if allowOptimized == nil then allowOptimized = true end
   local read = readFileAndAddToCache(url)
   local doOptimized = read.optimizedBatchMesh ~= nil

   local child = {
      folder = true,
      transforms = copy3(read.transforms),
      name = 'generated '..url,
      children = (allowOptimized and doOptimized) and {} or copy3(read.children)
   }

   child.transforms.l[1] = x
   child.transforms.l[2] = y
   child.depth = depth


   child.bbox = read.bbox
   child.metaTags = read.metaTags
   -- this one is needed for feet ...
   if allowOptimized and doOptimized then
      child.url = url
   end

   --meshAll(child)
   return child
end

function objToAssetBookType(obj)
   return createAssetBookType(
      obj.url,
      obj.transforms.l[1],
      obj.transforms.l[2],
      obj.depth,
      obj.transforms.l[4],
      obj.transforms.l[5]
   )
end


function createAssetBookType(url, x,y,depth, scaleX, scaleY)
   return {
      url = url,
      x = x,
      y = y,
      depth = depth,
      scaleX = scaleX or 1,
      scaleY = scaleY or 1

   }
end

function generateAssetBook(recipe)
   local result = {}

   for i = recipe.index.min, recipe.index.max do
      result[i] = {}
      for p= 1, recipe.amountPerTile do
         local addme = {
            url = pickRandom(recipe.urls),
            x= (i*tileSize) + random()*tileSize,
            y= -100, 
            depth = mapInto(random(),0,1,recipe.depth.min, recipe.depth.max)
         }

         addme = createAssetBookType(addme.url, addme.x, addme.y, addme.depth)

         table.insert(
	    result[i],
            addme
	 )
      end
   end
   result.min = recipe.index.min
   result.max = recipe.index.max

   return result
end

function makeContainerFolder(name)
   return   {
      folder = true,
      name = name,
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {}
   }
end

function generateRandomPolysAndAddToContainer(amount, factors, container)
   for j = 1, amount do
      local generated = generatePolygon(0,0, 4 + random()*160, .05 + random()*.01, .02 + random()*0.12 , 8 + random()*18)
      local points = {}
      for i = 1, #generated, 2 do
	 table.insert(points, {generated[i], generated[i+1]})
      end

      local tlx, tly, brx, bry = getPointsBBox(points)
      local pointsHeight = math.floor((bry - tly)/2)

      local r,g,b = hex2rgb('4D391F')
      r = random()*255
      local rnd = 0.45 + random()*0.1
      local rndDepth =  mapInto(rnd, 0,1,factors.far,factors.near )
      local xPos = -1000 + random()*2000
      local randomShape = {
	 folder = true,
	 transforms =  {l={xPos,0,0,1,1,0,pointsHeight,0,0}},
	 name="rood",
	 depth = rndDepth,
	 --depthLayer = 'hack',
	 --aabb = xPos,
	 bbox= {tlx, tly, brx, bry},
	 children ={
	    {
	       name="roodchild:"..1,
	       color = {r/255,g/255,b/255, 1.0},
	       points = points,
	    },
	 }
      }
      meshAll(randomShape)

      table.insert(container.children, randomShape)
   end


end
