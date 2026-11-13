#version 440
// Frame generation: builds the frame at time t between prev (t=0) and cur (t=1)
// by warping both along the motion field and blending. Where the two warped
// samples disagree (occlusion / bad vector), falls back toward the nearer frame.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;          // 1.0 = show cur unchanged
    float showFlow;   // debug: visualise motion vectors
};

layout(binding = 1) uniform sampler2D prevB;
layout(binding = 2) uniform sampler2D curB;
layout(binding = 3) uniform sampler2D flow;

const float SCALE = 10.0;

void main()
{
    vec2 uv = qt_TexCoord0;
    vec4 f = texture(flow, uv);
    vec2 v = (f.rg - 0.5) / SCALE;

    if (showFlow > 0.5) {
        fragColor = vec4(0.5 + v * 20.0, 0.5, 1.0) * qt_Opacity;
        return;
    }
    if (t >= 0.999) {
        fragColor = vec4(texture(curB, uv).rgb, 1.0) * qt_Opacity;
        return;
    }

    vec3 p = texture(prevB, uv - v * t).rgb;
    vec3 c = texture(curB, uv + v * (1.0 - t)).rgb;
    vec3 blend = mix(p, c, t);

    // disagreement -> trust the nearer frame (unwarped) to avoid ghosting
    float d = length(p - c);
    vec3 nearest = t < 0.5 ? texture(prevB, uv).rgb : texture(curB, uv).rgb;
    float w = smoothstep(0.15, 0.45, d);
    fragColor = vec4(mix(blend, nearest, w), 1.0) * qt_Opacity;
}
