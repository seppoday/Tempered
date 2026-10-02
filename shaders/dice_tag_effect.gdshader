shader_type canvas_item;

// Wymiary elementu (przekazywane automatycznie ze skryptu)
uniform vec2 size = vec2(150.0, 100.0);
uniform float corner_radius : hint_range(0.0, 100.0) = 12.0;

// Hover
uniform float hover_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hover_color : source_color = vec4(1.0, 1.0, 1.0, 0.15);

// Selected corner brackets
uniform float selected_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 bracket_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
// 0.5 oznacza dokładnie połowę szerokości/wysokości (ramki się połączą)
uniform float bracket_length : hint_range(0.0, 0.5) = 0.2; 
// Grubość i padding zdefiniowane sztywno w pikselach (zawsze uniform)
uniform float bracket_thickness : hint_range(0.0, 20.0) = 2.0;
uniform float bracket_padding : hint_range(0.0, 20.0) = 3.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.25;

// Locked (wyszarzenie)
uniform float locked_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 locked_color : source_color = vec4(0.1, 0.1, 0.12, 0.6);

// Funkcja SDF obliczająca zaokrąglone rogi
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	vec2 uv = UV;
	vec2 pixel_pos = uv * size;
	
	// Tworzenie maski zaokrąglonych rogów (antialiasing dzięki smoothstep)
	vec2 half_size = size * 0.5;
	float dist = sdRoundedBox(pixel_pos - half_size, half_size, corner_radius);
	float round_mask = smoothstep(1.0, 0.0, dist);

	vec4 final_color = vec4(0.0);

	// --- HOVER: zaokrąglony ---
	if (hover_intensity > 0.0 && locked_intensity < 0.5) {
		vec4 h = hover_color * hover_intensity;
		h.a *= round_mask; // Przycinamy do zaokrąglonych rogów
		final_color = mix(final_color, h, h.a);
	}

	// --- SELECTED: rogowe ramki ---
	if (selected_intensity > 0.0) {
		// Odległość w pikselach od krawędzi
		float dist_x = min(pixel_pos.x, size.x - pixel_pos.x);
		float dist_y = min(pixel_pos.y, size.y - pixel_pos.y);

		// Obliczamy maksymalną długość linii w pikselach na podstawie procentu (bracket_length)
		float max_len_x = size.x * bracket_length;
		float max_len_y = size.y * bracket_length;

		// Linia pozioma: od paddingu do max_len_x
		bool on_horizontal_line = (dist_y >= bracket_padding) && 
		                          (dist_y < bracket_padding + bracket_thickness) && 
		                          (dist_x >= bracket_padding) && 
		                          (dist_x < max_len_x);
		
		// Linia pionowa: od paddingu do max_len_y
		bool on_vertical_line = (dist_x >= bracket_padding) && 
		                        (dist_x < bracket_padding + bracket_thickness) && 
		                        (dist_y >= bracket_padding) && 
		                        (dist_y < max_len_y);

		if (on_horizontal_line || on_vertical_line) {
			float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
			vec4 c = bracket_color;
			c.rgb *= pulse;
			c.a *= selected_intensity;
			final_color = mix(final_color, c, c.a);
		}
	}

	// --- LOCKED: zaokrąglony ---
	if (locked_intensity > 0.0) {
		vec4 l = locked_color;
		l.a *= locked_intensity;
		l.a *= round_mask; // Przycinamy do zaokrąglonych rogów
		final_color = mix(final_color, l, l.a);
	}

	COLOR = final_color;
}