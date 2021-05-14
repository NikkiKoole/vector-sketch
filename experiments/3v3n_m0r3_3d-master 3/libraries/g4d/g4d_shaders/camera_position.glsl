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

varying vec4 vertex_position;


#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
{
	vertex_position = model.matrix * initial_vertex_position;

	return camera.projection_matrix * camera.view_matrix * model.matrix * initial_vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	float distance_to_camera = distance(camera.position, vertex_position);
	distance_to_camera = min(distance_to_camera/50, 1);

	return vec4(1 - distance_to_camera, distance_to_camera, 1 - distance_to_camera, 1);
}
#endif
