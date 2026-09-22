#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

#include "helpers.glsl"

uniform vec4 u_Color; // The color with which to render this instance of geometry.

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec3 fs_ViewDir;
in vec4 fs_Col;
in vec4 fs_Pos; // The position of the pixel in world space. This is useful for computing
                // procedural noise, which can be used to animate things over time.

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

in float fs_Time; // The time in seconds since the program started running. This is useful for
                // animating things over time.

uniform vec3 u_DimColor;
uniform vec3 u_BlueColor;
uniform vec3 u_ShimmerColorBase;
uniform vec3 u_ShimmerColorTop;
uniform vec3 u_BrightColor1;
uniform vec3 u_BrightColor2;
uniform vec3 u_TopColor;

float genericFBM(vec3 pos) {
    return fbm(pos, 5, 5.0f, 1.0f, vec3(0.0f, 0.0f, 0.0f), 2.0f, 0.5f); // Compute a Perlin noise value based on the pixel position and time
}

float fresnel(float amount) {
    return pow(1.0f - clamp(dot(normalize(fs_Nor.xyz), normalize(fs_ViewDir)), 0.0f, 1.0f), amount);
}

void main() {
    // Material base color (before shading)
    vec4 diffuseColor = u_Color;

        // Calculate the diffuse term for Lambert shading
    float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

    float ambientTerm = 0.2f;

    float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.
    // normalize y to [0, 1] range
    float yPos = (fs_Pos.y + 1.0f) / 2.0f;
    float distToBase = length(vec3(fs_Pos.x, 0.0f, fs_Pos.z));

    // DIM
    vec3 dimColor = u_DimColor * 5.0f;

    // BLUE
    vec3 blueColor = u_BlueColor;

    float blueColorRange = 0.2f;
    float blueColorSmoothness = 0.3f;

    float blueColorFactor = smoothstep(blueColorRange, blueColorRange + blueColorSmoothness, yPos);
    blueColorFactor = 1.0f - blueColorFactor; // Invert the factor to make it fade out towards the top

    // BLACK
    vec3 black1 = vec3(0.0f, 0.0f, 0.0f);
    vec3 black2 = blueColor;
    vec3 black = lerp(black1, black1, fresnel(8.0f));

    // make range round, so higher y values are more likely to be black
    float blackColorRange = 0.2f * (1.0f - fresnel(5.0f));
    float blackColorSmoothness = 0.4f;
    float blackColorFactor = smoothstep(blackColorRange, blackColorRange + blackColorSmoothness, (yPos + 0.2f) - (1.0f - fresnel(1.0f)));
    blackColorFactor = 1.0f - clamp(blackColorFactor, 0.0f, 1.0f);
    blackColorFactor -= fresnel(5.0f); // Add a Fresnel effect to the black factor
    blackColorFactor = clamp(blackColorFactor, 0.0f, 1.0f);

    float roundedY = yPos - clamp(dot(fs_Pos.xz, fs_ViewDir.xz), 0.0f, 1.0f) * 0.5f;

    float superBlackFactor = smoothstep(0.1f, 0.5f, roundedY);
    superBlackFactor = 1.0f - superBlackFactor; // Invert the factor to make it fade out towards the top

    // get distance from the base of the fireball to the current pixel
    blackColorFactor = 1.0f - blackColorFactor; // Invert the factor to make it fade out towards the top

    blackColorFactor = max(blackColorFactor, superBlackFactor); // Combine the two factors to get the final black factor

    // SHIMMER
    vec3 shimmerColorBase = u_ShimmerColorBase * 2.0f;
    vec3 shimmerColorTop = u_ShimmerColorTop * 2.0f;
    vec3 shimmerColor = lerp(shimmerColorBase, shimmerColorTop, bias(yPos, 0.8f));
    float shimmerColorFactor = 0.0f;
    shimmerColorFactor += fresnel(3.0f); // Add a Fresnel effect to the shimmer factor
    shimmerColorFactor = clamp(shimmerColorFactor, 0.0f, 1.0f);

// BRIGHTNESS
    float brightNoise = genericFBM(vec3(fs_Pos.x, fs_Pos.y, fs_Time * 100.0f));
    brightNoise = bias(brightNoise, 0.6f);

    vec3 brightColor1 = u_BrightColor1 * 6.0f;
    vec3 brightColor2 = u_BrightColor2 * 6.0f;

    vec3 brightColor = lerp(brightColor1, brightColor2, fresnel(0.2f));

    float brightColorRange = 0.2f * brightNoise;
    float brightColorSmoothness = 0.8f;

    float brightColorFactor = smoothstep(brightColorRange, brightColorRange + brightColorSmoothness, yPos);
    brightColorFactor = clamp(brightColorFactor, 0.0f, 1.0f);

    // float brightColorRange = 0.02f * (1.0f - fresnel(5.0f));
    // float brightColorSmoothness = 0.4f;
    // float brightColorFactor = smoothstep(brightColorRange, brightColorRange + brightColorSmoothness, distToBase);
    // brightColorFactor = clamp(brightColorFactor, 0.0f, 1.0f);

    // TOP COLOR
    vec3 topColor = u_TopColor * 10.0f;
    float topColorRange = 0.7f;
    float topColorSmoothness = 0.6f;
    float topColorFactor = smoothstep(topColorRange, topColorRange + topColorSmoothness, yPos);
    topColorFactor = clamp(topColorFactor, 0.0f, 1.0f);

    // FADE
    vec3 fade1 = black;
    vec3 fade2 = vec3(2.0f, 2.0f, 2.0f);
    vec3 fade = lerp(fade1, black, smoothstep(0.0f, 0.1f, yPos));

    // make range round, so higher y values are more likely to be black
    float fadeColorRange = (0.0f + sin(fs_Time) * 0.05f);
    float fadeColorSmoothness = 0.2f;
    float fadeColorFactor = smoothstep(fadeColorRange, fadeColorRange + fadeColorSmoothness, distToBase);
    fadeColorFactor -= fresnel(5.0f); // Add a Fresnel effect to the black factor
    fadeColorFactor = 1.0f - clamp(fadeColorFactor, 0.0f, 1.0f);

    // Compute final shaded color
    vec3 finalColor = lerp(dimColor, brightColor, brightColorFactor);

    finalColor = lerp(finalColor, topColor, topColorFactor);
    finalColor = lerp(finalColor, blueColor, blueColorFactor);

    finalColor = lerp(finalColor, shimmerColor, shimmerColorFactor);

    // add black
    //finalColor = lerp(finalColor, fade, fadeColorFactor);

    finalColor = lerp(finalColor, black, blackColorFactor);

    out_Col = clamp(vec4(finalColor, 1.0f), 0.0f, 100.0f);

}
