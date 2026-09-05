shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0, 0.1) = 0.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	COLOR = mix(original_color, vec4(1.0, 1.0, 1.0, original_color.a), flash_amount);
}
