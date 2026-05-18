shader_type spatial;
render_mode blend_mix, cull_back, depth_prepass_alpha;

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform float alpha_cutoff : hint_range(0.0,1.0) = 0.4;
uniform float speed : hint_range(0.0, 1.0) = 0.02;

void fragment() {
	vec2 uv = UV + TIME * vec2(speed, speed * 0.5);
	float n = texture(noise_tex, uv).r;
	
	float t = clamp((n - 0.1) * 1.25, 0.0, 1.0);
	float cloud = t * t * (3.0 - 2.0 * t);
	
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ALPHA = cloud;
	ALBEDO = vec3(1.0);
}