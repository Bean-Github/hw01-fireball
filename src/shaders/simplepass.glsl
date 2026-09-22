#version 300 es

// extracts bright pixels from a framebuffer
precision highp float;

uniform sampler2D u_Image;

in vec2 fs_UV;
out vec4 outColor;

uniform sampler2D u_Scene;
uniform sampler2D u_Bloom;

void main() {
    vec3 hdrColor = texture(u_Scene, fs_UV).rgb;
    vec3 bloomColor = texture(u_Bloom, fs_UV).rgb;

    // Additive blending
    float bloomIntensity = 1.0f; // Adjust this value to control the intensity of the bloom effect
    hdrColor += bloomColor * bloomIntensity; 

    // Tone mapping (Reinhard example) and Gamma Correction
    vec3 result = vec3(1.0f) - exp(-hdrColor * 1.0f);
    result = pow(result, vec3(1.0f / 2.2f));

    outColor = vec4(result, 1.0f);
}