Play_scene = Scene:extend('Play_scene')
local Vectors    = require('libraries/g4d/g4d_vectors')
local Collisions = require('libraries/g4d/g4d_collisions')
local load_shader   = require('libraries/g4d/g4d_shader_loader')

defaultshader = load_shader('default')


function Play_scene:new()
	Play_scene.super.new(@)

        
        @.root = {
           folder = true,
           name = 'root',
           transforms =  {l={0,0,0,1,1,0,0,0,0}},
           children = {
              {
                 children = { {
                       color = { 0.867, 0.239, 0.055, 1 },
                       name = "orange",
                       points = { { 270, 290 }, { 469, 335 }, { 341, 140 } }
                 } },
                 folder = true,
                 name = "orange parent",
                 transforms = {
                    l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 }
                 }
              }, {
                 children = { {
                       color = { 0.161, 0.678, 1, 1 },
                       name = "blue",
                       points = { { 270, 290 }, { 469, 335 }, { 341, 140 } }
                 } },
                 folder = true,
                 name = " blue parent",
                 transforms = {
                    l = { 9, 269, 0, 1, 1, 0, 0, 0, 0 }
                 }
                 }, {
                 children = { {
                       color = { 0, 0.529, 0.318, 1 },
                       name = "green",
                       points = { { 605, 339 }, { 749, 403 }, { 682, 135 } }
                 } },
                 folder = true,
                 name = "green parent",
                 transforms = {
                    l = { 0, 0, 0, 1, 1, 0, 0, 0, 0 }
                 }
                    }, {
                 children = { {
                       color = { 0.514, 0.463, 0.612, 1 },
                       name = "purple",
                       points = { { 605, 339 }, { 749, 403 }, { 682, 135 } }
                 } },
                 folder = true,
                 name = " purple parent",
                 transforms = {
                    l = { -27, 281, 0, 1, 1, 0, 0, 0, 0 }
                 }
           } }

        }
        makeScaleFit(@.root, 1.0/100)
        parentize(@.root)
        renderThings3d(@.root)
        meshAll(@.root)
        
	@.cubes = {
		{ model = g4d.Model('assets/obj/cube.obj'):move(0, 0, 10), selected = false },
		{ model = g4d.Model('assets/obj/cube.obj'):move(5, 0, 10), selected = false },
		{ model = g4d.Model('assets/obj/cube.obj'):move(0, 5, 10), selected = false },
		{ model = g4d.Model('assets/obj/cube.obj'):move(5, 5, 10), selected = false },
	}

	@.planes = {
		g4d.Model('assets/obj/plane.obj'):move(0 , -10, 0 ):scale(5):set_shader('default'):set_shader_data('color', COLORS.MAGENTA),
		g4d.Model('assets/obj/plane.obj'):move(10, -10, 0 ):scale(5):set_shader('random'),
		g4d.Model('assets/obj/plane.obj'):move(10, -10, 10):scale(5):set_shader('noise'),
		g4d.Model('assets/obj/plane.obj'):move(0 , -10, 10):scale(5):set_shader('water'),
		g4d.Model('assets/obj/plane.obj'):move(0 , -10, 20):scale(5):set_shader('coord'),
		g4d.Model('assets/obj/plane.obj'):move(10, -10, 20):scale(5):set_shader('simplex'),
		g4d.Model('assets/obj/plane.obj'):move(0 , -10, 30):scale(5):set_shader('camera_position'),
	}

	@.skybox = g4d.Model('assets/obj/skybox.obj')
		:set_shader('skybox')
		:set_shader_data('cube_texture', lg.newCubeImage('assets/images/skybox.jpg'))
		:scale(1000)

	-- TODO: find difference between the 2 billboard shaders 
	@.billboard = g4d.Model('assets/obj/billboard.obj')
		:move(10, 5, 10)
		:scale(3) -- TODO: scale bug
		:set_shader('billboard')
		:set_shader_data('scale', {3, 1, 1}) -- TODO: scale bug
		:set_shader_data('color', COLORS.LIGHT_PURPLE)

	@.billboard_scale = g4d.Model('assets/obj/billboard.obj')
		:move(10, 0, 10)
		:set_shader('billboard_scale')
		:set_shader_data('scale', {3, 3, 1}) -- TODO: scale bug
		:set_shader_data('canvas_flip', 1)
		:set_shader_data('color', COLORS.ORANGE)

	@.is_relative  = false
	@.is_selecting = false

	@.selection_origin = {0, 0}
	@.selection_corner = {0, 0} 
end

function Play_scene:update(dt)
	Play_scene.super.update(@, dt)

	if is_down('a')      then g4d.Camera:update(dt, 'left')   end
	if is_down('d')      then g4d.Camera:update(dt, 'right')  end
	if is_down('w')      then g4d.Camera:update(dt, 'toward') end
	if is_down('s')      then g4d.Camera:update(dt, 'back')   end
	if is_down('lshift') then g4d.Camera:update(dt, 'up')     end
	if is_down('lctrl')  then g4d.Camera:update(dt, 'down')   end

	local camera_pos = g4d.Camera:position()
	local camera_ray = g4d.Camera:get_center_ray()
	local mouse_ray  = g4d.Camera:get_mouse_ray()

	for cube in @.cubes do
		if cube.model:collide_with_directional_ray(camera_pos, camera_ray) && cube.model:collide_with_directional_ray(camera_pos, mouse_ray) then
			cube.model:set_shader_data('color', COLORS.GREEN)
	
		elseif cube.model:collide_with_directional_ray(camera_pos, camera_ray) then
			cube.model:set_shader_data('color', COLORS.BLUE)
	
		elseif cube.model:collide_with_directional_ray(camera_pos, mouse_ray) then
			cube.model:set_shader_data('color', COLORS.RED)
	
		else
			if cube.selected then
				cube.model:set_shader_data('color', COLORS.YELLOW)
			else
				cube.model:set_shader_data('color', COLORS.WHITE)
			end
		end
	end

	if @.is_selecting then
		@.selection_corner = {love.mouse.getPosition()}
	end
end


function Play_scene:draw_outside_camera_fg()

	@.planes[2]:set_shader_data('time', love.timer.getTime())
	@.planes[3]:set_shader_data('time', love.timer.getTime())
	@.planes[6]:set_shader_data('time', love.timer.getTime())

	g4d:attach()
		@.skybox:draw()
		for @.cubes  do it.model:draw() end
		for @.planes do it:draw() end

                -- set a shader
                
                lg.setShader(defaultshader)
                renderThings3d(@.root)
                lg.setShader()
                
		@.billboard:draw()
		@.billboard_scale:draw()
	g4d:detach()

	g4d:draw(0, 0)

	if @.is_selecting then
		lg.rectangle('line', @.selection_origin[1], @.selection_origin[2], @.selection_corner[1] -@.selection_origin[1], @.selection_corner[2] - @.selection_origin[2])
		lg.setColor(0, 1, 1, .2)
		lg.rectangle('fill', @.selection_origin[1], @.selection_origin[2], @.selection_corner[1] -@.selection_origin[1], @.selection_corner[2] - @.selection_origin[2])
		lg.setColor(1, 1, 1, 1)
	end

	lg.circle('line', lg.getWidth()/2, lg.getHeight()/2, 5)
        love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end

function Play_scene:filedropped(file)
   print('yo')
    fileDropPopup = file

    local tab = getDataFromFile(file)
    @.root.children = tab -- TableConcat(root.children, tab)
    parentize(@.root)
    renderThings3d(@.root)
    meshAll(@.root)
    makeScaleFit(@.root, 1.0/100)
end
function Play_scene:resize(w,h)

   g4d:resize(w,h)
end


function Play_scene:mousemoved(x, y, dx, dy)
	if @.is_relative then
		g4d.Camera:mousemoved(dx,dy)
	end
end

function Play_scene:mousepressed(a, b, c)
	if c == 1 then
		@.is_selecting     = true
		@.selection_origin = {love.mouse.getPosition()}
	else
		@.is_relative = true
		lm.setRelativeMode(@.is_relative)
	end
end

function Play_scene:mousereleased(a, b, c)
	if c == 1 then
		@.is_selecting = false

		local v1 = g4d.Camera:get_screen_ray(@.selection_origin[1], @.selection_origin[2]) -- top left
		local v2 = g4d.Camera:get_screen_ray(@.selection_corner[1], @.selection_origin[2]) -- top right
		local v3 = g4d.Camera:get_screen_ray(@.selection_corner[1], @.selection_corner[2]) -- bottom right
		local v4 = g4d.Camera:get_screen_ray(@.selection_origin[1], @.selection_corner[2]) -- bottom left

		for cube in @.cubes do 
			local top_left     = Collisions:ray_plane(g4d.Camera:position(), v1, cube.model:position(), g4d.Camera:get_center_ray())
			local top_right    = Collisions:ray_plane(g4d.Camera:position(), v2, cube.model:position(), g4d.Camera:get_center_ray())
			local bottom_left  = Collisions:ray_plane(g4d.Camera:position(), v3, cube.model:position(), g4d.Camera:get_center_ray())
			local bottom_right = Collisions:ray_plane(g4d.Camera:position(), v4, cube.model:position(), g4d.Camera:get_center_ray())
	
			if top_left || top_right || bottom_left || bottom_right then
				local t1 = Collisions:ray_triangle(g4d.Camera:position(), g4d.Camera:get_target_ray(cube.model:position()), {top_left, top_right, bottom_left})
				local t2 = Collisions:ray_triangle(g4d.Camera:position(), g4d.Camera:get_target_ray(cube.model:position()), {bottom_left, bottom_right, top_left})
				cube.selected = t1 || t2
			end	
		end

	else
		@.is_relative = false  
		lm.setRelativeMode(@.is_relative) 
	end
end

function Play_scene:keypressed(k)
	if k == 'escape' then love.event.quit() end
end

