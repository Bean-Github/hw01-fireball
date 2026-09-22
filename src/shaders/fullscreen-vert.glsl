#version 300 es

// simple fullscreen vert shader
precision highp float;

in vec2 vs_Pos;
out vec2 fs_UV;

void main() {
    fs_UV = vs_Pos * 0.5f + 0.5f;
    gl_Position = vec4(vs_Pos, 0.0f, 1.0f);
}
