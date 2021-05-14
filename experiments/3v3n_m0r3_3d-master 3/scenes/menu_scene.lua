Menu_scene = Scene:extend('Menu_scene')

function Menu_scene:new()
	Menu_scene.super.new(@)

	@:add('play_btn', Text(lg.getWidth()/2, lg.getHeight()/2 - 25, 'Play \x21', 
		{
			font           = lg.newFont('assets/fonts/fixedsystem.ttf', 32),
			centered       = true,
			outside_camera = true,
		})
	)
	
	@:add('quit_btn', Text(lg.getWidth()/2, lg.getHeight()/2 + 25, 'Quit :(', 
		{
			font           = lg.newFont('assets/fonts/fixedsystem.ttf', 32),
			centered       = true,
			outside_camera = true,
		})
	)
end

function Menu_scene:update(dt)
	Menu_scene.super.update(@, dt)

	if is_pressed('escape') then love.event.quit() end

	local play_btn = @:get('play_btn')
	local quit_btn = @:get('quit_btn')

	if point_rect_collision({lm:getX(), lm:getY()}, play_btn:aabb()) then
		@:once(fn() play_btn.scale_spring:change(1.5) end, 'is_inside_play')
		if is_pressed('m_1') then change_scene_with_transition('play') end
	else 
		if @.trigger:remove('is_inside_play') then play_btn.scale_spring:change(1) end
	end

	if point_rect_collision({lm:getX(), lm:getY()}, quit_btn:aabb()) then
		@:once(fn() quit_btn.scale_spring:change(1.5) end, 'is_inside_quit')
		if is_pressed('m_1') then love.event.quit() end
	else 
		if @.trigger:remove('is_inside_quit') then quit_btn.scale_spring:change(1) end
	end
end
