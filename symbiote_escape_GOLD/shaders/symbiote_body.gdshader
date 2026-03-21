shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  albedo      : source_color = vec4(0.03, 0.02, 0.06, 1.0);
uniform float metallic    : hint_range(0.0, 1.0) = 0.9;
uniform float roughness   : hint_range(0.0, 1.0) = 0.05;
uniform vec4  emission    : source_color = vec4(0.12, 0.0, 0.45, 1.0);
uniform float emit_energy : hint_range(0.0, 8.0) = 1.6;
uniform float ripple_speed : hint_range(0.0, 6.0) = 2.2;
uniform float ripple_amp   : hint_range(0.0, 0.15) = 0.042;
uniform float absorb_flash : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float t  = TIME * ripple_speed;
	float wv = sin(VERTEX.y * 8.0 + t) * ripple_amp
	         + sin(VERTEX.x * 6.0 + t * 1.4) * ripple_amp * 0.5;
	VERTEX  += NORMAL * wv;
}

void fragment() {
	vec3  base = albedo.rgb + vec3(absorb_flash * 0.35, 0.0, absorb_flash * 0.55);
	ALBEDO    = base;
	METALLIC  = metallic;
	ROUGHNESS = roughness;
	EMISSION  = emission.rgb * emit_energy
	           + vec3(absorb_flash*1.4, 0.0, absorb_flash*2.2);
	float frn = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += vec3(0.2, 0.0, 0.85) * frn * 2.2;
}
