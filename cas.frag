#version 440
// AMD Contrast Adaptive Sharpening (simplified 5-tap cross) + color adjust
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 px;
    float sharp;
    float br;
    float ct;
    float sat;
};

layout(binding = 1) uniform sampler2D source;

vec3 T(vec2 d) { return texture(source, qt_TexCoord0 + d * px).rgb; }

void main()
{
    vec3 e = T(vec2(0.0));
    vec3 c = e;
    if (sharp > 0.001) {
        vec3 b = T(vec2(0.0, -1.0));
        vec3 d = T(vec2(-1.0, 0.0));
        vec3 f = T(vec2(1.0, 0.0));
        vec3 h = T(vec2(0.0, 1.0));
        vec3 mn = min(min(min(b, d), min(f, h)), e);
        vec3 mx = max(max(max(b, d), max(f, h)), e);
        vec3 amp = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, vec3(1e-4)), 0.0, 1.0));
        vec3 w = amp * (-1.0 / mix(8.0, 5.0, sharp));
        c = clamp((b * w + d * w + f * w + h * w + e) / (1.0 + 4.0 * w), 0.0, 1.0);
    }
    c = (c - 0.5) * ct + 0.5 + br;
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(l), c, sat);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0) * qt_Opacity;
}
