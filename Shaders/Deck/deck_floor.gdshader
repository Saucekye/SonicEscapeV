shader_type spatial;
render_mode unshaded, cull_disabled;
// The deck above the maze

uniform vec4 base : source_color = vec4(0.03, 0.11, 0.11, 1.0);
uniform vec4 line : source_color = vec4(0.06, 0.2, 0.19, 1.0);
uniform vec4 shine : source_color = vec4(0.55, 1.0, 0.78, 1.0);
uniform float tile = 2.0;
uniform float tube_spacing = 8.0;       // the tubes run along z, this far apart in x
uniform float ripple = 0.35;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 g = abs(fract(wp.xz / tile) - 0.5);
	float grout = 1.0 - smoothstep(0.47, 0.5, max(g.x, g.y));
	vec3 col = mix(line.rgb, base.rgb, grout);
	// Each tile a touch different
	col *= 0.85 + 0.3 * h(floor(wp.xz / tile));
	// The tubes overhead, reflected in the wet floor
	float dx = abs(mod(wp.x + tube_spacing * 0.5, tube_spacing) - tube_spacing * 0.5);
	float band = exp(-dx * dx * 3.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - wp);
	float graze = pow(1.0 - clamp(to_cam.y, 0.0, 1.0), 2.0);
	col += shine.rgb * band * (0.12 + 0.5 * graze);
	// A slow ripple of light, like light off water
	float t = TIME * 0.25;
	float c = n(wp.xz * 0.6 + vec2(t, -t * 0.7)) + n(wp.xz * 1.3 - vec2(t * 0.8, t * 0.4));
	col += vec3(0.25, 0.55, 0.7) * pow(smoothstep(1.1, 1.6, c), 2.0) * ripple;
	ALBEDO = col;
}
