float random(float x) {
    float f = 43758.5453123;
    return fract(sin(x) * f);
}

float random(vec2 st) {
    return random(st.x + st.y * 57.0);
}

float random(vec3 st) {
    return random(st.x + st.y * 57.0 + st.z * 123.0);
}

vec3 randomOnUnitSphere(vec3 seed) {
    float u = random(seed);
    float v = random(seed + 17.23);

    float z = 1.0 - 2.0 * u;
    float r = sqrt(1.0 - z * z);
    float phi = 2.0 * 3.14159265359 * v;

    return vec3(r * cos(phi), r * sin(phi), z);
}

float perlinNoise3D(vec3 p) {

    // implement perlin noise here
    vec3 cell = vec3(floor(p));

    vec3 f = fract(p); // local coordinates within the cell

    vec3 p000 = randomOnUnitSphere(cell + vec3(0, 0, 0));
    vec3 p100 = randomOnUnitSphere(cell + vec3(1, 0, 0));
    vec3 p010 = randomOnUnitSphere(cell + vec3(0, 1, 0));
    vec3 p110 = randomOnUnitSphere(cell + vec3(1, 1, 0));

    vec3 p001 = randomOnUnitSphere(cell + vec3(0, 0, 1));
    vec3 p101 = randomOnUnitSphere(cell + vec3(1, 0, 1));
    vec3 p011 = randomOnUnitSphere(cell + vec3(0, 1, 1));
    vec3 p111 = randomOnUnitSphere(cell + vec3(1, 1, 1));

    float d000 = dot(p000, f - vec3(0, 0, 0));
    float d100 = dot(p100, f - vec3(1, 0, 0));
    float d010 = dot(p010, f - vec3(0, 1, 0));
    float d110 = dot(p110, f - vec3(1, 1, 0));
    float d001 = dot(p001, f - vec3(0, 0, 1));
    float d101 = dot(p101, f - vec3(1, 0, 1));
    float d011 = dot(p011, f - vec3(0, 1, 1));
    float d111 = dot(p111, f - vec3(1, 1, 1));

    vec3 fade = smoothstep(0.0, 1.0, f);

    float nx00 = mix(d000, d100, fade.x);
    float nx10 = mix(d010, d110, fade.x);

    float nx01 = mix(d001, d101, fade.x);
    float nx11 = mix(d011, d111, fade.x);

    float nxy0 = mix(nx00, nx10, fade.y);
    float nxy1 = mix(nx01, nx11, fade.y);

    float nxyz = mix(nxy0, nxy1, fade.z);

    return nxyz;
}

float fbm(vec3 x, int octaves, float amplitude, float frequency, vec3 shift, float lacunarity, float gain) {
    float value = 0.0;
    float maxAmplitude = 0.0; // Track the total possible amplitude

    for(int i = 0; i < octaves; ++i) {
        float sn = perlinNoise3D(x * frequency);
        value += amplitude * sn;
        maxAmplitude += amplitude; // Add current amplitude to the total

        x += shift;
        frequency *= lacunarity;
        amplitude *= gain;
    }

    float normalized = value / maxAmplitude;

    // Remap from [-1.0, 1.0] to [0.0, 1.0]
    return (normalized + 1.0) * 0.5;
}

float bias(float t, float b) {
    return pow(t, log(b) / log(0.5));
}

float gain(float t, float g) {
    if(t < 0.5) {
        return bias(t * 2.0, 1.0 - g) / 2.0;
    } else {
        return 1.0 - bias(2.0 - t * 2.0, 1.0 - g) / 2.0;
    }
}

vec3 lerp(vec3 a, vec3 b, float t) {
    return a + t * (b - a);
}
