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

	vec3 light_position;
	vec4 light_color;
	float diffuse_intensity;
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
	vec3  vertex_to_light = normalize(model.light_position - vertex_position);
	float direction_dp    = dot(vertex_surface_normal, normalize(vertex_to_light));
	vec4  diffuse_color   = model.light_color * direction_dp * model.diffuse_intensity;

	vec4 final_color = model.color + diffuse_color;

	return vec4(final_color.xyz, 1);
}
#endif