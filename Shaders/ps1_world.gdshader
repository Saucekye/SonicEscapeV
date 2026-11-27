// PS1-style surfaces for the Salvage mini game
shader_type spatial;
render_mode unshaded, cull_back;

// 0 checker floor, 1 concrete wall, 2 ceiling, 3 metal
uniform int pattern = 0;
uniform vec4 color_a : source_color = vec4(0.82, 0.78, 0.86, 1.0);
uniform vec4 color_b : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform float tile_size = 1.0;
uniform float level_height = 3.6;     // floor-to-floor height, for the grime band
uniform float snap_res = 160.0;        // vertex grid: lower = wobblier
uniform float player_light = 3.2;      // reach of the faint glow around you
uniform float player_glow = 0.15;      // how bright that glow is
uniform float view_drop = 0.0;         // top-down view
uniform vec4 fog_zones[8];             // foggy areas: x, z, radius, thickness
uniform int fog_zone_count = 0;
uniform vec4 fog_tint : source_color = vec4(0.2, 0.21, 0.23, 1.0);
uniform float flash_range = 14.0;      // flashlight reach
uniform float flash_strength = 1.0;
uniform float flash_inner = 0.95;      // cos of the bright centre of the beam
uniform float flash_outer = 0.78;      // cos of the beam's soft edge
uniform vec4 flash_tint : source_color = vec4(0.95, 0.9, 0.78, 1.0);
uniform float flicker = 1.0;           // set from the script each frame
uniform vec3 lamps[48];
uniform int lamp_count = 0;
uniform float lamp_range = 4.6;
uniform float lamp_power[48];         // each lamp's own state
uniform vec4 lamp_tint : source_color = vec4(0.95, 0.62, 0.38, 1.0);   // dim, sickly sodium

varying vec4 affine;   // world position * w, and w
varying vec3 world_true;   // world position, interpolated correctly
uniform vec3 alarm_light = vec3(0.0);  // the alarm
uniform float dark_falloff = 0.02;   // how fast even lit things fade into the dark with distance
uniform bool plain = true;           // flat colours: no scuffs, pits, grout lines, grime or brushed metal
uniform float affine_amount = 0.0;   // 0 = no PS1 texture warping, 1 = full warping
uniform float close_calm = 6.0;      // nearer than this

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view;
	// Snap to a coarse grid in screen space
	vec2 grid = vec2(snap_res, snap_res * 0.5625);
	vec2 snapped = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	clip.xy = mix(clip.xy, snapped, smoothstep(close_calm * 0.15, close_calm, clip.w));
	POSITION = clip;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	affine = vec4(world * clip.w, clip.w);
	world_true = world;
}

// Checker tiles with pale grout lines, scuffs and pits
vec3 checker(vec2 t, vec3 light_col, vec3 dark_col) {
	vec2 cell = floor(t);
	vec2 f = fract(t);
	float c = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(dark_col, light_col, c);
	if (plain) return col;
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
		// Walls: the same checker running up the wall
		vec3 col = checker(vec2(wp.x + wp.z, wp.y) / tile_size, color_a.rgb, color_b.rgb);
		if (!plain) col *= mix(0.6, 1.0, smoothstep(0.0, 0.6, mod(wp.y, level_height)));
		return col;
	}
	if (pattern == 2) {
		// Ceiling: checker overhead
		return checker(wp.xz / tile_size, color_a.rgb, color_b.rgb);
	}
	if (pattern == 3) {
		// Brushed metal with rivet rows
		if (plain) return color_a.rgb;
		float s = hash(vec2(floor(wp.y * 60.0), floor((wp.x + wp.z) * 3.0)));
		vec3 col = color_a.rgb * (0.8 + 0.25 * s);
		vec2 r = fract(vec2(wp.x + wp.z, wp.y) * 2.5);
		if (length(r - 0.5) < 0.08) col *= 1.4;
		return col;
	}
	if (pattern == 7) {
		// Rusted metal grate
		float d1 = abs(fract((wp.x + wp.z) * 3.2) - 0.5);
		float d2 = abs(fract((wp.x - wp.z) * 3.2) - 0.5);
		float mesh = step(0.4, max(d1, d2));
		vec2 beam = abs(fract(wp.xz / 1.5) - 0.5);
		mesh = max(mesh, step(0.46, max(beam.x, beam.y)));
		float rust = 0.6 + 0.4 * hash(floor(wp.xz * 9.0));
		vec3 bar = color_a.rgb * rust;
		return mix(color_b.rgb, bar, mesh);   // the holes: just dark, all the way down
	}
	if (pattern == 6) {
		float s = step(0.5, fract((wp.x + wp.z + wp.y) * 1.5));
		return mix(color_b.rgb, color_a.rgb, s);
	}
	return color_a.rgb;
}

void fragment() {
	// The floor and ceiling stay straight
	float far_enough = smoothstep(close_calm * 0.25, close_calm, -VERTEX.z);
	vec3 wp = mix(world_true, affine.xyz / affine.w, affine_amount * far_enough);
	vec3 col = surface(wp);
	wp = world_true;   // lighting always uses the true position
	if (pattern == 5) {
		ALBEDO = col * (0.85 + 0.15 * flicker);
	} else {
		vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz - vec3(0.0, view_drop, 0.0);
		vec3 fwd = -normalize(INV_VIEW_MATRIX[2].xyz);
		vec3 to_px = wp - cam;
		float d = length(to_px);
		// A faint glow right around you
		float light = pow(clamp(1.0 - d / player_light, 0.0, 1.0), 2.0) * player_glow;
		vec3 lit = vec3(light);
		// Your flashlight
		float cone = smoothstep(flash_outer, flash_inner, dot(to_px / max(d, 0.001), fwd));
		float reach = pow(clamp(1.0 - d / flash_range, 0.0, 1.0), 1.8);
		lit += flash_tint.rgb * cone * reach * flash_strength;
		// Ceiling lamps
		for (int i = 0; i < 48; i++) {
			if (i >= lamp_count) break;
			float ld = length(wp - lamps[i]);
			float k = pow(clamp(1.0 - ld / lamp_range, 0.0, 1.0), 2.0) * 1.35 * lamp_power[i];
			lit += lamp_tint.rgb * k;
		}
		lit += vec3(0.006);   // pure black between the lights
		lit += alarm_light;   // the alarm: everything bathed in red
		// Black fog: even lit things fade out with distance
		float fade = exp(-d * dark_falloff);
		lit *= fade;
		ALBEDO = col * lit + alarm_light * 0.3 * fade;   // even the black tiles glow a dark red
		// Foggy areas, seen from outside
		float fz = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= fog_zone_count) break;
			vec4 z = fog_zones[i];
			float in_px = 1.0 - smoothstep(z.z - 2.0, z.z, length(wp.xz - z.xy));
			float cam_in = 1.0 - smoothstep(z.z - 1.0, z.z + 1.0, length(cam.xz - z.xy));
			fz = max(fz, in_px * (1.0 - cam_in) * z.w);
		}
		ALBEDO = mix(ALBEDO, fog_tint.rgb, fz * 0.9);
	}
}
