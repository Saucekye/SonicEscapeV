shader_type spatial;
render_mode unshaded, cull_disabled;
// A mirror: shows what a camera on the other side of it sees

uniform sampler2D mirror_tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(0.82, 0.86, 0.9, 1.0);

void fragment() {
	vec3 col = texture(mirror_tex, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)).rgb;
	ALBEDO = col * tint.rgb;
}
