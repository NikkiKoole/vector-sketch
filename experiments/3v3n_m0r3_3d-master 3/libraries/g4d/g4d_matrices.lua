local Vectors = require(G4D_PATH .. '/g4d_vectors')
local cos, sin, tan = math.cos, math.sin, math.tan

local Matrices = {}

function Matrices:get_transformation_matrix(x, y, z, rx, ry, rz, sx, sy, sz)
	local matrix    = self:get_identity_matrix()
	local t_matrix  = self:get_translation_matrix(x, y, z)
	local rx_matrix = self:get_x_rotation_matrix(rx)
	local ry_matrix = self:get_y_rotation_matrix(ry)
	local rz_matrix = self:get_z_rotation_matrix(rz)
	local s_matrix  = self:get_scale_matrix(sx, sy, sz)

	matrix = self:multiply(matrix, t_matrix)
	matrix = self:multiply(matrix, rx_matrix)
	matrix = self:multiply(matrix, ry_matrix)
	matrix = self:multiply(matrix, rz_matrix)
	matrix = self:multiply(matrix, s_matrix)

	return matrix
end

function Matrices:get_identity_matrix()
	return {
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}
end

function Matrices:get_translation_matrix(x, y, z)
	return {
		1, 0, 0, x,
		0, 1, 0, y,
		0, 0, 1, z,
		0, 0, 0, 1,
	}
end

function Matrices:get_quaternion_matrix(x, y, z, w)
	return {
		1 - 2*y^2 - 2*z^2, 2*x*y - 2*z*w,     2*x*z + 2*y*w,     0,
		2*x*y + 2*z*w,     1 - 2*x^2 - 2*z^2, 2*y*z - 2*x*w,     0,
		2*x*z - 2*y*w,     2*y*z + 2*x*w,     1 - 2*x^2 - 2*y^2, 0,
		0,                 0,                 0,                 1,
	}
end

function Matrices:get_x_rotation_matrix(rx)
	return {
		1, 0,       0,        0,
		0, cos(rx), -sin(rx), 0,
		0, sin(rx), cos(rx),  0,
		0, 0,       0,        1,
	}
end

function Matrices:get_y_rotation_matrix(ry)
	return {
		cos(ry),  0, sin(ry), 0,
		0,        1, 0,       0,
		-sin(ry), 0, cos(ry), 0,
		0,        0, 0,       1,
	}
end

function Matrices:get_z_rotation_matrix(rz)
	return {
		cos(rz), -sin(rz), 0, 0,
		sin(rz), cos(rz),  0, 0,
		0,       0,        1, 0,
		0,       0,        0, 1,
	}
end

function Matrices:get_scale_matrix(sx, sy, sz)
	return {
		sx, 0,  0,  0,
		0,  sy, 0,  0,
		0,  0,  sz, 0,
		0,  0,  0,  1,
	}
end

function Matrices:get_projection_matrix(fov, near, far, aspect_ratio)
	local x = 1 / (aspect_ratio * tan(fov / 2))
	local y = 1 / (tan(fov / 2))
	local z = -((far + near) / (far - near)) 
	local w = -(( 2 * far * near) / (far - near)) 

	return {
		x, 0, 0,  0,
		0, y, 0,  0,
		0, 0, z,  w,
		0, 0, -1, 0,
	}
end

function Matrices:get_orthographic_matrix(fov, size, near, far, aspect_ratio)
	local t = size * tan(fov/2)
	local b = -1   * t
	local r = t    * aspect_ratio
	local l = -1   * r

	return {
		2/(r-l), 0,       0,             -((r+l)/(r-l)),
		0,       2/(t-b), 0,             -((t+b)/(t-b)),
		0,       0,       -2/(far-near), -((far+near)/(far-near)),
		0,       0,       0,             1
	}
end

function Matrices:get_view_matrix(eye, target, down)
	local z = Vectors:normalize({eye[1] - target[1], eye[2] - target[2], eye[3] - target[3]})
	local x = Vectors:normalize(Vectors:cross_product(down, z))
	local y = Vectors:cross_product(z, x)

	return {
		x[1], x[2], x[3], -1 * Vectors:dot_product(x, eye),
		y[1], y[2], y[3], -1 * Vectors:dot_product(y, eye),
		z[1], z[2], z[3], -1 * Vectors:dot_product(z, eye),
		0,    0,    0,    1,
	}
end

function Matrices:multiply(a, b)
	local matrix = {
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
	}

	local i = 1
	for y = 1, 4 do
		for x = 1, 4 do
			matrix[i] = matrix[i] + self:get_value_at(a, 1, y) * self:get_value_at(b, x, 1)
			matrix[i] = matrix[i] + self:get_value_at(a, 2, y) * self:get_value_at(b, x, 2)
			matrix[i] = matrix[i] + self:get_value_at(a, 3, y) * self:get_value_at(b, x, 3)
			matrix[i] = matrix[i] + self:get_value_at(a, 4, y) * self:get_value_at(b, x, 4)
			i = i + 1
		end
	end
	return matrix
end

function Matrices:get_value_at(matrix, x,y)
	return matrix[x + (y-1)*4]
end

function Matrices:transpose(m)
	return {
		self:get_value_at(m, 1,1), self:get_value_at(m, 1,2), self:get_value_at(m, 1,3), self:get_value_at(m, 1,4),
		self:get_value_at(m, 2,1), self:get_value_at(m, 2,2), self:get_value_at(m, 2,3), self:get_value_at(m, 2,4),
		self:get_value_at(m, 3,1), self:get_value_at(m, 3,2), self:get_value_at(m, 3,3), self:get_value_at(m, 3,4),
		self:get_value_at(m, 4,1), self:get_value_at(m, 4,2), self:get_value_at(m, 4,3), self:get_value_at(m, 4,4),
	}
end

function Matrices:invert(m)
	local matrix = self:get_identity_matrix()
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

function Matrices:multiply_vector(m, v) -- mat4, vec4
	local vec4 = {}

	vec4[1] = v[1]*m[1]  + v[2]*m[2]  + v[3]*m[3]  + v[4]*m[4]
	vec4[2] = v[1]*m[5]  + v[2]*m[6]  + v[3]*m[7]  + v[4]*m[8]
	vec4[3] = v[1]*m[9]  + v[2]*m[10] + v[3]*m[11] + v[4]*m[12]
	vec4[4] = v[1]*m[13] + v[2]*m[14] + v[3]*m[15] + v[4]*m[16]

	return vec4
end

return Matrices
