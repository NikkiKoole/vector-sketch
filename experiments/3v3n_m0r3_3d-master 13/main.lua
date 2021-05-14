function love.run()
	lg, la, lm, lk, lt = love.graphics, love.audio, love.mouse, love.keyboard, love.timer

	lg.setDefaultFilter('nearest', 'nearest')
	lg.setLineStyle('rough')
	lk.setKeyRepeat(true)
	
	Physics = require('libraries/physics')
	G4d     = require('libraries/g4d')

	require('class')
	require('utils')
	require('monkey')
        

	require_all('classes')
        require_all('vecsketch')
	require_all('scenes')
	require_all('entities', {recursive = true})

	GAME = {
		current_scene_id  = '',
		trigger     = Trigger(),
		scenes      = {},
		bg_color    = {r = 0, g = 0, b = 0, a = 0},
		input       = {current = {}, previous = {}},
		accumulator = 0,
		fixed_dt    = 1/60,
	}

	load_game()
	lt.step()

	return function()
		love.event.pump()
		for name, a, b, c, d, e, f in love.event.poll() do
			if name == 'quit'          then return 0 end
			if name == 'mousepressed'  then GAME.input.current['m_'.. c] = true end
			if name == 'mousereleased' then GAME.input.current['m_'.. c] = false end
			if name == 'keypressed'    then GAME.input.current[a]        = true if c then GAME.input.previous[a] = false end end -- c => isRepeat
			if name == 'keyreleased'   then GAME.input.current[a]        = false end
			if GAME.current_scene_id ~= '' and GAME.scenes[GAME.current_scene_id][name] then
				GAME.scenes[GAME.current_scene_id][name](GAME.scenes[GAME.current_scene_id], a, b, c, d, e, f)
			end
			love.handlers[name](a, b, c, d, e, f)
		end

		GAME.accumulator = GAME.accumulator + lt.step()
		while GAME.accumulator >= GAME.fixed_dt do
			GAME.trigger:update(GAME.fixed_dt)
			if GAME.current_scene_id ~= '' then 
				GAME.scenes[GAME.current_scene_id]:update(GAME.fixed_dt)
			end
			for k, v in pairs(GAME.input.current) do GAME.input.previous[k] = v end
			GAME.accumulator = GAME.accumulator - GAME.fixed_dt
		end

		lg.origin()
		lg.clear(lg.getBackgroundColor())
		if GAME.current_scene_id ~= '' then 
			GAME.scenes[GAME.current_scene_id]:draw()
		end
		local _color = {lg.getColor()}
		lg.setColor(GAME.bg_color.r, GAME.bg_color.g, GAME.bg_color.b, GAME.bg_color.a)
		lg.rectangle('fill', 0, 0, lg.getWidth(), lg.getHeight())
		lg.setColor(_color)
		lg.present()

		lt.sleep(0.001)
	end
end

function load_game()
	add_scene('intro', Intro_scene())
	add_scene('menu', Menu_scene())
	add_scene('play', Play_scene())

	change_scene('play')
end

function add_scene(id, scene)
	scene.id        = id
	GAME.scenes[id] = scene
end

function change_scene(name, ...)
	local args = {...}
	local previous = GAME.current_scene_id
	if GAME.current_scene_id ~= '' then GAME.scenes[GAME.current_scene_id]:exit() end
	GAME.current_scene_id = name
	GAME.scenes[GAME.current_scene_id]:enter(previous, args)
end

function change_scene_with_transition(name, ...)
	local args = {...}
	GAME.trigger:tween(.4, GAME.bg_color, {a = 1}, 'in-cubic', 'transition_fade_in', function() 
		local previous = GAME.current_scene_id
		if GAME.current_scene_id ~= '' then GAME.scenes[GAME.current_scene_id]:exit() end
		GAME.current_scene_id = name
		GAME.scenes[GAME.current_scene_id]:enter(previous, args)
		GAME.trigger:tween(.4, GAME.bg_color, {a = 0}, 'out-cubic', 'transition_fade_out')
	end)
end

function is_pressed(key)	
	return GAME.input.current[key] and not GAME.input.previous[key]
end

function is_released(key)
	return GAME.input.previous[key] and not GAME.input.current[key] 
end

function is_down(key) 
	if key=='m_1'or key=='m_2'or key=='m_3' then 
		return lm.isDown(tonumber(key:sub(3))) 
	else 
		return lk.isDown(key) 
	end 
end

COLORS = {
	BLACK        = {0 , 0 , 0 , 1},
	WHITE        = {1 , 1 , 1 , 1},
	RED          = {1 , 0 , 0 , 1},
	GREEN        = {0 , 1 , 0 , 1},
	BLUE         = {0 , 0 , 1 , 1},
	CYAN         = {0 , 1 , 1 , 1},
	YELLOW       = {1 , 1 , 0 , 1},
	MAGENTA      = {1 , 0 , 1 , 1},
	PURPLE       = {.5, 0 , 1 , 1},
	PINK         = {1 , .5, .5, 1},
	LIGHT_PURPLE = {.5, .5, 1 , 1},
	LIGHT_GREEN  = {.5, .5, 1 , 1},
	ORANGE       = {1 , .5, 0 , 1},
}
