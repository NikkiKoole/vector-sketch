Class = {}

function Class:extend(name)
	local class = {}

	for k, v in pairs(self) do
		if k:find('__') == 1 then 
			class[k] = v 
		end
	end
	class.__index = class
	class.super   = self
	class.new     = function() end
	class.class   = function() return name or 'Default' end

	return setmetatable(class, self)
end

function Class:implement(...)
	for _, class in pairs({...}) do
		for k, v in pairs(class) do
			if self[k] == nil and type(v) == 'function' then
				self[k] = v
			end
		end
	end
end

function Class:__index(v) 
	return Class[v] 
end

function Class:__call(...) 
	local obj = setmetatable({}, self) 
	obj:new(...) 
	return obj 
end
