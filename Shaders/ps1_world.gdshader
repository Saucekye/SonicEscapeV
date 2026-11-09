// PS1-style surfaces for the Salvage mini game (Scenes/Salvage/salvage.gd).
// Everything is drawn in code from world position, so no textures are needed:
//  - vertex snapping: corners jitter to a coarse screen grid, like the PS1's
//    lack of sub-pixel precision
//  - affine texture warping: patterns bend across big polygons (the classic
//    PS1 "swimming" floors), done by dividing by w per pixel ourselves
//  - lighting: pools of light under the ceiling lamps, a dim glow around you,
//    and everything else falls off into black
shader_type spatial;
render_mode unshaded, cull_back;

// 0 checker floor, 1 concrete wall, 2 ceiling, 3 metal (elevator), 4 flat
// colour (scrap), 5 glowing (lamps, exit sign), 6 hazard stripes
uniform int pattern = 0;
uniform vec4 color_a : source_color = vec4(0.82, 0.78, 0.86, 1.0);
uniform vec4 color_b : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform float tile_size = 1.0;
uniform float level_height = 3.6;     // floor-to-floor height, for the grime band
uniform float snap_res = 160.0;        // vertex grid: lower = wobblier
uniform float player_light = 3.2;      // reach of the faint glow around you (m)
uniform float flash_range = 14.0;      // flashlight reach (m): the dark swallows the rest
uniform float flash_strength = 1.0;
uniform float flash_inner = 0.95;      // cos of the bright centre of the beam
uniform float flash_outer = 0.78;      // cos of the beam's soft edge
uniform vec4 flash_tint : source_color = vec4(0.95, 0.9, 0.78, 1.0);
uniform float flicker = 1.0;           // set from the script each frame
uniform vec3 lamps[48];
uniform int lamp_count = 0;
uniform float lamp_range = 4.6;
uniform float lamp_power[48];         // each lamp's own state: 0 = dead, flickering, or on (salvage.gd)
uniform vec4 lamp_tint : source_color = vec4(0.95, 0.62, 0.38, 1.0);   // dim, sickly sodium

varying vec4 affine;   // world position * w, and w (affine interpolation)
varying vec3 world_true;   // world position, interpolated correctly
uniform float affine_amount = 0.0;   // 0 = no PS1 texture warping, 1 = full warping

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view;
	// Snap to a coarse grid in screen space
	vec2 grid = vec2(snap_res, snap_res * 0.5625);
	clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	POSITION = clip;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	affine = vec4(world * clip.w, clip.w);
	world_true = world;
}

// Checker tiles with pale grout lines, scuffs and pits (like the reference floor)
vec3 checker(vec2 t, vec3 light_col, vec3 dark_col) {
	vec2 cell = floor(t);
	vec2 f = fract(t);
	float c = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(dark_col, light_col, c);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col = mix(col, light_col * 1.08, (1.0 - smoothstep(0.0, 0.02, edge)) * 0.6);
	float n = hash(floor(t * 24.0) + cell * 7.0);
	col *= 0.88 + 0.12 * n;
	if (hash(floor(t * 40.0)) > 0.985) col *= 0.35;   // pits
	return col;
}

vec3 surface(vec3 wp) {
	if (pattern == 0) {
		// Floor: checker on the ground plane
		return checker(wp.xz / tile_size, color_a.rgb, color_b.rgb);
	}
	if (pattern == 1) {
		// Walls: the same checker running up the wall (x + z works for walls facing
		// either way), with grime near the floor
		vec3 col = checker(vec2(wp.x + wp.z, wp.y) / tile_size, color_a.rgb, color_b.rgb);
		col *= mix(0.6, 1.0, smoothstep(0.0, 0.6, mod(wp.y, level_height)));
		return col;
	}
	if (pattern == 2) {
		// Ceiling: checker overhead
		return checker(wp.xz / tile_size, color_a.rgb, color_b.rgb);
	}
	if (pattern == 3) {
		// Brushed metal with rivet rows
		float s = hash(vec2(floor(wp.y * 60.0), floor((wp.x + wp.z) * 3.0)));
		vec3 col = color_a.rgb * (0.8 + 0.25 * s);
		vec2 r = fract(vec2(wp.x + wp.z, wp.y) * 2.5);
		if (length(r - 0.5) < 0.08) col *= 1.4;
		return col;
	}
	if (pattern == 6) {
		float s = step(0.5, fract((wp.x + wp.z + wp.y) * 1.5));
		return mix(color_b.rgb, color_a.rgb, s);
	}
	return color_a.rgb;
}

void fragment() {
	// The floor and ceiling stay straight (warping made the checker bend and kink
	// when you looked down); walls and props keep a little of the PS1 warp
	vec3 wp = mix(world_true, affine.xyz / affine.w, affine_amount);
	vec3 col = surface(wp);
	wp = world_true;   // lighting always uses the true position
	if (pattern == 5) {
		ALBEDO = col * (0.85 + 0.15 * flicker);
	} else {
		vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 fwd = -normalize(INV_VIEW_MATRIX[2].xyz);
		vec3 to_px = wp - cam;
		float d = length(to_px);
		// A faint glow right around you, so your feet aren't lost in the black
		float light = pow(clamp(1.0 - d / player_light, 0.0, 1.0), 2.0) * 0.15;
		vec3 lit = vec3(light);
		// Your flashlight: a soft warm cone straight ahead (It Steals style)
		float cone = smoothstep(flash_outer, flash_inner, dot(to_px / max(d, 0.001), fwd));
		float reach = pow(clamp(1.0 - d / flash_range, 0.0, 1.0), 1.8);
		lit += flash_tint.rgb * cone * reach * flash_strength;
		// Ceiling lamps: warm pools that fall off fast into the dark
		for (int i = 0; i < 48; i++) {
			if (i >= lamp_count) break;
			float ld = length(wp - lamps[i]);
			float k = pow(clamp(1.0 - ld / lamp_range, 0.0, 1.0), 2.0) * 1.35 * lamp_power[i];
			lit += lamp_tint.rgb * k;
		}
		lit += vec3(0.006);   // pure black between the lights
		// Black fog: even lit things fade out with distance
		lit *= exp(-d * 0.02);
		ALBEDO = col * lit;
	}
}
