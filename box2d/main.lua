inspect = require "inspect"

function love.load()
   local width = 1024
   local height = 768
   -- the height of a meter our worlds will be 64px
   love.physics.setMeter(100)
   world = love.physics.newWorld(0, 9.81*100, true)
   world:setCallbacks(beginContact, endContact, preSolve, postSolve)
   objects = {}
   objects.border = {}
   objects.border.body = love.physics.newBody(world,0,0)
   local margin = 20
   objects.border.shape = love.physics.newChainShape( true,
						      margin,margin,
						      width-margin,margin,
						      width-margin,height-margin,
						      margin,height-margin )
   --objects.border.shape = love.physics.newChainShape( true, 0,0, width,0, width,height, 0,height )
   objects.border.fixture = love.physics.newFixture(objects.border.body, objects.border.shape)
   objects.border.fixture:setUserData("wall")


   -- objects.ground = {}
   -- objects.ground.body = love.physics.newBody(world, width/2, height-50/2)
   -- objects.ground.shape = love.physics.newRectangleShape(width, 50)
   -- objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape)
   -- objects.ground.fixture:setUserData("wall")
   
   -- objects.top = {}
   -- objects.top.body = love.physics.newBody(world, width/2, 0)
   -- objects.top.shape = love.physics.newRectangleShape(width, 50)
   -- objects.top.fixture = love.physics.newFixture(objects.top.body, objects.top.shape)
   -- objects.top.fixture:setUserData("wall")

   
   -- objects.left = {}
   -- objects.left.body = love.physics.newBody(world, 0, height/2)
   -- objects.left.shape = love.physics.newRectangleShape(50, height)
   -- objects.left.fixture = love.physics.newFixture(objects.left.body, objects.left.shape)
   -- objects.left.fixture:setUserData("wall")

   
   -- objects.right = {}
   -- objects.right.body = love.physics.newBody(world, width, height/2)
   -- objects.right.shape = love.physics.newRectangleShape(50, height)
   -- objects.right.fixture = love.physics.newFixture(objects.right.body, objects.right.shape)
   -- objects.right.fixture:setUserData("wall")

   
   objects.ball = {}
   objects.ball.body = love.physics.newBody(world, width/2, height/2, "dynamic")
   objects.ball.shape = love.physics.newCircleShape(20)
   objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1)
   --objects.ball.fixture:setRestitution(0.5) -- let the ball bounce
   objects.ball.fixture:setUserData("ball")
   objects.ball.fixture:setDensity(3)
   -- let's create a couple blocks to play around with

   objects.blocks = {}
   for i=1, 50 do
      local block = {
	 body = love.physics.newBody(
	    world,
	    50 + love.math.random()*width,
	    50 + love.math.random()*height, "dynamic"),
	 --shape = love.physics.newRectangleShape(0, 0, 25, 25)
	 --shape = love.physics.newPolygonShape( 0,-10, 10,10 , -10, 10)
	 shape = love.physics.newPolygonShape(capsule(20 + love.math.random() * 20, 10 + love.math.random() * 20, 5))
	 --shape = love.physics.newCircleShape(20)

      }
      block.fixture = love.physics.newFixture(block.body,
					      block.shape,
					      love.math.random()*10)
      
      table.insert(objects.blocks, block)
   end

   love.graphics.setBackgroundColor(0.41, 0.53, 0.97)
   love.window.setMode(width, height) -- set the window dimensions to 650 by 650

   ppm = 64

   local soundData = love.sound.newSoundData( 'mallet2-c4.wav' )
   sound = love.audio.newSource(soundData, 'static')
   local soundData2 = love.sound.newSoundData( 'mallet2-c2.wav' )
   sound2 = love.audio.newSource(soundData2, 'static')

   joint = nil 
end

function love.mousereleased()
   if (joint) then
      joint:destroy()
       joint = nil
   end
   
end


function love.mousepressed(x,y)
   local bx, by = objects.ball.body:getPosition()
   local dx, dy = x-bx, y-by
   local distance = math.sqrt(dx*dx + dy*dy)
   if (distance < 20) then
      joint = love.physics.newMouseJoint( objects.ball.body, x, y )
      joint:setDampingRatio( 1 )
   else
      if (joint) then
	 joint:destroy()
	 joint = nil
      end
   end
   --print(x,y, objects.ball.body:getPosition())
   
   
end



-- https://love2d.org/wiki/Tutorial:PhysicsCollisionCallbacks

function beginContact(a, b, coll)
   --
   local x1, y1 = a:getBody():getLinearVelocity()
   local x2, y2 = b:getBody():getLinearVelocity()
   local total = math.abs(x1+x2+y1+y2)
   if total > 100 then
      local s
      local p = 1
      if (a:getUserData() == 'ball' or b:getUserData() == 'ball' ) then
	 s = sound2:clone()
	 p = 1 + math.random()/(2000/total)
	 s:setPitch(p)
      else 
      
	 s = sound:clone()
	 s:setVolume(0.5)
	 p = 1 + math.random()/(3000/total)
	 s:setPitch(p)

      end
      
      

     
      local x,y = coll:getNormal()
      s:setPosition( -x,y,0 )
      love.audio.play(s)
   end
    --end
end

function endContact(a, b, coll)
  
end

function preSolve(a, b, coll)

end

function postSolve(a, b, coll, normalimpulse, tangentimpulse)

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
   if (joint) then
      joint:setTarget(love.mouse.getPosition())

   end
   
   world:update(dt) -- this puts the world into motion

   -- here we are going to create some keyboard events
   -- press the right arrow key to push the ball to the right
   -- if love.keyboard.isDown("right") then
   --    objects.ball.body:applyForce(400, 0)
   -- end
   -- if love.keyboard.isDown("left") then
   --    objects.ball.body:applyForce(-400, 0)
   -- end

   -- if love.keyboard.isDown("up") then
   --    objects.ball.body:applyForce(0, -400)
   -- end

   -- if love.keyboard.isDown("down") then
   --    objects.ball.body:applyForce(0, 400)
   -- end

   if love.keyboard.isDown("p") then
      local x,y  = world:getGravity()
      for i = 1, #objects.blocks do
	 local b = objects.blocks[i].body
	 b:setAwake(true) -- this solves the objects sticking
      end
      
      world:setGravity(0, y*-1)
   end

   if love.keyboard.isDown("escape") then
      love.event.quit()
   end

   -- local contacts = world:getContacts( )
   -- for i = 1, #contacts do
   --    local indexA, indexB =  contacts[i]:getChildren( )
   --    local touching = contacts[i]:isTouching( )
   --    print(indexA, indexB, touching)
   -- end


end

function drawBlock(thing)
   local d = thing.fixture:getDensity()
   love.graphics.setColor(0.20*(d*3), 1.0 - d*5, 0.20)
   love.graphics.polygon("fill", thing.body:getWorldPoints(thing.shape:getPoints()))
   love.graphics.setColor(1, 0.5, 0.20)
   love.graphics.setLineWidth(3)
   love.graphics.polygon("line", thing.body:getWorldPoints(thing.shape:getPoints()))

   --love.graphics.setColor(0, 0, 0)
   --love.graphics.setLineWidth(2)
   --local topLeftX, topLeftY, bottomRightX, bottomRightY = thing.fixture:getBoundingBox(1 )
   --love.graphics.rectangle("line", topLeftX, topLeftY, bottomRightX - topLeftX, bottomRightY - topLeftY)

end

function drawPolygon(body, fixture, shape)
   local d = fixture:getDensity()
   love.graphics.setColor(0.20*(d*3), 1.0 - d*5, 0.20)
   love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
   love.graphics.setColor(1, 0.5, 0.20)
   love.graphics.setLineWidth(3)
   love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))

   -- love.graphics.setColor(0, 0, 0)
   -- love.graphics.setLineWidth(2)
   -- local topLeftX, topLeftY, bottomRightX, bottomRightY = thing.fixture:getBoundingBox(1 )
   -- love.graphics.rectangle("line", topLeftX, topLeftY, bottomRightX - topLeftX, bottomRightY - topLeftY)
end

function drawCircle(body, shape)
   love.graphics.setColor(233/255,100/255,14/255)
   love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
   love.graphics.setColor(1, 0.5, 0.20)
   love.graphics.setLineWidth(3)
   love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
end

function love.draw()
   local width, height = love.graphics.getDimensions()
   local m = 20

   love.graphics.setColor(14/255,100/255,14/255)
   love.graphics.rectangle("fill", 0,0, width, m)
   love.graphics.rectangle("fill", 0,height-m, width, m)
   love.graphics.rectangle("fill", 0,0, m, height)
   love.graphics.rectangle("fill", width-m,0, m, height)
   
   -- drawBlock(objects.top)
   -- drawBlock(objects.ground)
   -- drawBlock(objects.left)
   -- drawBlock(objects.right)
  
   drawCircle(objects.ball.body, objects.ball.shape)
   for i =1, #objects.blocks do
       drawBlock(objects.blocks[i])
   end
   if (joint) then
      love.graphics.setColor(0,0,0)
      love.graphics.setLineWidth(2)
      local mx, my = love.mouse.getPosition()
      local bx, by = objects.ball.body:getPosition()
      love.graphics.line(mx,my,bx,by)
   end
   
   
   -- local contacts = world:getContacts( )
   -- love.graphics.setColor(1, 1, 1)
   -- for i=1, #contacts do
   --    x1, y1, x2, y2 = contacts[i]:getPositions( )
   --    if (x1 and y1) then
   -- 	 love.graphics.circle("fill", x1 , y1 , 2)
   --    end
   --    if (x2 and y2) then
   -- 	 love.graphics.circle("fill", x2 , y2 , 2)
   --    end

   -- end
end
