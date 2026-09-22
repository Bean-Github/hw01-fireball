#version 300 es

precision highp float;

in vec2 fs_UV;                  // Texture coordinates passed from Vertex Shader

out vec4 outColor;

uniform sampler2D u_Image;
uniform vec2 uResolution;
uniform vec2 uDirection;      // vec2(1.0, 0.0) for horizontal, vec2(0.0, 1.0) for vertical

void main() {
    // Calculate the size of a single pixel in UV space
    vec2 texelSize = 1.0f / uResolution;

    // Pre-calculated weights for a 9-tap Gaussian kernel (sum = 1.0)
    float weights[5] = float[](0.227027f, 0.1945946f, 0.1216216f, 0.054054f, 0.016216f);

    vec4 result = texture(u_Image, fs_UV) * weights[0];

    // Sample symmetrical neighboring pixels along the direction axis
    for(int i = 1; i < 5; ++i) {
        vec2 offset = uDirection * texelSize * float(i);
        result += texture(u_Image, fs_UV + offset) * weights[i];
        result += texture(u_Image, fs_UV - offset) * weights[i];
    }

    outColor = result;
}
