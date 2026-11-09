// Full-screen colour grade, glow and vignette.
// Draws under the HUD, so the HUD keeps its own colours.
// One preset per stage gives every stage a single colour mood.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// Colour grade: shadows lean toward one colour, highlights toward another
uniform vec4 shadow_tint : source_color = vec4(1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
uniform float grade_strength : hint_range(0.0, 1.0) = 1.0;

// Soft glow around bright areas (sky, moon, lights, rings)
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;
uniform float glow_radius_px = 10.0;
uniform vec4 glow_color : source_color = vec4(1.0);

// Light shafts: bright parts of the scene streak away from a light source
uniform float rays_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec2 rays_source = vec2(0.75, 0.05);   // light position on screen (0-1)
uniform float rays_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float rays_length : hint_range(0.0, 1.0) = 0.35;
uniform vec4 rays_color : source_color = vec4(1.0);

// Darker screen edges
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.6;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 bright(vec2 uv) {
	vec3 c = texture(screen_tex, uv).rgb;
	return max(c - vec3(glow_threshold), vec3(0.0)) / max(1.0 - glow_threshold, 0.001);
}

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	vec3 c = src;

	// Glow: 12 taps on two rings around each pixel (cheap enough for any GPU)
	if (glow_strength > 0.0) {
		vec2 px = SCREEN_PIXEL_SIZE * glow_radius_px;
		vec3 g = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			float a = float(i) * 1.0471976; // 60 degrees
			vec2 d = vec2(cos(a), sin(a));
			g += bright(SCREEN_UV + d * px);
			g += bright(SCREEN_UV + d * px * 2.2 + vec2(-d.y, d.x) * px * 0.6);
		}
		c += (g / 12.0) * glow_color.rgb * glow_strength;
	}

	// Light shafts: march from this pixel toward the light, collecting bright sky
	if (rays_strength > 0.0) {
		vec2 step_uv = (rays_source - SCREEN_UV) * rays_length / 16.0;
		vec2 uv = SCREEN_UV;
		float decay = 1.0;
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 16; i++) {
			uv += step_uv;
			vec3 s = texture(screen_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
			acc += max(s - vec3(rays_threshold), vec3(0.0)) * decay;
			decay *= 0.9;
		}
		// Stronger near the light, fading with distance from it
		float falloff = 1.0 - smoothstep(0.0, 1.1, distance(SCREEN_UV, rays_source));
		c += acc / 16.0 * rays_color.rgb * rays_strength * falloff * 2.5;
	}

	// Grade
	float l = luma(c);
	vec3 graded = mix(c * shadow_tint.rgb, c * highlight_tint.rgb, smoothstep(0.05, 0.85, l));
	float gl = luma(graded);
	graded = mix(vec3(gl), graded, saturation);
	graded = (graded - 0.5) * contrast + 0.5;
	c = mix(c, graded, grade_strength);

	// Vignette
	vec2 v = SCREEN_UV - 0.5;
	v.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; // keep it round on wide screens
	float dist = length(v) * 1.2;
	c *= 1.0 - vignette_strength * smoothstep(1.0 - vignette_softness, 1.0, dist);

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
