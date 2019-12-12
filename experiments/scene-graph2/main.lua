
function love.keypressed(key)
   if key == "escape" then
      love.event.quit()
   end
   if key == 'r' then
      print('roatte that fuck')
      rotation = rotation + .1
   end
   
end


function love.load()
   love.keyboard.setKeyRepeat(true )
   rotation = 0

end

function love.draw()

   local points = {{0,0},{100,0},{100,100},{0,100}}
   local mesh = makeMeshFromVertices(makeTriangles(points))

   --local transform = love.math.newTransform()
   local transform = love.math.newTransform( 200, 200, rotation, 1, 1, 50, 50)
   --transform:translate(200, 0)
   --transform:rotate(math.pi/3)
   
   love.graphics.setColor(1,0,0)
   love.graphics.draw(mesh, transform)

   --local transform2 = love.math.newTransform( )
   --transform2:translate(200,200)
   --transform2:rotate(rotation)
   local transform2 = love.math.newTransform( 200, 200, rotation,1, 1, 50, 50)
   transform2 = transform * transform2
   
   love.graphics.setColor(1,1,0)
   love.graphics.draw(mesh, transform2)

end



function makeTriangles(points)
   local triangles = {}
   local vertices = {}
   if (#points >= 2 ) then

      local scale = 1
      local coords = {}
      --local coordsRound = {}
      local ps = {}
      for l=1, #points do
	 table.insert(coords, points[l][1])
	 table.insert(coords, points[l][2])
      end
      
    --  if (shape.color) then
      local polys = {coords} --decompose_complex_poly(coords, {})
	 local result = {}
	 for k=1 , #polys do
	    local p = polys[k]
	    if (#p >= 6) then
	       -- if a import breaks on triangulation errors uncomment this
	       --print(shapes[i].name, #p, inspect(p))
	       local triangles = love.math.triangulate(p)
	       for j = 1, #triangles do
		  local t = triangles[j]
		  --ocal cx, cy = getTriangleCentroid(t)
		  --if isPointInPath(cx,cy, p) then
		     table.insert(result, t)
		  --end
	       end
	    end
	 end
	 
	 for j = 1, #result do
	    table.insert(vertices, {result[j][1], result[j][2]})
	    table.insert(vertices, {result[j][3], result[j][4]})
	    table.insert(vertices, {result[j][5], result[j][6]})
	 end
	 
      --end
   end
   return vertices
end

local simple_format = {
   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
}

function makeMeshFromVertices(vertices)
   if (vertices and vertices[1] and vertices[1][1]) then
      local mesh = love.graphics.newMesh(simple_format, vertices, "triangles")
      return mesh
   end
   return nil
end
