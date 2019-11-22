inspect = require "inspect"

function love.load()
   -- the height of a meter our worlds will be 64px
   love.physics.setMeter(64)
   world = love.physics.newWorld(0, 9.81*64, true)

   objects = {}
   objects.ground = {}
   objects.ground.body = love.physics.newBody(world, 650/2, 650-50/2)
   objects.ground.shape = love.physics.newRectangleShape(650, 50)
   objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape)

   objects.top = {}
   objects.top.body = love.physics.newBody(world, 650/2, 0)
   objects.top.shape = love.physics.newRectangleShape(650, 50)
   objects.top.fixture = love.physics.newFixture(objects.top.body, objects.top.shape)

   objects.left = {}
   objects.left.body = love.physics.newBody(world, 0, 650/2)
   objects.left.shape = love.physics.newRectangleShape(50, 650)
   objects.left.fixture = love.physics.newFixture(objects.left.body, objects.left.shape)

   objects.right = {}
   objects.right.body = love.physics.newBody(world, 650, 650/2)
   objects.right.shape = love.physics.newRectangleShape(50, 650)
   objects.right.fixture = love.physics.newFixture(objects.right.body, objects.right.shape)



   objects.ball = {}
   objects.ball.body = love.physics.newBody(world, 650/2, 650/2, "dynamic")
   objects.ball.shape = love.physics.newCircleShape(20)
   objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1)
   objects.ball.fixture:setRestitution(0.4) -- let the ball bounce

   -- let's create a couple blocks to play around with

   objects.blocks = {}
   for i=1, 50 do
      local block = {
	 body = love.physics.newBody(
	    world,
	    50 + love.math.random()*600,
	    50 + love.math.random()*600, "dynamic"),
	 --shape = love.physics.newRectangleShape(0, 0, 25, 25)
	 --shape = love.physics.newPolygonShape( 0,-10, 10,10 , -10, 10)
	 shape = love.physics.newPolygonShape(capsule(10 + love.math.random() * 20, 10 + love.math.random() * 20, 5))

      }
      block.fixture = love.physics.newFixture(block.body, block.shape, love.math.random()*1)
      table.insert(objects.blocks, block)
   end

   love.graphics.setBackgroundColor(0.41, 0.53, 0.97)
   love.window.setMode(650, 650) -- set the window dimensions to 650 by 650

   ppm = 64
end

function capsule(w, h, cs)
   -- cs == cornerSize
   local w2 = w/2
   local h2 = h/2
   local bt = -h2 + cs
   local bb = h2 - cs
   local bl = -w2 + cs
   local br = w2 - cs

   local result = {
	 -w2, bt,
	 bl, -h2,
	 br, -h2,
	 w2, bt,
	 w2, bb,
	 br, h2,
	 bl, h2,
	 -w2, bb
   }
   return result

end



function love.update(dt)
   world:update(dt) -- this puts the world into motion

   -- here we are going to create some keyboard events
   -- press the right arrow key to push the ball to the right
   if love.keyboard.isDown("right") then
      objects.ball.body:applyForce(400, 0)
   elseif love.keyboard.isDown("left") then
      objects.ball.body:applyForce(-400, 0)
   elseif love.keyboard.isDown("up") then
      objects.ball.body:applyForce(0, -400)
   elseif love.keyboard.isDown("down") then
      objects.ball.body:applyForce(0, 400)
   elseif love.keyboard.isDown("p") then
      local x,y  = world:getGravity()
      world:setGravity(0, y*-1)
   elseif love.keyboard.isDown("escape") then
      love.event.quit()
   end




end

function drawPolygon(body, fixture, shape, hit)
   local d = fixture:getDensity()
   love.graphics.setColor(0.20*(d*3), 1.0 - d*5, 0.20)
   love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
   love.graphics.setColor(1, 0.5, 0.20)
   if hit then
      love.graphics.setColor(1, 1, 1)
   end

   love.graphics.setLineWidth(3)
   love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
end

function drawCircle(body, shape)
   love.graphics.setColor(0.20, 0.20, 0.20)
   love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
   love.graphics.setColor(1, 0.5, 0.20)
   love.graphics.setLineWidth(3)
   love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
end

function addToSet(set, key)
    set[key] = true
end

function removeFromSet(set, key)
    set[key] = nil
end

function setContains(set, key)
    return set[key] ~= nil
end


function love.draw()
   local contacts = world:getContacts( )
   local fixturesInContact = {}

   for i = 1, #contacts do
      local fixtureA, fixtureB = contacts[i]:getFixtures( )
      addToSet(fixturesInContact, fixtureA)
      addToSet(fixturesInContact, fixtureB)
   end

   for _, body in pairs(world:getBodies()) do
      for _, fixture in pairs(body:getFixtures()) do
	 local shape = fixture:getShape()
	 local type = shape:getType()
	 if (type == 'polygon') then

	    drawPolygon(body, fixture, shape,  setContains(fixturesInContact, fixture) )
	 elseif type == "circle" then
	    drawCircle(body, shape)
	 end
      end
   end

end
