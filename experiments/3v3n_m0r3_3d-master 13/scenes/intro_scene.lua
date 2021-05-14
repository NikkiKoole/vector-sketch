Intro_scene = Scene:extend('Intro_scene')

function Intro_scene:new()
	Intro_scene.super.new(@)

	@.splashscreen = lg.newImage('assets/images/splashscreen.png')

	@.alpha = 0

	@:chain({
		.5, fn() @:tween(1, @, {alpha = 1}, 'in-out-cubic') end,
		2, fn() @:tween(1, @, {alpha = 0}, 'in-out-cubic') end,
		1, fn() change_scene_with_transition('menu')       end,
	})
end

function Intro_scene:update(dt)
	Intro_scene.super.update(@, dt)
end

function Intro_scene:keypressed(k)
	if k then change_scene_with_transition('menu') end
end

function Intro_scene:draw_outside_camera_fg()
	lg.setColor(1, 1, 1, @.alpha)
	lg.draw(@.splashscreen, 0, 0 + lg:getHeight() / 2 -  @.splashscreen:getHeight() / 2)
end