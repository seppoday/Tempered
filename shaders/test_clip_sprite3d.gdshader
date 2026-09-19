shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D sprite_texture : source_color;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 col = texture(sprite_texture, UV);

    if (UV.y > reveal) {
        discard;
    }

    ALBEDO = col.rgb;
    ALPHA = col.a;
}