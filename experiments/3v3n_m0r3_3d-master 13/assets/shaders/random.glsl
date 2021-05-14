float random(vec2 coord) { 
	return fract(sin(dot(coord , vec2(1.23, 4.56))) * 785910.11);
}

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
	float time;
};


const float CELL_SIZE = 50;

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
	vec2 translated_coord1 = floor(vec2(texture_coords.x   + model.time/10, texture_coords.y   + model.time/10) * CELL_SIZE);
	vec2 translated_coord2 = floor(vec2(texture_coords.x+1 - model.time/10, texture_coords.y+1 - model.time/10) * CELL_SIZE);
	vec2 translated_coord3 = floor(vec2(texture_coords.x+2 + model.time/10, texture_coords.y+2 - model.time/10) * CELL_SIZE);
	vec2 translated_coord4 = floor(vec2(texture_coords.x+3 - model.time/10, texture_coords.y+3 + model.time/10) * CELL_SIZE);

	float random1 = random(translated_coord1);
	float random2 = random(translated_coord2);
	float random3 = random(translated_coord3);
	float random4 = random(translated_coord4);

	float mix1      = mix(random1, random2, .5);
	float mix2      = mix(random3, random4, .5);
	float final_mix = mix(mix1, mix2, .5);

	return vec4(final_mix, final_mix, final_mix, 1);
}
#endif
