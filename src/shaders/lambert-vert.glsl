#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

#include "helpers.glsl"

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform float u_Time;           // The time in seconds since the program started running. This is useful for
                            // animating things over time.

uniform vec3 u_CamPos;      // The position of the camera in world space. This is useful for computing
                            // the direction from the camera to each vertex, which can be used to
                            // compute a Fresnel effect in the fragment shader.

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;            // The position of each vertex in world space. This is implicitly passed to the fragment shader.
out float fs_Time;          // The time in seconds since the program started running. This is useful for
                            // animating things over time.

out vec3 fs_ViewDir;

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

float displace(vec3 pos, float time) {
    float wave = sin(pos.y * 10.0f + time * 14.0f) * 0.07f; // A simple sine wave based on the y position and time

    // Compute a Perlin noise value based on the vertex position and time
    return perlinNoise3D(vec3(pos.x, pos.y, u_Time)) * wave;
}

void main() {
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation
    fs_Time = u_Time;                       // Pass the time to the fragment shader for use in animation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    float offset = displace(vs_Pos.xyz, u_Time * 2.0f);

    vec4 displacedPos = vs_Pos + vec4(vec3(vs_Nor) * offset, 0.0f);

    float yPos = (displacedPos.y + 1.0f) / 2.0f; // Normalize y to [0, 1] range

    float eggScale = mix(0.02f, 0.001f, yPos) * 1.2f;
    eggScale = bias(eggScale, 0.82f); // Apply gain function to eggScale for a more pronounced effect

    displacedPos.x *= eggScale;
    displacedPos.z *= eggScale;

    float yScale = sin(u_Time * 0.2f + displacedPos.y * 0.5f) * 0.1f + 1.2f; // Scale y based on time and y position

    displacedPos.y = displacedPos.y * yScale;

    // tip sway
    float tipSway = perlinNoise3D(vec3(u_Time * 2.0f + displacedPos.y * 0.2f, 0.0f, 0.0f)) * yPos * 0.2f; // Sway based on time and y position

    float sideToSide = sin(u_Time * 2.0f) * 0.1f; // Move side to side over time

    vec4 modelposition = u_Model * displacedPos + tipSway;

    fs_LightVec = lightPos - modelposition;
    fs_Pos = modelposition;

    // CALCULATE VIEW DIR HERE, using the final displaced position!
    fs_ViewDir = normalize(u_CamPos - fs_Pos.xyz);

    gl_Position = u_ViewProj * modelposition;
}
