Tileset = Class:extend('Tileset')

function Tileset:new(image, tile_w, tile_h, ox, oy, x_number, y_number)
	@.image  = image
	@.tile_w = tile_w
	@.tile_h = tile_h
	@.ox     = ox or 0
	@.oy     = oy or 0
	@.tiles  = (fn()
		local tiles = {}
		foreach(x_number, fn(i)
			foreach(y_number, fn(j)
				insert(tiles, lg.newQuad(
					(j-1) * @.tile_w, (i-1) * @.tile_h,
					@.tile_w, @.tile_h,
					@.image:getWidth(), @.image:getHeight()
				))
			end)
		end)
		return tiles
	end)()
end

