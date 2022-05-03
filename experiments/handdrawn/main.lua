

function CreateTexturedCircle(image, segments)
	segments = segments or 40
	local vertices = {}
	
	-- The first vertex is at the center, and has a red tint. We're centering the circle around the origin (0, 0).
	table.insert(vertices, {0, 0, 0.5, 0.5, 255, 255,255})
	
	-- Create the vertices at the edge of the circle.
	for i=0, segments do
		local angle = (i / segments) * math.pi * 2

		-- Unit-circle.
		local x = math.cos(angle)
		local y = math.sin(angle)
		
		-- Our position is in the range of [-1, 1] but we want the texture coordinate to be in the range of [0, 1].
		local u = (x + 1) * 0.5
		local v = (y + 1) * 0.5
		
		-- The per-vertex color defaults to white.
		table.insert(vertices, {x, y, u, v})
	end
	
	-- The "fan" draw mode is perfect for our circle.
	local mesh = love.graphics.newMesh(vertices, "fan")
        mesh:setTexture(image)

        return mesh
end

function createTexturedRectangle(image)
   local w, h = image:getDimensions( )
   print(w,h)
   local vertices = {}
   -- x,y,u,v,r,g,b,
   table.insert(vertices, {0,     0,   0.5, 0.5, 0, 0, 0})
   table.insert(vertices, {-w/2, -h/2, 0, 0, 0, 0, 0})
   table.insert(vertices, { w/2, -h/2, 1, 0, 0, 0, 0})
   table.insert(vertices, { w/2,  h/2, 1, 1, 0, 0, 0})
   table.insert(vertices, {-w/2,  h/2, 0, 1, 0, 0, 0})


   --simple_format = {
   --   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
  -- }
   
   local mesh = love.graphics.newMesh(vertices, "fan")
   mesh:setTexture(image)

   return mesh
end

function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end



function love.load()
   success = love.window.setMode( 2048,768, {highdpi=true, vsync=false} )
   image = love.graphics.newImage("cactuss2.png", {mipmaps=true})
   image:setMipmapFilter( 'nearest', -1 )
   mesh = createTexturedRectangle(image)

end

function love.draw()
--	local radius = 400
	local mx, my = love.mouse.getPosition()

	love.graphics.clear(.4,.5,.4)
	-- We created a unit-circle, so we can use the scale parameter for the radius directly.
	local w, h = image:getDimensions( )
	--mesh:setVertex( 1, love.math.random()*140, -h/2 + love.math.random()*100)
	love.graphics.draw(mesh, mx, my, 0, 1, 1)
	love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)

	local stats = love.graphics.getStats()
	
	--print('#images', stats.images)
	--print('img mem', stats.texturememory)
	--print('#draw calls', stats.drawcalls)

end
