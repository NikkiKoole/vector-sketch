local Vec3 = require(G4D_PATH .. '/vec3')
local cos, sin, tan = math.cos, math.sin, math.tan

local Mat4 = {}

function Mat4:new(...)
	local args = {...}
	if type(args[1]) == 'table' then m = args[1] else m = args end

	local matrix = setmetatable({}, Mat4)

	matrix[1] , matrix[2] , matrix[3] , matrix[4]  = m[1] , m[2] , m[3] , m[4]  
	matrix[5] , matrix[6] , matrix[7] , matrix[8]  = m[5] , m[6] , m[7] , m[8]  
	matrix[9] , matrix[10], matrix[11], matrix[12] = m[9] , m[10], m[11], m[12] 
	matrix[13], matrix[14], matrix[15], matrix[16] = m[13], m[14], m[15], m[16] 

	return matrix
end

function Mat4:get_transformation_matrix(x, y, z, rx, ry, rz, rw, sx, sy, sz)
	local matrix = self:get_identity_matrix()

	matrix = matrix * self:get_translation_matrix(x, y, z)

	if not rw then
		matrix = matrix * self:get_x_axis_rotation_matrix(rx)
		matrix = matrix * self:get_y_axis_rotation_matrix(ry)
		matrix = matrix * self:get_z_axis_rotation_matrix(rz)
	else
		matrix = matrix * self:get_quaternion_matrix(rx, ry, rz, rw)
	end

	matrix = matrix * self:get_scale_matrix(sx, sy, sz)

	return matrix
end

function Mat4:get_identity_matrix()
	return Mat4(
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1
	)
end

function Mat4:get_translation_matrix(x, y, z)
	return Mat4(
		1, 0, 0, x,
		0, 1, 0, y,
		0, 0, 1, z,
		0, 0, 0, 1
	)
end

function Mat4:get_quaternion_matrix(x, y, z, w)
	return Mat4(
		1 - 2*y^2 - 2*z^2, 2*x*y - 2*z*w    , 2*x*z + 2*y*w    , 0,
		2*x*y + 2*z*w    , 1 - 2*x^2 - 2*z^2, 2*y*z - 2*x*w    , 0,
		2*x*z - 2*y*w    , 2*y*z + 2*x*w    , 1 - 2*x^2 - 2*y^2, 0,
		0                , 0                , 0                , 1
	)
end

function Mat4:get_x_axis_rotation_matrix(rx)
	return Mat4(
		1, 0      , 0        , 0,
		0, cos(rx), -sin(rx) , 0,
		0, sin(rx), cos(rx)  , 0,
		0, 0      , 0        , 1
	)
end

function Mat4:get_y_axis_rotation_matrix(ry)
	return Mat4(
		cos(ry) , 0, sin(ry), 0,
		0       , 1, 0      , 0,
		-sin(ry), 0, cos(ry), 0,
		0       , 0, 0      , 1
	)
end

function Mat4:get_z_axis_rotation_matrix(rz)
	return Mat4(
		cos(rz), -sin(rz), 0, 0,
		sin(rz), cos(rz) , 0, 0,
		0      , 0       , 1, 0,
		0      , 0       , 0, 1
	)
end

function Mat4:get_scale_matrix(sx, sy, sz)
	return Mat4(
		sx, 0 , 0 , 0,
		0 , sy, 0 , 0,
		0 , 0 , sz, 0,
		0 , 0 , 0 , 1
	)
end

function Mat4:get_projection_matrix(fov, near, far, aspect_ratio)
	local x = 1 / (aspect_ratio * tan(fov / 2))
	local y = 1 / (tan(fov / 2))
	local z = -((far + near) / (far - near)) 
	local w = -(( 2 * far * near) / (far - near)) 

	return Mat4(
		x, 0, 0 , 0,
		0, y, 0 , 0,
		0, 0, z , w,
		0, 0, -1, 0
	)
end

function Mat4:get_orthographic_matrix(fov, size, near, far, aspect_ratio)
	local t = size * tan(fov/2)
	local b = -1   * t
	local r = t    * aspect_ratio
	local l = -1   * r

	return Mat4(
		2/(r-l), 0      , 0            , -((r+l)/(r-l))          ,
		0      , 2/(t-b), 0            , -((t+b)/(t-b))          ,
		0      , 0      , -2/(far-near), -((far+near)/(far-near)),
		0      , 0      , 0            , 1
	)
end

function Mat4:get_view_matrix(eye, target, down)
	local z = Vec3(eye[1] - target[1], eye[2] - target[2], eye[3] - target[3]):normalized()
	local x = Vec3.cross_product(down, z):normalized()
	local y = Vec3.cross_product(z, x)

	return Mat4(
		x[1], x[2], x[3], -1 * Vec3.dot_product(x, eye),
		y[1], y[2], y[3], -1 * Vec3.dot_product(y, eye),
		z[1], z[2], z[3], -1 * Vec3.dot_product(z, eye),
		0   , 0   , 0   , 1
	)
end

function Mat4:mul_matrix(m)
	local matrix = Mat4(
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0
	)

	local i = 1
	for y = 1, 4 do
		for x = 1, 4 do
			matrix[i] = matrix[i] + self:get_value_at(1, y) * m:get_value_at(x, 1)
			matrix[i] = matrix[i] + self:get_value_at(2, y) * m:get_value_at(x, 2)
			matrix[i] = matrix[i] + self:get_value_at(3, y) * m:get_value_at(x, 3)
			matrix[i] = matrix[i] + self:get_value_at(4, y) * m:get_value_at(x, 4)
			i = i + 1
		end
	end
	return matrix
end

function Mat4:mul_vector(x, y, z, w)
	if type(x) == 'table' then x, y, z, w = x[1], x[2], x[3], x[4] end
	if not w then w = 1 end

	local vec3 = Vec3()

	vec3[1]     = x * self[1]  + y * self[2]  + z * self[3]  + w * self[4]
	vec3[2]     = x * self[5]  + y * self[6]  + z * self[7]  + w * self[8]
	vec3[3]     = x * self[9]  + y * self[10] + z * self[11] + w * self[12]
	local vec_w = x * self[13] + y * self[14] + z * self[15] + w * self[16]

	return vec3, vec_w
end

function Mat4:get_value_at(x, y)
	return self[x + (y-1)*4]
end

function Mat4:transpose()
	return Mat4(
		self:get_value_at(1, 1), self:get_value_at(1, 2), self:get_value_at(1, 3), self:get_value_at(1, 4),
		self:get_value_at(2, 1), self:get_value_at(2, 2), self:get_value_at(2, 3), self:get_value_at(2, 4),
		self:get_value_at(3, 1), self:get_value_at(3, 2), self:get_value_at(3, 3), self:get_value_at(3, 4),
		self:get_value_at(4, 1), self:get_value_at(4, 2), self:get_value_at(4, 3), self:get_value_at(4, 4)
	)
end

function Mat4:invert()
	local matrix = self:get_identity_matrix()
	local m      = self

	matrix[1]  =  m[6] * m[11] * m[16] - m[6] * m[12] * m[15] - m[10] * m[7] * m[16] + m[10] * m[8] * m[15] + m[14] * m[7] * m[12] - m[14] * m[8] * m[11]
	matrix[2]  = -m[2] * m[11] * m[16] + m[2] * m[12] * m[15] + m[10] * m[3] * m[16] - m[10] * m[4] * m[15] - m[14] * m[3] * m[12] + m[14] * m[4] * m[11]
	matrix[3]  =  m[2] * m[7]  * m[16] - m[2] * m[8]  * m[15] - m[6]  * m[3] * m[16] + m[6]  * m[4] * m[15] + m[14] * m[3] * m[8]  - m[14] * m[4] * m[7]
	matrix[4]  = -m[2] * m[7]  * m[12] + m[2] * m[8]  * m[11] + m[6]  * m[3] * m[12] - m[6]  * m[4] * m[11] - m[10] * m[3] * m[8]  + m[10] * m[4] * m[7]
	matrix[5]  = -m[5] * m[11] * m[16] + m[5] * m[12] * m[15] + m[9]  * m[7] * m[16] - m[9]  * m[8] * m[15] - m[13] * m[7] * m[12] + m[13] * m[8] * m[11]
	matrix[6]  =  m[1] * m[11] * m[16] - m[1] * m[12] * m[15] - m[9]  * m[3] * m[16] + m[9]  * m[4] * m[15] + m[13] * m[3] * m[12] - m[13] * m[4] * m[11]
	matrix[7]  = -m[1] * m[7]  * m[16] + m[1] * m[8]  * m[15] + m[5]  * m[3] * m[16] - m[5]  * m[4] * m[15] - m[13] * m[3] * m[8]  + m[13] * m[4] * m[7]
	matrix[8]  =  m[1] * m[7]  * m[12] - m[1] * m[8]  * m[11] - m[5]  * m[3] * m[12] + m[5]  * m[4] * m[11] + m[9]  * m[3] * m[8]  - m[9]  * m[4] * m[7]
	matrix[9]  =  m[5] * m[10] * m[16] - m[5] * m[12] * m[14] - m[9]  * m[6] * m[16] + m[9]  * m[8] * m[14] + m[13] * m[6] * m[12] - m[13] * m[8] * m[10]
	matrix[10] = -m[1] * m[10] * m[16] + m[1] * m[12] * m[14] + m[9]  * m[2] * m[16] - m[9]  * m[4] * m[14] - m[13] * m[2] * m[12] + m[13] * m[4] * m[10]
	matrix[11] =  m[1] * m[6]  * m[16] - m[1] * m[8]  * m[14] - m[5]  * m[2] * m[16] + m[5]  * m[4] * m[14] + m[13] * m[2] * m[8]  - m[13] * m[4] * m[6]
	matrix[12] = -m[1] * m[6]  * m[12] + m[1] * m[8]  * m[10] + m[5]  * m[2] * m[12] - m[5]  * m[4] * m[10] - m[9]  * m[2] * m[8]  + m[9]  * m[4] * m[6]
	matrix[13] = -m[5] * m[10] * m[15] + m[5] * m[11] * m[14] + m[9]  * m[6] * m[15] - m[9]  * m[7] * m[14] - m[13] * m[6] * m[11] + m[13] * m[7] * m[10]
	matrix[14] =  m[1] * m[10] * m[15] - m[1] * m[11] * m[14] - m[9]  * m[2] * m[15] + m[9]  * m[3] * m[14] + m[13] * m[2] * m[11] - m[13] * m[3] * m[10]
	matrix[15] = -m[1] * m[6]  * m[15] + m[1] * m[7]  * m[14] + m[5]  * m[2] * m[15] - m[5]  * m[3] * m[14] - m[13] * m[2] * m[7]  + m[13] * m[3] * m[6]
	matrix[16] =  m[1] * m[6]  * m[11] - m[1] * m[7]  * m[10] - m[5]  * m[2] * m[11] + m[5]  * m[3] * m[10] + m[9]  * m[2] * m[7]  - m[9]  * m[3] * m[6]

	local det = m[1] * matrix[1] + m[2] * matrix[5] + m[3] * matrix[9] + m[4] * matrix[13]

	if det == 0 then return m end

	det = 1 / det

	for i = 1, 16 do matrix[i] = matrix[i] * det end

	return matrix
end

function Mat4:__index(v)
	return Mat4[v]
end

function Mat4:__mul(m)
	if #m == 3 or #m == 4 then 
		return self:mul_vector(m)
	elseif #m == 16 then
		return self:mul_matrix(m)
	end
end

return setmetatable(Mat4, {__call = Mat4.new})
