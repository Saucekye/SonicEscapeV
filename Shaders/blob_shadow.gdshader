shader_type spatial;
// A character's shadow on the floor
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float steps = 4.0;   // banded like the rest of the PS1 look

uniform bool outline = false;              // use the picture below instead of a round patch
uniform sampler2D picture : filter_nearest;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);   // the frame in the picture
uniform bool flip = false;
uniform float tip_fade = 0.6;              // the far end (their head) is this much lighter

void fragment() {
	float a;
	if (outline) {
		// UV.y = 0 at their feet, 1 at the far end
		vec2 uv = vec2(flip ? 1.0 - UV.x : UV.x, 1.0 - UV.y);
		a = texture(picture, region.xy + uv * region.zw).a;
		a *= 1.0 - tip_fade * UV.y;
	} else {
		vec2 d = UV * 2.0 - 1.0;
		a = 1.0 - smoothstep(0.15, 1.0, dot(d, d));
	}
	if (steps > 0.0) {
		a = ceil(a * steps) / steps;
	}
	ALBEDO = vec3(0.0);
	ALPHA = a * strength;
}
