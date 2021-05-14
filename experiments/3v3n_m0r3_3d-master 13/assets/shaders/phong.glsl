#define MAX_LIGHTS 32

struct Light {
	vec3 position;
	vec4 color;

	float ambient_intensity;
	float diffuse_intensity;
	float specular_intensity;
};

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

	bool is_ambient_disabled;
	bool is_diffuse_disabled;
	bool is_specular_disabled;
	bool is_model_color_disabled;

	int light_count;
	Light lights[MAX_LIGHTS];
};


uniform Camera camera;
uniform Model  model;

varying vec3 vertex_position;
varying vec3 vertex_surface_normal;
varying vec3 vertex_normal;

#ifdef VERTEX
attribute vec4 initial_vertex_surface_normal;
attribute vec4 initial_vertex_normal;
vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
{
	vertex_position       = (model.matrix * initial_vertex_position).xyz;
	vertex_surface_normal = normalize((model.inverse_matrix * initial_vertex_surface_normal).xyz);
	vertex_normal         = normalize((model.inverse_matrix * initial_vertex_normal).xyz);

	return camera.projection_matrix * camera.view_matrix * model.matrix * initial_vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 final_color = vec4(0, 0, 0, 1);

	for (int i = 0; i < model.light_count; i++) {
		Light light = model.lights[i];

		// Ambient
		vec4 ambient_color = light.ambient_intensity * light.color;
		if (!model.is_ambient_disabled) final_color += ambient_color;

		// Diffuse
		vec3  vertex_to_light = normalize(light.position - vertex_position);
		float direction_dp    = dot(vertex_surface_normal, normalize(vertex_to_light));
		vec4  diffuse_color   = light.color * direction_dp * light.diffuse_intensity;
		if (!model.is_diffuse_disabled) final_color += diffuse_color;

		// Specular
		// TODO: do something about camera target
		// float dp_dir = dot(light_reflexion, -camera.target); 
		vec3 light_to_model   = normalize(model.position - light.position);
		vec3 light_reflexion  = reflect(light_to_model, vertex_surface_normal);
		vec3 vertex_to_camera = normalize(camera.position - vertex_position);

		float dot_product = dot(light_reflexion, vertex_to_camera);
		if (dot_product > (1 - .05)) { //TODO - create a parameter for specular_size
			vec4 specular_color = light.specular_intensity * light.color;
			if (!model.is_specular_disabled) final_color += specular_color;
		}
	}

	// TODO: caculate color better
	if (!model.is_model_color_disabled) final_color += model.color;

	return vec4(final_color.xyz, 1);
}
#endif
