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
varying vec3 vertex_surface_normal;

#ifdef VERTEX
attribute vec4 initial_vertex_surface_normal;
vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
{
	vertex_position       = (model.matrix * initial_vertex_position).xyz;
	vertex_surface_normal = normalize((model.inverse_matrix * initial_vertex_surface_normal).xyz);

	return camera.projection_matrix * camera.view_matrix * model.matrix * initial_vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	float vertex_cam_dot_product = dot(vertex_surface_normal, -camera.target); // value between [-1, +1]
	vertex_cam_dot_product       = (vertex_cam_dot_product + 1) / 2;   // normalize     [0 , +1]

	return vec4(vertex_cam_dot_product, 0, 0, 1);
}
#endif
