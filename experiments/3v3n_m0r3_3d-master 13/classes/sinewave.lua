Sinewave = Class:extend('Sinewave')

function Sinewave:new(value, amplitude, duration, initial_completion_amount)
	local initial_completion_amount = initial_completion_amount or 0

	@.initial   = value     or 0
	@.amplitude = amplitude or 1
	@.duration  = duration  or 1
	@.timer     = initial_completion_amount * @.duration
	@.sin       = 0
	@.cos       = 0
	@.playing   = true
end

function Sinewave:update(dt)
	if !@.playing then return end
	
	@.timer += dt
	@.timer %= @.duration

	local completion_amount = @.timer / @.duration
	local radius_amount     = 2 * math.pi * completion_amount

	@.sin = @.amplitude * math.sin(radius_amount)
	@.cos = @.amplitude * math.cos(radius_amount)
end

function Sinewave:stop()
	@.playing = false
end

function Sinewave:play()
	@.playing = true
end

function Sinewave:get() 
	return @.initial + @.sin
end

function Sinewave:get_sin() 
	return @.initial + @.sin
end

function Sinewave:get_cos() 
	return @.initial + @.cos
end

function Sinewave:set(value)
	@.initial = value
end
