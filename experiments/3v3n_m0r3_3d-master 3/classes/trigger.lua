Trigger = Class:extend('Trigger')

function Trigger:new()
	@.triggers = {}
end

function Trigger:update(dt)
  for tag, v in pairs(@.triggers) do
		if v.active then
			v.elapsed += dt
	
			if v.type == 'after' then 
				if v.elapsed >= v.total then 
					v.action(dt)
					v.after(dt)
					@:remove(tag)
				end

			elif v.type == 'during' then
				v.action(dt)
				if v.elapsed >= v.total then 
					v.after(dt)
					@:remove(tag) 
				end
	
			elif v.type == 'every' then
				if v.elapsed >= v.total then
					v.action(dt)
					v.elapsed -= v.total
					v.total = @:calculate_time(v.initial)
					v.count += 1
					if v.count == v.total_count then 
						v.after(dt)
						@:remove(tag)
					end
				end
	
			elif v.type == 'after_true' then
				if v.cond() then 
					v.action(dt)
					v.after(dt)
					@:remove(tag) 
				end
	
			elif v.type == 'during_true' then
				if v.cond() then 
					if v.action_switch then v.action_switch = false end
					v.action(dt)
				elif !v.cond() && !v.action_switch then
					v.count += 1
					if v.count == v.total_count then
						v.after(dt)
						@:remove(tag)
					else
						v.action_switch = true
					end
				end
	
			elif v.type == 'every_true' then
				if v.cond() && v.action_switch then 
					v.action_switch = false
					v.action(dt)
					v.count += 1 
					if v.count == v.total_count then 
						v.after(dt)
						@:remove(tag)
					end
				elif !v.cond() && !v.action_switch then
					v.action_switch = true
				end
	
			elif v.type == 'tween' then
				local progress       = math.min(1, v.elapsed/v.total)
				local tween_progress = @:calculate_tween_progress(v.method, progress, _) -- TODO: add arguments to tween

				for _, tweened_value in ipairs(v.tweened_values) do 
					local subject, key, initial, delta = unpack(tweened_value)
					subject[key] = initial + delta * tween_progress
				end

				if v.elapsed >= v.total then 
					v.after(dt)
					@:remove(tag)
				end
			end
		end
	end
end

function Trigger:after(condition, action, tag, after)
	local tag = tag || uid()
	if @.triggers[tag] then return false end

	if type(condition) == 'function' then
		@.triggers[tag] = { 
			tag     = tag,
			type    = 'after_true',
			active  = true,
			elapsed = 0,
			cond    = condition,
			action  = action,
			after   = after || fn() end
		}
	else
		@.triggers[tag] = {
			tag     = tag,
			type    = 'after', 
			active  = true,
			elapsed = 0, 
			total   = @:calculate_time(condition), 
			action  = action,
			after   = after || fn() end,
		}
	end

	return @.triggers[tag]
end

function Trigger:every(condition, action, count, tag, after)
	local tag = tag || uid()
	if @.triggers[tag] then return false end

	if type(condition) == 'function' then
		@.triggers[tag] = { 
			tag           = tag,
			type          = 'every_true',
			elapsed       = 0,
			active        = true,
			total_count   = count || -1,
			count         = 0,
			cond          = condition,
			action        = action,
			action_switch = true,
			after         = after || fn() end
		}
	else
		@.triggers[tag] = {
			tag         = tag,
			type        = 'every', 
			active      = true,
			total       = @:calculate_time(condition), 
			initial     = condition, 
			elapsed     = 0, 
			total_count = count || -1, 
			count       = 0, 
			action      = action, 
			after       = after || fn() end,
		}
	end

	return @.triggers[tag]
end

function Trigger:every_immediate(time, action, count, tag, after)
	local tag = tag || uid()
	if @.triggers[tag] then return false end
	
	local total = @:calculate_time(time)
	@.triggers[tag] = {
		tag         = tag,
		type        = 'every', 
		active      = true,
		total       = total, 
		initial     = time,
		elapsed     = total,
		total_count = count || -1, 
		count       = 0, 
		action      = action, 
		after       = after || fn() end,
	}

	return @.triggers[tag]
end

function Trigger:during(time, action, tag, after)
	local tag = tag || uid()
  	if @.triggers[tag] then return false end

	@.triggers[tag] = {
		tag     = tag,
		type    = 'during', 
		active  = true,
		elapsed = 0,
		total   = @:calculate_time(time), 
		action  = action, 
		after   = after || fn() end,
	}

	return @.triggers[tag]
end

function Trigger:during_true(condition, action, count, tag, after)
	local tag = tag || uid()
  	if @.triggers[tag] then return false end

	@.triggers[tag] = {
		tag           = tag, 
		type          = 'during_true',
		elapsed       = 0,
		active        = true,
		action_switch = true,
		total_count   = count || -1,
		count         = 0,
		cond          = condition,
		action        = action,
		after         = after || fn() end,
	}

	return @.triggers[tag]
end

function Trigger:tween(time, subject, target, method, tag, after)
	local tag = tag || uid()
	if @.triggers[tag] then return false end

	@.triggers[tag] = { 
		tag            = tag,
		type           = 'tween', 
		active         = true,
		elapsed        = 0,
		total          = @:calculate_time(time), 
		subject        = subject, 
		target         = target, 
		method         = method, 
		tweened_values = @:calculate_tweened_values(subject, target, {}),
		after          = after || fn() end, 
	}

	return @.triggers[tag]
end

function Trigger:chain(triggers, tag)
	local tag = tag || uid()
	if @.triggers[tag] then return false end

	@.triggers[tag] = {
		tag             = tag,
		type            = 'chain',
		tags            = {},
		elapsed         = 0,
		active          = true,
		current_trigger = 1,
	}

	local chain = @.triggers[tag]

	-- initialize triggers contained in the chain
	for i = 1, #triggers, 2 do
		local after_tag = @:after(triggers[i], triggers[i + 1]).tag
		if i > 1 then @:pause(after_tag) end
		insert(chain.tags, after_tag)
	end

	-- enable next trigger when previous is finished
	ifor chain.tags do
		local trigger         = @.triggers[it]
		local trigger_action  = trigger.action
		
		trigger.action = fn() 
			trigger_action()
			chain.current_trigger += 1
			if chain.current_trigger > #chain.tags then
				@:remove(chain.tag)
			else
				@:play(chain.tags[chain.current_trigger])
			end
		end
	end

	return @.triggers[tag]
end

function Trigger:once(action, tag)
	return @:every_immediate(math.huge, action, _, tag) 
end

function Trigger:always(action, tag)
	return @:during(math.huge, action, tag) 
end

function Trigger:get(tag)
	return @.triggers[tag]
end

function Trigger:pause(tag)
	local trigger = @:get(tag)
	if !trigger then return false end

	if trigger.type == 'chain' then
		@:pause(trigger.tags[trigger.current_trigger])
	end
	trigger.active = false

	return true
end

function Trigger:play(tag)
	local trigger = @:get(tag)
	if !trigger then return false end

	if trigger.type == 'chain' then
		@:play(trigger.tags[trigger.current_trigger])
	end
	trigger.active = true 

	return true
end

function Trigger:remove(tag)
	local trigger = @:get(tag)
	if !trigger then return false end

	if trigger.type == 'chain' then
		for trigger.tags do @:remove(it) end
	end
	@.triggers[tag] = nil

	return true
end

function Trigger:remove_all_triggers() 
	@.triggers = {} 
end

function Trigger:calculate_time(time) 
	if type(time) == 'table' then 
		return time[1] + love.math.random() * (time[2] - time[1]) 
	else 
		return time 
	end 
end

function Trigger:calculate_tweened_values(subject, targets, tweened_values)
	for key, target in pairs(targets) do
		if type(target) == 'table' then 
			@:calculate_tweened_values(subject[key], target, tweened_values)
		else 
			local initial = subject[key]
			local delta   = target - subject[key]
			insert(tweened_values, {subject, key, initial, delta})
		end
	end
	return tweened_values
end

function Trigger:calculate_tween_progress(method, progress, ...)
	if progress >= 1 then 
		return 1 
	elif method:find('in%-out%-') then 
		return Trigger.chain_methods(Trigger[method:sub(8, -1)], Trigger.out(Trigger[method:sub(8, -1)]))(progress, ...) 
	elif method:find('in%-')      then 
		return Trigger[method:sub(4, -1)](progress, ...)
	elif method:find('out%-')     then
		return Trigger.out(Trigger[method:sub(5, -1)])(progress, ...) 
	else  
		return Trigger[method](progress, ...) 
	end
end

function Trigger.out(f) 
	return fn(x, ...) return 1 - f(1-x, ...) end 
end

function Trigger.chain_methods(f1, f2) 
	return fn(x, ...) return (x < 0.5 && f1(2*x, ...) || 1 + f2(2*x-1, ...))*0.5 end 
end

function Trigger.linear(x) 
	return x 
end

function Trigger.quad(x) 
	return x^2 
end

function Trigger.cubic(x) 
	return x^3
end

function Trigger.quart(x) 
	return x^4
end

function Trigger.quint(x) 
	return x^5 
end

function Trigger.sine(x) 
	return 1-math.cos(x*math.pi/2) 
end

function Trigger.expo(x) 
	return 2^(10*(x-1)) 
end

function Trigger.circ(x) 
	return 1-math.sqrt(1-x^2) 
end

function Trigger.bounce(x) 
	local a, b = 7.5625, 1/2.75
	return math.min(a*x^2, a*(x-1.5*b)^2 + 0.75, a*(x-2.25*b)^2 + 0.9375, a*(x-2.625*b)^2 + 0.984375) 
end

function Trigger.back(x, b) --bounciness
	b = b || 1.70158
	return x^2*((b+1)*x - b) 
end 

function Trigger.elastic(x, a, p) -- amplitude, period
	a = a && math.max(1, a) || 1 
	p = p || 0.3
	return (-a*math.sin(2*math.pi/p*(x-1) - math.asin(1/a)))*2^(10*(x-1)) 
end 