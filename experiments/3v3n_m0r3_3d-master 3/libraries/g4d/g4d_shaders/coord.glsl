struct Camera {
	mat4 projection_matrix;
	mat4 view_matrix;
	vec4 position;
};

struct Model {
	mat4 matrix;
	vec4 color;
};

uniform Camera camera;
uniform Model model;


#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
{
	return camera.projection_matrix * camera.view_matrix * model.matrix * initial_vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	return vec4(1, texture_coords.x, texture_coords.y, 1);
}
#endif
