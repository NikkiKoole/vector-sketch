local acos, atan2, sqrt, cos, sin, min, max = math.acos, math.atan2, math.sqrt, math.cos, math.sin, math.min, math.max

Vec2 = Class:extend('Vec2')

function Vec2:new(x, y)
	if type(x) == 'table' then
		x, y = x.x or x[1], x.y or x[2]
	end
	@.x = x or 0
	@.y = y or x or 0
end

function Vec2:is_vec2(a)
	return type(a) == 'table' and type(a.x) == 'number' and type(a.y) == 'number' 
end

function Vec2:clone() 
	return Vec2(@.x, @.y) 
end

function Vec2:copy() 
	return Vec2(@.x, @.y)
end

function Vec2:mul(b)
	if Vec2:is_vec2(b) then 
		return Vec2(@.x * b.x, @.y * b.y) 
	else 
		return Vec2(@.x * b, @.y * b) 
	end 
end

function Vec2:div(b)
	if Vec2:is_vec2(b) then 
		return Vec2(@.x / b.x, @.y / b.y) 
	else
		return Vec2(@.x / b, @.y / b)
	end
end

function Vec2:trim(length) 
	return @:normalized():mul(min(@:len(), length)) 
end

function Vec2:cross(b) 
	return @.x * b.y - @.y * b.x 
end

function Vec2:dot(b) 
	return @.x * b.x + @.y * b.y 
end

function Vec2:length() 
	return sqrt(@.x * @.x + @.y * @.y)
end

function Vec2:len() 
	return sqrt(@.x * @.x + @.y * @.y)
end

function Vec2:len2()
	return @.x * @.x + @.y * @.y
end

function Vec2:normalize()
	local temp 
	if @:is_zero() then 
		temp = Vec2() 
	else 
		temp = @:mul(1 / @:len()) 
	end 
	@.x, @.y = temp.x, temp.y 
	return @ 
end

function Vec2:scale(b) 
	local temp = Vec2(@.x, @.y):normalized():mul(b) 
	@.x, @.y = temp.x, temp.y 
	return @ 
end

function Vec2:rotate(angle)
	local temp = Vec2(cos(angle) * @.x - sin(angle) * @.y, sin(angle) * @.x + cos(angle) * @.y) 
	@.x, @.y = temp.x, temp.y 
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
	return Vec2(@.x, @.y):normalized():mul(b)
end

function Vec2:rotated(phi) 
	local c = cos(phi) 
	local s = sin(phi) 
	return Vec2(c * @.x - s * @.y, s * @.x + c * @.y) 
end

function Vec2:perpendicular() 
	return Vec2(-@.y, @.x) 
end

function Vec2:angle() 
	return atan2(@.y, @.x) 
end

function Vec2:lerp(b, s) 
	return @ + (b - @) * s 
end

function Vec2:unpack() 
	return @.x, @.y 
end

function Vec2:component_min(b) 
	return Vec2(min(@.x, b.x), min(@.y, b.y)) 
end

function Vec2:component_max(b) 
	return Vec2(max(@.x, b.x), max(@.y, b.y)) 
end

function Vec2:from_cartesian(length, angle) 
	return Vec2(length * cos(angle), length * sin(angle)) 
end

function Vec2:to_string() 
	return string.format('(%+0.3f,%+0.3f)', @.x, @.y) 
end

function Vec2:is_zero() 
	return @.x == 0 and @.y == 0 
end

function Vec2:unit_x() 
	return Vec2(1, 0) 
end

function Vec2:unit_y() 
	return Vec2(0, 1) 
end

function Vec2:distance_to(b) 
	local dx = @.x - b.x 
	local dy = @.y - b.y 
	return sqrt(dx^2 + dy^2) 
end

function Vec2:length_to(b) 
	local dx = @.x - b.x 
	local dy = @.y - b.y 
	return sqrt(dx^2 + dy^2) 
end

function Vec2:len2_to(b) 
	local dx = @.x - b.x 
	local dy = @.y - b.y 
	return dx^2 + dy^2 
end

function Vec2:to_polar() 
	local length = sqrt(@.x^2 + @.y^2) 
	local angle  = atan2(@.y, @.x) 
	angle = angle > 0 and angle or angle + 2 * math.pi 
	return length, angle 
end

function Vec2:angle_to(b) 
	return atan2(b.y - @.y, b.x - @.x) 
end

function Vec2:angle_between(b) 
	local source, target = @:angle(), b:angle() 
	return atan2(sin(source-target), cos(source-target)) 
end

function Vec2:__tostring()
	return @:to_string()
end

function Vec2:__unm() 
	return Vec2(-@.x, -@.y) 
end

function Vec2:__eq(b)
	return @.x == b.x and @.y == b.y
end

function Vec2:__add(b)
	return Vec2(@.x + b.x, @.y + b.y)
end

function Vec2:__sub(b)
	return Vec2(@.x - b.x, @.y - b.y)
end

function Vec2:__mul(b)
	return @:mul(b)
end

function Vec2:__div(b)
	return @:div(b)
end