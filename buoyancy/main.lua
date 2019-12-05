
function love.keypressed(k)
   if (k == 'escape') then
      love.event.quit()
   end
end

function love.mousepressed(x, y)
   local check = {objects.floater, objects.ball1, objects.ball2}
   for i = 1, #check do
      local o = check[i]
      local isInside = o.fixture:testPoint( x, y )
      if (isInside) then
	 jointBody = check[i].body 
	 joint = love.physics.newMouseJoint( jointBody, x, y )
	 joint:setDampingRatio( 1 )
	 return
      end
   end
end

function love.mousereleased()
   if (joint) then
      joint:destroy()
      joint = nil
      jointBody = nil
   end
end

function beginContact(a, b, coll)
   if (a:getUserData() == "water" and b:getUserData() == "ball") then
      (b:getBody()):applyForce(0, -10000)
      print("applying oposite force?")
   end
   if (a:getUserData() == "ball" and b:getUserData() == "water") then
      (a:getBody()):applyForce(0, -10000)
      print("applying oposite force?")

   end
   
   print('begin contact', a:getUserData(), b:getUserData())
end

function endContact(a, b, coll)
  
   print('end contact', a:getUserData(), b:getUserData())

end

function preSolve(a, b, coll)
end

function postSolve(a, b, coll, normalimpulse, tangentimpulse)
end

function createThing(body, shape, userdata)
   local result = {
      body=body, shape=shape,
      fixture = love.physics.newFixture(body, shape) 
   }
   if (userdata) then
      result.fixture:setUserData(userdata)
   end
   
   return result
end


function love.load()
   local width = 1024
   local height = 768
   love.physics.setMeter(100)
   world = love.physics.newWorld(0, 9.81*100, true)
   world:setCallbacks(beginContact, endContact, preSolve, postSolve)
   love.window.setMode(1024, 768)

   local margin = 20
   objects = {}
   
   objects.border = createThing(
      love.physics.newBody(world,0,0),
      love.physics.newChainShape(
	 true, margin,margin,
	 width-margin,margin,
	 width-margin,height-margin,
	 margin,height-margin ),
      "wall"
   )

   objects.water = createThing(
      love.physics.newBody(world, width/2, (height - height/4) - margin/2),
      love.physics.newRectangleShape( width-margin*2, height/2 - margin ),
      "water"
   )
   objects.water.fixture:setSensor(true)

   objects.floater = createThing(
      love.physics.newBody(world, width/2, height/2 - 100, "dynamic"),
      love.physics.newRectangleShape( 100, 20 ),
      "floater"
   )

   objects.ball1 = createThing(
      love.physics.newBody(world, width/2-20, height/2, "dynamic"),
      love.physics.newCircleShape(20),
      "ball"
   )
   
   objects.ball2 = createThing(
      love.physics.newBody(world, width/2+20, height/2, "dynamic"),
      love.physics.newCircleShape(20),
      "ball"
   )

   joint = nil
   jointBody = nil
   
   miffy = {
      name='miffy',
      colors={
	 {name="green", rgb={48,112,47}},
	 {name="blue", rgb={27,84,154}},
	 {name="yellow", rgb={250,199,0}},
	 {name="orange1", rgb={233,100,14}},
	 {name="orange2", rgb={237,76,6}},
	 {name="orange3", rgb={221,61,14}},
	 {name="black1", rgb={34,30,30}},
	 {name="black2", rgb={24,26,23}},
	 {name="black2", rgb={24,26,23}},
	 {name="brown1", rgb={145,77,35}},
	 {name="brown2", rgb={114,65,11}},
	 {name="brown3", rgb={136,95,62}},
	 {name="grey1", rgb={147,142,114}},
	 {name="grey2", rgb={149,164,151}},
      }
   }
   for i = 1, #miffy.colors do
      miffy.colors[i].rgb = {
	 miffy.colors[i].rgb[1]/255,
	 miffy.colors[i].rgb[2]/255,
	 miffy.colors[i].rgb[3]/255,
      }
      miffy[miffy.colors[i].name] = miffy.colors[i].rgb
   end
   
end


function drawBlock(thing)
   local d = thing.fixture:getDensity()
   love.graphics.setColor(0.20*(d*3), 1.0 - d*5, 0.20)
   love.graphics.polygon("fill", thing.body:getWorldPoints(thing.shape:getPoints()))
   love.graphics.setColor(1, 0.5, 0.20)
   love.graphics.setLineWidth(3)
   love.graphics.polygon("line", thing.body:getWorldPoints(thing.shape:getPoints()))
   love.graphics.setColor(1, 1, 1)
   local cx, cy = thing.body:getWorldCenter()
   love.graphics.rectangle("line", cx, cy, 1 ,1)
end

function drawCircle(body, shape)
   love.graphics.setColor(233/255,255/255,14/255)
   love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
   love.graphics.setColor(1, 0.5, 0.20)
   love.graphics.setLineWidth(3)
   love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
end

function love.update(dt)
   if (joint) then
      joint:setTarget(love.mouse.getPosition())
   end
   
   world:update(dt) -- this puts the world into motion
end


function love.draw()
   love.graphics.clear(miffy.orange1)

   local width, height = love.graphics.getDimensions()
   local m = 20

   love.graphics.setColor(miffy.brown1)
   love.graphics.rectangle("fill", 0,0, width, m)
   love.graphics.rectangle("fill", 0,height-m, width, m)
   love.graphics.rectangle("fill", 0,0, m, height)
   love.graphics.rectangle("fill", width-m,0, m, height)

   local alpha = (math.sin(love.timer.getTime() * 12)/2 + 0.5)/ 5
   love.graphics.setColor(135/255, 206/255, 235/255, 0.6 + alpha)

   love.graphics.rectangle("fill", m,height/2,width-m*2,height/2 - m)

   drawBlock(objects.floater)
   

   drawCircle(objects.ball1.body, objects.ball1.shape)
   drawCircle(objects.ball2.body, objects.ball2.shape)
end
