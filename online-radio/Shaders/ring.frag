#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    float time;
    vec4 bgWidget;
    vec2 resolution;
    vec4 bgColor1;  // цвет тени для волны
} ubuf;

// noise from https://www.shadertoy.com/view/4sc3z2
vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .11369, .13787));
    p3 += dot(p3, p3.yxz + 19.19);
    return -1.0 + 2.0 * fract(vec3(p3.x + p3.y, p3.x + p3.z, p3.y + p3.z) * p3.zyx);
}

float snoise3(vec3 p) {
    const float K1 = 0.333333333;
    const float K2 = 0.166666667;

    vec3 i = floor(p + (p.x + p.x + p.z) * K1);
    vec3 d0 = p - (i - (i.x + i.y + i.z) * K2);

    vec3 e = step(vec3(0.0), d0 - d0.yzx);
    vec3 i1 = e * (1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy * (1.0 - e);

    vec3 d1 = d0 - (i1 - K2);
    vec3 d2 = d0 - (i2 - K1);
    vec3 d3 = d0 - 0.5;

    vec4 h = max(0.6 - vec4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
    vec4 n = h * h * h * h * vec4(dot(d0, hash33(i)), dot(d1, hash33(i + i1)), dot(d2, hash33(i + i2)), dot(d3, hash33(i + 1.0)));

    return dot(vec4(31.316), n);
}

vec4 extractAlpha(vec3 colorIn) {
    vec4 colorOut;
    float maxValue = min(max(max(colorIn.r, colorIn.g), colorIn.b), 1.0);
    if(maxValue > 1e-5) {
        colorOut.rgb = colorIn.rgb * (1.0 / maxValue);
        colorOut.a = maxValue;
    } else {
        colorOut = vec4(0.0);
    }
    return colorOut;
}

// Параметры эффекта ripple
struct RippleParams {
    float frequency;    // частота волны
    float amplitude;    // амплитуда волны
    float speed;        // скорость волны
    float intensity;    // интенсивность искажения
};

vec2 applyConcentricRipple(vec2 uv, float time, RippleParams ripple) {
    vec2 center = vec2(0.5);
    vec2 dir = uv - center;
    float dist = length(dir);
    
    // Концентрические волны от центра
    // Основная волна: sin от расстояния
    float rippleOffset1 = sin(dist * ripple.frequency * 12.0 - time * ripple.speed) * ripple.amplitude;
    
    // Вторая гармоника для сложности
    float rippleOffset2 = sin(dist * ripple.frequency * 24.0 - time * ripple.speed * 1.5) * ripple.amplitude * 0.4;
    
    // Третья гармоника
    float rippleOffset3 = cos(dist * ripple.frequency * 36.0 + time * ripple.speed * 2.0) * ripple.amplitude * 0.2;
    
    float totalOffset = (rippleOffset1 + rippleOffset2 + rippleOffset3) * ripple.intensity;
    
    // Искажение по направлению от центра (радиальное)
    vec2 distortedUv = uv;
    if (dist > 0.01) {
        distortedUv = uv + dir * totalOffset / dist;
    }
    
    return distortedUv;
}

vec4 calculateRippleShadow(vec2 uv, vec2 originalUv, vec4 sourceColor, float time, RippleParams ripple) {
    vec2 shadowOffset = vec2(0.008, 0.008);
    vec2 shadowUv = originalUv - shadowOffset;
    
    vec2 distortedShadowUv = applyConcentricRipple(shadowUv, time, ripple);
    
    vec4 shadowColor = texture(source, distortedShadowUv);
    
    if (distortedShadowUv.x < 0.0 || distortedShadowUv.x > 1.0 || 
        distortedShadowUv.y < 0.0 || distortedShadowUv.y > 1.0) {
        shadowColor = vec4(0.0);
    }
    
    float shadowIntensity = ripple.amplitude * 0.8;
    
    vec3 finalShadow = mix(shadowColor.rgb, ubuf.bgColor1.rgb, 0.5);
    
    return vec4(finalShadow, shadowColor.a * shadowIntensity);
}

// Ring parameters structure https://www.shadertoy.com/view/3tBGRm
struct RingParams {
    float innerRadius;
    float noiseScale;
    float r0;
    float d0;
    float n0;
    float cl;
    vec3 color;
};

// Calculate ring geometry and noise
RingParams calculateRing(vec2 uv, float time, float aspect) {
    RingParams ring;
    ring.innerRadius = 0.6;
    ring.noiseScale = 0.65;
    
    const vec3 color1 = vec3(0.611765, 0.262745, 0.996078);
    const vec3 color2 = vec3(0.298039, 0.760784, 0.913725);
    const vec3 color3 = vec3(0.062745, 0.078431, 0.600000);
    
    float ang = atan(uv.y, uv.x);
    float len = length(uv);
    
    // ring noise
    ring.n0 = snoise3(vec3(uv * ring.noiseScale, time * 0.15)) * 0.5 + 0.5;
    ring.r0 = mix(mix(ring.innerRadius, 1.0, 0.4), mix(ring.innerRadius, 1.0, 0.6), ring.n0);
    ring.d0 = distance(uv, ring.r0 / len * uv);
    ring.cl = cos(ang + time * 0.04) * 0.5 + 0.5;
    
    // ring color
    vec3 col = mix(color1, color2, ring.cl);
    col = mix(color3, col, 1.0 / (1.0 + ring.d0 * 10.0) * smoothstep(ring.r0 * 1.05, ring.r0, len));
    ring.color = col;
    
    return ring;
}

// Calculate highlight
float calculateHighlight(vec2 uv, float r0, float d0, float time) {
    float a = time * -0.03;
    vec2 pos = vec2(cos(a), sin(a)) * r0;
    float d = distance(uv, pos);
    float v1 = 1.5 / (1.0 + d * d * 5.0);
    v1 *= 1.0 / (1.0 + d0 * 50.0);
    return v1;
}

// Calculate decay masks
vec2 calculateMasks(float len, float innerRadius, float n0) {
    float v2 = smoothstep(1.0, mix(innerRadius, 1.0, n0 * 0.5), len);
    float v3 = smoothstep(innerRadius, mix(innerRadius, 1.0, 0.5), len);
    return vec2(v2, v3);
}

// Build final ring color with all effects
vec4 buildRingColor(vec2 uv, float time, float aspect) {
    RingParams ring = calculateRing(uv, time, aspect);
    float len = length(uv);
    
    // Calculate ring base intensity
    float v0 = 1.0 / (1.0 + ring.d0 * 10.0);
    v0 *= smoothstep(ring.r0 * 1.05, ring.r0, len);
    
    // Add highlight
    float highlight = calculateHighlight(uv, ring.r0, ring.d0, time);
    
    // Apply decay masks
    vec2 masks = calculateMasks(len, ring.innerRadius, ring.n0);
    
    // Final color assembly
    vec3 col = ring.color;
    col = col * v0;
    col = col + highlight;
    col = col * masks.x * masks.y;
    col = clamp(col, 0.0, 1.0);
    
    return extractAlpha(col);
}

vec4 getZoomedSourceWithRipple(vec2 texCoord, float zoom, float time, sampler2D source) {
    vec2 uv = (texCoord - 0.5) / zoom + 0.5;
    
    RippleParams ripple;
    ripple.frequency = 1.8;     // частота волн (меньше - волны шире)
    ripple.amplitude = 0.025;   // амплитуда волны
    ripple.speed = 0.5;         // скорость волны
    ripple.intensity = 1.2;     // интенсивность искажения
    
    vec4 originalColor = texture(source, uv);
    
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        originalColor = vec4(0.0);
    }
    
    vec2 distortedUv = applyConcentricRipple(uv, time, ripple);
    
    vec4 rippleColor = texture(source, distortedUv);
    
    if (distortedUv.x < 0.0 || distortedUv.x > 1.0 || 
        distortedUv.y < 0.0 || distortedUv.y > 1.0) {
        rippleColor = vec4(0.0);
    }
    
    vec4 shadowColor = calculateRippleShadow(distortedUv, uv, rippleColor, time, ripple);
    
    vec4 finalColor = rippleColor;
    finalColor.rgb = mix(finalColor.rgb, shadowColor.rgb, shadowColor.a);
    
    vec2 center = vec2(0.5);
    float dist = length(uv - center);
    
    float glowIntensity = abs(sin(dist * ripple.frequency * 12.0 - time * ripple.speed)) * 0.25;
    glowIntensity *= (1.0 - smoothstep(0.0, 0.8, dist));
    glowIntensity *= ripple.amplitude * 8.0;
    
    finalColor.rgb += vec3(glowIntensity * 0.3, glowIntensity * 0.5, glowIntensity * 0.8);
    
    float colorShift = sin(dist * ripple.frequency * 20.0 - time * ripple.speed * 1.2) * ripple.amplitude * 0.5;
    finalColor.r += colorShift * 0.1;
    finalColor.b -= colorShift * 0.1;
    
    return finalColor;
}

// Blend ring and source textures
vec4 blendRingAndSource(vec4 ringColor, vec4 sourceColor, float len, float innerRadius) {
    vec3 finalRgb;
    float finalAlpha;
    
    if (len < innerRadius) {
        finalRgb = sourceColor.rgb;
        finalAlpha = 1.0;
    } else {
        finalRgb = ringColor.rgb;
        finalAlpha = ringColor.a;
    }
    
    float edge = smoothstep(innerRadius - 0.05, innerRadius + 0.05, len);
    finalRgb = mix(sourceColor.rgb, finalRgb, edge);
    
    return vec4(finalRgb, finalAlpha);
}

void main() {
    // Transform UV coordinates
    vec2 uv = (qt_TexCoord0 * 2.0 - 1.0);
    float aspect = ubuf.resolution.x / ubuf.resolution.y;
    uv.x *= aspect;
    
    const float innerRadius = 0.6;
    const float sourceZoom = 0.7;
    
    float len = length(uv);
    
    // Build ring
    vec4 ringColor = buildRingColor(uv, ubuf.time, aspect);
    
    // Get zoomed source texture with concentric ripple effect
    vec4 sourceColor = getZoomedSourceWithRipple(qt_TexCoord0, sourceZoom, ubuf.time, source);
    
    // Blend ring and source
    vec4 blended = blendRingAndSource(ringColor, sourceColor, len, innerRadius);
    
    // Mix with background
    vec3 bg = ubuf.bgWidget.xyz;
    fragColor = vec4(mix(bg, blended.rgb, blended.a), 1.0);
}