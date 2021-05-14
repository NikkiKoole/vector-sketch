local Quaternion = require(G4D_PATH .. '/quaternion')
local THRESHOLD  = 0.0001


local Vec3 = {}

function Vec3:new(x, y, z)
	if type(x) == 'table' then x, y, z = x[1], x[2], x[3] end

	local vec3 = setmetatable({}, Vec3)

	vec3[1] = x or 0
	vec3[2] = y or 0
	vec3[3] = z or 0

	return vec3
end

function Vec3:clone()
	return Vec3(self[1], self[2], self[3])
end

function Vec3:copy()
	return Vec3(self[1], self[2], self[3])
end

function Vec3:add(v)
	return Vec3(self[1] + v[1], self[2] + v[2], self[3] + v[3])
end

function Vec3:sub(v)
	return Vec3(self[1] - v[1], self[2] - v[2], self[3] - v[3])
end

function Vec3:mul_scalar(scalar)
	return Vec3(self[1]*scalar, self[2]*scalar, self[3]*scalar)
end

function Vec3:div_vector(v)
	return Vec3(self[1]/v[1], self[2]/v[2], self[3]/v[3])
end

function Vec3:div_scalar(scalar)
	return Vec3(self[1]/scalar, self[2]/scalar, self[3]/scalar)
end

function Vec3:invert()
	return Vec3(-self[1], -self[2], -self[3])
end

function Vec3:inverted()
	return self:clone():invert()
end

function Vec3:length()
	return math.sqrt(self[1]^2 + self[2]^2 + self[3]^2)
end

function Vec3:normalize()
	return self:div_scalar(self:length())
end

function Vec3:normalized()
	return self:clone():normalize()
end

function Vec3:dot_product(v)
	return self[1]*v[1] + self[2]*v[2] + self[3]*v[3]
end

function Vec3:cross_product(v)
	return Vec3(self[2]*v[3] - self[3]*v[2], self[3]*v[1] - self[1]*v[3], self[1]*v[2] - self[2]*v[1])
end

function Vec3:rotate_from_angle_axis(...) -- {angle, x, y, z}
	return self:rotate_quaternion(Quaternion:from_angle_axis(...))
end

function Vec3:rotate_from_quaternion(q) -- quaternion
	local conjugate = q:conjugate()
	local final     = q * self * conjugate

	if math.abs(final[1]) < THRESHOLD then final[1] = 0 end
	if math.abs(final[2]) < THRESHOLD then final[2] = 0 end
	if math.abs(final[3]) < THRESHOLD then final[3] = 0 end

	self[1] = final[1]
	self[2] = final[2]
	self[3] = final[3]

	return self
end

function Vec3:fast_add(a1, a2 , a3, b1, b2, b3)
	return a1+b1, a2+b2, a3+b3
end

function Vec3:fast_sub(a1, a2, a3, b1, b2, b3)
	return a1-b1, a2-b2, a3-b3
end

function Vec3:fast_mul_scalar(scalar, v1, v2, v3)
	return v1*scalar, v2*scalar, v3*scalar
end

function Vec3:fast_magnitude(x, y, z)
	return math.sqrt(x^2 + y^2 + z^2)
end

function Vec3:fast_normalize(x, y, z)
	local mag = math.sqrt(x^2 + y^2 + z^2)
	return x/mag, y/mag, z/mag
end

function Vec3:fast_dot_product(a1, a2, a3, b1, b2, b3)
	return a1*b1 + a2*b2 + a3*b3
end

function Vec3:fast_cross_product(a1, a2, a3, b1, b2, b3)
	return a2*b3 - a3*b2, a3*b1 - a1*b3, a1*b2 - a2*b1
end

function Vec3:__add(v)
	return self:add(v)
end

function Vec3:__sub(v)
	return self:sub(v)
end

function Vec3:__sub(v)
	return self:sub(v)
end

function Vec3:__div(b)
	if type(b) == 'number' then
		return self:div_scalar(b)
	else
		return self:div_vector(b)
	end
end

function Vec3:__index(v)
	return Vec3[v]
end

function Vec3:__tostring()
	local x = math.floor(self[1] * 1000)/1000
	local y = math.floor(self[2] * 1000)/1000
	local z = math.floor(self[3] * 1000)/1000

	return 'Vec3 = [x]: ' .. x .. ' [y]: ' .. y .. ' [z]: ' .. z
end

return setmetatable(Vec3, {__call = Vec3.new})
