#version 440
// Plain see-through tinted glass for floating panels: what is behind shows through,
// very slightly blurred. No bending, no colour effects.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;      // rgb = glass colour, a = how opaque the glass body is
    vec2 size;      // item size in px, including the shadow margin
    vec2 origin;    // the point the panel scales around, in item px
    float margin;   // space around the pane reserved for its shadow
    float radius;
    float soften;   // blur radius, px
    float ready;    // 1 once the capture has a frame
    float zoom;     // current scale of the panel
};
layout(binding = 1) uniform sampler2D source;

vec3 tap(vec2 p) {
    vec2 screen = origin + (p - origin) * zoom; // keep the view behind fixed while the panel scales
    return texture(source, clamp(screen / size, 0.0, 1.0)).rgb;
}

vec3 soft(vec2 p) {
    vec3 acc = tap(p);
    float n = 1.0;
    for (int ring = 1; ring <= 2; ring++) {
        float rr = soften * float(ring) / 2.0;
        int count = ring * 6;
        for (int i = 0; i < count; i++) {
            float a = (float(i) + 0.5 * float(ring)) * 6.2831853 / float(count);
            acc += tap(p + vec2(cos(a), sin(a)) * rr);
            n += 1.0;
        }
    }
    return acc / n;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 half_ = size * 0.5 - margin;
    vec2 c = p - size * 0.5;
    vec2 q = abs(c) - (half_ - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius; // < 0 inside
    float inside = -d;

    vec2 n;
    if (q.x > 0.0 && q.y > 0.0) n = normalize(q) * sign(c);
    else if (q.x > q.y) n = vec2(sign(c.x), 0.0);
    else n = vec2(0.0, sign(c.y));

    float body = smoothstep(0.75, -0.75, d);

    vec3 glass = tint.rgb + 0.05 + smoothstep(26.0, 0.0, p.y - margin) * 0.06;
    vec3 col = mix(soft(p) * ready, glass, tint.a);

    float rim = smoothstep(1.5, 0.2, inside) * 0.24
              + smoothstep(1.8, 0.0, inside) * clamp(-n.y, 0.0, 1.0) * 0.45
              + smoothstep(1.4, 0.0, inside) * clamp(n.y, 0.0, 1.0) * 0.10;
    col = mix(col, vec3(1.0), clamp(rim, 0.0, 1.0));

    vec2 sq = abs(c - vec2(0.0, 5.0)) - (half_ - radius);
    float sd = length(max(sq, 0.0)) + min(max(sq.x, sq.y), 0.0) - radius;
    float shadow = (1.0 - body) * 0.38 * exp(-max(sd, 0.0) / 9.0);

    fragColor = (vec4(col, 1.0) * body + vec4(0.0, 0.0, 0.0, shadow)) * qt_Opacity;
}
