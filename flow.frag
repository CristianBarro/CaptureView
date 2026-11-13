#version 440
// Motion estimation for frame generation.
// Runs at low resolution (e.g. 240x135) over 1/4-res luma snapshots of the
// previous (prevS) and current (curS) frames. Symmetric block matching:
// for each candidate vector v, compare prev(x - v/2) with cur(x + v/2) over a
// 3x3 patch and keep the cheapest. Output: rg = v (uv units) * SCALE + 0.5,
// b = match cost, a = 1.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 spx;      // texel size of the small snapshots
};

layout(binding = 1) uniform sampler2D prevS;
layout(binding = 2) uniform sampler2D curS;

const int R = 10;          // search radius in small texels (= 40 px at 1080p)
const float SCALE = 10.0;

float L(sampler2D t, vec2 uv) { return dot(texture(t, uv).rgb, vec3(0.299, 0.587, 0.114)); }

float cost(vec2 uv, vec2 h)
{
    float c = 0.0;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(x, y) * spx * 2.0;
            c += abs(L(prevS, uv + o - h) - L(curS, uv + o + h));
        }
    return c;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float best = cost(uv, vec2(0.0)) - 0.02;   // small bias toward "no motion"
    vec2 bv = vec2(0.0);
    for (int y = -R; y <= R; y++)
        for (int x = -R; x <= R; x++) {
            vec2 v = vec2(x, y) * spx;
            float c = cost(uv, v * 0.5);
            if (c < best) { best = c; bv = v; }
        }
    fragColor = vec4(bv * SCALE + 0.5, best, 1.0);
}
