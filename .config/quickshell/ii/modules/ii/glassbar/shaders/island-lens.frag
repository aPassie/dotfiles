#version 440
// Clear-glass capsule for the bar's islands.
//
// The lens model (rounded-edge normal, refraction through a slab of glass,
// per-channel dispersion and the Fresnel "OS 27" highlight) is adapted from
// hyprliquid's LiquidGlass.frag:
//   Copyright (c) 2026, zaregototsukai. BSD 3-Clause License.
//   https://github.com/zaregototsukai/hyprliquid
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;        // rgb = tint colour, a = strength
    vec4 iorRGB;      // per-channel index of refraction (rgb), used when dispersion is on
    vec2 size;        // island size in px
    vec2 pos;         // island top-left inside the band, px
    vec2 bandSize;    // band size in px
    float radius;     // corner radius
    float zRadius;    // depth of the rounded edge
    float thickness;  // glass thickness in px: how far the edge bends the backdrop
    float ior;        // index of refraction when dispersion is off
    float dispersion; // 1 = split colours at the edge
    float fill;       // light added by the glass body
};
layout(binding = 1) uniform sampler2D source;

const vec3 INCIDENT = vec3(0.0, 0.0, -1.0);

vec3 backdrop(vec2 p) {
    return texture(source, (pos + p) / bandSize).rgb;
}

vec2 bend(vec3 normal, float n) {
    vec3 r = refract(INCIDENT, normal, 1.0 / n);
    float cosTheta = max(1e-5, dot(r, INCIDENT));
    return (normal.z * zRadius + thickness) / cosTheta * r.xy;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = p - size * 0.5;
    vec2 v = sign(c) * max(abs(c) - (size * 0.5 - radius), 0.0); // vector from the flat middle to this pixel
    float len = length(v);
    vec2 n2 = len > 0.0 ? v / len : vec2(0.0);

    // surface normal of the rounded edge
    float dist = max(len - radius + zRadius, 0.0);
    float r = clamp(dist / max(1e-5, zRadius), 0.0, 1.0);
    vec3 normal = dist > 1e-5 ? normalize(vec3(n2 * r, sqrt(1.0 - r * r))) : vec3(0.0, 0.0, 1.0);

    vec3 col;
    if (dispersion > 0.5) {
        col.r = backdrop(p + bend(normal, iorRGB.r)).r;
        col.g = backdrop(p + bend(normal, iorRGB.g)).g;
        col.b = backdrop(p + bend(normal, iorRGB.b)).b;
    } else {
        col = backdrop(p + bend(normal, ior));
    }

    col = mix(col, tint.rgb, tint.a);
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(l), col, 1.45) + fill;
    col += smoothstep(10.0, 0.0, p.y) * 0.04; // faint glow under the top edge

    // OS 27-style highlight: the rim darkens, then catches light along the top and bottom
    float f0 = (ior - 1.0) / (ior + 1.0);
    f0 *= f0;
    // The textbook exponent is 5; on a capsule this small that leaves a rim thinner than a pixel,
    // so the falloff is softened to keep the highlight about 1.5 px wide.
    float fresnel = f0 + (1.0 - f0) * pow(1.0 - max(normal.z, 0.0), 2.0);
    float w = smoothstep(0.5, 1.0, abs(n2.y));
    col = mix(col, vec3(0.0), fresnel);
    col = mix(col, vec3(1.0), fresnel * w);

    float a = smoothstep(0.75, -0.75, len - radius);
    fragColor = vec4(col * a, a) * qt_Opacity;
}
