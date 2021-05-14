Text = Entity:extend('Text')

function Text:new(x, y, text, opts)
	Text.super.new(@, { x = x, y = y, outside_camera = get(opts, 'outside_camera', false)})

	@.text         = lg.newText(get(opts, 'font', lg.getFont()), text)
	@.scale        = get(opts, 'scale', 1)
	@.radian       = get(opts, 'radian', 0)
	@.color        = get(opts, 'color', {1, 1, 1})
	@.centered     = get(opts, 'centered', false)
	@.scale_spring = Spring(@.scale)
end

function Text:update(dt)
	Text.super.update(@, dt)
	@.scale_spring:update(dt)
end

function Text:draw()
	lg.setColor(@.color)
	local offset_x, offset_y
	if @.centered then
		offset_x, offset_y = @.text:getWidth() / 2, @.text:getHeight() / 2
	end
	lg.draw(@.text, @.pos.x, @.pos.y, @.radian, @.scale_spring:get(), _, offset_x, offset_y)
	lg.setColor(1, 1, 1, 1)
end

function Text:set_text(text)
	@.text:set(text)
end

function Text:aabb()
	if @.centered then
		return {
			@.pos.x - @.text:getWidth() / 2, 
			@.pos.y - @.text:getHeight() / 2, 
			@.text:getWidth(), 
			@.text:getHeight(),
		}
	else 
		return { 
			@.pos.x, 
			@.pos.y, 
			@.text:getWidth(), 
			@.text:getHeight(),
		} 
	end
end
