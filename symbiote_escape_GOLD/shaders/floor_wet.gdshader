shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// === APARIENCIA DEL SUELO ===
uniform vec4 color_base : source_color = vec4(0.05, 0.04, 0.07, 1.0);
uniform vec4 color_grout : source_color = vec4(0.02, 0.01, 0.04, 1.0);
uniform vec4 color_wet : source_color = vec4(0.08, 0.0, 0.15, 1.0);
uniform vec4 color_glow_line : source_color = vec4(0.4, 0.0, 0.8, 1.0);

// === TEXTURA ===
uniform float tile_scale : hint_range(0.5, 20.0) = 4.0;
uniform float tile_size : hint_range(0.01, 0.5) = 0.08;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.08;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.5;
uniform float wet_amount : hint_range(0.0, 1.0) = 0.85;

// === LÍNEAS SYMBIOTE ===
uniform float glow_line_speed : hint_range(0.0, 3.0) = 0.4;
uniform float glow_line_width : hint_range(0.0, 0.05) = 0.008;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float glow_spacing : hint_range(0.5, 5.0) = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
			   mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise(p)*0.5 + noise(p*2.0)*0.25 + noise(p*4.0)*0.125;
}

// Grid de baldosas
float tile_grid(vec2 uv, float size) {
	vec2 g = fract(uv) / size;
	vec2 edge = smoothstep(0.0, 1.0, g) * (1.0 - smoothstep(0.0, 1.0, fract(uv) / size - (1.0/size - 1.0)));
	return min(edge.x, edge.y);
}

void fragment() {
	vec2 uv = UV * tile_scale;
	float t = TIME;
	
	// === GRID DE BALDOSAS ===
	vec2 tile_uv = fract(uv);
	vec2 tile_id = floor(uv);
	
	// Grouting (líneas entre baldosas)
	float grout_x = smoothstep(0.0, tile_size, tile_uv.x) * (1.0 - smoothstep(1.0 - tile_size, 1.0, tile_uv.x));
	float grout_y = smoothstep(0.0, tile_size, tile_uv.y) * (1.0 - smoothstep(1.0 - tile_size, 1.0, tile_uv.y));
	float grout_mask = grout_x * grout_y;
	
	// Color variación por tile
	float tile_var = hash(tile_id) * 0.08;
	vec3 tile_color = color_base.rgb + tile_var;
	
	// === IMPERFECCIONES ===
	float scratches = fbm(uv * 3.0) * 0.06;
	float dirt = noise(uv * 1.5) * 0.04;
	tile_color -= scratches + dirt;
	tile_color = max(tile_color, vec3(0.0));
	
	// Mezcla con grouting
	vec3 base = mix(color_grout.rgb, tile_color, grout_mask);
	
	// === HUMEDAD / WET LOOK ===
	float wet_noise = fbm(uv * 0.8 + vec2(t * 0.02, 0.0));
	float wet_mask = smoothstep(0.3, 0.8, wet_noise) * wet_amount;
	float wet_roughness = mix(roughness_base, roughness_base * 0.3, wet_mask);
	float wet_metallic = mix(metallic_base, 0.9, wet_mask);
	
	vec3 wet_tint = mix(base, color_wet.rgb, wet_mask * 0.3);
	
	// === LÍNEAS DE ENERGÍA SYMBIOTE ===
	// Líneas que fluyen por el suelo
	float line_uv_x = fract(uv.x / glow_spacing + t * glow_line_speed * 0.1);
	float line_uv_y = fract(uv.y / glow_spacing - t * glow_line_speed * 0.15);
	
	// Distorsión orgánica
	float dist_x = noise(vec2(uv.y * 0.5, t * 0.3)) * 0.1;
	float dist_y = noise(vec2(uv.x * 0.5, t * 0.2)) * 0.1;
	
	float glow_x = smoothstep(glow_line_width, 0.0, abs(line_uv_x - 0.5 + dist_x));
	float glow_y = smoothstep(glow_line_width, 0.0, abs(line_uv_y - 0.5 + dist_y));
	float glow_lines = max(glow_x, glow_y) * 0.6;
	
	// Pulsación de las líneas
	float pulse = sin(t * 1.5) * 0.3 + 0.7;
	glow_lines *= pulse;
	
	vec3 final_color = wet_tint + color_glow_line.rgb * glow_lines * 0.2;
	
	// === NORMAL MAP PROCEDURAL ===
	// Simular bump desde el fbm
	float h = fbm(uv * 2.0);
	float hx = fbm(uv * 2.0 + vec2(0.01, 0.0));
	float hy = fbm(uv * 2.0 + vec2(0.0, 0.01));
	NORMAL_MAP = normalize(vec3((h - hx) * 5.0, (h - hy) * 5.0, 0.3) * 0.5 + 0.5);
	NORMAL_MAP_DEPTH = 0.4;
	
	ALBEDO = final_color;
	METALLIC = wet_metallic;
	ROUGHNESS = wet_roughness;
	EMISSION = color_glow_line.rgb * glow_lines * glow_intensity;
	SPECULAR = mix(0.6, 1.0, wet_mask);
}
