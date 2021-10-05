--local random = love.math.random
local inspect = require 'vendor.inspect'
function createStuff()
    local W, H = love.graphics.getDimensions()
    player = {
      x = - 25,
      y = 0,
      width = 50,
      height = -180,
      speed = 200,
      color = { 1,0,0 }
   }
   player.depth = 0

    if true  then
      for i = 1, 140 do
	 local rndHeight = random(100, 200)
	 local rndDepth =  mapInto(random(), 0,1,depthMinMax.min,depthMinMax.max )
	 table.insert(
	    stuff,
	    {
	       x = random(-W*5, W*5 ),
	       y = -rndHeight,
	       width = 10, --love.math.random(30, 50),
	       height = rndHeight,
	       color = {.6,
			mapInto(rndDepth, depthMinMax.min,depthMinMax.max,  .6, .5),
			mapInto(rndDepth, depthMinMax.min,depthMinMax.max, 0.4, .6) ,
			random(.3,.9)},
	       depth = rndDepth
	    }
	 )
      end
      table.insert(stuff, player)
      sortOnDepth(stuff)
    end

    cameraPoints = {}
    for i = 1, 10 do
       table.insert(
	  cameraPoints,
	  {
	     x = random(-W*2, W*2 ),
	     y = random(-H*2, H*2),
	     width = random(200, 500),
	     height = random(200, 500),
	     color = { 1, 1, 1 },
	     selected = false
	  }
       )
    end

    root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {}
    }

    function initCarParts()
      carparts = {}
      carparts.children = parseFile('assets/carparts_.polygons.txt')

      carbody = copy3(findNodeByName(carparts, 'carbody'))
      carbody.children[1].color[4] = 1.0
      carbody.transforms.l[1]=0
      carbody.transforms.l[2]=0
      carbody.depth = 0

      carbodyVoor = copy3(findNodeByName(carparts, 'carbody'))
      carbodyVoor.children[1].color[4] = 0.3
      carbodyVoor.children[2].children[1].color[4] = 0.6
      carbodyVoor.children[2].children[2].color[4] = 0.6
      carbodyVoor.transforms.l[1]=0
      carbodyVoor.transforms.l[2]=0
      --carbodyVoor.depth = carThickness
   end
   --initCarParts()
    plantUrls = {
      'assets/grassagain_.polygons.txt',
      'assets/plant1.polygons.txt',
      'assets/plant2.polygons.txt',
      'assets/plant3.polygons.txt',
      'assets/plant4.polygons.txt',
      'assets/plant5.polygons.txt',
      'assets/plant6.polygons.txt',
      'assets/plant7.polygons.txt',
      'assets/plant8.polygons.txt',
      'assets/plant9.polygons.txt',
      'assets/plant10.polygons.txt',
      'assets/plant11.polygons.txt',
      'assets/plant12.polygons.txt',
      'assets/plant13.polygons.txt',
  --    'assets/digger_.polygons.txt',
--      'assets/digger02__.polygons.txt',
      -- 'assets/poep.polygons.txt',

       --'assets/isthissizeok.polygons.txt',
 --      'assets/anotherdog.polygons.txt',
      -- 'assets/birdword.polygons.txt',
      -- 'assets/birdword.polygons.txt',
      -- 'assets/birdword.polygons.txt',
      -- 'assets/birdword.polygons.txt',
     -- 'assets/ramen_.polygons.txt',
 --      'assets/bedje.polygons.txt',
      -- 'assets/raampje2.polygons.txt',
      -- 'assets/raamagain.polygons.txt',
      -- 'assets/raamagain2.polygons.txt',
      -- 'assets/raamagain2_.polygons.txt',

--      'Assets/gerns2.polygons.txt',

    }
    plantData = {}



   for i = -1000, 1000 do

      plantData[i] = {}
      for p = 1, 1 do

         table.insert(
            plantData[i],
            {

               x=random()*tileSize,
               groundTileIndex = i,
               depth=mapInto(random(), 0,1,
                             depthMinMax.min, depthMinMax.max ),
	       depthLayer = 'hack',
               scaleX = 1.0 + random(),
               scaleY = 1.0 + random()*1.5,

               urlIndex=math.ceil(random()* #plantUrls)
            }
         )
      end

   end
   --print(inspect(plantData))





   --[[

      ok my plan to make the loading faster and huge worlds possible
      - make the initted list just a big list of groundindexes ? -100 -> 100 or something
      - at each list add a bunch of random things
      - then try and display this thing.
      - from there we are ion a good location to improve

   ]]--



   -- function initGrass()
   --    local all = {}
   --    for j = 1, #plantUrls do
   --       local url = plantUrls[j]
   --       local read = readFileAndAddToCache(url)
   --       local grass = {}

   --       for i= 1, 5 do
   --          grass[i]= {
   --             folder = true,
   --             transforms =  copy3(read.transforms),
   --             name="generated",
   --             children ={}
   --          }
   --          if grass[i].transforms then
   --             grass[i].transforms.l[1] = -1000 + random() * 2000
   --             grass[i].transforms.l[2] = 0
   --             grass[i].transforms.l[4] = 1.0 + random()*.2
   --             grass[i].transforms.l[5] = 1.0 + random()* 2

   --             local rndDepth = mapInto(random(), 0,1, depthMinMax.min, depthMinMax.max )
   --             grass[i].depth = rndDepth
   --             grass[i].aabb =  grass[i].transforms.l[1]
   --             grass[i].url = url
   --          end
   --       end
   --       all = TableConcat(all, grass)
   --    end
   --    root.children = all
   -- end
   --initGrass()

   groundPlanes = {
      assets = {
	 --{url = 'assets/grasssquare_.polygons.txt'},
         {url = 'assets/fit1.polygons.txt'},
	 {url = 'assets/fit2.polygons.txt'},
	 {url = 'assets/fit3.polygons.txt'},
	 {url = 'assets/fit4.polygons.txt'},
	 {url = 'assets/fit5.polygons.txt'}
      },
      perspectiveContainer = {
	 -- all perspective groundmeshes drawn on screen will end up in here
      }
   }

   for i = 1, #groundPlanes.assets do
      local url = groundPlanes.assets[i].url
      groundPlanes.assets[i].thing = readFileAndAddToCache(url)
      groundPlanes.assets[i].bbox = getBBoxOfChildren(groundPlanes.assets[i].thing.children)
   end
   for i = 0, 100 do  -- maximum of 100 groundplanes visible onscreen
      groundPlanes.perspectiveContainer[i] = {}
      for j =0, 10 do -- maximum of 10 'layers/children/optimized layers' in a thing
	 groundPlanes.perspectiveContainer[i][j] = {}
      end
   end


   local points = {{-50,-250},{50,-250},{50,0},{-50,0}}
   local tlx, tly, brx, bry = getPointsBBox(points)
   -- new player
   newPlayer = {
      folder = true,
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      name="player",
      depth = 0,
      depthLayer = 'hack',
      x=0,
      bbox= {tlx, tly, brx, bry},
      children ={
         {
            name="yellow shape:"..1,
            color = {1,1,0, 0.8},
            points = points,
         },
      }
   }
   if testCar then
      table.insert(newPlayer.children, 1, carbody)
   end

   table.insert(root.children, newPlayer)
   meshAll(newPlayer)

   if testCar then
      voor2 = {
         folder = true,
         transforms =  {l={0,0,0,1,1,0,0,0,0}},
         name="voor2",
         depth = 12,
         x=0,
         children ={
            carbodyVoor
         }
      }
      table.insert(root.children, voor2)
   end

   if true then
   for j = 1, 10 do
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
      local rndDepth =  mapInto(rnd, 0,1,depthMinMax.min,depthMinMax.max )
      local xPos = -600 + random()*1200
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

      table.insert(root.children, randomShape)
   end
   end

end
