package.path = package.path .. ";../../?.lua"

local lurker = require 'vendor.lurker'
lurker.quiet = true
require 'palette'

lurker.postswap = function(f)
    print("File " .. f .. " was swapped")
    grabDevelopmentScreenshot()
end

function grabDevelopmentScreenshot()
    love.graphics.captureScreenshot('ScreenShot-' .. os.date("%Y-%m-%d-[%H-%M-%S]") .. '.png')
    local openURL = "file://" .. love.filesystem.getSaveDirectory()
    love.system.openURL(openURL)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end



-- https://www.iforce2d.net/b2dtut/one-way-walls
-- in the original tutorial they hack box3d to stop reenabling contacts every frame, i cannot do that. so i must keep a list around.
local disabledContacts = {}

function beginContact(a, b, contact)
    local ab =  a:getBody()
    local bb =  b:getBody()
    -- if the collision is with a thing that has a mousejoint (in other words if we are dragging it with the mopuse)
    local withMouseDraggedObject = false
    if (mouseJoints.jointBody) then
        if (ab == mouseJoints.jointBody or bb == mouseJoints.jointBody) then
                --print('begin colliding with amousedragged item')
                withMouseDraggedObject = true
                --contact:setEnabled( false )
                table.insert(disabledContacts, contact)
        end
    end

    if not  withMouseDraggedObject then 
        --print('vanilla')
    end

  
end

function endContact(a, b, contact)
    for i = #disabledContacts, 1, -1 do
        if disabledContacts[i] == contact then
            table.remove(disabledContacts, i)
        end
    end 
   -- print(#disabledContacts)
end

function preSolve(a, b, contact)
    for i =1, #disabledContacts do
       disabledContacts[i]:setEnabled(false)
    end

end

function postSolve(a, b, contact, normalimpulse, tangentimpulse)
    
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

function love.load()
    local font = love.graphics.newFont('WindsorBT-Roman.otf', 48)
    love.graphics.setFont(font)

    vlooienspel = love.graphics.newImage('vlooienspel.jpg')

    local width = 800
    local height = 600

    love.physics.setMeter(100)

    world = love.physics.newWorld(0, 9.81 * love.physics.getMeter(), true)
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)

    objects = {}
    objects.border = {}
    objects.border.body = love.physics.newBody(world, 0, 0)

    margin = 20
    --angularVelocity = 5
    objects.border.shape = love.physics.newChainShape(true,
            margin, margin,
            width - margin, margin,
            width - margin, height - margin,
            margin, height - margin)

    objects.border.fixture = love.physics.newFixture(objects.border.body, objects.border.shape)
    objects.border.fixture:setUserData("border")
    objects.border.fixture:setFriction(.5)

    ballRadius = love.physics.getMeter() / 2




    objects.ball = {}
    objects.ball.body = love.physics.newBody(world, width / 2, height / 2, "dynamic")
    
    objects.ball.body:setFixedRotation(true)
    --objects.ball.shape = love.physics.newPolygonShape(capsule(ballRadius + love.math.random() * 20, ballRadius + love.math.random() * 20, 5))
    objects.ball.shape =  love.physics.newCircleShape(ballRadius)
    objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1)
    objects.ball.fixture:setRestitution(.4) -- let the ball bounce
    objects.ball.fixture:setUserData("ball")
    objects.ball.fixture:setFriction(.5)

    if true then
        objects.ball2 = {}
        objects.ball2.body = love.physics.newBody(world, 100 + width / 2, height / 2, "dynamic")
        
        objects.ball2.body:setFixedRotation(true)
        --objects.ball.shape = love.physics.newPolygonShape(capsule(ballRadius + love.math.random() * 20, ballRadius + love.math.random() * 20, 5))
        objects.ball2.shape =  love.physics.newCircleShape(ballRadius)
        objects.ball2.fixture = love.physics.newFixture(objects.ball2.body, objects.ball2.shape, 1)
        objects.ball2.fixture:setRestitution(.4) -- let the ball bounce
        objects.ball2.fixture:setUserData("ball")
        objects.ball2.fixture:setFriction(.5)

    end

    --objects.ball.fixture:setDensity(3)
    -- objects.ball.body:setLinearDamping(5)


    angularVelocity = 2
    objects.carousel = {}
    objects.carousel.body = love.physics.newBody(world, width / 2, height / 2, "kinematic")
    objects.carousel.shape = love.physics.newRectangleShape(width / 5, width / 10)
    objects.carousel.fixture = love.physics.newFixture(objects.carousel.body, objects.carousel.shape, 1)
    objects.carousel.body:setAngularVelocity(angularVelocity)
    objects.carousel.fixture:setUserData("caroussel")



    objects.ground = {}
    objects.ground.body = love.physics.newBody(world, width/2, height  - (height/10), "static")
    objects.ground.shape = love.physics.newRectangleShape(width, height/10)
    objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 1)
    objects.ground.fixture:setUserData("ground")

    if false then
    objects.ground2 = {}
    objects.ground2.body = love.physics.newBody(world, width/2, height  - (height/10) + 10, "static")
    objects.ground2.shape = love.physics.newRectangleShape(width, height/10)
    objects.ground2.fixture = love.physics.newFixture(objects.ground2.body, objects.ground2.shape, 1)
    objects.ground2.fixture:setUserData("ground")
    end


    mouseJoints = {
        joint = nil,
        jointBody = nil
    }


    love.graphics.setBackgroundColor(palette[colors.light_cream][1], palette[colors.light_cream][2],
        palette[colors.light_cream][3])
    love.window.setMode(width, height, { resizable = true })

    --grabDevelopmentScreenshot()
end

function killMouseJointIfPossible()
    if (mouseJoints.joint) then
        mouseJoints.joint:destroy()
        mouseJoints.joint     = nil
        mouseJoints.jointBody = nil
    end
end

function love.mousereleased()
    killMouseJointIfPossible()
end

function love.mousepressed(x, y)

    local bodies = {objects.ball.body, objects.ball2.body}
    local hit = false
    for i = 1, #bodies do
            local body = bodies[i]
        local bx, by = body:getPosition()
        local dx, dy = x - bx, y - by
        local distance = math.sqrt(dx * dx + dy * dy)

        if (distance < ballRadius) then
            mouseJoints.jointBody = body
            mouseJoints.joint = love.physics.newMouseJoint(mouseJoints.jointBody, x, y)
            mouseJoints.joint:setDampingRatio(.5)
            body:applyLinearImpulse( 0, 1000 )  -- so you can drag it through the floor from  there!!
            hit = true

        end
    end 
    if hit == false then killMouseJointIfPossible() end
end

function drawThing(thing)
    
    local cx, cy = thing.body:getWorldCenter()
    local d = thing.fixture:getDensity()
    local t = thing.body:getType()

    local shape = thing.shape
    local body = thing.body

    if t == 'kinematic' then
        love.graphics.setColor(palette[colors.peach][1], palette[colors.peach][2], palette[colors.peach][3])  
    elseif (t == 'dynamic') then
        love.graphics.setColor(palette[colors.blue][1], palette[colors.blue][2], palette[colors.blue][3])  
    elseif (t == 'static') then
        love.graphics.setColor(palette[colors.green][1], palette[colors.green][2], palette[colors.green][3])  
    end
    
    if ( shape:getType( ) == 'polygon') then
        love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
        love.graphics.setColor(palette[colors.black][1], palette[colors.black][2], palette[colors.black][3])  
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
    end

    if ( shape:getType( ) == 'circle') then
        love.graphics.setColor(palette[colors.orange][1], palette[colors.orange][2], palette[colors.orange][3])
        love.graphics.circle("fill", body:getX(), body:getY(), shape:getRadius())
        love.graphics.setColor(palette[colors.black][1], palette[colors.black][2], palette[colors.black][3])
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", body:getX(), body:getY(), shape:getRadius())
    end
  
   
end



function drawCenteredBackgroundText(str)
    local width, height = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local textw, wrappedtext = font:getWrap(str, width)
    local texth = font:getHeight() * #wrappedtext
    love.graphics.print(str, width / 2 - textw / 2, height / 2 - texth / 2)
end

function love.draw()
    local width, height = love.graphics.getDimensions()
    drawMeterGrid()

    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
    love.graphics.rectangle("fill", 0, 0, width, margin)
    love.graphics.rectangle("fill", 0, height - margin, width, margin)
    love.graphics.rectangle("fill", 0, 0, margin, height)
    love.graphics.rectangle("fill", width - margin, 0, margin, height)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(vlooienspel, width / 2, height / 4, 0, 1, 1,
        vlooienspel:getWidth() / 2, vlooienspel:getHeight() / 2)
    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3])
    drawCenteredBackgroundText('Pull back to aim and shoot.')
    drawThing(objects.carousel)
    drawThing(objects.ground)
    --drawThing(objects.ground2)
    drawThing(objects.ball)
    drawThing(objects.ball2)
    --drawCircle(objects.ball.body, objects.ball.shape)
end

function drawMeterGrid()
    local width, height = love.graphics.getDimensions()
    local ppm = love.physics.getMeter()
    love.graphics.setColor(palette[colors.cream][1], palette[colors.cream][2], palette[colors.cream][3], 0.2)
    for x = 0, width, ppm do
        love.graphics.line(x, 0, x, height)
    end
    for y = 0, height, ppm do
        love.graphics.line(0, y, width, y)
    end
end

function love.update(dt)
    lurker.update()
    if (mouseJoints.joint) then
        mouseJoints.joint:setTarget(love.mouse.getPosition())
    end
    world:update(dt)
end
