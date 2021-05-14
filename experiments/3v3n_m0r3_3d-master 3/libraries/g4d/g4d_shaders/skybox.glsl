struct Camera {
	mat4 projection_matrix;
	mat4 view_matrix;
	vec4 position;
};

struct Model {
	mat4 matrix;
	vec4 color;
	CubeImage cube_texture;
};

uniform Camera camera;
uniform Model model;

varying vec4 cube_texture_coord;


#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 initial_vertex_position)
{
	mat4 untranslated_view_matrix = mat4(mat3(camera.view_matrix));
	cube_texture_coord = initial_vertex_position;

	return camera.projection_matrix * untranslated_view_matrix * model.matrix * initial_vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 texture_color = Texel(model.cube_texture, -vec3(cube_texture_coord));
	return texture_color * model.color;
}
#endif
