-- License CC0 (Creative Commons license) (c) darkfrei, 2023

-- tiled polygons v. 2023-07-12
love.window.setTitle ('Tiled Polygons 2023-07-12')

Tiles = {}

Size = 4

local v1, v2, v3, v4 = 1, 1+1*Size, 1+2*Size, 1+3*Size

for y = 0, 2*Size-1 do
	for x = 0, 2*Size-1 do
		local absDif = math.abs (y-x)
		if absDif < Size then
			if x == 0 and y == 0 then
				-- square
				local tile = {v1, v2, v3, v4}
				tile.x, tile.y = x, y
				table.insert (Tiles, tile)
			elseif y == 0 then
				-- rectangle
				local tile = {v1, v2-x, v3+x, v4}
				print (x, y, table.concat (tile, ','))
				tile.x, tile.y = x, y
				table.insert (Tiles, tile)
			elseif x == 0 then
				-- rectangle
				local tile = {v1, v2, v3-y, v4+y}
				print (x, y, table.concat (tile, ','))
				tile.x, tile.y = x, y
				table.insert (Tiles, tile)
			else
				local tile = {v1}
				local vx = v3-x
				local vy = v3+y
				if vx > v2 then
					table.insert (tile, v2)
				end				
				table.insert (tile, vx)
				table.insert (tile, vy)
				if vy < v4 then
					table.insert (tile, v4)
				end
				print (x, y, table.concat (tile, ','))
				tile.x, tile.y = x, y
				table.insert (Tiles, tile)
			end
		end
	end
end

Vertices = {}
for i = 1, Size do
	local t1 = (i - 1)/Size
	Vertices[i] = {x=t1, y=0}
	Vertices[i + Size] = {x=1, y=t1}
	Vertices[i + Size * 2] = {x=1-t1, y=1}
	Vertices[i + Size * 3] = {x=0, y=1-t1}
end

for i, v in ipairs (Vertices) do
	print (i, v.x, v.y)
end

Polygons = {}

for i, tile in ipairs (Tiles) do
	local x = 1.25*tile.x
	local y = 1.25*tile.y
	local vertices = {}
	print ('{'..table.concat (tile, ',')..'}, -- ' .. i)
	for j, vIndex in ipairs (tile) do
		local x1 = x + Vertices[vIndex].x
		local y1 = y + Vertices[vIndex].y
		table.insert (vertices, x1)
		table.insert (vertices, y1)
	end
	table.insert (Polygons, vertices)
end

	
function love.draw ()
	love.graphics.translate (10, 10)
	local scale = 58
	love.graphics.scale (scale)
	love.graphics.setLineWidth (2/scale)
	for i, vertices in ipairs (Polygons) do
		love.graphics.polygon ('line', vertices)
	end
end