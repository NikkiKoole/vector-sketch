Spring = Class:extend('Spring')

function Spring:new(value, stiffness, dampening)
	@.target    = value
	@.current   = value
	@.v         = 0
	@.stiffness = stiffness or 100
	@.dampening = dampening or 10
end

function Spring:update(dt)
	local diff = @.current - @.target
	local a    = -@.stiffness * diff - @.dampening * @.v
	@.v       += (a   * dt)
	@.current += (@.v * dt)
end

function Spring:pull(amount)
	@.current += amount
end

function Spring:change(value) 
	@.target = value
end

function Spring:get() 
	return @.current
end

function Spring:set(value) 
	@.current = value
	@.target  = value
end
