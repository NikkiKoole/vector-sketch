Play_scene = Scene:extend('Play_scene')
local Shaders    = require('libraries/g4d//shaders')
--local load_shader   = require('libraries/g4d/g4d_shader_loader')

defaultShader = Shaders['default.glsl']


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
    --------
   
   @.is_relative      = false
   @.is_selecting     = false
   @.selection_origin = {0, 0}
   @.selection_corner = {0, 0}

   @.world = G4d()

   @.skybox = @.world:add_model('assets/obj/skybox.obj')
      :scale(1000)
      :set_shader('skybox.glsl')
      :set_shader_data('cube_texture', lg.newCubeImage('assets/images/skybox.jpg'))

   @.divided = @.world:add_model('assets/obj/divided_plane.obj')
      :move(0, -10, -40)
      :set_shader('vertex_displacement.glsl')

   -- TODO: find difference between the 2 billboard shaders 
   @.billboards = {
      @.world:add_model('assets/obj/billboard.obj')
         :move(10, 0, 10)
         :set_shader('billboard_scale.glsl')
         :set_shader_data('scale', {3, 3, 1}) -- TODO: scale bug
         :set_shader_data('canvas_flip', 1)
         :set_shader_data('color', COLORS.ORANGE),

      @.world:add_model('assets/obj/billboard.obj')
         :move(10, 5, 10)
         :scale(3) -- TODO: scale bug
         :set_shader('billboard.glsl')
         :set_shader_data('scale', {3, 1, 1}) -- TODO: scale bug
         :set_shader_data('color', COLORS.LIGHT_PURPLE)
   }

   -- @.quaternion1 = G4d.Quaternion:from_angle_axis(0, 0, 0, 0)
   -- @.quaternion2 = G4d.Quaternion:from_angle_axis(math.pi, 1, 1, 0)
   @.quaternion1 = G4d.Quaternion:from_euler(0, 0, 0)
   @.quaternion2 = G4d.Quaternion:from_euler(math.rad(-90), math.rad(-90), 0)

   @.rulers  = {
      @.world:add_model('assets/obj/ruler.obj'):move(50, 0, 0 ):set_shader('vertex_normal_initial.glsl'):set_shader_data('is_smooth', false),
      @.world:add_model('assets/obj/ruler.obj'):move(40, 0, 10):set_shader('vertex_normal_transformed.glsl'):set_shader_data('is_smooth', false),
   }

   @.cubes = {
      { model = @.world:add_model('assets/obj/cube.obj'):move(0, 0, 10):set_shader_data('color', COLORS.PINK), selected = false },
      { model = @.world:add_model('assets/obj/cube.obj'):move(5, 0, 10):set_shader_data('color', COLORS.PINK), selected = false },
      { model = @.world:add_model('assets/obj/cube.obj'):move(0, 5, 10):set_shader_data('color', COLORS.PINK), selected = false },
      { model = @.world:add_model('assets/obj/cube.obj'):move(5, 5, 10):set_shader_data('color', COLORS.PINK), selected = false },
   }

   @.planes = {
      @.world:add_model('assets/obj/plane.obj'):move(0 , -10, 0 ):scale(5):set_shader_data('color', COLORS.MAGENTA),
      @.world:add_model('assets/obj/plane.obj'):move(10, -10, 0 ):scale(5):set_shader('random.glsl'),
      @.world:add_model('assets/obj/plane.obj'):move(10, -10, 10):scale(5):set_shader('noise.glsl'),
      @.world:add_model('assets/obj/plane.obj'):move(0 , -10, 10):scale(5):set_shader('vertex_displacement.glsl'),
      @.world:add_model('assets/obj/plane.obj'):move(0 , -10, 20):scale(5):set_shader('coord.glsl'),
      @.world:add_model('assets/obj/plane.obj'):move(10, -10, 20):scale(5):set_shader('simplex.glsl'),
      @.world:add_model('assets/obj/plane.obj'):move(0 , -10, 30):scale(5):set_shader('camera_position.glsl'),
   }

   @.suzannes = {
      @.world:add_model('assets/obj/suzanne.obj'):scale(3):move(-10, 5 , 10):set_shader('camera_target.glsl'),
      @.world:add_model('assets/obj/suzanne.obj'):scale(3):move(-20, 5 , 10):rotate(_, math.pi):set_shader('vertex_normal_initial.glsl'):set_shader_data('is_smooth', false),
      @.world:add_model('assets/obj/suzanne.obj'):scale(3):move(-40, 5 , 10):set_shader('vertex_normal_initial.glsl'),
      @.world:add_model('assets/obj/suzanne.obj'):scale(3):move(-10, 15, 10):set_shader('vertex_camera_target.glsl'),
      @.world:add_model('assets/obj/suzanne.obj'):scale(3):move(-30, 15, 10):set_shader('vertex_normal_initial.glsl'),
      @.world:add_model('assets/obj/suzanne.obj'):scale(10):move(-20, 15, -100):set_shader('vertex_normal_transformed.glsl'):set_shader_data('is_smooth', false),
      @.world:add_model('assets/obj/suzanne.obj'):scale(10):move(-20, 15, -150):set_shader('vertex_normal_transformed.glsl'):set_shader_data('is_smooth', true),
   }

   @.lights = {
      @.world:add_model('assets/obj/sphere.obj')
         :set_shader_data('color', COLORS.PINK)
         :set_shader_data('ambient_intensity', .1)
         :set_shader_data('diffuse_intensity', .6)
         :set_shader_data('specular_intensity', .3)
         :set_shader_data('specular_size', .05),

      @.world:add_model('assets/obj/sphere.obj')
         :set_shader_data('color', COLORS.CYAN)
         :set_shader_data('ambient_intensity', .1)
         :set_shader_data('diffuse_intensity', .6)
         :set_shader_data('specular_intensity', .3)
         :set_shader_data('specular_size', .05),
   }

   @.phong = @.world:add_model('assets/obj/dragon.obj'):scale(3):move(-40, 25, 50)
      :set_shader('phong.glsl')
      :set_shader_data('color', {0, 0, .3, 1})
      :set_shader_data('is_ambient_disabled', false)
      :set_shader_data('is_diffuse_disabled', false)
      :set_shader_data('is_specular_disabled', false)
      :set_shader_data('is_model_color_disabled', false)
      :set_shader_data('light_count', 2)
   
      :set_shader_data('lights[0].position'          , @.lights[1]:pos())
      :set_shader_data('lights[0].color'             , @.lights[1]:get_shader_data('color'))
      :set_shader_data('lights[0].ambient_intensity' , @.lights[1]:get_shader_data('ambient_intensity'))
      :set_shader_data('lights[0].diffuse_intensity' , @.lights[1]:get_shader_data('diffuse_intensity'))
      :set_shader_data('lights[0].specular_intensity', @.lights[1]:get_shader_data('specular_intensity'))

      :set_shader_data('lights[1].position'          , @.lights[2]:pos())
      :set_shader_data('lights[1].color'             , @.lights[2]:get_shader_data('color'))
      :set_shader_data('lights[1].ambient_intensity' , @.lights[2]:get_shader_data('ambient_intensity'))
      :set_shader_data('lights[1].diffuse_intensity' , @.lights[2]:get_shader_data('diffuse_intensity'))
      :set_shader_data('lights[1].specular_intensity', @.lights[2]:get_shader_data('specular_intensity'))
   
end

function Play_scene:update(dt)
   Play_scene.super.update(@, dt)

   if is_down('a')      then @.world.camera:update(dt * 4, 'left')   end
   if is_down('d')      then @.world.camera:update(dt * 4, 'right')  end
   if is_down('w')      then @.world.camera:update(dt * 4, 'toward') end
   if is_down('s')      then @.world.camera:update(dt * 4, 'back')   end
   if is_down('lshift') then @.world.camera:update(dt * 4, 'up')     end
   if is_down('lctrl')  then @.world.camera:update(dt * 4, 'down')   end

   local camera_pos = @.world.camera:position()
   local camera_ray = @.world.camera:get_target_ray()
   local mouse_ray  = @.world.camera:get_mouse_ray()

   for cube in @.cubes do
      if cube.model:collide_with_directional_ray(camera_pos, camera_ray) && cube.model:collide_with_directional_ray(camera_pos, mouse_ray) then
         cube.model:set_shader_data('color', COLORS.RED)
         
      elseif cube.model:collide_with_directional_ray(camera_pos, camera_ray) then
         cube.model:set_shader_data('color', COLORS.YELLOW)
         
      elseif cube.model:collide_with_directional_ray(camera_pos, mouse_ray) && !@.is_relative then
         cube.model:set_shader_data('color', COLORS.ORANGE)

      else
         if cube.selected then
            cube.model:set_shader_data('color', COLORS.CYAN)
         else
            cube.model:set_shader_data('color', COLORS.PINK)
         end
      end
   end

   if @.is_selecting then
      @.selection_corner = {love.mouse.getPosition()}
   end
end


function Play_scene:draw_outside_camera_fg()
   local time = love.timer.getTime()
   @.divided:set_shader_data('time', time)
   @.planes[2]:set_shader_data('time', time)
   @.planes[3]:set_shader_data('time', time)
   @.planes[6]:set_shader_data('time', time)
   @.suzannes[3]:rotate(_, time)
   @.suzannes[5]:rotate(_, time)
   @.suzannes[6]:rotate(_, time)
   @.suzannes[7]:rotate(_, time)

   local q3 = @.quaternion1:slerp(@.quaternion2, ((math.cos(time) + 1)/2))
   local q4 = @.quaternion1:nlerp(@.quaternion2 , ((math.cos(time) + 1)/2))

   @.rulers[1]:rotate(q3)
   @.rulers[2]:rotate(q4)

   @.lights[1]:move(-40 + math.sin(time) * 35, 20, 50 + math.cos(time) * 35)
   @.lights[2]:move(-40 + math.cos(time) * 35, 50, 50 + math.sin(time) * 35)

   @.phong:set_shader_data('lights[0].position', @.lights[1]:pos())
   @.phong:set_shader_data('lights[1].position', @.lights[2]:pos())

   @.world:draw(0, 0, @.root)

   if @.is_selecting then
      lg.rectangle('line', @.selection_origin[1], @.selection_origin[2], @.selection_corner[1] -@.selection_origin[1], @.selection_corner[2] - @.selection_origin[2])
      lg.setColor(0, 1, 1, .2)
      lg.rectangle('fill', @.selection_origin[1], @.selection_origin[2], @.selection_corner[1] -@.selection_origin[1], @.selection_corner[2] - @.selection_origin[2])
      lg.setColor(1, 1, 1, 1)
   end

   lg.circle('line', 400, 300, 5)
end

function Play_scene:mousepressed(x, y, button)
   if button == 1 then
      @.is_selecting = true
      @.selection_origin = {love.mouse.getPosition()}
   else
      @.is_relative = true
      lm.setRelativeMode(@.is_relative)
   end
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

function Play_scene:mousereleased(x, y, button)
   if button == 1 then
      @.is_selecting = false

      local v1 = @.world.camera:get_screen_ray(@.selection_origin[1], @.selection_origin[2]) -- top left
      local v2 = @.world.camera:get_screen_ray(@.selection_corner[1], @.selection_origin[2]) -- top right
      local v3 = @.world.camera:get_screen_ray(@.selection_corner[1], @.selection_corner[2]) -- bottom right
      local v4 = @.world.camera:get_screen_ray(@.selection_origin[1], @.selection_corner[2]) -- bottom left

      for cube in @.cubes do 
         local top_left     = G4d.Collision:ray_plane(@.world.camera:position(), v1, cube.model:position(), @.world.camera:get_target_ray())
         local top_right    = G4d.Collision:ray_plane(@.world.camera:position(), v2, cube.model:position(), @.world.camera:get_target_ray())
         local bottom_left  = G4d.Collision:ray_plane(@.world.camera:position(), v3, cube.model:position(), @.world.camera:get_target_ray())
         local bottom_right = G4d.Collision:ray_plane(@.world.camera:position(), v4, cube.model:position(), @.world.camera:get_target_ray())
         
         if top_left || top_right || bottom_left || bottom_right then
            local t1 = G4d.Collision:ray_triangle(@.world.camera:position(), @.world.camera:get_ray_to(cube.model:position()), {top_left, top_right, bottom_left})
            local t2 = G4d.Collision:ray_triangle(@.world.camera:position(), @.world.camera:get_ray_to(cube.model:position()), {bottom_left, bottom_right, top_left})
            cube.selected = t1 || t2
         end	
      end

   else
      @.is_relative = false  
      lm.setRelativeMode(@.is_relative) 
   end
end

function Play_scene:mousemoved(x, y, dx, dy)
   if @.is_relative then
      @.world.camera:mousemoved(dx,dy)
   end
end

function Play_scene:keypressed(key)
   if key == 'escape' then love.event.quit() end
end
