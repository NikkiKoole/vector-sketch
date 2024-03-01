
local connect          = require 'lib.connectors'
package.path = package.path .. ";../../?.lua"

local lib = {}
lib.createVehicleUsingDNACreation = function(key, c, x, y)
     local vehicleData = {
         ['scooter']= {
             steeringHeight = c.luleg.h + c.llleg.h,
             floorWidth = math.max(c.lfoot.h * 3, c.torso.w * 1.2),
             radius = 200,
             f = makeScooter
         },
         ['bikeold']= {
             steeringHeight = c.luleg.h + c.llleg.h,
             floorWidth = c.luleg.h + c.llleg.h + c.torso.h,
             radius = 250,
             f = makePedalBike
         },
         ['bus'] = {
             floorWidth = c.luleg.h + c.llleg.h + c.torso.h,
             legLength = c.luleg.h + c.llleg.h,
             radius = 100,
             f = makeBusThing
         },
         ['rollerbladeL'] = {
             floorWidth = c.lfoot.h * 1.3,
             radius = 100,
             connector = 'left',
             f= makeRollerBlade
         },
         ['rollerbladeR'] = {
             floorWidth = c.lfoot.h * 1.3,
             radius = 100,
             connector = 'right',
             f= makeRollerBlade
         },
         ['skate'] = {
             floorWidth = c.lfoot.h * 2.5,
             radius = 100,
             f = makeSkateBoard
         },
         ['bike'] = {
             steeringHeight = c.luleg.h + c.llleg.h,
             floorWidth = c.luleg.h + c.llleg.h + c.torso.h / 1,
             frameHeight = (c.luleg.h + c.llleg.h) / 3,
             radius = math.max((c.luleg.h + c.llleg.h) / 2),
             f = makeBike2
         },
         ['connectLess'] = {
             radius = (c.luleg.h + c.llleg.h) / 2,
             floorWidth = (c.lfoot.h) * 2 + ((c.luleg.h + c.llleg.h)),
             footH = c.lfoot.h,
             footW = c.lfoot.w,
             f= makeConnectLess
         }
     }
     local data = vehicleData[key]
     local bike = data.f(x,y,data)
     return bike, data
 end

 local function makeUserData(bodyType, moreData)
     local result = {
         bodyType = bodyType,
     }
     if moreData then
         result.data = moreData
     end
     return result
 end



 function makeBusThing(x, y, data)
     local floorWidth = data.floorWidth or data.radius
     local radius = data.radius
     local ball1 = {}
     ball1.body = love.physics.newBody(world, x + floorWidth / 3, y + 100, "dynamic")
     ball1.shape = love.physics.newCircleShape(radius)
     ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)
     ball1.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball1.fixture:setFriction(1)
     ball1.body:setAngularVelocity(10000)

     local ball2 = {}
     ball2.body = love.physics.newBody(world, x - floorWidth / 3, y + 100, "dynamic")
     ball2.shape = love.physics.newCircleShape(radius)
     ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
     ball2.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball2.fixture:setFriction(1)
     ball2.body:setAngularVelocity(10000)

     local frame = {}
     frame.body = love.physics.newBody(world, x, y, "dynamic")
     frame.shape = makeCarShape(floorWidth, 200, 0, 0) -- love.physics.newRectangleShape(floorWidth, 300)
     frame.fixture = love.physics.newFixture(frame.body, frame.shape, 1)
     frame.fixture:setUserData(makeUserData("frame"))


     local back = {}
     back.shape = love.physics.newRectangleShape(-floorWidth / 2, -400, 100, 400)
     back.fixture = love.physics.newFixture(frame.body, back.shape, 1)

     --local back = {}
     --back.shape = love.physics.newRectangleShape(floorWidth/3,-400,100, 100)
     --back.fixture = love.physics.newFixture(frame.body, back.shape, 1)


     local seat = {}
     local seatXOffset = -200
     local seatYOffset = -300
     -- seat.body = love.physics.newBody(world, x+seatXOffset, y + seatYOffset, "dynamic")
     -- seat.shape = love.physics.newRectangleShape(seatXOffset,   seatYOffset, 100, 100)
     -- seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)

     connect.makeAndAddConnector(frame.body, seatXOffset, seatYOffset, { type = 'seat' }, 100, 100)
     connect.makeAndAddConnector(frame.body, seatXOffset, seatYOffset, { type = 'seat' }, 100, 100)
     connect.makeAndAddConnector(frame.body, seatXOffset, seatYOffset, { type = 'seat' }, 100, 100)


     connect.makeAndAddConnector(frame.body, seatXOffset + data.legLength * 0.75, seatYOffset, { type = 'feet' }, 100, 100)
     -- connect.makeAndAddConnector(frame.body, seatXOffset,  seatYOffset, { type = 'seat' }, 100, 100)

     local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
     local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


     return { frontWheel = ball1, backWheel = ball2, frame = frame }
 end

 function makeConnectLess(x, y, data)
     local floorWidth = data.floorWidth
     local radius = data.radius
     print(data.footW, data.footH)
     print(inspect(data))

     local ball1 = {}
     ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
     ball1.shape = love.physics.newCircleShape(radius)
     ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)
     ball1.fixture:setFriction(.10)

     local ball2 = {}
     ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
     ball2.shape = love.physics.newCircleShape(radius)
     ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 1)
     --ball2.fixture:setRestitution(.2) -- let the ball bounce
     ball2.fixture:setFriction(.1)

     local frame = {}
     frame.body = love.physics.newBody(world, x, y, "dynamic")
     frame.shape = love.physics.newRectangleShape(floorWidth, 150)
     frame.fixture = love.physics.newFixture(frame.body, frame.shape, 1)
     frame.fixture:setUserData(makeUserData("frame"))
     --frame.fixture:setSensor(true)

     local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
     local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)

     -- now we need a type of hook that will keep feet in place



     --ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")


     if true then
         local shape = love.physics.newPolygonShape(
             0, 0 - data.footW - 150,
             0 + data.footH * 1.5, 0 - data.footW - 150,
             0 + data.footH * 1.5, 0 - 150

         )
         local fixture = love.physics.newFixture(frame.body, shape, 1)
     end
     if false then
         local back = {}
         back.shape = love.physics.newRectangleShape(-data.footH / 2 - 100, -400, 30, 400)
         back.fixture = love.physics.newFixture(frame.body, back.shape, 1)

         local back = {}
         back.shape = love.physics.newRectangleShape(data.footH / 2 + 100, -400, 30, 400)
         back.fixture = love.physics.newFixture(frame.body, back.shape, 1)
     end
     return { frontWheel = ball1, backWheel = ball2, frame = frame }
 end

 function makePedalBike(x, y, data)
     local floorWidth = data.floorWidth or data.radius
     local radius = data.radius

     local ball1 = {}
     ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
     ball1.shape = love.physics.newCircleShape(radius)
     ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)
     ball1.fixture:setFriction(.10)
     --ball1.fixture:setRestitution(.2) -- let the ball bounce
     --ball1.body:setAngularVelocity(10000)

     local ball2 = {}
     ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
     ball2.shape = love.physics.newCircleShape(radius)
     ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 1)
     --ball2.fixture:setRestitution(.2) -- let the ball bounce
     ball2.fixture:setFriction(.1)
     --ball2.body:setAngularVelocity(10000)

     local frame = {}
     frame.body = love.physics.newBody(world, x, y, "dynamic")
     frame.shape = love.physics.newRectangleShape(floorWidth, 150)
     frame.fixture = love.physics.newFixture(frame.body, frame.shape, 1)
     frame.fixture:setUserData(makeUserData("frame"))
     --frame.fixture:setSensor(true)


     local back = {}
     back.shape = love.physics.newRectangleShape(-floorWidth / 2, -400, 300, 400)
     back.fixture = love.physics.newFixture(frame.body, back.shape, 1)


     local groundFeeler = {}
     --groundFeeler.body = love.physics.newBody(world, x, y+600, "dynamic")
     groundFeeler.shape = love.physics.newRectangleShape(0, 750, 10, 10)
     groundFeeler.fixture = love.physics.newFixture(frame.body, groundFeeler.shape, 1)
     groundFeeler.fixture:setSensor(true)

     local seat = {}
     local seatXOffset = -0
     local seatYOffset = -300
     seat.body = love.physics.newBody(world, x + seatXOffset, y - data.steeringHeight / 1.2 + seatYOffset, "dynamic")
     seat.shape = love.physics.newRectangleShape(seatXOffset, -data.steeringHeight / 1.2 + seatYOffset, 100, 100)
     seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)

     connect.makeAndAddConnector(frame.body, seatXOffset, -data.steeringHeight / 1.2 + seatYOffset, { type = 'seat' }, 105,
         105)

     if false then
         local seat2 = {}
         seat2.shape = love.physics.newRectangleShape(-1000, -600, 200, 200)
         seat2.fixture = love.physics.newFixture(frame.body, seat2.shape, 1)
         connect.makeAndAddConnector(frame.body, -1000, -600, {}, 205, 205)
     end

     local steerHeight = data.steeringHeight
     local steer = {}

     steer.shape = love.physics.newRectangleShape(floorWidth / 2, -steerHeight / 2, 10, steerHeight)
     steer.fixture = love.physics.newFixture(frame.body, steer.shape, 0)
     steer.fixture:setSensor(true)

     if true then
         connect.makeAndAddConnector(frame.body, floorWidth / 2 - 40, -steerHeight - 40, {}, 125, 125)
         connect.makeAndAddConnector(frame.body, floorWidth / 2, -steerHeight, {}, 125, 125)
     end


     local pedalRadius = 150
     local connectorRadius = 50
     local connectorD = connectorRadius * 2
     local pedalXOffset = -0
     local pedal = {}
     pedal.body = love.physics.newBody(world, x + pedalXOffset, y - data.steeringHeight * 0.5 + seatYOffset / 2, "dynamic")
     pedal.shape = love.physics.newRectangleShape(pedalRadius * 2, pedalRadius * 2)

     pedal.fixture = love.physics.newFixture(pedal.body, pedal.shape, .1)
     pedal.fixture:setSensor(true)
     pedal.fixture:setFriction(0)
     connect.makeAndAddConnector(pedal.body, -(pedalRadius + connectorRadius), 0, { type = 'lfoot' }, connectorD,
         connectorD)
     connect.makeAndAddConnector(pedal.body, (pedalRadius + connectorRadius), 0, { type = 'rfoot' }, connectorD,
         connectorD)

     local joint1 = love.physics.newRevoluteJoint(frame.body, pedal.body, pedal.body:getX(), pedal.body:getY(), false)
     pedal.fixture:setSensor(true)


     local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
     local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


     joint1:setMotorEnabled(true)
     joint1:setMotorSpeed(-500000)
     joint1:setMaxMotorTorque(20000)


     return {
         frontWheel = ball1,
         backWheel = ball2,
         pedalWheel = pedal,
         frame = frame,
         seat = seat,
         groundFeeler =
             groundFeeler
     }
 end

 function makeScooter(x, y, data)
     local floorWidth = data.floorWidth or data.radius
     local radius = data.radius

     local ball1 = {}
     ball1.body = love.physics.newBody(world, x + floorWidth / 2, y + 150, "dynamic")
     ball1.shape = love.physics.newCircleShape(radius)
     ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 2)
     ball1.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball1.fixture:setFriction(1)
     ball1.body:setAngularVelocity(10000)

     local ball2 = {}
     ball2.body = love.physics.newBody(world, x - floorWidth / 2, y + 150, "dynamic")
     ball2.shape = love.physics.newCircleShape(radius * 1)
     ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
     ball2.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball2.fixture:setFriction(1)
     ball2.body:setAngularVelocity(10000)


     local frame = {}
     frame.body = love.physics.newBody(world, x, y, "dynamic")
     frame.shape = love.physics.newRectangleShape(floorWidth, 100)
     frame.fixture = love.physics.newFixture(frame.body, frame.shape, 12)
     frame.fixture:setUserData(makeUserData("frame"))

     local back = {}
     back.shape = love.physics.newRectangleShape(-floorWidth / 2, -200, 100, 100)
     back.fixture = love.physics.newFixture(frame.body, back.shape, 1)
     --frame.fixture:setSensor(true)
     if false then
         local seat = {}
         seat.shape = love.physics.newRectangleShape(-200, -600, 200, 200)
         seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)
         connect.makeAndAddConnector(frame.body, -200, -600, {}, 205, 205)

         local seat2 = {}
         seat2.shape = love.physics.newRectangleShape(-1000, -600, 200, 200)
         seat2.fixture = love.physics.newFixture(frame.body, seat2.shape, 1)
         connect.makeAndAddConnector(frame.body, -1000, -600, {}, 205, 205)
     end

     --local achterWielSpat = {}
     --achterWielSpat.shape = love.physics.newRectangleShape(-radius/1.4, -500, 20, 500)
     --achterWielSpat.fixture = love.physics.newFixture(frame.body, achterWielSpat.shape, 1)

     local steer = {}
     local steerHeight = data.steeringHeight
     --steer.body = love.physics.newBody(world, x, y, "dynamic")
     steer.shape = love.physics.newRectangleShape(floorWidth / 2, -steerHeight / 2, 10, steerHeight)
     steer.fixture = love.physics.newFixture(frame.body, steer.shape, .1)
     --steer.fixture:setSensor(true)
     connect.makeAndAddConnector(frame.body, floorWidth / 2 - 40, -steerHeight - 40, { type = 'lhand' }, 125, 125)
     connect.makeAndAddConnector(frame.body, floorWidth / 2, -steerHeight, { type = 'rhand' }, 125, 125)


     connect.makeAndAddConnector(frame.body, 0, -100, { type = 'left' }, 100, 100)
     connect.makeAndAddConnector(frame.body, 0, -100, { type = 'right' }, 100, 100)

     if false then
         local pedal = {}
         pedal.body = love.physics.newBody(world, x + radius, y - 500, "dynamic")
         pedal.shape = love.physics.newRectangleShape(300, 300)
         pedal.fixture = love.physics.newFixture(pedal.body, pedal.shape, 1)
         connect.makeAndAddConnector(pedal.body, -150, 0, {}, 150, 150)
         connect.makeAndAddConnector(pedal.body, 150, 0, {}, 150, 150)

         local joint1 = love.physics.newRevoluteJoint(frame.body, pedal.body, pedal.body:getX(), pedal.body:getY(), false)
         pedal.fixture:setSensor(true)
     end

     local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
     local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


     joint1:setMotorEnabled(true)
     joint1:setMotorSpeed(500000)
     joint1:setMaxMotorTorque(20000)


     return { frontWheel = ball1, backWheel = ball2, pedalWheel = pedal, frame = frame, steer = steer }
 end

 function makeRollerBlade(x, y, data)
     local floorWidth = data.floorWidth or data.radius
     floorWidth = floorWidth * 2
     local radius = data.radius

     local ball1 = {}
     ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
     ball1.shape = love.physics.newCircleShape(radius)
     ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 2)
     ball1.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball1.fixture:setFriction(1)

     local groupId = 1
     ball1.fixture:setFilterData(1, 65535, -1 * groupId)
     ball1.body:setAngularVelocity(10000)



     local ball2 = {}
     ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
     ball2.shape = love.physics.newCircleShape(radius * 1)
     ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
     ball2.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball2.fixture:setFriction(1)
     ball2.fixture:setFilterData(1, 65535, -1 * groupId)
     ball2.body:setAngularVelocity(10000)


     local frame = {}
     frame.body = love.physics.newBody(world, x, y, "dynamic")
     frame.shape = love.physics.newRectangleShape(floorWidth, 50)
     frame.fixture = love.physics.newFixture(frame.body, frame.shape, 2)
     --frame.fixture:setSensor(true)
     -- frame.fixture:setFilterData(1, 65535, -1 * groupId)
     frame.fixture:setUserData(makeUserData("frame"))

     connect.makeAndAddConnector(frame.body, 0, 0, { type = data.connector }, floorWidth / 1.5, 100 + 50)
     local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
     local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


     return { frontWheel = ball1, backWheel = ball2, frame = frame }
 end

 function makeSkateBoard(x, y, data)
     local floorWidth = data.floorWidth or data.radius

     local radius = data.radius

     local ball1 = {}
     ball1.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
     ball1.shape = love.physics.newCircleShape(radius)
     ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 2)
     ball1.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball1.fixture:setFriction(1)

     local groupId = 1
     ball1.fixture:setFilterData(1, 65535, -1 * groupId)
     ball1.body:setAngularVelocity(10000)



     local ball2 = {}
     ball2.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
     ball2.shape = love.physics.newCircleShape(radius * 1)
     ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 2)
     ball2.fixture:setRestitution(.2) -- let the ball bounce
     --ball.fixture:setUserData(phys.makeUserData("ball"))
     --ball2.fixture:setFriction(1)
     ball2.fixture:setFilterData(1, 65535, -1 * groupId)
     ball2.body:setAngularVelocity(10000)


     local frame = {}
     frame.body = love.physics.newBody(world, x, y, "dynamic")
     frame.shape = love.physics.newRectangleShape(floorWidth, 50)
     frame.fixture = love.physics.newFixture(frame.body, frame.shape, 2)
     --frame.fixture:setSensor(true)
     -- frame.fixture:setFilterData(1, 65535, -1 * groupId)
     frame.fixture:setUserData(makeUserData("frame"))

     connect.makeAndAddConnector(frame.body, -floorWidth / 4, -100, { type = 'left' }, 100, 100)
     connect.makeAndAddConnector(frame.body, -floorWidth / 4 + 200, -100, { type = 'right' }, 100, 100)

     local joint1 = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
     local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


     return { frontWheel = ball1, backWheel = ball2, frame = frame }
 end

 function makeBikeFrameShape(w, h, cx, cy)
     return love.physics.newPolygonShape(
         cx - w / 2, cy - h / 2,
         cx - w / 2, cy + h / 2,
         cx, cy + h / 2,
         cx + w / 2, cy,
         cx + w / 2, cy - h,
         cx, cy - h / 2
     )
 end

 function makeBike2(x, y, data)
     local floorWidth = data.floorWidth or data.radius

     local frameHeight = data.frameHeight
     local radius = data.radius
     local frame = {}
     frame.body = love.physics.newBody(world, x, y, "dynamic")
     frame.shape = makeBikeFrameShape(floorWidth, frameHeight, 0, 0)
     frame.fixture = love.physics.newFixture(frame.body, frame.shape, 1)
     frame.fixture:setUserData(makeUserData("frame"))


     local groundFeeler = {}
     --groundFeeler.body = love.physics.newBody(world, x, y+600, "dynamic")
     groundFeeler.shape = love.physics.newRectangleShape(0, 1750, 10, 10)
     groundFeeler.fixture = love.physics.newFixture(frame.body, groundFeeler.shape, 1)
     groundFeeler.fixture:setSensor(true)

     local ball1 = {}
     ball1.body = love.physics.newBody(world, x - floorWidth / 2, y, "dynamic")
     ball1.shape = love.physics.newCircleShape(radius)
     ball1.fixture = love.physics.newFixture(ball1.body, ball1.shape, 1)

      -- ball1.fixture:setFriction(1)

     local ball2 = {}
     ball2.body = love.physics.newBody(world, x + floorWidth / 2, y, "dynamic")
     ball2.shape = love.physics.newCircleShape(radius)
     ball2.fixture = love.physics.newFixture(ball2.body, ball2.shape, 1)
   --  ball2.fixture:setFriction(1)

     local seat = {}
     local seatYOffset = 0 --radius * .5
     local seatXOffset = 0 --radius --* .5
     seat.body = love.physics.newBody(world, x + seatXOffset, y - frameHeight + seatYOffset, "dynamic")
     seat.shape = love.physics.newRectangleShape(seatXOffset, -frameHeight + seatYOffset, 100, 100)
     seat.fixture = love.physics.newFixture(frame.body, seat.shape, 1)
     connect.makeAndAddConnector(frame.body, seatXOffset, -frameHeight + seatYOffset, { type = 'seat' }, 105, 105)

     local wheelJoint = love.physics.newRevoluteJoint(frame.body, ball1.body, ball1.body:getX(), ball1.body:getY(), false)
     local joint2 = love.physics.newRevoluteJoint(frame.body, ball2.body, ball2.body:getX(), ball2.body:getY(), false)


     local pedalRadius = 100 --== radius / 2
     local connectorRadius = pedalRadius / 3
     local connectorD = connectorRadius * 2
     local pedalXOffset = floorWidth / 5 --radius * .5
     local pedalYOffset = 0              -- radius * .5
     local pedal = {}
     pedal.body = love.physics.newBody(world, x + pedalXOffset, y + pedalYOffset, "dynamic")
     pedal.shape = love.physics.newCircleShape(pedalRadius)

     pedal.fixture = love.physics.newFixture(pedal.body, pedal.shape, 10)
     pedal.fixture:setSensor(true)
     --
     connect.makeAndAddConnector(pedal.body, -(pedalRadius + connectorRadius), 0, { type = 'lfoot' }, connectorD,
         connectorD)
     connect.makeAndAddConnector(pedal.body, (pedalRadius + connectorRadius), 0, { type = 'rfoot' }, connectorD,
         connectorD)

     local pedalJoint = love.physics.newRevoluteJoint(frame.body, pedal.body, pedal.body:getX(), pedal.body:getY(), false)

     joint = love.physics.newGearJoint(wheelJoint, pedalJoint, -1.0, false)

     return {
         frontWheel = ball1,
         backWheel = ball2,
         frame = frame,
         seat = seat,
         pedalWheel = pedal,
         groundFeeler = groundFeeler
     }
 end

 function makeCarShape2(w, h, cx, cy)
     return love.physics.newPolygonShape(
         cx - w / 2, cy - h / 2,
         cx - w / 2, cy + h / 2 - h / 5,
         cx - w / 2 + w / 8, cy + h / 2,
         cx + w / 2 - w / 8, cy + h / 2,
         cx + w / 2, cy + h / 2 - h / 5,
         cx + w / 2, cy - h / 2
     )
 end

 function makeCarShape(w, h, cx, cy)
     return love.physics.newPolygonShape(
         cx + w / 2 - w / 3, cy - h,
         cx - w / 2, cy - h,
         cx - w / 2, cy - h / 2,
         cx - w / 2, cy + h / 2 - h / 5,
         cx - w / 2 + w / 8, cy + h / 2,
         cx + w / 2 - w / 8, cy + h / 2,
         cx + w / 2, cy + h / 2 - h / 5,
         cx + w / 2, cy - h / 2

     )
 end


 return lib
