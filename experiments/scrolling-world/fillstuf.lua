
-- function createStuff()
--    local W, H = love.graphics.getDimensions()
--    --  player = {
--    --    x = - 25,
--    --    y = 0,
--    --    width = 50,
--    --    height = -180,
--    --    speed = 200,
--    --    color = { 1,0,0 }
--    -- }
--    -- player.depth = 0

--    -- if true  then
--    --    for i = 1, 140 do
--    --       local rndHeight = random(100, 200)
--    --       local rndDepth =  mapInto(random(), 0,1,depthMinMax.min,depthMinMax.max )
--    --       table.insert(
--    --          stuff,
--    --          {
--    --             x = random(-W*5, W*5 ),
--    --             y = -rndHeight,
--    --             width = 10, --love.math.random(30, 50),
--    --             height = rndHeight,
--    --             color = {.6,
--    --      		mapInto(rndDepth, depthMinMax.min,depthMinMax.max,  .6, .5),
--    --      		mapInto(rndDepth, depthMinMax.min,depthMinMax.max, 0.4, .6) ,
--    --      		random(.3,.9)},
--    --             depth = rndDepth
--    --          }
--    --       )
--    --    end
--    --    --table.insert(stuff, player)
--    --    sortOnDepth(stuff)
--    --  end

--    cameraPoints = {}
--    for i = 1, 10 do
--       table.insert(
--          cameraPoints,
--          {
--             x = random(-W*2, W*2 ),
--             y = random(-H*2, H*2),
--             width = random(200, 500),
--             height = random(200, 500),
--             color = { 1, 1, 1 },
--             selected = false
--          }
--       )
--    end

   


--    function initCarParts()
--       carparts = {}
--       carparts.children = parseFile('assets/carparts_.polygons.txt')

--       carbody = copy3(findNodeByName(carparts, 'carbody'))
--       carbody.children[1].color[4] = 1.0
--       carbody.transforms.l[1]=0
--       carbody.transforms.l[2]=0
--       carbody.depth = 0

--       carbodyVoor = copy3(findNodeByName(carparts, 'carbody'))
--       carbodyVoor.children[1].color[4] = 0.3
--       carbodyVoor.children[2].children[1].color[4] = 0.6
--       carbodyVoor.children[2].children[2].color[4] = 0.6
--       carbodyVoor.transforms.l[1]=0
--       carbodyVoor.transforms.l[2]=0
--       --carbodyVoor.depth = carThickness
--    end
--    --initCarParts()




--    local points = {{-50,-250},{50,-250},{50,0},{-50,0}}
--    local tlx, tly, brx, bry = getPointsBBox(points)
--    -- new player
--    -- newPlayer = {
--    --    folder = true,
--    --    transforms =  {l={0,0,0,1,1,0,0,0,0}},
--    --    name="player",
--    --    depth = 0,
--    --    depthLayer = 'hack',
--    --    x=0,
--    --    bbox= {tlx, tly, brx, bry},
--    --    children ={
--    --       {
--    --          name="yellow shape:"..1,
--    --          color = {1,1,0, 0.8},
--    --          points = points,
--    --       },
--    --    }
--    -- }
--    -- if testCar then
--    --    table.insert(newPlayer.children, 1, carbody)
--    -- end

--    -- table.insert(middleLayer.children, newPlayer)
--    -- meshAll(newPlayer)

--    -- if testCar then
--    --    voor2 = {
--    --       folder = true,
--    --       transforms =  {l={0,0,0,1,1,0,0,0,0}},
--    --       name="voor2",
--    --       depth = 12,
--    --       x=0,
--    --       children ={
--    --          carbodyVoor
--    --       }
--    --    }
--    --    table.insert(middleLayer.children, voor2)
--    -- end



-- end
