Scene = Class:extend('Scene')

function Scene:new()
	@.trigger      = Trigger()
	@.camera       = Camera()
	@.id           = ''
	@.queue        = {}
	@.ents         = {}
	@.ents_by_id   = {}
	@.ents_by_type = {}
end

function Scene:update(dt)
	@.trigger:update(dt)
	@.camera:update(dt)

	-- update entitites
	ifor @.ents do 
		it:update(dt) 
	end

	-- delete dead entities
	rfor @.ents do 
		if it.dead then
			for type in it.types do @.ents_by_type[type][it.id] = nil end
			it:remove_all_triggers()
			it.scene            = nil
			@.ents_by_id[it.id] = nil
			table.remove(@.ents, key)
		end
	end

	-- push entities from queue
	for queued_ent in @.queue do
		ifor type in queued_ent.types do 
			@.ents_by_type[type] = get(@, {'ents_by_type', type}, {}) -- create 'type' table if not already existing
			@.ents_by_type[type][queued_ent.id] = queued_ent
		end
		@.ents_by_id[queued_ent.id] = queued_ent
		insert(@.ents, queued_ent)
	end
	@.queue = {}
end

function Scene:draw()
	table.sort(@.ents, fn(a, b) if a.z == b.z then return a.id < b.id else return a.z < b.z end end)

	local previous_color = {lg.getColor()}
	@.camera:draw(function()
		@:draw_inside_camera_bg()
		lg.setColor(previous_color)

		for @.ents do 
			if it.draw && !it.outside_camera && it.visible then 
				it:draw()
				lg.setColor(previous_color)
			end
		end

		@:draw_inside_camera_fg()
		lg.setColor(previous_color)
	end)

	@:draw_outside_camera_bg()
	lg.setColor(previous_color)

	for @.ents do 
		if it.draw && it.outside_camera && it.visible then
			it:draw()
			lg.setColor(previous_color)
		end
	end

	@:draw_outside_camera_fg()
	lg.setColor(previous_color)
end

function Scene:add(a, b, c)
	local id, types, entity

	if   type(a) == 'string' && type(b) == 'table' && type(c) == 'nil' then
		id, types, entity = a, {}, b
	elif type(a) == 'string' && type(b) == 'table' && type(c) == 'table' then
		id, types, entity = a, b, c
	elif type(a) == 'string' && type(b) == 'string' && type(c) == 'table' then 
		id, types, entity = a, {b}, c
	elif type(a) == 'table' && type(b) == 'table' && type(c) == 'nil' then
		id, types, entity = uid(), a, b
	elif type(a) == 'table' && type(b) == 'nil' && type(c) == 'nil' then
		id, types, entity = uid(), {}, a
	end

	if @:get(id) then return false end

	insert(types, entity:class())
	for entity.types do insert(types, it) end

	entity.types = types  
	entity.id    = id
	entity.scene = @
	@.queue[id]  = entity
	
	return entity
end

function Scene:remove(id) 
	local entity = @:get(id)
	if entity then entity:kill() end
end

function Scene:remove_all_entities()
	for @:get_all_entities() do
		it:kill()
	end
end

function Scene:get(id)
	local entity = @.ents_by_id[id]
	if !entity or entity.dead then return false end
	return entity
end

function Scene:get_all_entities()
	local entities = {}
	for @.ents do
		if !it.dead then insert(entities, it) end
	end
	return entities
end

function Scene:get_by_type(...)
	local entities = {}
	local types    = {...}
	local filtered = {} -- filter duplicate entities using id

	if types[1] == 'All' then 
		return @:get_all_entities() 
	end

	for type in types do
		if @.ents_by_type[type] then
			for @.ents_by_type[type] do
				if !it.dead then filtered[it.id] = it end
			end
		end
	end

	for filtered do insert(entities, it) end

	return entities
end

function Scene:count(...)
	return #@:get_by_type(...)
end

function Scene:draw_inside_camera_bg()
end

function Scene:draw_outside_camera_bg()
end

function Scene:draw_inside_camera_fg()
end

function Scene:draw_outside_camera_fg()
end

function Scene:enter() 
end

function Scene:exit() 
end

function Scene:after(...)
	return @.trigger:after(...)
end

function Scene:tween(...)
	return @.trigger:tween(...)
end

function Scene:every(...)
	return @.trigger:every(...)
end

function Scene:every_immediate(...)
	return @.trigger:every_immediate(...)
end

function Scene:during(...)
	return @.trigger:during(...)
end

function Scene:during_true(...)
	return @.trigger:during_true(...)
end

function Scene:once(...)
	return @.trigger:once(...)
end

function Scene:chain(...)
	return @.trigger:chain(...)
end

function Scene:always(...)
	return @.trigger:always(...)
end

function Scene:get_trigger(...)
	return @.trigger:get(...)
end

function Scene:remove_all_triggers()
	@.trigger:remove_all_triggers()
end

function Scene:remove_trigger(...)
	return @.trigger:remove(...)
end

function Scene:zoom(...)
	@.camera:zoom(...)
end

function Scene:shake(...)
	@.camera:shake(...)
end

function Scene:follow(...)
	@.camera:follow(...)
end

function Scene:move(...)
	@.camera:move(...)
end

function Scene:get_mouse_position_inside_camera() 
	return {@.camera:get_mouse_position()}
end

function Scene:get_mouse_position_outside_camera()
	return {lm.getPosition()} 
end