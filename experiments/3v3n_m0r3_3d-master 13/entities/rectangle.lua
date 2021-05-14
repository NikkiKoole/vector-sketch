Rectangle = Entity:extend('Rectangle')

function Rectangle:new(x, y, w, h, opts)
	Rectangle.super.new(@, { x = x, y = y, z = get(opts, 'z'), outside_camera = get(opts, 'outside_camera'), visible = get(opts, 'visible')})
	
	@.w        = w
	@.h        = h
	@.rx       = get(opts, 'rx'      , 0)    -- rounded corners
	@.ry       = get(opts, 'ry'      , 0)    -- rounded corners
	@.lw       = get(opts, 'lw'      , 1)    -- line width
	@.segments = get(opts, 'segments', nil)  -- nb of segments for rounded corners
	@.centered = get(opts, 'centered', false)
	@.mode     = get(opts, 'mode'    , 'line')
	@.color    = get(opts, 'color'   , COLORS.WHITE)
end

function Rectangle:update(dt)
	Rectangle.super.update(@, dt)
end

function Rectangle:draw()
	lg.setLineWidth(@.lw)
	lg.setColor(@.color)
	if @.centered then 
		lg.rectangle(@.mode, @.pos[1] - @.w/2, @.pos[2] - @.h/2, @.w , @.h , @.rx, @.ry, @.segments)
	else
		lg.rectangle(@.mode, @.pos[1], @.pos[2], @.w, @.h, @.rx, @.ry, @.segments)
	end
	lg.setColor(1, 1, 1, 1)
	lg.setLineWidth(1)
end

function Rectangle:center()
	if @.centered then
		return {self.pos[1], self.pos[2]}
	else
		return rect_center({@.pos[1], @.pos[2], @.w, @.h})
	end
end

function Rectangle:left()
	if @.centered then
		return self.pos[1] - self.w / 2
	else
		return self.pos[1]
	end
end

function Rectangle:right()
	if @.centered then
		return self.pos[1] + self.w / 2
	else
		return self.pos[1] + self.w
	end
end

function Rectangle:top()
	if @.centered then
		return self.pos[2] - self.h / 2
	else
		return self.pos[2]
	end
end

function Rectangle:bottom()
	if @.centered then
		return self.pos[2] + self.h / 2
	else
		return self.pos[2] + self.h
	end
end

function Rectangle:set_left(x)
	if @.centered then
		self.pos[1] = x + self.w / 2
	else
		self.pos[1] = x
	end
end

function Rectangle:set_right(x)
	if @.centered then
		self.pos[1] = x - self.w / 2
	else
		self.pos[1] = x - self.w
	end
end

function Rectangle:set_top(y)
	if @.centered then
		self.pos[2] = y + self.h / 2
	else
		self.pos[2] = y
	end
end

function Rectangle:set_bottom(y)
	if @.centered then
		self.pos[2] = y - self.h / 2
	else
		self.pos[2] = y - self.h
	end
end

function Rectangle:collide_with_point(p)
	return rect_point_collision(@:aabb(), p)
end

function Rectangle:collide_with_circ(c)
	return rect_circ_collision(@:aabb(), c)
end

function Rectangle:collide_with_rect(r)
	return rect_rect_collision(@:aabb(), r)
end

function Rectangle:aabb()
	if @.centered then
		return {@.pos[1] - @.w/2, @.pos[2] - @.h/2, @.w, @.h}
	else
		return {@.pos[1], @.pos[2], @.w, @.h}
	end
end
