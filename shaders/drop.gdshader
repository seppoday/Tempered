shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform float edge_softness : hint_range(0.0, 0.2) = 0.02;

void fragment() {
    vec2 uv = UV - vec2(0.5); // centrujemy współrzędne (0,0 = środek)
    float dist = length(uv);

    vec4 tex_color = texture(TEXTURE, UV);

    float mask = smoothstep(radius, radius - edge_softness, dist);

    COLOR = vec4(tex_color.rgb, tex_color.a * mask);
}