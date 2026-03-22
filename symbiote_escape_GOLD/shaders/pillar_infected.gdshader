shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 color_metal : source_color = vec4(0.15, 0.13, 0.17, 1.0);
uniform vec4 color_rust : source_color = vec4(0.1, 0.05, 0.02, 1.0);
uniform vec4 color_symbiote : source_color = vec4(0.12, 0.0, 0.22, 1.0);
uniform vec4 color_glow : source_color = vec4(0.5, 0.0, 0.9, 1.0);

uniform float metallic : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_clean : hint_range(0.0, 1.0) = 0.3;
uniform float infection_amount : hint_range(0.0, 1.0) = 0.55;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.2;
uniform float stripe_count : hint_range(1.0, 20.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 3.0) = 1.2;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p) { return noise(p)*0.5+noise(p*2.0)*0.25+noise(p*4.0)*0.125; }

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	
	// === METAL BASE ===
	float metal_var = noise(uv * 8.0) * 0.06;
	float scratches = noise(uv * vec2(1.0, 20.0)) * 0.04;
	vec3 metal_base = color_metal.rgb + metal_var - scratches;
	
	// Rayas horizontales del metal (anillos del cilindro)
	float stripes = sin(uv.y * stripe_count * 3.14159) * 0.5 + 0.5;
	stripes = smoothstep(0.3, 0.7, stripes) * 0.05;
	metal_base += stripes;
	
	// Óxido/envejecimiento
	float rust = fbm(uv * 3.0) * smoothstep(0.4, 0.8, fbm(uv * 1.5));
	metal_base = mix(metal_base, color_rust.rgb, rust * 0.4);
	
	// === INFECCIÓN SYMBIOTE ===
	// Crece desde abajo (UV.y bajo = parte de arriba en Godot)
	float infection_height = smoothstep(1.0 - infection_amount - 0.2, 1.0 - infection_amount + 0.3, uv.y);
	
	// Contorno orgánico de la infección
	float infection_edge = fbm(vec2(uv.x * 4.0, uv.y * 3.0 + t * 0.1));
	float infection_mask = smoothstep(0.0, 0.4, infection_height + infection_edge * 0.3 - 0.15);
	
	// Textura symbiote
	float sym_texture = fbm(uv * 5.0 + vec2(t * 0.08, t * 0.05));
	vec3 sym_color = mix(color_symbiote.rgb, color_symbiote.rgb * 1.5, sym_texture);
	
	// Venas en el simbionte
	float veins = 1.0 - smoothstep(0.0, 0.12, abs(fbm(uv * 6.0 + vec2(t * 0.1, 0.0)) - 0.5));
	veins *= infection_mask;
	
	// Mezclar metal con simbionte
	vec3 final_color = mix(metal_base, sym_color, infection_mask * 0.8);
	final_color = mix(final_color, color_glow.rgb * 0.5, veins * 0.5);
	
	// === HIGHLIGHT METÁLICO ===
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
	final_color += vec3(0.3) * fresnel * (1.0 - infection_mask) * 0.4;
	
	// === PULSO ===
	float pulse = sin(t * pulse_speed) * 0.4 + 0.6;
	
	// === NORMAL MAP ===
	float h = noise(uv * 6.0) * 0.1;
	float hx = noise(uv * 6.0 + vec2(0.01,0.0)) * 0.1;
	float hy = noise(uv * 6.0 + vec2(0.0,0.01)) * 0.1;
	NORMAL_MAP = normalize(vec3((h-hx)*5.0,(h-hy)*5.0,0.3)*0.5+0.5);
	NORMAL_MAP_DEPTH = mix(0.3, 0.7, infection_mask);
	
	ALBEDO = final_color;
	METALLIC = mix(metallic, 0.1, infection_mask);
	ROUGHNESS = mix(roughness_clean, 0.6, infection_mask);
	EMISSION = color_glow.rgb * veins * glow_intensity * pulse;
	SPECULAR = mix(0.8, 0.3, infection_mask);
}
