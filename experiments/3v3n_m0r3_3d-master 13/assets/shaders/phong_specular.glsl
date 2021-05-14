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
	float specular_intensity;
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
	vec3 light_to_model  = normalize(model.position - model.light_position);
	vec3 light_reflexion = reflect(light_to_model, vertex_surface_normal);

	vec3 camera_to_model  = normalize(model.position - camera.position);
	vec3 camera_to_vertex = normalize(vertex_position - camera.position);

	float dp_pos = dot(light_reflexion, -camera_to_vertex);
	float dp_dir = dot(light_reflexion, -camera.target);

	vec4 final_color = model.color;
	
	if (dp_pos > .9) {
		vec4 specular_color = model.specular_intensity * model.light_color;
		final_color += specular_color;
	}

	return vec4(final_color.xyz, 1);

}
#endif
