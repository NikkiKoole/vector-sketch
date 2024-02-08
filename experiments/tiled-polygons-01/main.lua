local tp = require ("tiled-polygons")

function love.load()
   tp.newWorld (15, 11, 50) -- width, height, scale
   physicsWorld = love.physics.newWorld( 0, 9800 )
   love.physics.setMeter( 10 )
   lameConvertor()
end

function love.update(dt)
   physicsWorld:update(dt)
   killDynamicsThatAreOffscreen()
end


function love.draw()
   tp.drawWorld ()
   drawPhysicsWorld(physicsWorld)
end

function love.keypressed(key, scancode, isrepeat)
   if key == "escape" then
      love.event.quit()
   end
end

function love.wheelmoved(x, y)
   tp.wheelmoved (x, y)
   lameConvertor()
end

function love.mousemoved(x, y, dx, dy)
   tp.mousemoved (x, y)
end

function love.mousepressed(x, y, button, istouch)
   if button == 1 then
   end
   for i = 1, 10 do
      local ball = love.physics.newBody(physicsWorld, x+i, y-i, "dynamic")
      local shape = love.physics.newCircleShape(0, 0, 12)
      love.physics.newFixture(ball, shape, 1)
   end
end


------

function killDynamicsThatAreOffscreen()
   local bodies = physicsWorld:getBodies()
   local w,h = love.graphics.getDimensions()
   for _, body in ipairs(bodies) do
      if body:getType() == 'dynamic' then
         local bx,by = body:getPosition()
         if by > h then
            body:destroy()
         end
      end
   end
end

function lameConvertor()
   local tiles = tp.getWorld()
   local bodies = physicsWorld:getBodies()

   -- just destroy all the statics
   for _, body in ipairs(bodies) do
      if body:getType() == 'static' then
         body:destroy()
      end
   end

   -- and redo them
   for i = 1, #tiles do
      for j = 1, #tiles[i] do
         if (tiles[i][j].polygon) then
            local b = love.physics.newBody(physicsWorld, 0,0, "static")
            local p = {}
            for v = 1,#tiles[i][j].polygon do
               p[v] = tiles[i][j].polygon[v]*50
            end
            local s = love.physics.newPolygonShape(p)
            local f = love.physics.newFixture(b, s, 1)
         end
      end
   end
end

local function getBodyColor(body)
   if body:getType() == 'kinematic' then
      return { 1, 0, 0, 1 } --palette[colors.peach]
   end
   if body:getType() == 'dynamic' then
      return { 0, 1, 0, 1 } --palette[colors.blue]
   end
   if body:getType() == 'static' then
      return { 1, 1, 0, 1 } --palette[colors.green]
   end
end


function drawPhysicsWorld(world)
   local r, g, b, a = love.graphics.getColor()
   local alpha = .8

   love.graphics.setColor(0, 0, 0, alpha)
   local bodies = world:getBodies()
   love.graphics.setLineWidth(1)
   for _, body in ipairs(bodies) do
      local fixtures = body:getFixtures()

      for _, fixture in ipairs(fixtures) do

         if fixture:getShape():type() == 'PolygonShape' then
            local color = getBodyColor(body)
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            if (fixture:getUserData() ) then 
               if fixture:getUserData().bodyType == "connector" then 
                  love.graphics.setColor(1, 0, 0, alpha)
            end end
            love.graphics.polygon("fill", body:getWorldPoints(fixture:getShape():getPoints()))
            love.graphics.setColor(1, 1, 1, alpha)
            if (fixture:getUserData() ) then 
               if fixture:getUserData().bodyType == "connector" then 
                  love.graphics.setColor(1, 0, 0, alpha)
               end
            end
            love.graphics.polygon('line', body:getWorldPoints(fixture:getShape():getPoints()))
         elseif fixture:getShape():type() == 'EdgeShape' or fixture:getShape():type() == 'ChainShape' then
            love.graphics.setColor(1, 1, 1, alpha)
            local points = { body:getWorldPoints(fixture:getShape():getPoints()) }
            for i = 1, #points, 2 do
               if i < #points - 2 then love.graphics.line(points[i], points[i + 1], points[i + 2], points[i + 3]) end
            end
         elseif fixture:getShape():type() == 'CircleShape' then
            local body_x, body_y = body:getPosition()
            local shape_x, shape_y = fixture:getShape():getPoint()
            local r = fixture:getShape():getRadius()
            local color = getBodyColor(body)
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.circle('fill', body_x + shape_x, body_y + shape_y, r, 360)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.circle('line', body_x + shape_x, body_y + shape_y, r, 360)
         end
      end
   end
   love.graphics.setColor(255, 255, 255, alpha)
   -- Joint debug
   love.graphics.setColor(1, 0, 0, alpha)
   local joints = world:getJoints()
   for _, joint in ipairs(joints) do
      local x1, y1, x2, y2 = joint:getAnchors()
      if x1 and y1 then love.graphics.circle('line', x1, y1, 4) end
      if x2 and y2 then love.graphics.circle('line', x2, y2, 4) end
   end

   love.graphics.setColor(r, g, b, a)
   love.graphics.setLineWidth(1)
end
