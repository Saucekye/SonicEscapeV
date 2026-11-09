// Analog CRT / VHS look over the whole screen (game, HUD and menus).
// Scanlines, a faint RGB shadow mask, slight screen curvature with dark rounded
// corners, colour fringing, film grain, flicker, a slow VHS tracking band, and
// short glitch bursts driven by crt_overlay.gd. No glow or bloom.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float curvature : hint_range(0.0, 0.2) = 0.025;      // barrel distortion (subtle)
uniform float corner_round : hint_range(0.0, 0.1) = 0.02;     // rounded screen corners
uniform float scanline_count = 360.0;                         // visible lines top to bottom
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float mask_strength : hint_range(0.0, 0.5) = 0.07;    // RGB phosphor stripes
uniform float aberration_px = 1.2;                            // red/blue fringing, in screen pixels
uniform float grain : hint_range(0.0, 0.3) = 0.045;
uniform float flicker : hint_range(0.0, 0.1) = 0.012;
uniform float vignette : hint_range(0.0, 1.0) = 0.22;
uniform float brightness = 1.12;                               // makes up for scanline/mask darkening
uniform float tracking_strength : hint_range(0.0, 1.0) = 0.35; // slow rolling VHS band
uniform float desaturate : hint_range(0.0, 1.0) = 0.08;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;              // set by crt_overlay.gd during bursts

// Sprites left out of the effect (the HUD's player icon), set by crt_overlay.gd.
// (CRT on the rest of the screen; the icon stays crisp.)
// Each maps screen UV to the sprite's frame (0..1) with x/y/origin columns;
// where the sprite's own pixel is solid, the screen is shown untouched.
uniform bool skip_on = false;
uniform sampler2D skip_tex0 : filter_nearest;
uniform sampler2D skip_tex1 : filter_nearest;
uniform vec2 skip0_x; uniform vec2 skip0_y; uniform vec2 skip0_o; uniform vec4 skip0_region; uniform bool skip0_on = false;
uniform vec2 skip1_x; uniform vec2 skip1_y; uniform vec2 skip1_o; uniform vec4 skip1_region; uniform bool skip1_on = false;

bool skipped(sampler2D tex, vec2 suv, vec2 ax, vec2 ay, vec2 o, vec4 region) {
	vec2 f = ax * suv.x + ay * suv.y + o;
	if (f.x < 0.0 || f.y < 0.0 || f.x >= 1.0 || f.y >= 1.0) {
		return false;
	}
	return texture(tex, region.xy + f * region.zw).a > 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 barrel(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * dot(c, c);
	c /= 1.0 + curvature;   // keep the edge centres on screen, so only the corners curve away
	return c * 0.5 + 0.5;
}

void fragment() {
	// (checked 2 pixels either side too, so the colour fringing doesn't smear the icon's edge)
	bool skip = false;
	if (skip_on) {
		for (int k = -1; k <= 1; k++) {
			vec2 q = SCREEN_UV + vec2(float(k) * 2.0 * SCREEN_PIXEL_SIZE.x, 0.0);
			skip = skip || (skip0_on && skipped(skip_tex0, q, skip0_x, skip0_y, skip0_o, skip0_region))
					|| (skip1_on && skipped(skip_tex1, q, skip1_x, skip1_y, skip1_o, skip1_region));
		}
	}
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = barrel(SCREEN_UV);

	// Outside the curved tube: black bezel
	vec2 edge = min(uv, 1.0 - uv);
	if (edge.x < 0.0 || edge.y < 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// VHS tracking band: a soft horizontal band that rolls slowly up the screen
		float band_y = fract(TIME * 0.035);
		float band = smoothstep(0.06, 0.0, abs(uv.y - band_y)) * tracking_strength;
		float wobble = (hash(vec2(floor(uv.y / px.y / 2.0), floor(TIME * 30.0))) - 0.5) * px.x * 6.0 * band;

		// Glitch bursts: torn horizontal strips
		float strip = floor(uv.y * 24.0);
		float tear = (hash(vec2(strip, floor(TIME * 20.0))) - 0.5) * 0.06 * glitch * step(0.6, hash(vec2(strip, 3.0)));
		vec2 suv = vec2(uv.x + wobble + tear, uv.y);

		// Colour fringing (stronger during a glitch)
		float ab = (aberration_px + glitch * 6.0) * px.x;
		vec3 col;
		col.r = texture(screen_tex, suv + vec2(ab, 0.0)).r;
		col.g = texture(screen_tex, suv).g;
		col.b = texture(screen_tex, suv - vec2(ab, 0.0)).b;

		// Slight analog desaturation
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(l), desaturate);

		// Scanlines
		float line = sin(uv.y * scanline_count * 3.14159265);
		col *= 1.0 - scanline_strength * (0.5 - 0.5 * line);

		// Phosphor mask: faint R / G / B vertical stripes
		float m = mod(FRAGCOORD.x, 3.0);
		vec3 mask = vec3(m < 1.0 ? 1.0 : 1.0 - mask_strength,
						 (m >= 1.0 && m < 2.0) ? 1.0 : 1.0 - mask_strength,
						 m >= 2.0 ? 1.0 : 1.0 - mask_strength);
		col *= mask;

		// Tracking band is a little brighter and noisier
		col += band * 0.04;

		// Grain and flicker
		float n = hash(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5;
		col += n * (grain + band * 0.08 + glitch * 0.1);
		col *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 120.0));

		// Vignette and rounded corners
		vec2 v = uv - 0.5;
		col *= 1.0 - vignette * smoothstep(0.45, 0.8, length(v));
		col *= brightness;
		float corner = smoothstep(0.0, corner_round, edge.x) * smoothstep(0.0, corner_round, edge.y);
		col *= corner;

		COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
	}
	// The player icon is shown untouched
	if (skip) {
		COLOR = vec4(texture(screen_tex, SCREEN_UV).rgb, 1.0);
	}
}
