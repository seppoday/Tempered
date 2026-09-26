shader_type canvas_item;

/*
    ============================================================
    ADVANCED SCREEN POST-PROCESSING
    Godot 4.x / CanvasItem Shader
    ============================================================
*/

// Wymagany w Godot 4 dla odczytu ekranu
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// ============================================================
// GENERAL
// ============================================================
uniform bool enabled = true;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// ============================================================
// COLOR CORRECTION
// ============================================================
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float exposure : hint_range(-5.0, 5.0) = 0.0;
uniform float gamma : hint_range(0.1, 3.0) = 1.0;
uniform float vibrance : hint_range(-1.0, 1.0) = 0.0;

// ============================================================
// TINT
// ============================================================
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

// ============================================================
// HUE
// ============================================================
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;

// ============================================================
// COLOR TEMPERATURE
// ============================================================
uniform float temperature : hint_range(-1.0, 1.0) = 0.0;

// ============================================================
// VIGNETTE
// ============================================================
uniform bool vignette_enabled = true;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.35;
uniform float vignette_radius : hint_range(0.0, 2.0) = 0.75;
uniform float vignette_softness : hint_range(0.01, 2.0) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// ============================================================
// FILM GRAIN
// ============================================================
uniform bool grain_enabled = false;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.08;
uniform float grain_size : hint_range(0.1, 5.0) = 1.0;
uniform float grain_speed : hint_range(0.0, 10.0) = 1.0;

// ============================================================
// NOISE
// ============================================================
uniform bool noise_enabled = false;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.05;
uniform float noise_scale : hint_range(1.0, 100.0) = 25.0;

// ============================================================
// CHROMATIC ABERRATION
// ============================================================
uniform bool chromatic_aberration_enabled = false;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.005;

// ============================================================
// RGB SPLIT
// ============================================================
uniform bool rgb_split_enabled = false;
uniform float rgb_split : hint_range(0.0, 0.05) = 0.002;

// ============================================================
// SHARPEN
// ============================================================
uniform bool sharpen_enabled = false;
uniform float sharpen_strength : hint_range(0.0, 2.0) = 0.35;

// ============================================================
// BLOOM / GLOW
// ============================================================
uniform bool bloom_enabled = false;
uniform float bloom_strength : hint_range(0.0, 2.0) = 0.35;
uniform float bloom_threshold : hint_range(0.0, 2.0) = 0.8;
uniform float bloom_radius : hint_range(0.001, 0.05) = 0.01;

// ============================================================
// SCANLINES
// ============================================================
uniform bool scanlines_enabled = false;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_density : hint_range(50.0, 2000.0) = 600.0;
uniform float scanline_speed : hint_range(-10.0, 10.0) = 0.0;

// ============================================================
// CRT
// ============================================================
uniform bool crt_enabled = false;
uniform float crt_curvature : hint_range(0.0, 1.0) = 0.15;

// ============================================================
// PIXELATION
// ============================================================
uniform bool pixelation_enabled = false;
uniform float pixelation : hint_range(1.0, 500.0) = 100.0;

// ============================================================
// DITHERING
// ============================================================
uniform bool dithering_enabled = false;
uniform float dither_strength : hint_range(0.0, 0.1) = 0.02;

// ============================================================
// SCREEN DISTORTION
// ============================================================
uniform bool distortion_enabled = false;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.01;
uniform float distortion_speed : hint_range(0.0, 10.0) = 1.0;
uniform float distortion_frequency : hint_range(1.0, 100.0) = 20.0;

// ============================================================
// FADE
// ============================================================
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// ============================================================
// TIME
// ============================================================
uniform float time_scale : hint_range(0.0, 10.0) = 1.0;


// ============================================================
// HELPERS
// ============================================================

float random(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 rgb_to_hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 1.0 / 3.0, 2.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 apply_hue_shift(vec3 color, float amount) {
    vec3 hsv = rgb_to_hsv(color);
    hsv.x = fract(hsv.x + amount);
    return hsv_to_rgb(hsv);
}

vec3 apply_temperature(vec3 color, float amount) {
    float warm = max(amount, 0.0);
    float cold = max(-amount, 0.0);
    color.r += warm * 0.08;
    color.g += warm * 0.02;
    color.b -= warm * 0.08;
    color.r -= cold * 0.08;
    color.g += cold * 0.01;
    color.b += cold * 0.08;
    return color;
}

vec3 apply_vibrance(vec3 color, float amount) {
    float average = (color.r + color.g + color.b) / 3.0;
    float max_channel = max(color.r, max(color.g, color.b));
    float saturation_value = max_channel - average;
    float boost = amount * (1.0 - saturation_value);
    return mix(vec3(average), color, 1.0 + boost);
}

vec2 apply_crt(vec2 uv) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    centered *= 1.0 + crt_curvature * r2;
    return centered + 0.5;
}

vec2 apply_distortion(vec2 uv, float time) {
    float wave_x = sin(uv.y * distortion_frequency + time * distortion_speed);
    float wave_y = cos(uv.x * distortion_frequency * 0.73 + time * distortion_speed * 0.7);
    uv.x += wave_x * distortion_strength;
    uv.y += wave_y * distortion_strength;
    return uv;
}

float calculate_vignette(vec2 uv) {
    vec2 centered = uv - 0.5;
    float distance_from_center = length(centered) * 1.4142;
    float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, distance_from_center);
    return vignette * vignette_strength;
}

vec3 bloom_sample(vec2 uv, vec2 pixel_size, sampler2D screen_tex) {
    vec3 result = vec3(0.0);
    vec2 offsets[8] = vec2[](
        vec2(-1.0, -1.0), vec2( 0.0, -1.0), vec2( 1.0, -1.0),
        vec2(-1.0,  0.0),                    vec2( 1.0,  0.0),
        vec2(-1.0,  1.0), vec2( 0.0,  1.0), vec2( 1.0,  1.0)
    );

    for (int i = 0; i < 8; i++) {
        vec3 sample_color = texture(screen_tex, uv + offsets[i] * pixel_size * bloom_radius).rgb;
        float brightness_value = max(sample_color.r, max(sample_color.g, sample_color.b));
        float mask = smoothstep(bloom_threshold, bloom_threshold + 0.2, brightness_value);
        result += sample_color * mask;
    }
    return result / 8.0;
}

vec3 apply_sharpen(vec2 uv, vec3 color, vec2 pixel_size, sampler2D screen_tex) {
    vec3 north = texture(screen_tex, uv + vec2(0.0, -pixel_size.y)).rgb;
    vec3 south = texture(screen_tex, uv + vec2(0.0,  pixel_size.y)).rgb;
    vec3 east  = texture(screen_tex, uv + vec2( pixel_size.x, 0.0)).rgb;
    vec3 west  = texture(screen_tex, uv + vec2(-pixel_size.x, 0.0)).rgb;
    vec3 blur = (north + south + east + west) * 0.25;
    return color + (color - blur) * sharpen_strength;
}

vec3 apply_dither(vec3 color, vec2 screen_position) {
    float value = random(screen_position);
    return color + (value - 0.5) * dither_strength;
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment() {
    vec2 uv = SCREEN_UV;
    float current_time = TIME * time_scale;

    // CRT
    if (crt_enabled) {
        uv = apply_crt(uv);
    }

    // Distortion
    if (distortion_enabled) {
        uv = apply_distortion(uv, current_time);
    }

    // Pixelation
    if (pixelation_enabled) {
        vec2 pixel_size = SCREEN_PIXEL_SIZE * pixelation;
        uv = floor(uv / pixel_size) * pixel_size + pixel_size * 0.5;
    }

    // Chromatic aberration / base sample
    vec3 color;
    if (chromatic_aberration_enabled) {
        vec2 direction = uv - vec2(0.5);
        float distance_from_center = length(direction);
        direction = normalize(direction + vec2(0.00001));
        float offset = chromatic_aberration * distance_from_center;

        float red   = texture(SCREEN_TEXTURE, uv + direction * offset).r;
        float green = texture(SCREEN_TEXTURE, uv).g;
        float blue  = texture(SCREEN_TEXTURE, uv - direction * offset).b;
        color = vec3(red, green, blue);
    } else {
        color = texture(SCREEN_TEXTURE, uv).rgb;
    }

    // RGB Split
    if (rgb_split_enabled) {
        float red  = texture(SCREEN_TEXTURE, uv + vec2(rgb_split, 0.0)).r;
        float blue = texture(SCREEN_TEXTURE, uv - vec2(rgb_split, 0.0)).b;
        color.r = red;
        color.b = blue;
    }

    vec3 original_color = color;

    // Exposure
    color *= pow(2.0, exposure);

    // Brightness
    color += brightness;

    // Contrast
    color = (color - 0.5) * contrast + 0.5;

    // Saturation
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luminance), color, saturation);

    // Vibrance
    color = apply_vibrance(color, vibrance);

    // Hue
    color = apply_hue_shift(color, hue_shift);

    // Temperature
    color = apply_temperature(color, temperature);

    // Tint
    color = mix(color, color * tint.rgb, tint_strength);

    // Gamma
    color = pow(max(color, vec3(0.0)), vec3(1.0 / gamma));

    // Sharpen
    if (sharpen_enabled) {
        color = apply_sharpen(uv, color, SCREEN_PIXEL_SIZE, SCREEN_TEXTURE);
    }

    // Bloom
    if (bloom_enabled) {
        vec3 bloom = bloom_sample(uv, SCREEN_PIXEL_SIZE, SCREEN_TEXTURE);
        color += bloom * bloom_strength;
    }

    // Vignette
    if (vignette_enabled) {
        float vignette = calculate_vignette(uv);
        color = mix(color, vignette_color.rgb, vignette);
    }

    // Scanlines
    if (scanlines_enabled) {
        float line = sin(uv.y * scanline_density + current_time * scanline_speed);
        float scanline = line * 0.5 + 0.5;
        color *= mix(1.0, scanline, scanline_strength);
    }

    // Film Grain
    if (grain_enabled) {
        vec2 grain_uv = uv * grain_size * 1000.0;
        grain_uv += vec2(current_time * grain_speed, current_time * grain_speed * 1.37);
        float grain = random(floor(grain_uv));
        color += (grain - 0.5) * grain_strength;
    }

    // Noise
    if (noise_enabled) {
        float n = noise(uv * noise_scale + current_time);
        color += (n - 0.5) * noise_strength;
    }

    // Dither
    if (dithering_enabled) {
        color = apply_dither(color, FRAGCOORD.xy);
    }

    // Fade
    color = mix(color, fade_color.rgb, fade);

    // Final intensity
    color = mix(original_color, color, intensity);

    // Output
    COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}