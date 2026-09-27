shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Base surface properties
uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec2 uv_scale = vec2(1.0, 1.0);

// Fake AO / Vignette settings
uniform vec4 ao_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 0.8;      // How dark the edges get
uniform float ao_size : hint_range(0.01, 0.5) = 0.15;         // How far the AO reaches from the edges
uniform float ao_smoothness : hint_range(0.01, 2.0) = 1.5;    // Falloff curve (higher = softer)
uniform bool affect_ao_channel = true;                        // Also write to AO output for lighting

void fragment() {
	vec2 uv = UV * uv_scale;
	
	// Sample base color
	vec4 tex_color = texture(albedo_texture, uv);
	vec3 base_color = albedo.rgb * tex_color.rgb;
	
	// --- Vignette / Fake AO calculation ---
	// Distance from the nearest edge on each axis (0.0 at edge, 0.5 in center)
	vec2 edge_dist = min(UV, 1.0 - UV);
	
	// Take the closest edge distance
	float dist_to_edge = min(edge_dist.x, edge_dist.y);
	
	// Remap: 0.0 at edge -> 1.0 fully lit inside
	float ao_factor = smoothstep(0.0, ao_size, dist_to_edge);
	
	// Apply falloff curve for a softer gradient
	ao_factor = pow(ao_factor, 1.0 / ao_smoothness);
	
	// Mix base color with AO color based on vignette factor
	vec3 final_color = mix(ao_color.rgb, base_color, mix(1.0 - ao_strength, 1.0, ao_factor));
	
	// Output PBR values
	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// Optionally also affect the AO channel (interacts with lighting)
	if (affect_ao_channel) {
		AO = ao_factor;
		AO_LIGHT_AFFECT = 1.0;
	}
}