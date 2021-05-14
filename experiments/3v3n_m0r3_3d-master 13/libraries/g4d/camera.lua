local Vec3      = require(G4D_PATH .. '/vec3')
local Mat4      = require(G4D_PATH .. '/mat4')
local Collision = require(G4D_PATH .. '/collision')
local Shaders   = require(G4D_PATH .. '/shaders')

local cos, sin, max, min, abs, atan2, sqrt = math.cos, math.sin, math.max, math.min, math.abs, math.atan2, math.sqrt
local not_zero_cos = function(x)
	local sign = (function() if math.cos(x) < 0 then return -1 else return 1 end end)()
	return sign * math.max(math.abs(math.cos(x)), .001)
end

local Camera = {}

function Camera:new()
	local cam = setmetatable({}, {__index = Camera})

	cam.x , cam.y , cam.z  = 0, 0, 0
	cam.tx, cam.ty, cam.tz = 0, 0, 1
	cam.yaw          = 0
	cam.pitch        = 0
	cam.speed        = 10
	cam.near_clip    = .01
	cam.far_clip     = 1000
	cam.fov          = math.pi/3
	cam.sensitivity  = .003
	cam.down         = {0, -1, 0} -- 1: flip camera
	cam.aspect_ratio = love.graphics.getWidth()/love.graphics.getHeight()

	cam:update_projection_matrix()
	cam:update_view_matrix()

	return cam
end

function Camera:update(dt, dir)
	local speed = self.speed * dt
	local dx    = 0
	local dy    = 0
	local dir_t = 0

	-- move camera's absolute position
	if     dir == 'right_abs' then self.x = self.x + speed
	elseif dir == 'left_abs'  then self.x = self.x - speed
	elseif dir == 'forth_abs' then self.z = self.z + speed
	elseif dir == 'back_abs'  then self.z = self.z - speed
	elseif dir == 'up'        then self.y = self.y + speed
	elseif dir == 'down'      then self.y = self.y - speed
	-- move camera relative to target
	elseif dir == 'left'      then dx    = -1
	elseif dir == 'right'     then dx    =  1
	elseif dir == 'forth'     then dy    = -1
	elseif dir == 'back'      then dy    =  1
	elseif dir == 'away_from' then dir_t = -1
	elseif dir == 'toward'    then dir_t =  1 end

	if dx ~= 0 or dy ~= 0 then
		local angle = atan2(dy, dx)
		local dir_x = cos(self.yaw + angle)           
		local dir_z = sin(self.yaw + angle + math.pi) 

		self.x = self.x + speed * dir_x
		self.z = self.z + speed * dir_z
	end

	if dir_t ~= 0 then 
		local sign = 0 
		if     math.cos(self.pitch) > 0 then sign =  1
		elseif math.cos(self.pitch) < 0 then sign = -1 end

		local cos_pitch = not_zero_cos(self.pitch)
		local tx = sin(self.yaw) * cos_pitch
		local ty = sin(self.pitch)
		local tz = cos(self.yaw) * cos_pitch

		self.x = self.x + tx * speed * dir_t
		self.y = self.y - ty * speed * dir_t
		self.z = self.z + tz * speed * dir_t
	end
	
	self:look_in_dir()
end

function Camera:mousemoved(dx, dy)
	local dir   = self.yaw + dx * self.sensitivity
	local pitch = max(min(self.pitch + dy * self.sensitivity, math.pi/2), -math.pi/2)
	self:look_in_dir(dir, pitch)
end

function Camera:position()
	return Vec3(self.x, self.y, self.z)
end

function Camera:pos()
	return Vec3(self.x, self.y, self.z)
end

function Camera:move(x, y, z)
	if type(x) == 'table' then x, y, z = x[1], x[2], x[3]  end

	self.x, self.y, self.z = x or self.x, y or self.y, z or self.z

	self:update_view_matrix()
end

function Camera:look_at(tx, ty, tz)
	if type(tx) == 'table' then tx, ty, tz = tx[1], tx[2], tx[3] end

	self.tx, self.ty, self.tz = Vec3:fast_normalize(tx or self.tx, ty or self.ty, tz or self.tz)
	if self.tx == 0 then self.tx = .001 end

	local dx = self.tx - self.x
	local dy = self.ty - self.y
	local dz = self.tz - self.z

	self.yaw   = -atan2(dz, dx) + math.pi/2
	self.pitch = -atan2(dy, sqrt(dx^2 + dz^2))

	self:update_view_matrix()
end

function Camera:look_in_dir(yaw, pitch)
	self.yaw   = yaw   or self.yaw
	self.pitch = pitch or self.pitch

	local cos_pitch = not_zero_cos(self.pitch)
	self.tx = self.x + sin(self.yaw) * cos_pitch
	self.ty = self.y - sin(self.pitch)
	self.tz = self.z + cos(self.yaw) * cos_pitch

	self:update_view_matrix()
end

function Camera:update_view_matrix(dt)
	for _, shader in pairs(Shaders) do 
		if shader:hasUniform('camera.view_matrix') then 
			shader:send('camera.view_matrix', self:get_view_matrix())
		end

		if shader:hasUniform('camera.position') then 
			shader:send('camera.position', self:position())
		end

		if shader:hasUniform('camera.target') then 
			shader:send('camera.target', self:get_target_ray())
		end
	end
end

function Camera:update_projection_matrix()
	-- matrix = Mat4:get_orthographic_matrix(self.fov, size or 5, self.near_clip, self.far_clip, self.aspect_ratio)
	for k, shader in pairs(Shaders) do
		if shader:hasUniform('camera.projection_matrix') then 
			shader:send('camera.projection_matrix', self:get_projection_matrix())
		end
	end
end

function Camera:get_projection_matrix()
	return Mat4:get_projection_matrix(self.fov, self.near_clip, self.far_clip, self.aspect_ratio)
end

function Camera:get_view_matrix()
	return Mat4:get_view_matrix({self.x, self.y, self.z}, {self.tx, self.ty, self.tz}, self.down)
end

function Camera:get_inverse_projection_matrix()
	return Mat4.invert(self:get_projection_matrix())
end

function Camera:get_inverse_view_matrix()
	return Mat4.invert(self:get_view_matrix())
end

function Camera:is_world_position_on_screen(pos) -- vec3
	local width, height = love.graphics.getDimensions()
	local pv_matrix     = self:get_projection_matrix() * self:get_view_matrix()

	local pos, pos_w = pv_matrix * pos
	pos[1] = pos[1] / pos_w
	pos[2] = pos[2] / pos_w
	pos[3] = pos[3] / pos_w

	local screen_x = math.floor(((pos[1] + 1) / 2) * width )
	local screen_y = math.floor(((pos[2] + 1) / 2) * height)

	if screen_x < 0 or screen_x > width or screen_y < 0 or screen_y > height then return false end

	-- is pos facing camera
	local cam_dir     = self:get_target_ray()
	local targ_to_cam = self:get_ray_to(pos)
	local dot_product = cam_dir:dot_product(targ_to_cam)

	if dot_product < 0 then return false end

	return true
end

-- ray directed from camera position to world space point under screen center
function Camera:get_target_ray()
	local width, height = love.graphics.getDimensions()
	return self:get_screen_ray(width/2, height/2)
end

-- ray directed from camera position to world space point under the mouse cursor
function Camera:get_mouse_ray()
	local mouse_x, mouse_y = love.mouse.getPosition()
	return self:get_screen_ray(mouse_x, mouse_y)
end

-- ray directed from camera position to a world space point
function Camera:get_ray_to(pos) -- vec3
	return Vec3.sub(pos, self:position()):normalized()
end

-- ray directed from camera position to world space point under x, y screen coord
function Camera:get_screen_ray(x, y)
	local nds_coord   = {2 * x / love.graphics.getWidth() - 1, 2 * y / love.graphics.getHeight() - 1}
	local clip_coord  = {nds_coord[1], nds_coord[2], -1, 1}
	local eye_coord   = self:get_inverse_projection_matrix() * clip_coord
	local world_coord = self:get_inverse_view_matrix() *  {eye_coord[1], eye_coord[2], -1, 0}

	return Vec3(world_coord):normalized()
end

return Camera:new()
