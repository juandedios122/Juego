shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// === COLORES SIMBIONTE ===
uniform vec4 color_base : source_color = vec4(0.04, 0.01, 0.08, 1.0);
uniform vec4 color_venas : source_color = vec4(0.35, 0.0, 0.6, 1.0);
uniform vec4 color_glow : source_color = vec4(0.6, 0.0, 1.0, 1.0);
uniform vec4 color_tendrils : source_color = vec4(0.15, 0.0, 0.3, 1.0);

// === PROPIEDADES MATERIAL ===
uniform float metallic : hint_range(0.0, 1.0) = 0.7;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.6;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 1.4;

// === ANIMACIÓN ===
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform float pulse_speed : hint_range(0.1, 4.0) = 1.5;
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.12;
uniform float tendril_speed : hint_range(0.1, 3.0) = 0.8;
uniform float tendril_scale : hint_range(1.0, 20.0) = 6.0;
uniform float vein_intensity : hint_range(0.0, 3.0) = 1.8;

// === DESPLAZAMIENTO ===
uniform float displacement_strength : hint_range(0.0, 0.15) = 0.04;
uniform float noise_scale : hint_range(1.0, 15.0) = 5.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float pulse;
varying float vein_pattern;
varying float tendril_pattern;

// === FUNCIONES NOISE ===
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.1;
	}
	return value;
}

// Patrón de venas tipo simbionte
float vein_network(vec2 uv, float t) {
	vec2 p = uv * tendril_scale;
	float v1 = fbm(p + vec2(t * 0.3, t * 0.2), 4);
	float v2 = fbm(p * 1.3 - vec2(t * 0.15, t * 0.4), 3);
	float v3 = fbm(p * 0.7 + vec2(t * 0.5, -t * 0.25), 3);
	float veins = abs(v1 - v2) * abs(v2 - v3);
	veins = pow(veins, 0.4);
	return 1.0 - smoothstep(0.0, 0.35, veins);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	float t = TIME * time_scale;
	vec2 uv_anim = UV + vec2(t * 0.08, t * 0.05);
	
	// Pulsación orgánica
	pulse = sin(t * pulse_speed) * 0.5 + 0.5;
	float noise_disp = fbm(UV * noise_scale + vec2(t * 0.3, t * 0.2), 3);
	float organic_disp = noise_disp * displacement_strength * (0.8 + pulse * 0.4);
	
	// Tendrils en superficie
	tendril_pattern = vein_network(UV, t * tendril_speed * 0.5);
	vein_pattern = fbm(uv_anim * 4.0, 5);
	
	// Aplicar desplazamiento
	VERTEX += NORMAL * organic_disp;
	// Efecto tentáculos en bordes
	VERTEX += NORMAL * tendril_pattern * 0.02 * pulse;
}

void fragment() {
	float t = TIME * time_scale;
	vec2 uv = UV;
	
	// === PATRÓN DE VENAS ANIMADAS ===
	float v = vein_network(uv, t * tendril_speed);
	float v2 = vein_network(uv * 1.7 + vec2(0.3, 0.7), t * tendril_speed * 0.6);
	float veins = max(v, v2 * 0.7);
	
	// === RUIDO ORGÁNICO ===
	float organic = fbm(uv * 8.0 + vec2(t * 0.1, t * 0.15), 4);
	float deep_pattern = fbm(uv * 3.0 - vec2(t * 0.05, t * 0.08), 3);
	
	// === PULSO ===
	float p = sin(t * pulse_speed) * 0.5 + 0.5;
	float p2 = sin(t * pulse_speed * 1.7 + 1.2) * 0.5 + 0.5;
	
	// === MEZCLA DE COLORES ===
	vec3 base = color_base.rgb;
	vec3 vein_col = mix(color_tendrils.rgb, color_venas.rgb, p);
	vec3 glow_col = color_glow.rgb * (p * 0.6 + 0.4);
	
	// Capa base con profundidad
	vec3 final_color = mix(base, base * 1.4, deep_pattern * 0.5);
	
	// Añadir venas
	float vein_strength = veins * vein_intensity * (0.7 + p * 0.6);
	final_color = mix(final_color, vein_col, vein_strength * 0.8);
	
	// Glow pulsante en venas
	vec3 vein_glow = glow_col * pow(veins, 1.5) * (p * 1.2 + 0.3);
	final_color += vein_glow * 0.4;
	
	// Brillo orgánico superficial
	float surface_sheen = pow(organic, 2.0) * 0.3;
	final_color += color_venas.rgb * surface_sheen * p2;
	
	// === RIM LIGHT (efecto symbiote brillante en bordes) ===
	float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	rim = pow(rim, rim_power);
	vec3 rim_color = mix(color_venas.rgb, color_glow.rgb, p);
	final_color += rim_color * rim * rim_strength * (0.8 + p * 0.4);
	
	// === SUBSURFACE SCATTERING SIMULADO ===
	float sss = max(0.0, dot(NORMAL, vec3(0.0, 1.0, 0.0)));
	final_color += color_venas.rgb * sss * subsurface_strength * 0.3 * p;
	
	ALBEDO = final_color;
	METALLIC = metallic;
	ROUGHNESS = roughness - organic * 0.08;
	EMISSION = vein_glow * 0.6 + rim_color * rim * 0.3 * rim_strength;
	EMISSION += color_glow.rgb * surface_sheen * p * 0.5;
	SPECULAR = 0.9;
}
