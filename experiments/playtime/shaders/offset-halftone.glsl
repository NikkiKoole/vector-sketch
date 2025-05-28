extern Image tex;
extern vec2 screenSize;

const float PI = 3.14159265359;

vec2 rotate(vec2 coord, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    mat2 m = mat2(c, -s, s, c);
    return m * coord;
}

float halftone(vec2 uv, float angle, float size) {
    vec2 rotated = rotate(uv * screenSize, angle);
    vec2 grid = floor(rotated / size);
    vec2 cellCenter = (grid + 0.5) * size;
    float dist = length(rotated - cellCenter);
    return smoothstep(size * 0.5, 0.0, dist);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screenCoords) {
    vec4 texColor = Texel(tex, uv);

    float C = 1.0 - texColor.r;
    float M = 1.0 - texColor.g;
    float Y = 1.0 - texColor.b;
    float K = min(min(C, M), Y);

    // Simulated CMY without K, subtract K to keep only chroma
    C -= K;
    M -= K;
    Y -= K;

    float dotSize = 4.0;

    float cDot = halftone(uv + vec2(0.002, 0.002), radians(15.0), dotSize) * C;
    float mDot = halftone(uv + vec2(-0.002, 0.001), radians(75.0), dotSize) * M;
    float yDot = halftone(uv + vec2(0.001, -0.002), radians(0.0), dotSize) * Y;
    float kDot = halftone(uv, radians(45.0), dotSize) * K;

    vec3 cmyk = vec3(1.0) - vec3(cDot, mDot, yDot);
    float kMix = 1.0 - kDot;

    vec3 final = cmyk * kMix;

    return vec4(final, 1.0);
}
