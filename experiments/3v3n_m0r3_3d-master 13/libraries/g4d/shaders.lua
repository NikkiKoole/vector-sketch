local Shaders = {}

Shaders['default.glsl'] = love.graphics.newShader([[
	struct Camera {
		mat4 projection_matrix;
		mat4 view_matrix;
		vec3 position;
		vec3 target;
	};
	
	struct Model {
		mat4 matrix;
		mat4 inverse_matrix;
		vec3 position;
		vec4 color;
	};
	
	uniform Camera camera;
	uniform Model  model;
	
	#ifdef VERTEX
	vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
	{
		return camera.projection_matrix * camera.view_matrix * model.matrix * initial_vertex_position;
	}
	#endif
	
	#ifdef PIXEL
	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
	{
		vec4 texture_color = Texel(texture, texture_coords);
		return texture_color * model.color;
	}
	#endif
]])

-- TODO: gérer mieux les shaders avec des path arbitraires
local folder_paths = {'assets/shaders'}

for _, path in pairs(folder_paths) do
	for _, item in pairs(love.filesystem.getDirectoryItems(path)) do
		Shaders[item] = love.graphics.newShader(path .. '/' .. item) 
	end
end

for k, v in pairs(Shaders) do
	print('shader loaded: ' .. k)
end

return Shaders