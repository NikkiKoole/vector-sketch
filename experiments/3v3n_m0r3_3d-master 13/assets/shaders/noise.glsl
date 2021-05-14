float random(vec2 coord) { 
	return fract(sin(dot(coord , vec2(1.23, 4.56))) * 78910.11);
}

float noise(vec2 p) {    
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0-2.0  *f);
    return mix(mix(random(i + vec2(0.,0.)), random(i + vec2(1.,0.)), u.x), mix(random(i + vec2(0.,1.)), random(i + vec2(1.,1.)), u.x), u.y);
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

const float CELL_SIZE = 10;

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
	vec2 translated_coord = texture_coords * CELL_SIZE;

	float motion1 = noise(vec2(translated_coord.x    + model.time, translated_coord.y    + model.time));
	float motion2 = noise(vec2(translated_coord.x+1. + model.time, translated_coord.y+1. - model.time));
	float motion3 = noise(vec2(translated_coord.x+2. - model.time, translated_coord.y+2. - model.time));
	float motion4 = noise(vec2(translated_coord.x+3. - model.time, translated_coord.y+3. + model.time));

	float mix1      = mix(motion1, motion2, .5);
	float mix2      = mix(motion3, motion4, .5);
	float final_mix = mix(mix1, mix2, .5);

	return vec4(final_mix, final_mix, final_mix, 1);
}
#endif
