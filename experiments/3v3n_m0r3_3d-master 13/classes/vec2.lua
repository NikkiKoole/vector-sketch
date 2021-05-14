local acos, atan2, sqrt, cos, sin, min, max = math.acos, math.atan2, math.sqrt, math.cos, math.sin, math.min, math.max

Vec2 = Class:extend('Vec2')

function Vec2:new(x, y)
	if type(x) == 'table' then x, y = x.x or x[1], x.y or x[2] end

	@[1] = x or 0
	@[2] = y or x or 0
end

function Vec2:is_vec2(a)
	return type(a) == 'table' and type(a[1]) == 'number' and type(a[2]) == 'number' 
end

function Vec2:clone() 
	return Vec2(@[1], @[2]) 
end

function Vec2:copy() 
	return Vec2(@[1], @[2])
end

function Vec2:mul(b)
	if Vec2:is_vec2(b) then 
		return Vec2(@[1] * b[1], @[2] * b[2]) 
	else 
		return Vec2(@[1] * b, @[2] * b) 
	end 
end

function Vec2:div_vector(b)
	return Vec2(@[1] / b[1], @[2] / b[2]) 
end

function Vec2:div_scalar(b)
	return Vec2(@[1] / b, @[2] / b)
end

function Vec2:trim(length) 
	return @:normalized():mul(min(@:len(), length)) 
end

function Vec2:cross(b) 
	return @[1] * b[2] - @[2] * b[1] 
end

function Vec2:dot(b) 
	return @[1] * b[1] + @[2] * b[2] 
end

function Vec2:length() 
	return sqrt(@[1] * @[1] + @[2] * @[2])
end

function Vec2:len() 
	return sqrt(@[1] * @[1] + @[2] * @[2])
end

function Vec2:len2()
	return @[1] * @[1] + @[2] * @[2]
end

function Vec2:normalize()
	local temp 
	if @:is_zero() then 
		temp = Vec2() 
	else 
		temp = @:mul(1 / @:len()) 
	end 
	@[1], @[2] = temp[1], temp[2] 
	return @ 
end

function Vec2:scale(b) 
	local temp = Vec2(@[1], @[2]):normalized():mul(b) 
	@[1], @[2] = temp[1], temp[2] 
	return @ 
end

function Vec2:rotate(angle)
	local temp = Vec2(cos(angle) * @[1] - sin(angle) * @[2], sin(angle) * @[1] + cos(angle) * @[2]) 
	@[1], @[2] = temp[1], temp[2] 
	return @
end

function Vec2:normalized() 
	if @:is_zero() then 
		return Vec2() 
	else 
		return @:mul(1 / @:len()) 
	end 
end

function Vec2:scaled(b) 
	return Vec2(@[1], @[2]):normalized():mul(b)
end

function Vec2:rotated(phi) 
	local c = cos(phi) 
	local s = sin(phi) 
	return Vec2(c * @[1] - s * @[2], s * @[1] + c * @[2]) 
end

function Vec2:perpendicular() 
	return Vec2(-@[2], @[1]) 
end

function Vec2:angle() 
	return atan2(@[2], @[1]) 
end

function Vec2:lerp(b, s) 
	return @ + (b - @) * s 
end

function Vec2:unpack() 
	return @[1], @[2] 
end

function Vec2:component_min(b) 
	return Vec2(min(@[1], b[1]), min(@[2], b[2])) 
end

function Vec2:component_max(b) 
	return Vec2(max(@[1], b[1]), max(@[2], b[2])) 
end

function Vec2:from_cartesian(length, angle) 
	return Vec2(length * cos(angle), length * sin(angle)) 
end

function Vec2:to_string() 
	return string.format('(%+0.3f,%+0.3f)', @[1], @[2]) 
end

function Vec2:is_zero() 
	return @[1] == 0 and @[2] == 0 
end

function Vec2:unit_x() 
	return Vec2(1, 0) 
end

function Vec2:unit_y() 
	return Vec2(0, 1) 
end

function Vec2:distance_to(b) 
	local dx = @[1] - b[1] 
	local dy = @[2] - b[2] 
	return sqrt(dx^2 + dy^2) 
end

function Vec2:length_to(b) 
	local dx = @[1] - b[1] 
	local dy = @[2] - b[2] 
	return sqrt(dx^2 + dy^2) 
end

function Vec2:len2_to(b) 
	local dx = @[1] - b[1] 
	local dy = @[2] - b[2] 
	return dx^2 + dy^2 
end

function Vec2:to_polar() 
	local length = sqrt(@[1]^2 + @[2]^2) 
	local angle  = atan2(@[2], @[1]) 
	angle = angle > 0 and angle or angle + 2 * math.pi 
	return length, angle 
end

function Vec2:angle_to(b) 
	return atan2(b[2] - @[2], b[1] - @[1]) 
end

function Vec2:angle_between(b) 
	local source, target = @:angle(), b:angle() 
	return atan2(sin(source-target), cos(source-target)) 
end

function Vec2:__tostring()
	return @:to_string()
end

function Vec2:__unm() 
	return Vec2(-@[1], -@[2]) 
end

function Vec2:__eq(b)
	return @[1] == b[1] and @[2] == b[2]
end

function Vec2:__add(b)
	return Vec2(@[1] + b[1], @[2] + b[2])
end

function Vec2:__sub(b)
	return Vec2(@[1] - b[1], @[2] - b[2])
end

function Vec2:__mul(b)
	return @:mul(b)
end

function Vec2:__div(b)
	if Vec2:is_vec2(b) then 
		return @:div_vector(b)
	else
		return @:div_scalar(b)
	end
end