varying float noiseVal;
uniform float colorVariance;
uniform float u_time;
uniform float u_darkMode;

// Creating the color palette that oscillates over time (replacing the prior HSL hue logic)
// Colors (sRGB hex):
//  - Blue   0E0AFF
//  - Red    FF0004
//  - Pink   FF00DD
//  - Yellow E4FF34 // removed
vec3 paletteColor(float t) {
    // HOW COLOR CYCLING WORKS (3-color version):
    // 1) We compute a phase t in [0..1] (see main()) that drifts over time and varies per particle via noise.
    // 2) We map t across the palette by scaling to the number of segments (3), producing x in [0..3).
    // 3) i = floor(x) picks the current segment index (0,1,2). f = fract(x) is the local blend position in that segment.
    // 4) A and B are the segment endpoints (neighboring palette colors). We smoothly interpolate A->B by f (with smoothstep).
    //    This yields continuous transitions Blue→Red→Pink→Blue.

    // Normalize hex colors to 0..1
    const vec3 C0 = vec3(14.0/255.0, 10.0/255.0, 255.0/255.0); // Blue 0E0AFF
    const vec3 C1 = vec3(255.0/255.0, 0.0/255.0, 4.0/255.0);   // Red  FF0004
    const vec3 C2 = vec3(255.0/255.0, 0.0/255.0, 221.0/255.0); // Pink FF00DD
    // const vec3 C3 = vec3(228.0/255.0, 255.0/255.0, 52.0/255.0); // Yellow E4FF34 

    
    // 4-color palette version:
    // float x4 = fract(t) * 4.0;
    // float i4 = floor(x4);
    // float f4 = fract(x4);
    // vec3 A4 = (i4 < 1.0) ? C0 : (i4 < 2.0) ? C1 : (i4 < 3.0) ? C2 : C3;
    // vec3 B4 = (i4 < 1.0) ? C1 : (i4 < 2.0) ? C2 : (i4 < 3.0) ? C3 : C0;
    // float sf4 = smoothstep(0.0, 1.0, f4);
    // return mix(A4, B4, sf4);

    // 3-color palette (Blue -> Red -> Pink)
    float x = fract(t) * 3.0;
    float i = floor(x);
    float f = fract(x);
    vec3 A = (i < 1.0) ? C0 : (i < 2.0) ? C1 : C2;
    vec3 B = (i < 1.0) ? C1 : (i < 2.0) ? C2 : C0;
    float sf = smoothstep(0.0, 1.0, f);
    return mix(A, B, sf);
}

void main() {
    float time = u_time * 0.04;

    // Phase of palette oscillation combines time and spatial noise variation:
    //  - time: drives global color cycling
    //  - colorVariance: scales how much noise influences the phase (higher = more per-particle variance)
    //  - noiseVal: per-particle value from vertex shader; adds spatial variation
    float phase = fract(time + colorVariance * 0.2 + noiseVal * 0.25);
    vec3 baseCol = paletteColor(phase);

    // Modulate brightness by noise to preserve depth variation
    float light = clamp(noiseVal * 0.5, 0.2, 1.0);
    // Balance for background: on white, increase saturation and brightness; on black, already boosted
    float brightnessBoost = mix(1.2, 1.35, u_darkMode);
    // Simple saturation boost towards base hue to keep colors vivid on white
    float satBoost = mix(1.25, 1.0, u_darkMode);
    vec3 gray = vec3(dot(baseCol, vec3(0.299, 0.587, 0.114)));
    vec3 saturated = mix(gray, baseCol, satBoost);
    vec3 finalCol = saturated * light * brightnessBoost;

    // Make point sprites circular with smooth falloff to avoid dark edges
    vec2 uv = gl_PointCoord * 2.0 - 1.0;           // [-1,1] range
    float r2 = dot(uv, uv);
    if (r2 > 1.0) discard;                          // hard cut outside circle
    float edge = smoothstep(1.0, 0.7, r2);          // softer edge near the rim
    // Raise alpha a bit on white to fight background bleed; higher on black for pop
    float alpha = (2.0 - edge) * mix(0.5, 0.9, u_darkMode);

    // Premultiply to avoid fringes during blending
    vec3 premul = finalCol * alpha;
    gl_FragColor = vec4(premul, alpha);
}