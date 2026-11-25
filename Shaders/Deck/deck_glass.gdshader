shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
// Big glass panes in chrome frames

uniform vec4 tint : source_color = vec4(0.1, 0.22, 0.35, 0.18);
uniform vec4 frame : source_color = vec4(0.36, 0.45, 0.5, 1.0);
uniform float pane = 4.0;          // width of a pane
uniform float pane_h = 3.4;        // height of a pane
uniform float bar = 0.05;          // frame thickness

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Along the wall
	vec2 uv = abs(wn.y) > 0.5 ? wp.xz : vec2(abs(wn.z) > 0.5 ? wp.x : wp.z, wp.y);
	vec2 cell = abs(wn.y) > 0.5 ? vec2(pane * 2.0) : vec2(pane, pane_h);
	vec2 d = abs(fract(uv / cell + 0.5) - 0.5) * cell;
	float on_bar = 1.0 - step(bar, min(d.x, d.y));
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - wp);
	float fres = pow(1.0 - abs(dot(to_cam, wn)), 3.0);
	// A soft sheen sliding down the glass
	float sheen = smoothstep(0.92, 1.0, sin(uv.x * 0.35 + uv.y * 0.6 + TIME * 0.1)) * 0.25;
	vec3 glass = tint.rgb + vec3(0.5, 0.7, 0.85) * (fres * 0.6 + sheen);
	vec3 metal = frame.rgb * (0.55 + 0.45 * fres) + vec3(0.25) * smoothstep(0.35, 0.0, abs(d.x - bar * 0.5));
	ALBEDO = mix(glass, metal, on_bar);
	ALPHA = mix(clamp(tint.a + fres * 0.35 + sheen, 0.0, 1.0), 1.0, on_bar);
}
