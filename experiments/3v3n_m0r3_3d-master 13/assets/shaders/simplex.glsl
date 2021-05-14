vec3 mod289(vec3 x)  { 
	return x - floor(x * (1.0 / 289.0)) * 289.0; 
}

vec2 mod289(vec2 x)  { 
	return x - floor(x * (1.0 / 289.0)) * 289.0; 
}

vec3 permute(vec3 x) { 
	return mod289(((x*34.0)+1.0)*x); 
}

float simplex(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626,  0.024390243902439);
    vec2 i   = floor(v + dot(v, C.yy) );
    vec2 x0  = v - i + dot(i, C.xx);
    vec2 i1  = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;

    x12.xy -= i1;
    i = mod289(i);

    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 )) + i.x + vec3(0.0, i1.x, 1.0 ));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m;
    m = m*m;

    vec3 x  = 2.0 * fract(p * C.www) - 1.0;
    vec3 h  = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	 
    return 130.0 * dot(m, g);
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

const float CELL_SIZE = 3;

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

	float motion1 = simplex(vec2(translated_coord.x    + model.time/5, translated_coord.y    + model.time/5));
	float motion2 = simplex(vec2(translated_coord.x+1. + model.time/5, translated_coord.y+1. - model.time/5));
	float motion3 = simplex(vec2(translated_coord.x+2. - model.time/5, translated_coord.y+2. - model.time/5));
	float motion4 = simplex(vec2(translated_coord.x+3. - model.time/5, translated_coord.y+3. + model.time/5));

	float mix1      = mix(motion1, motion2, .5);
	float mix2      = mix(motion3, motion4, .5);
	float final_mix = mix(mix1, mix2, .5);

	// make final result whiter
	final_mix += .3; 

	// fun parameteur
	// final_mix = fract(final_mix * 6);

	// other fun parameter
	// float noise_change = fwidth(final_mix);
	// float line_height  = smoothstep(1 - noise_change, 1, final_mix);
	// line_height += smoothstep(noise_change, 0, final_mix);
	// final_mix = line_height;

	return vec4(final_mix, final_mix, final_mix, 1);
}
#endif
