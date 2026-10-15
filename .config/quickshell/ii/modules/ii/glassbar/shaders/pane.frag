#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;      // rgb = glass colour, a = how opaque the glass body is
    vec2 size;      // item size in px, including the shadow margin
    float margin;   // space around the pane reserved for its shadow
    float radius;
};

// A sheet of clear tinted glass that floats over windows: see-through body,
// bright rim, soft glow under the top edge and a drop shadow.
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
    vec3 col = tint.rgb + 0.05;
    col += smoothstep(26.0, 0.0, p.y - margin) * 0.06;
    float a = tint.a;

    float rim = smoothstep(1.5, 0.2, inside) * 0.24
              + smoothstep(1.8, 0.0, inside) * clamp(-n.y, 0.0, 1.0) * 0.45
              + smoothstep(1.4, 0.0, inside) * clamp(n.y, 0.0, 1.0) * 0.10;
    rim = clamp(rim, 0.0, 1.0);
    col = mix(col, vec3(1.0), rim);
    a = mix(a, 1.0, rim * 0.85);

    // shadow, only outside the pane
    vec2 sq = abs(c - vec2(0.0, 5.0)) - (half_ - radius);
    float sd = length(max(sq, 0.0)) + min(max(sq.x, sq.y), 0.0) - radius;
    // a light, rounded shadow that follows the glass and is gone well inside the margin
    float reach = max(margin - 6.0, 4.0);
    float fall = 1.0 - clamp(max(sd, 0.0) / reach, 0.0, 1.0);
    float shadow = (1.0 - body) * 0.22 * fall * fall;
    // fade the shadow to nothing before the edge of the drawing area, or its cut-off shows as a box
    vec2 px = qt_TexCoord0 * size;
    float edge = min(min(px.x, px.y), min(size.x - px.x, size.y - px.y));
    shadow *= smoothstep(0.0, margin * 0.6, edge);

    fragColor = (vec4(col * a, a) * body + vec4(0.0, 0.0, 0.0, shadow)) * qt_Opacity;
}
