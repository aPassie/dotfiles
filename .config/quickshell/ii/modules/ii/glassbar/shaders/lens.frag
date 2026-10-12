#version 440
// Liquid glass for panels that float over windows. `source` is a live capture
// of the screen area behind the panel (the panel itself is hidden from capture
// by a niri layer rule), so the glass bends and softens what is really there.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;      // rgb = glass colour, a = strength
    vec4 glow;      // rgb = ambient colour (from the artwork), a = strength
    vec2 size;      // item size in px, including the shadow margin
    float margin;   // space around the pane reserved for its shadow
    float radius;
    float bezel;    // width of the refracting rim
    float strength; // max refraction offset, px
    float soften;   // blur radius of the glass body, px
    float spread;   // colour split at the rim (0 = none)
    float ready;    // 1 once the capture has a frame
    float zoom;     // current scale of the panel (it grows out of the bar when it opens)
    vec2 origin;    // the point the panel scales around, in item px
};
layout(binding = 1) uniform sampler2D source;

// The capture covers the panel's final, full-size area. While the panel is scaled, map each
// pixel to where it really is on screen, so the view behind stays put instead of growing with it.
vec3 tap(vec2 p) {
    vec2 screen = origin + (p - origin) * zoom;
    return texture(source, clamp(screen / size, 0.0, 1.0)).rgb;
}

// Three-ring disc blur (37 taps) over a half-resolution capture: smooth even over small text.
vec3 soft(vec2 p) {
    vec3 acc = tap(p);
    float n = 1.0;
    for (int ring = 1; ring <= 3; ring++) {
        float rr = soften * float(ring) / 3.0;
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
    vec2 local = (c + half_) / (half_ * 2.0); // 0..1 across the pane

    vec2 n;
    if (q.x > 0.0 && q.y > 0.0) n = normalize(q) * sign(c);
    else if (q.x > q.y) n = vec2(sign(c.x), 0.0);
    else n = vec2(0.0, sign(c.y));

    float body = smoothstep(0.75, -0.75, d);

    // thick rounded edge: bend the backdrop towards the centre, splitting colours slightly.
    // Every sample is already blurred, so the split shows as a soft fringe, never as noise.
    float t = clamp(1.0 - inside / bezel, 0.0, 1.0);
    float bend = t * t * strength;
    vec3 col = soft(p - n * bend);
    if (spread > 0.0 && t > 0.0) {
        col.r = soft(p - n * bend * (1.0 - spread)).r;
        col.b = soft(p - n * bend * (1.0 + spread)).b;
    }
    col *= ready;

    // vibrancy: glass makes what is behind it richer and a little brighter
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(l), col, 1.6) * 1.12;
    col = mix(col, tint.rgb, tint.a);

    // ambient colour from the artwork, pooled on the left where the artwork sits
    float pool = exp(-dot((local - vec2(0.1, 0.45)) * vec2(1.4, 1.0), (local - vec2(0.1, 0.45)) * vec2(1.4, 1.0)) * 5.0);
    col = mix(col, glow.rgb, glow.a * (0.25 + 0.75 * pool));

    // the glass body itself: lighter at the top, with a soft inner glow under the upper edge
    col += mix(0.085, 0.02, local.y);
    col += smoothstep(22.0, 0.0, inside) * clamp(-n.y, 0.0, 1.0) * 0.07;
    col *= 1.0 - smoothstep(14.0, 0.0, inside) * clamp(n.y, 0.0, 1.0) * 0.16; // faint shade inside the lower edge

    // specular rim: light from the upper left, with a weaker echo at the lower right
    float lit = max(dot(n, normalize(vec2(-0.55, -1.0))), 0.0);
    float echo = max(dot(n, normalize(vec2(0.55, 1.0))), 0.0);
    float line = smoothstep(1.6, 0.15, inside);
    col = mix(col, vec3(1.0), line * (0.16 + 0.62 * lit * lit + 0.26 * echo * echo));
    col += smoothstep(5.0, 0.0, inside) * lit * 0.10;

    // shadow, only outside the pane
    vec2 sq = abs(c - vec2(0.0, 7.0)) - (half_ - radius);
    float sd = length(max(sq, 0.0)) + min(max(sq.x, sq.y), 0.0) - radius;
    float shadow = (1.0 - body) * 0.42 * exp(-max(sd, 0.0) / 11.0);

    fragColor = (vec4(col, 1.0) * body + vec4(0.0, 0.0, 0.0, shadow)) * qt_Opacity;
}
