


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
   --print(w,h)
   local vertices = {}
   -- x,y,u,v,r,g,b,
   --table.insert(vertices, {0,     0,   0.5, 0.5, 0, 0, 0})
   table.insert(vertices, {-w/2, -h/2, 0, 0})
   table.insert(vertices, { w/2, -h/2, 1, 0})
   table.insert(vertices, { w/2,  h/2, 1, 1})
   table.insert(vertices, {-w/2,  h/2, 0, 1})
   --table.insert(vertices, {-w/2, -h/2, 0, 0, 0, 0, 0})


   --simple_format = {
   --   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
  -- }
   
   local mesh = love.graphics.newMesh(vertices, "fan")
   mesh:setTexture(image)

   return mesh
end

function createTexturedTriangleStrip(image)
   -- this assumes an strip that is oriented vertically
   local w, h = image:getDimensions( )
   local vertices = {}
   --print(w,h)

   
   local segments = 20
   local hPart = h / (segments-1)
   local hv = 1/ (segments-1)

   local runningHV = 0
   local runningHP = 0
   local index = 0
   for i =1, segments do
      
      vertices[index + 1] = {-w/2, runningHP, 0,runningHV }
      vertices[index +  2] = {w/2, runningHP, 1,runningHV }

      runningHV = runningHV + hv
      runningHP = runningHP + hPart
      index = index + 2
   end
   --print(runningHP, runningHV)
   local mesh = love.graphics.newMesh(vertices, "strip")
   mesh:setTexture(image)

   return mesh

end


function love.keypressed(key)
   if (key == 'escape') then love.event.quit() end
end

function love.mousepressed(x,y,button)
   if flip == 1 then flip = -1 else flip = 1 end
end



function love.load()
   success = love.window.setMode( 1024,768, {highdpi=true, vsync=false} )
   
   image = love.graphics.newImage("dogman3.png", {mipmaps=true})
   image:setMipmapFilter( 'nearest', 1 )
   mesh = createTexturedRectangle(image)

   image2 = love.graphics.newImage("kleed2.jpg", {mipmaps=true})
   image2:setMipmapFilter( 'nearest', 1 )
   mesh2 = createTexturedRectangle(image2)

   image3 = love.graphics.newImage("leg.png", {mipmaps=true})
   image3:setMipmapFilter( 'nearest', 1 )
   mesh3 = createTexturedTriangleStrip(image3)
   flip = 1
end

function love.draw()
	local mx, my = love.mouse.getPosition()

	love.graphics.clear(.4,.5,.4)

	local w, h = image3:getDimensions( )
	--print(w,h)

	local offsetW = 500
	
	local curveL = love.math.newBezierCurve({0, 0, 0+offsetW, h/2, 0, h})
	local curveR = love.math.newBezierCurve({w, 0, w+offsetW, h/2, w, h})

	--local curve = love.math.newBezierCurve({mx, my,  mx+50, my + 100, mx, my + 5})
        for i =1, 1 do


	   local count = mesh3:getVertexCount( )

	   for j =1, count, 2 do

	      print((j-1)/(count-2))
	      --print(j-1)
	      --print((j-1)/count, j-1, count)
	     
	      local xl,yl = curveL:evaluate((j-1)/ (count-2))
	      local xr,yr = curveR:evaluate((j-1)/ (count-2)) 
	      
	      local x, y, u, v, r, g, b, a = mesh3:getVertex(j )
	      mesh3:setVertex(j, {xl, yl, u,v})
	      x, y, u, v, r, g, b, a = mesh3:getVertex(j +1)
	      mesh3:setVertex(j+1, {xr, yr, u,v})
	   end
	   
	   love.graphics.draw(mesh2, mx, my, 0, flip, .5)
           love.graphics.draw(mesh2, mx+488, my, 0, flip, .5)
	   love.graphics.draw(mesh, mx, my, 0, flip, 1)

	   --mesh3:setVertex(1, {0, 0})
	   --local x, y, u, v, r, g, b, a = mesh3:getVertex( 2 )
	   --mesh3:setVertex(2, {x, y + love.math.random()*20 -10, u,v})
           love.graphics.draw(mesh3, mx, my, 0, 1, 1)

	end


	love.graphics.line(curveL:render())
	love.graphics.line(curveR:render())

--	love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)

	local stats = love.graphics.getStats()
	love.graphics.print('fps: '..tostring(love.timer.getFPS( )).." "..'#draws: '..stats.drawcalls, 10, 10)
	
--	print('#images', stats.images)-
--	print('img mem', stats.texturememory)-
--	print('#draw calls', stats.drawcalls)
--	print(stats.drawcallsbatched)

end



