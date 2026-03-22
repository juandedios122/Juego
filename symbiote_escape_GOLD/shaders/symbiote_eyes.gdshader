shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 color_iris : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_pupil : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_glow_inner : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 color_glow_outer : source_color = vec4(0.5, 0.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.5, 5.0) = 2.5;
uniform float pupil_size : hint_range(0.0, 0.8) = 0.25;
uniform float iris_sharpness : hint_range(1.0, 20.0) = 8.0;
uniform float scan_speed : hint_range(0.0, 3.0) = 0.6;
uniform float flicker_speed : hint_range(0.0, 10.0) = 3.0;
uniform float menace_pulse : hint_range(0.0, 1.0) = 0.5;

float circle(vec2 uv, float radius, float softness) {
	float d = length(uv - vec2(0.5));
	return 1.0 - smoothstep(radius - softness, radius + softness, d);
}

void fragment() {
	vec2 uv = UV;
	vec2 center = uv - vec2(0.5);
	float t = TIME;
	
	float dist = length(center);
	
	// === IRIS BASE ===
	float iris = circle(uv, 0.45, 0.03);
	float iris_edge = circle(uv, 0.45, 0.0) - circle(uv, 0.38, 0.0);
	
	// === PUPILA ===
	// Pupila que se dilata/contrae
	float pupil_r = pupil_size + sin(t * menace_pulse * 2.0) * 0.04;
	float pupil = circle(uv, pupil_r, 0.015);
	
	// Deformación de pupila (forma amenazante)
	float angle = atan(center.y, center.x);
	float threat = sin(angle * 3.0 + t * 0.5) * 0.015;
	float pupil_distorted = circle(uv + vec2(threat, threat * 0.5), pupil_r, 0.02);
	
	// === SCAN LINES (efecto alien/simbiote) ===
	float scan = sin(uv.y * 20.0 + t * scan_speed) * 0.5 + 0.5;
	scan = pow(scan, 4.0) * 0.15;
	
	// === PATRONES DE IRIS ===
	// Radial lines
	float radial = sin(angle * 16.0 + t * 0.2) * 0.5 + 0.5;
	radial *= (1.0 - smoothstep(0.15, 0.45, dist));
	radial = pow(radial, 3.0) * 0.3;
	
	// Rings
	float rings = sin(dist * 30.0 - t * 0.8) * 0.5 + 0.5;
	rings = pow(rings, 5.0) * 0.2 * iris;
	
	// === PARPADEO ===
	float flicker = sin(t * flicker_speed) * 0.03 + sin(t * flicker_speed * 2.3) * 0.02;
	float brightness = 1.0 + flicker + sin(t * menace_pulse) * menace_pulse * 0.1;
	
	// === COMPOSICIÓN ===
	vec3 base_iris = color_iris.rgb;
	
	// Añadir detail patterns
	base_iris += vec3(radial);
	base_iris += vec3(rings);
	base_iris += scan * color_glow_outer.rgb * 0.5;
	
	// Añadir tinte púrpura en bordes del iris
	float iris_tint = 1.0 - smoothstep(0.2, 0.45, dist);
	base_iris = mix(base_iris, color_glow_outer.rgb * 0.5 + base_iris, iris_tint * 0.3);
	
	// Mezclar con pupila
	vec3 final_color = mix(base_iris, color_pupil.rgb, pupil_distorted);
	
	// Reflection spot (hace el ojo 3D/realista)
	float spec1 = circle(uv - vec2(0.15, 0.15) + vec2(0.5), 0.07, 0.04);
	float spec2 = circle(uv - vec2(0.22, 0.18) + vec2(0.5), 0.03, 0.02);
	final_color = mix(final_color, vec3(1.0), spec1 * (1.0 - pupil_distorted) * 0.6);
	final_color = mix(final_color, vec3(1.0), spec2 * (1.0 - pupil_distorted) * 0.4);
	
	// Glow exterior
	float glow = 1.0 - smoothstep(0.3, 0.55, dist);
	glow = pow(glow, 2.0);
	
	// Mask todo al círculo del ojo
	float eye_mask = circle(uv, 0.48, 0.02);
	final_color *= eye_mask;
	
	ALBEDO = final_color * brightness;
	EMISSION = final_color * glow_intensity * brightness * eye_mask;
	EMISSION += color_glow_outer.rgb * glow * 0.8 * eye_mask;
	ALPHA = eye_mask;
}
