local DOT_THRESHOLD = 0.9995

local Quaternion = {}

function Quaternion:new(x, y, z, w)
	if type(x) == 'table' then x, y, z, w = x[1], x[2], x[3], x[4] end

	local quaternion = setmetatable({}, Quaternion)

	quaternion[1] = x or 0
	quaternion[2] = y or 0
	quaternion[3] = z or 0
	quaternion[4] = w or 1

	return quaternion
end

function Quaternion:from_angle_axis(angle, x, y, z)
	if     type(angle) == 'table' then angle, x, y, z = angle[1], angle[2], angle[3], angle[4]
	elseif type(x)     == 'table' then x, y, z = x[1], x[2], x[3] end

	local qx = x * math.sin(angle/2)
	local qy = y * math.sin(angle/2)
	local qz = z * math.sin(angle/2)
	local qw =     math.cos(angle/2)

	return Quaternion(qx, qy, qz, qw)
end

function Quaternion:from_euler(yaw, pitch, roll) -- z-axis, y-axis, x-axis 
	if type(yaw) == 'table' then yaw, pitch, roll = yaw[1], yaw[2], yaw[3] end

	local cos_y = math.cos(yaw   * 0.5)
	local sin_y = math.sin(yaw   * 0.5)
	local cos_p = math.cos(pitch * 0.5)
	local sin_p = math.sin(pitch * 0.5)
	local cos_r = math.cos(roll  * 0.5)
	local sin_r = math.sin(roll  * 0.5)

	local qx = sin_r * cos_p * cos_y - cos_r * sin_p * sin_y
	local qy = cos_r * sin_p * cos_y + sin_r * cos_p * sin_y
	local qz = cos_r * cos_p * sin_y - sin_r * sin_p * cos_y
	local qw = cos_r * cos_p * cos_y + sin_r * sin_p * sin_y

	return Quaternion(qx, qy, qz, qw)
end

function Quaternion:to_euler(qx, qy, qz, qw)
	if type(qx) == 'table' then qx, qy, qz, qw = qx[1], qx[2], qx[3], qx[4] end
	local yaw, pitch, roll

	local siny_cosp =     2 * (qw * qz + qx * qy)
	local cosy_cosp = 1 - 2 * (qy * qy + qz * qz)
	yaw = math.atan2(siny_cosp, cosy_cosp)

	local sinp = 2 * (qw * qy - qz * qx)
	if math.abs(sinp) >= 1 then
		-- use 90 degrees if out of range
		if sinp < 0 then pitch = -math.pi/2 else pitch = math.pi/2 end 
	else
		pitch = math.asin(sinp)
	end

	local sinr_cosp =     2 * (qw * qx + qy * qz)
	local cosr_cosp = 1 - 2 * (qx * qx + qy * qy)
	roll = math.atan2(sinr_cosp, cosr_cosp)

	return Vec3(yaw, pitch, roll) -- z-axis, y-axis, x-axis 
end

function Quaternion:normalize()
	local length = self:length()

	self[1] = self[1] / length
	self[2] = self[2] / length
	self[3] = self[3] / length
	self[4] = self[4] / length

	return self
end

function Quaternion:length()
	return math.sqrt(self[1]^2 + self[2]^2 + self[3]^2 + self[4]^2)
end

function Quaternion:dot_product(q)
	return self[1] * q[1] + self[2] * q[2] + self[3] * q[3] + self[3] * q[3]
end

function Quaternion:add(q)
	return Quaternion(self[1]+q[1], self[2]+q[2], self[3]+q[3],self[4]+q[4])
end

function Quaternion:sub(q)
	return Quaternion(self[1]-q[1], self[2]-q[2], self[3]-q[3],self[4]-q[4])
end

function Quaternion:conjugate()
	return Quaternion(-self[1], -self[2], -self[3], self[4])
end

function Quaternion:mul_quaternion(q)
	local x = self[1]*q[4] + self[4]*q[1] + self[2]*q[3] - self[3]*q[2]
	local y = self[2]*q[4] + self[4]*q[2] + self[3]*q[1] - self[1]*q[3]
	local z = self[3]*q[4] + self[4]*q[3] + self[1]*q[2] - self[2]*q[1]
	local w = self[4]*q[4] - self[1]*q[1] - self[2]*q[2] - self[3]*q[3]

	return Quaternion(x, y, z, w)
end

function Quaternion:mul_vector(v)
	local x =  self[4]*v[1] + self[2]*v[3] - self[3]*v[2]
	local y =  self[4]*v[2] + self[3]*v[1] - self[1]*v[3]
	local z =  self[4]*v[3] + self[1]*v[2] - self[2]*v[1]
	local w = -self[1]*v[1] - self[2]*v[2] - self[3]*v[3]

	return Quaternion(x, y, z, w)
end

function Quaternion:mul_scalar(s)
	return Quaternion(self[1]*s, self[2]*s, self[3]*s, self[4]*s)
end

function Quaternion:nlerp(q, step)
	return Quaternion(self + (q - self) * step):normalize()
end

function Quaternion:slerp(q, step) -- quaternion, number
	local dot_product = self:dot_product(q)

	if dot_product < 0 then
		self        = -self
		dot_product = -dot_product
	end

	if dot_product > DOT_THRESHOLD then
		return self:nlerp(q, step)
	end

	dot_product = math.min(math.max(dot_product, -1), 1)

	local theta = math.acos(dot_product) * step
	local c     = (q - self * dot_product):normalize()
	local interpolated = self * math.cos(theta) + c * math.sin(theta)

	return interpolated
end

function Quaternion:__index(v)
	return Quaternion[v]
end

function Quaternion:__add(q)
	return self:add(q)
end

function Quaternion:__sub(q)
	return self:sub(q)
end

function Quaternion:__mul(q)
	if type(q) == 'number' then 
		return self:mul_scalar(q) -- scalar
	elseif #q == 3 then 
		return self:mul_vector(q) -- vec3
	elseif #q == 4 then
		return self:mul_quaternion(q) -- quaternion
	end
end

function Quaternion:__tostring()
	local x = math.floor(self[1] * 1000)/1000
	local y = math.floor(self[2] * 1000)/1000
	local z = math.floor(self[3] * 1000)/1000
	local w = math.floor(self[4] * 1000)/1000

	return 'Quaternion = [x]: ' .. x .. ' [y]: ' .. y .. ' [z]: ' .. z .. ' [w]: ' .. w
end

return setmetatable(Quaternion, {__call = Quaternion.new})

