shader_type spatial;
render_mode unshaded, cull_disabled;
// Pool hall floor

uniform vec4 tile_col : source_color = vec4(0.42, 0.55, 0.62, 1.0);
uniform vec4 grout_col : source_color = vec4(0.16, 0.24, 0.3, 1.0);
uniform vec4 caustic : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float tile = 0.5;
uniform float dim = 0.45;          // the hall's lit low

varying vec3 wp;

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 g = abs(fract(wp.xz / tile) - 0.5);
	float grout = smoothstep(0.44, 0.5, max(g.x, g.y));
	vec3 col = mix(tile_col.rgb * (0.9 + 0.2 * h(floor(wp.xz / tile))), grout_col.rgb, grout) * dim;
	float t = TIME * 0.3;
	float a = n(wp.xz * 0.9 + vec2(t, t * 0.5));
	float b = n(wp.xz * 1.4 - vec2(t * 0.6, -t * 0.8));
	float lines = smoothstep(0.07, 0.0, abs(a - b));
	// Brighter near the pools along both sides
	float near_pool = smoothstep(9.0, 4.0, abs(abs(wp.x) - 9.5));
	col += caustic.rgb * lines * (0.08 + 0.3 * near_pool);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - wp);
	col += vec3(0.2, 0.3, 0.4) * pow(1.0 - clamp(to_cam.y, 0.0, 1.0), 4.0) * 0.5;   // wet sheen at a glance
	ALBEDO = col;
}
