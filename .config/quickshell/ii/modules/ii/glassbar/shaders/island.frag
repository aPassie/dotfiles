#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;      // rgb = tint colour, a = strength
    vec2 size;      // island size in px
    vec2 pos;       // island top-left inside the band, px
    vec2 bandSize;  // band size in px
    float radius;
    float bezel;    // width of the refracting rim
    float strength; // max refraction offset, px
    float fill;     // light added by the glass body
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = p - size * 0.5;
    vec2 q = abs(c) - (size * 0.5 - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius; // < 0 inside
    float inside = -d;

    vec2 n;
    if (q.x > 0.0 && q.y > 0.0) n = normalize(q) * sign(c);
    else if (q.x > q.y) n = vec2(sign(c.x), 0.0);
    else n = vec2(0.0, sign(c.y));

    // bend the backdrop towards the centre near the rim, like a thick lens edge
    float t = clamp(1.0 - inside / bezel, 0.0, 1.0);
    vec2 sp = pos + p - n * (t * t) * strength;
    vec3 col = mix(texture(source, sp / bandSize).rgb, tint.rgb, tint.a);

    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(l), col, 1.45) + fill;
    col += smoothstep(11.0, 0.0, p.y) * 0.07;                                   // soft glow under the top edge
    col = mix(col, vec3(1.0), smoothstep(1.5, 0.2, inside) * 0.20);             // rim
    col = mix(col, vec3(1.0), smoothstep(1.7, 0.0, inside) * clamp(-n.y, 0.0, 1.0) * 0.42); // top highlight
    col = mix(col, vec3(1.0), smoothstep(1.4, 0.0, inside) * clamp(n.y, 0.0, 1.0) * 0.10);  // bottom highlight

    float a = smoothstep(0.75, -0.75, d);
    fragColor = vec4(col * a, a) * qt_Opacity;
}
