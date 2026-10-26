#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D src;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
};

void main() {
    vec4 tex = texture(src, qt_TexCoord0);

    // Use opposite luminance mapping for light and dark themes so a dark
    // blue background does not collapse into a black square in light mode.
    float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    float tintLuma = dot(tint.rgb, vec3(0.299, 0.587, 0.114));

    vec3 mappedColor = tintLuma > 0.5
        ? mix(vec3(0.0), tint.rgb, luma)
        : mix(vec3(1.0), tint.rgb, luma);

    fragColor = vec4(mappedColor, tex.a) * qt_Opacity;
}
