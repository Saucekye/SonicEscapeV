// A drifting band of mist or smog between city depth layers.
// Drawn on the characters' pixel grid with a few dithered steps of density, so
// it reads as pixel-art fog rather than a smooth gradient laid over pixel art.
shader_type canvas_item;

uniform vec4 mist_color : source_color = vec4(0.3, 0.4, 0.6, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float texel_px = 2.0;          // one character pixel, in screen pixels
uniform vec2 offset_px = vec2(0.0);    // scroll + drift, in screen pixels
uniform float time_s = 0.0;

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[i.y * 4 + i.x]) / 16.0;
}

void fragment() {
	// Snap to the character pixel grid
	vec2 cell = floor((FRAGCOORD.xy + offset_px) / texel_px);
	vec2 p = cell * texel_px;
	float n1 = texture(noise_tex, p / vec2(900.0, 260.0) + vec2(time_s * 0.004, 0.0)).r;
	float n2 = texture(noise_tex, p / vec2(420.0, 140.0) + vec2(-time_s * 0.009, 0.37)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	// Thicker in the middle of the band, thinning out above and below
	float fall = smoothstep(0.0, 0.45, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float a = smoothstep(0.38, 0.72, n) * fall * strength;
	// Four dithered steps of density
	a = floor(a * 4.0 + bayer4(cell)) / 4.0;
	COLOR = vec4(mist_color.rgb, a);
}
