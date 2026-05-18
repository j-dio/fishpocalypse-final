shader_type spatial;

uniform sampler2D noise_tex;
uniform vec3 water_color : source_color = vec3(0.0, 0.1, 0.3);
uniform float speed = 0.03;
uniform float strength = 0.15;
uniform float pixel_size = 256.0;

void fragment() {
	// pixel UV (pixelator); constant came from 1/256
	vec2 uv = floor(UV * pixel_size) * 0.00390625;
	// moving noise UV
	vec2 noise_uv = uv + TIME * vec2(speed, speed * 0.5);
	// white noise
	float n = texture(noise_tex, noise_uv).r;
	// PSX chunkiness
	n = floor(n * 6.0) * 0.16667;
	ALBEDO = water_color + (n - 0.5) * strength * 0.5;
    ROUGHNESS = 1.0;
}