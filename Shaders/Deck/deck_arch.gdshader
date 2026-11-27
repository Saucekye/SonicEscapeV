shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_opaque;
// The vaulted roof, seen from inside

uniform vec4 glass : source_color = vec4(0.02, 0.05, 0.12, 1.0);
uniform vec4 rib : source_color = vec4(0.55, 0.62, 0.68, 1.0);
uniform float floor_y = 40.0;     // nothing below the hall's floor
uniform float rib_every = 4.0;    // m along the hall
uniform float ribs_round = 14.0;  // ribs around the curve

varying vec3 wp;
varying vec3 lp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
}

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	if (wp.y < floor_y) discard;
	float ang = atan(lp.x, lp.z);          // round the curve
	float along = lp.y;
	float r1 = 1.0 - smoothstep(0.0, 0.08, abs(fract(along / rib_every + 0.5) - 0.5) * rib_every);
	float r2 = 1.0 - smoothstep(0.0, 0.025, abs(fract(ang / 6.2832 * ribs_round + 0.5) - 0.5) / ribs_round * 6.2832);
	// Glass you can see the night and the city through, in pale ribs
	float sheen = smoothstep(0.85, 1.0, sin(along * 0.25 + ang * 2.0)) * 0.3;
	vec3 col = glass.rgb + vec3(0.25, 0.4, 0.6) * sheen;
	float frame = max(r1, r2 * 0.7);
	ALBEDO = mix(col, rib.rgb * 0.7, frame);
	ALPHA = mix(0.28 + sheen * 0.5, 1.0, frame);
}
