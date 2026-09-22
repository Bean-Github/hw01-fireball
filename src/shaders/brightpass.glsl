#version 300 es

// extracts bright pixels from a framebuffer
precision highp float;

uniform sampler2D u_Image;

in vec2 fs_UV;

out vec4 outColor;

void main() {
    vec3 color = texture(u_Image, fs_UV).rgb;

    float brightness = dot(color, vec3(0.2126f, 0.7152f, 0.0722f));

    if(brightness > 1.0f) {
        outColor = vec4(color, 1.0f);
    } else {
        outColor = vec4(0.0f);
    }

}