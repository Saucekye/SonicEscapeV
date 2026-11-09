// Screen look for the Salvage mini game, after "It Steals": the scene is rendered
// small (salvage.gd) and blown up soft rather than with hard pixels, then
//  - bloom: lamps and anything brightly lit bleed a warm halo into the dark
//  - film grain that crawls every frame
//  - light colour banding with ordered dithering (a touch of the PS1)
//  - a heavy vignette, so the corners sink into black
shader_type canvas_item;

uniform vec2 low_res = vec2(400.0, 225.0);
uniform float levels = 40.0;         // shades per colour channel
uniform float vignette = 1.05;
uniform float bloom_threshold = 0.5;
uniform float bloom_strength = 0.9;
uniform float grain = 0.07;
uniform float desaturate = 0.4;      // drained, cold colour
uniform vec3 tint = vec3(0.86, 0.95, 0.92);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 bright(sampler2D tex, vec2 uv) {
	vec3 c = texture(tex, uv).rgb;
	return max(c - bloom_threshold, 0.0);
}

void fragment() {
	vec2 texel = 1.0 / low_res;
	// Soft upscale with a slight blur, like the reference's smeared low-res look
	vec3 col = texture(TEXTURE, UV).rgb * 0.6;
	col += texture(TEXTURE, UV + vec2(texel.x, 0.0) * 0.6).rgb * 0.1;
	col += texture(TEXTURE, UV - vec2(texel.x, 0.0) * 0.6).rgb * 0.1;
	col += texture(TEXTURE, UV + vec2(0.0, texel.y) * 0.6).rgb * 0.1;
	col += texture(TEXTURE, UV - vec2(0.0, texel.y) * 0.6).rgb * 0.1;
	// Bloom: two rings of taps around the pixel, of only the bright parts
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 dir = vec2(cos(a), sin(a)) * texel;
		glow += bright(TEXTURE, UV + dir * 2.5) * 0.6;
		glow += bright(TEXTURE, UV + dir * 6.0) * 0.4;
		glow += bright(TEXTURE, UV + dir * 11.0) * 0.25;
	}
	col += glow / 8.0 * bloom_strength * vec3(1.0, 0.85, 0.65);
	// Drained, cold colour and crushed shadows
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate) * tint;
	col = pow(max(col, 0.0), vec3(1.04));
	// Grain, new every frame
	float g = hash(floor(FRAGCOORD.xy / 2.0) + fract(TIME * 13.7) * 91.0) - 0.5;
	col += g * grain;
	// Light banding with dithering
	vec2 px = floor(UV * low_res);
	col += bayer4(px) / levels;
	col = floor(col * levels + 0.5) / levels;
	// Vignette
	vec2 c = UV - 0.5;
	col *= clamp(1.0 - dot(c, c) * vignette * 2.2, 0.0, 1.0);
	COLOR = vec4(max(col, 0.0), 1.0);
}
