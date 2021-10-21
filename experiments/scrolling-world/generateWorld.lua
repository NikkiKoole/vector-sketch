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


function generateAssetBook(recipe)
   local result = {}

   for i = recipe.index.min, recipe.index.max do
      result[i] = {}
      for p= 1, recipe.amountPerTile do
	 table.insert(
	    result[i],
	    {
	       x=random()*tileSize,
	       groundTileIndex = i,
	       depth = mapInto(random(),0,1,recipe.depth.min, recipe.depth.max),
	       scaleX=1,
	       scaleY=1,
	       url=pickRandom(recipe.urls)
	    }
	 )
      end
   end
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
	 depthLayer = 'hack',
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
