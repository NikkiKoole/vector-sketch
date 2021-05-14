Tween = Class:extend('Tween')

function Tween:new(value, method, ...)
	@.current  = value
	@.initial  = value
	@.delta    = 0
	@.method   = method or 'linear'
	@.args     = {...}
	@.duration = 0
	@.elapsed  = 0
end

function Tween:update(dt)
	if @.elapsed == @.duration then return end

	@.elapsed += dt

	local progress       = math.min(1, @.elapsed / @.duration)
	local tween_progress = @:tween_progress(@.method, progress, @.args)
	@.current            = @.initial + @.delta * tween_progress

	if progress == 1 then 
		@.duration = 0
		@.elapsed  = 0
	end
end

function Tween:tween(target, time, method, ...)
	local args = {...}
	if !method && #args == 0 then args = @.args end -- keep tween args if we don't chage the method
	if time  == 0 then @.current = target end
	
	@.initial  = @.current
	@.delta    = target - @.current
	@.duration = time
	@.elapsed  = 0
	@.args     = args
	@.method   = method or @.method
end

function Tween:get() 
	return @.current
end

function Tween:set(value)
	@.current  = value
	@.initial  = value
	@.delta    = 0
	@.duration = 0
	@.elapsed  = 0
end

function Tween:tween_progress(method, progress, ...)
	if progress >= 1 then 
		return 1 
	elif method:find('in%-out%-') then 
		return Tween.chain(Tween[method:sub(8, -1)], Tween.out(Tween[method:sub(8, -1)]))(progress, ...) 
	elif method:find('in%-')      then 
		return Tween[method:sub(4, -1)](progress, ...)
	elif method:find('out%-')     then
		return Tween.out(Tween[method:sub(5, -1)])(progress, ...) 
	else  
		return Tween[method](progress, ...) 
	end
end

function Tween.out(f) 
	return function(x, ...) return 1 - f(1-x, ...) end 
end

function Tween.chain(f1, f2) 
	return function(x, ...) return (x < 0.5 and f1(2*x, ...) or 1 + f2(2*x-1, ...))*0.5 end 
end

function Tween.linear(x)
	 return x 
end

function Tween.quad(x) 
	return x^2 
end

function Tween.cubic(x) 
	return x^3 
end

function Tween.quart(x) 
	return x^4 
end

function Tween.quint(x) 
	return x^5 
end

function Tween.sine(x) 
	return 1 - math.cos(x * math.pi/2 ) 
end

function Tween.expo(x) 
	return 2^(10 * (x - 1)) 
end

function Tween.circ(x) 
	return 1 - math.sqrt(1 - x^2) 
end

function Tween.back(x, args) -- bounciness
	local b = args[1] or 1.70158
	return x * x * ((b+1) * x - b) 
end

function Tween.bounce(x) 
	local a, b = 7.5625, 1/2.75
	return math.min(
		a * x^2, 
		a * (x - 1.5   * b) ^ 2 + .75,
		a * (x - 2.25  * b) ^ 2 + .9375, 
		a * (x - 2.625 * b) ^ 2 + .984375
	) 
end

function Tween.elastic(x, args) -- amp, period
	local a = args[1] or 1
	local p = args[2] or .3
	a = math.max(1, a) 
	return (-a * math.sin(2 * math.pi/p * (x-1) - math.asin(1/a))) * 2^(10 * (x-1)) 
end
