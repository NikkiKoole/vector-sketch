Segment = Class:extend('Segment')

function Segment:new(x, y, length, angle)
	@.length = length
	@.angle  = angle % (math.pi*2)
	@.a      = Vec2(x, y)
	@.b      = @.a + Vec2:from_cartesian(@.length, @.angle)
end

function Segment:set_a(x, y)
	@.a = Vec2(x, y)
	@.b = @.a + Vec2:from_cartesian(@.length, @.angle)
end

function Segment:set_b(x, y)
	@.b = Vec2(x, y)
	@.a = @.b + Vec2:from_cartesian(@.length, @.angle)
end

function Segment:a_follow(target_x, target_y)
	local target = Vec2(target_x, target_y)
	local dir    = target - @.b

	@.angle = dir:angle()
	@.a     = target
	@.b     = @.a - Vec2:from_cartesian(@.length, @.angle)
end

function Segment:b_follow(target_x, target_y)
	local target = Vec2(target_x, target_y)
	local dir    = target - @.a

	@.angle = dir:angle()
	@.b     = target
	@.a     = @.b - Vec2:from_cartesian(@.length, @.angle)
end
