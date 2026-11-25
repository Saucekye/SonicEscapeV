shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// One of the city's 2D layers, wrapped round the hall a long way off

uniform sampler2D art : source_color, filter_nearest_mipmap, repeat_enable;
uniform float repeats = 6.0;       // times the picture goes round
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 haze : source_color = vec4(0.12, 0.25, 0.45, 1.0);
uniform float haze_amount = 0.3;
uniform bool lights = false;       // a lights layer
uniform float drift = 0.0;         // turns a second
uniform float ring_h = 1.0;        // the ring's height
uniform float bright = 1.3;        // how bright a lights layer is
uniform float turn = 0.0;          // where round the picture starts

varying vec3 lp;

void vertex() { lp = VERTEX; }

void fragment() {
	float ang = atan(lp.x, lp.z) / 6.2832 + 0.5;
	vec2 uv = vec2((ang + turn + TIME * drift) * repeats, 0.5 - lp.y / ring_h);
	vec4 c = texture(art, uv);
	if (c.a < 0.5) discard;
	vec3 col = lights ? c.rgb * tint.rgb * bright : mix(c.rgb * tint.rgb, haze.rgb, haze_amount);
	ALBEDO = col;
}
