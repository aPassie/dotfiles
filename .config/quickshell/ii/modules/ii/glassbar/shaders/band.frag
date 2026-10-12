#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;      // rgb = tint colour, a = strength
    vec2 size;      // item size in px
    float barH;
    float radius;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec3 c = mix(texture(source, qt_TexCoord0).rgb, tint.rgb, tint.a);
    float a = 1.0;
    if (p.y > barH) {
        // hug corners: keep only what lies outside a circle tucked under each end of the bar
        float d = 0.0;
        if (p.x < radius) d = length(p - vec2(radius, barH + radius));
        else if (p.x > size.x - radius) d = length(p - vec2(size.x - radius, barH + radius));
        a = smoothstep(radius - 0.75, radius + 0.75, d);
        if (p.y > barH + radius) a = 0.0;
    }
    fragColor = vec4(c * a, a) * qt_Opacity;
}
