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

varying vec3 vertex_position;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
{
	vertex_position = (model.matrix * initial_vertex_position).xyz;

	return camera.projection_matrix * camera.view_matrix * model.matrix * initial_vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	return vec4(camera.target.xyz, 1);
}
#endif
