// Reflective water surface. Mirrors whatever is on screen above
// the waterline, with moving ripples, a tint, and a bright shimmering surface line.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float surface_uv_y = 0.5;          // set by reflective_water.gd every frame
uniform vec4 water_color : source_color = vec4(0.1, 0.35, 0.75, 1.0);
uniform vec4 reflection_tint : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float reflectivity : hint_range(0.0, 1.0) = 0.55;
uniform float fade_uv = 0.35;              // how far down the reflection fades out (screen height fraction)
uniform float ripple_strength = 0.004;
uniform float ripple_speed = 2.0;
uniform vec4 surface_color : source_color = vec4(0.85, 0.97, 1.0, 1.0);
uniform float surface_px = 3.0;            // thickness of the shimmering top line, in screen pixels

void fragment() {
	float depth = SCREEN_UV.y - surface_uv_y;
	// Ripples grow a little with depth, like a real surface
	float ripple = sin(SCREEN_UV.y * 220.0 - TIME * ripple_speed * 3.0) * 0.6
				 + sin(SCREEN_UV.x * 60.0 + TIME * ripple_speed) * 0.4;
	vec2 ruv = vec2(SCREEN_UV.x + ripple * ripple_strength * (0.5 + depth * 4.0),
					surface_uv_y - depth);
	vec3 reflected = texture(screen_tex, clamp(ruv, vec2(0.0), vec2(1.0))).rgb * reflection_tint.rgb;
	float fade = clamp(1.0 - depth / fade_uv, 0.0, 1.0);
	vec3 c = mix(water_color.rgb, reflected, reflectivity * fade);
	// Shimmering waterline
	float line_px = depth / SCREEN_PIXEL_SIZE.y;
	float shimmer = 0.6 + 0.4 * sin(SCREEN_UV.x * 300.0 + TIME * 4.0);
	if (line_px < surface_px) {
		c = mix(c, surface_color.rgb, 0.8 * shimmer);
	}
	COLOR = vec4(c, water_color.a);
}
