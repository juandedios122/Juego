shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 color_concrete : source_color = vec4(0.08, 0.07, 0.1, 1.0);
uniform vec4 color_dark : source_color = vec4(0.02, 0.01, 0.03, 1.0);
uniform vec4 color_symbiote_vein : source_color = vec4(0.3, 0.0, 0.5, 1.0);
uniform vec4 color_crack_glow : source_color = vec4(0.55, 0.0, 0.9, 1.0);

uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float vein_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float crack_glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float tile_scale : hint_range(0.5, 10.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.8;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p, int oct) {
	float v = 0.0; float a = 0.5;
	for(int i = 0; i < oct; i++) { v += a*noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

// Grietas procedurales
float cracks(vec2 uv) {
	float c = 0.0;
	for(int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 offset = vec2(hash(vec2(fi, 0.0)), hash(vec2(0.0, fi)));
		float crack = fbm(uv * (1.5 + fi * 0.8) + offset, 3);
		float crack_line = abs(crack - 0.5);
		c = max(c, 1.0 - smoothstep(0.0, 0.06, crack_line));
	}
	return c;
}

// Venas del simbionte en la pared
float symbiote_veins(vec2 uv, float t) {
	float v1 = fbm(uv * 3.0 + vec2(t * 0.1, 0.0), 4);
	float v2 = fbm(uv * 2.0 - vec2(0.0, t * 0.08), 3);
	float veins = abs(v1 - v2);
	veins = 1.0 - smoothstep(0.0, 0.08 + vein_coverage * 0.15, veins);
	return veins * vein_coverage;
}

void fragment() {
	vec2 uv = UV * tile_scale;
	float t = TIME;
	
	// === CONCRETO BASE ===
	float concrete_noise = fbm(uv * 4.0, 5);
	float stains = fbm(uv * 1.5, 3) * 0.15;
	vec3 base = mix(color_dark.rgb, color_concrete.rgb, concrete_noise);
	base -= stains;
	
	// === BLOQUES DE CONCRETO ===
	vec2 block_uv = fract(uv * 0.5);
	float mortar_x = smoothstep(0.0, 0.05, block_uv.x) * (1.0 - smoothstep(0.95, 1.0, block_uv.x));
	float mortar_y = smoothstep(0.0, 0.05, block_uv.y) * (1.0 - smoothstep(0.95, 1.0, block_uv.y));
	float mortar = mortar_x * mortar_y;
	base = mix(color_dark.rgb * 0.5, base, mortar);
	
	// === GRIETAS CON GLOW SYMBIOTE ===
	float crack_mask = cracks(uv);
	float pulse = sin(t * pulse_speed) * 0.3 + 0.7;
	vec3 crack_color = mix(color_dark.rgb, color_crack_glow.rgb, pulse);
	base = mix(base, crack_color * 0.6, crack_mask * 0.7);
	
	// === VENAS DEL SIMBIONTE ===
	float veins = symbiote_veins(uv, t);
	vec3 vein_col = mix(color_symbiote_vein.rgb, color_crack_glow.rgb, sin(t * pulse_speed) * 0.4 + 0.4);
	base = mix(base, vein_col * 0.6, veins * 0.6);
	
	// Manchas de simbionte en las paredes
	float symbiote_blob = fbm(uv * 0.7, 3);
	float blob_mask = smoothstep(0.55, 0.75, symbiote_blob) * vein_coverage;
	base = mix(base, color_dark.rgb * 0.5 + vein_col * 0.2, blob_mask);
	
	// === NORMAL MAP ===
	float h = concrete_noise + crack_mask * 0.3;
	float hx = fbm(uv * 4.0 + vec2(0.01, 0.0), 3) + cracks(uv + vec2(0.01,0)) * 0.3;
	float hy = fbm(uv * 4.0 + vec2(0.0, 0.01), 3) + cracks(uv + vec2(0.0,0.01)) * 0.3;
	NORMAL_MAP = normalize(vec3((h - hx) * 8.0, (h - hy) * 8.0, 0.3) * 0.5 + 0.5);
	NORMAL_MAP_DEPTH = 0.8;
	
	ALBEDO = base;
	METALLIC = metallic;
	ROUGHNESS = roughness - crack_mask * 0.2;
	EMISSION = color_crack_glow.rgb * crack_mask * crack_glow_intensity * pulse * 0.5;
	EMISSION += vein_col * veins * crack_glow_intensity * 0.3 * pulse;
}
