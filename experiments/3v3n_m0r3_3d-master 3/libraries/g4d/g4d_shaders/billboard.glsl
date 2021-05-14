struct Camera {
	mat4 projection_matrix;
	mat4 view_matrix;
	vec4 position;
};

struct Model {
	mat4 matrix;
	vec4 color;
	vec3 scale;
};

uniform Camera camera;
uniform Model model;


#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
{

	mat4 model_matrix_copy = model.matrix;
	model_matrix_copy[1][1] = -model_matrix_copy[1][1];

	mat4 view_model_matrix = camera.view_matrix * model_matrix_copy;

	view_model_matrix[0][0] = model.scale[0];
	view_model_matrix[0][1] = 0.0;
	view_model_matrix[0][2] = 0.0;

	// Comment for no y rotation
	// view_model_matrix[1][0] = 0.0;
	// view_model_matrix[1][1] = model.scale[1];
	// view_model_matrix[1][1] = -view_model_matrix[1][1];
	// view_model_matrix[1][2] = 0.0;

	view_model_matrix[2][0] = 0.0;
	view_model_matrix[2][1] = 0.0;
	view_model_matrix[2][2] = model.scale[2];

	return camera.projection_matrix * view_model_matrix * vec4(initial_vertex_position.x, initial_vertex_position.y, 0,initial_vertex_position.w);
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 texture_color = Texel(texture, texture_coords);
	return texture_color * model.color;
}
#endif
