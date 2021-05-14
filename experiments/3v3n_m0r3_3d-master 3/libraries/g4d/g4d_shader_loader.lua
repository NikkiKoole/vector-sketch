local Shaders = {}

for _, item in pairs(love.filesystem.getDirectoryItems(G4D_PATH .. '/g4d_shaders')) do
	Shaders[item:gsub('.glsl', '')] = love.graphics.newShader(G4D_PATH .. '/g4d_shaders/' .. item) 
end

return function(name) 
	if name == 'all' then
		return Shaders 
	else
		return Shaders[name] 
	end
end