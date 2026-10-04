shader_type spatial;
render_mode unshaded, depth_test_disabled, blend_mix;

uniform float border_width : hint_range(0.0, 0.5) = 0.08;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.1;
uniform vec2 plane_size = vec2(2.0, 1.2);
uniform vec4 border_color : source_color = vec4(1.0, 0.85, 0.4, 0.9);
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 0.08);
instance uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
    vec2 centered = (UV - 0.5) * plane_size;
    float dist = rounded_box_sdf(centered, plane_size * 0.5 - corner_radius, corner_radius);

    float border_strength = 1.0 - smoothstep(0.0, border_width, -dist);

    vec3 color = mix(fill_color.rgb, border_color.rgb, border_strength);
    float alpha = mix(fill_color.a, border_color.a, border_strength);

    ALBEDO = color;
    ALPHA = alpha * intensity;
}