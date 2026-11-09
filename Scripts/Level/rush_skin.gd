extends RefCounted
## Dresses the silhouette terrain with Sonic Rush tiles.
##  - The fill colour becomes a Rush fill texture (terrain_skin.gdshader).
##  - Every upward-facing surface (flat ground and slopes) gets a Rush surface
##    strip (grass, crystals, rails, plating...) laid along it with a Line2D,
##    worked out from the tiles' own collision shapes, so no level needs editing.
## Called from map.gd for every TileMapLayer. Art credit: SEGA and Dimps
## (see Sprites/Tileset/RushAdventure/CREDITS.txt).

const SKIN_SHADER := preload("res://Shaders/terrain_skin.gdshader")
const ART := "res://Sprites/Tileset/RushAdventure/"
const TEXEL_WORLD := 1.125   # world units per art pixel, same as the characters
const STEEPEST_SURFACE := 0.12 # surfaces steeper than ~83 degrees (walls) get no strip;
                               # curves get it nearly all the way up
const JOIN_GAP := 8.0          # tile units: pieces whose ends are this close join into one strip,
                               # if they carry on in roughly the same direction (stairs stay apart)
const JOIN_MAX_TURN := 50.0    # degrees: how sharply a join may change direction
const OPEN_PROBES := [3.0, 8.0]   # tile units out from a surface that must be open air too, going
                               # by the tiles' pictures (an edge facing into ground that's drawn
                               # solid, like a collision wedge inside a fill tile, gets no strip)
const MIN_POINT_GAP := 2.0     # tile units: closer points are merged before smoothing
const SMOOTHING := 2           # rounds of corner smoothing (0 = follow the tiles exactly)
const MIN_STRIP_LENGTH := 6.0  # tile units: shorter leftover bits get no strip
const OVERHANG := 2.0         # art pixels the strip sits above the true surface
const DEPTH_COPY := false   # the darker "thickness" copy behind the terrain
const SHADE_DEPTH := 56.0     # art pixels of darkening under each ledge
const SHADE_STRENGTH := 0.55  # how dark it starts (0 = off)

## Background id (Background.gd) -> zone art and the tileset colours to replace.
## fill_key / edge_key must match the colours of the tileset texture map.gd uses
## for that stage.
## Stage 6 (the teal tech stage used by the boss arenas) is left out and keeps
## its original tileset.
const STAGES := {
	1: {"zone": "neon_tech", "fill_key": Color8(0, 0, 0), "edge_key": Color8(0, 155, 255), "edge": Color8(110, 50, 140)},
	2: {"zone": "brick_ruins", "fill_key": Color8(1, 18, 28), "edge_key": Color8(148, 144, 118), "edge": Color8(90, 50, 30)},
	4: {"zone": "roof_town", "fill_key": Color8(1, 18, 28), "edge_key": Color8(148, 144, 118), "edge": Color8(80, 50, 35)},
	5: {"zone": "industrial", "fill_key": Color8(0, 0, 0), "edge_key": Color8(255, 0, 0), "edge": Color8(60, 55, 50)},
}


static func apply(layer: TileMapLayer, background_id: int, with_surfaces: bool = true) -> void:
	if not Test.rush_terrain or not STAGES.has(background_id):
		return
	var stage: Dictionary = STAGES[background_id]
	var fill: Texture2D = load(ART + stage.zone + "_fill.png")
	var strip: Texture2D = load(ART + stage.zone + "_surface.png")
	if fill == null or strip == null:
		return
	# 1. Fill + edge recolour
	if layer.material == null:
		var m := ShaderMaterial.new()
		m.shader = SKIN_SHADER
		m.set_shader_parameter("fill_tex", fill)
		m.set_shader_parameter("fill_key", stage.fill_key)
		m.set_shader_parameter("edge_key", stage.edge_key)
		m.set_shader_parameter("edge_color", stage.edge)
		m.set_shader_parameter("texel_world", TEXEL_WORLD)
		m.set_shader_parameter("fill_size", float(fill.get_height()))
		m.set_shader_parameter("fill_count", float(fill.get_width()) / float(fill.get_height()))
		layer.material = m
	# 2. Surface strips (skipped for loops, whose overlapping front/back layers would double up)
	if with_surfaces:
		_build_surfaces(layer, strip)
		# 3. Terrain thickness: a darker copy further back, in perspective (terrain_depth.gd).
		# Turned off: the shaded copy showed beside walls and ledges. Set DEPTH_COPY to bring it back.
		if not DEPTH_COPY:
			return
		var back_mat := (layer.material as ShaderMaterial).duplicate() as ShaderMaterial
		back_mat.set_shader_parameter("fill_darken", 0.42)
		back_mat.set_shader_parameter("fill_all", true)
		preload("res://Scripts/Level/terrain_depth.gd").make(layer, back_mat, stage.get("depth_tint", Color(0.8, 0.82, 0.95)))


static func _build_surfaces(layer: TileMapLayer, strip: Texture2D) -> void:
	if layer.has_node("RushSurfaces"):
		return
	# Collision polygons of every cell, in the layer's local space
	var polys := {}   # Vector2i -> Array[PackedVector2Array]
	for cell in layer.get_used_cells():
		var td := layer.get_cell_tile_data(cell)
		if td == null or layer.tile_set.get_physics_layers_count() == 0:
			continue
		var list: Array = []
		var origin := layer.map_to_local(cell)
		for i in td.get_collision_polygons_count(0):
			var pts := td.get_collision_polygon_points(0, i)
			var out := PackedVector2Array()
			for p in pts:
				out.append(origin + p)
			if out.size() >= 3:
				list.append(out)
		if not list.is_empty():
			polys[cell] = list

	# Upward-facing edges that nothing sits on top of
	var segments: Array = []
	for cell in polys:
		for poly in polys[cell]:
			for i in poly.size():
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % poly.size()]
				if a.distance_to(b) < 0.01:
					continue
				var mid := (a + b) * 0.5
				var n := (b - a).orthogonal().normalized()
				if Geometry2D.is_point_in_polygon(mid + n * 0.25, poly):
					n = -n   # make the normal point out of the solid
				if n.y > -STEEPEST_SURFACE:
					continue   # not facing up enough
				if _covered(layer, polys, mid + n * 0.5, cell):
					continue   # another tile sits on this edge
				var buried := false
				for d in OPEN_PROBES:
					if _drawn_solid(layer, mid + n * d):
						buried = true
						break
				if buried:
					continue   # it faces a little gap inside the ground, not the open air
				segments.append([a, b] if a.x <= b.x else [b, a])

	if segments.is_empty():
		return
	# Join touching segments into continuous runs, left to right
	var chains := _chain(segments)
	chains = _join_close(chains)

	var holder := Node2D.new()
	holder.name = "RushSurfaces"
	layer.add_child(holder)
	var texel_local := TEXEL_WORLD / layer.scale.y
	var width: float = strip.get_height() * texel_local
	for raw_chain in chains:
		if raw_chain.size() < 2:
			continue
		var chain := _smooth(raw_chain)
		if _length(chain) < MIN_STRIP_LENGTH:
			continue
		var line := Line2D.new()
		line.texture = strip
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		line.width = width
		line.joint_mode = Line2D.LINE_JOINT_SHARP
		line.sharp_limit = 4.0
		# Push the strip down so its top edge sits on the surface
		var pts := PackedVector2Array()
		for i in chain.size():
			var prev: Vector2 = chain[max(i - 1, 0)]
			var next: Vector2 = chain[min(i + 1, chain.size() - 1)]
			var up := _outward(prev, next)
			pts.append(chain[i] - up * (width * 0.5 - OVERHANG * texel_local))
		line.points = pts
		# Ledge shading: the ground darkens just under the surface, like official
		# stages, instead of one flat brightness all the way down
		var shade := Line2D.new()
		shade.texture = _shade_texture()
		shade.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		shade.width = SHADE_DEPTH * texel_local
		shade.joint_mode = Line2D.LINE_JOINT_BEVEL   # (sharp joints spike out at corners; round ones streak)
		# How deep the band goes at each point (0..1 of SHADE_DEPTH): less on steep parts,
		# over peaks and wherever the ground underneath runs out
		var depth := _shade_factors(pts, shade.width, width * 0.5 - 2.0 * texel_local, layer)
		var shade_pts := PackedVector2Array()
		for i in pts.size():
			var prev: Vector2 = pts[max(i - 1, 0)]
			var next: Vector2 = pts[min(i + 1, pts.size() - 1)]
			var down := -_outward(prev, next)
			# hangs from the strip's underside, so a shallower band stays against it
			shade_pts.append(pts[i] + down * (width * 0.5 - 2.0 * texel_local + shade.width * depth[i] * 0.5))
		shade.points = shade_pts
		shade.width_curve = _curve_along(pts, depth)
		holder.add_child(shade)
		holder.add_child(line)


static func _covered(layer: TileMapLayer, polys: Dictionary, p: Vector2, own_cell: Vector2i) -> bool:
	var cell := layer.local_to_map(p)
	# A neighbouring tile with no collision shape (decorative fill) still counts as solid
	if cell != own_cell and layer.get_cell_source_id(cell) != -1 and not polys.has(cell):
		return true
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var c: Vector2i = cell + Vector2i(dx, dy)
			if polys.has(c):
				for poly in polys[c]:
					if Geometry2D.is_point_in_polygon(p, poly):
						return true
	return false


static func _key(v: Vector2) -> Vector2i:
	return Vector2i(roundi(v.x * 10.0), roundi(v.y * 10.0))


static func _chain(segments: Array) -> Array:
	# Link segments end-to-start into polylines
	var by_start := {}
	var has_incoming := {}
	for s in segments:
		var k := _key(s[0])
		if not by_start.has(k):
			by_start[k] = []
		by_start[k].append(s)
		has_incoming[_key(s[1])] = true
	var used := {}
	var chains: Array = []
	# Start from segments nothing flows into, then sweep up any loops left over
	var order: Array = []
	for s in segments:
		if not has_incoming.has(_key(s[0])):
			order.append(s)
	for s in segments:
		order.append(s)
	for s in order:
		if used.has(s):
			continue
		var chain: Array = [s[0], s[1]]
		used[s] = true
		var cur = s
		while true:
			var nexts: Array = by_start.get(_key(cur[1]), [])
			var found = null
			for cand in nexts:
				if not used.has(cand):
					found = cand
					break
			if found == null:
				break
			used[found] = true
			chain.append(found[1])
			cur = found
		chains.append(chain)
	return chains


## Joins chains whose end is within JOIN_GAP of another chain's start (the tiles
## of a curve don't always meet exactly), so a curve gets one unbroken strip
static func _join_close(chains: Array) -> Array:
	var out: Array = chains.duplicate()
	var merged := true
	while merged:
		merged = false
		for i in out.size():
			var a: Array = out[i]
			var best := -1
			var best_d := JOIN_GAP
			for j in out.size():
				if j == i:
					continue
				var d: float = (a[a.size() - 1] as Vector2).distance_to(out[j][0])
				if d <= best_d and (d < 0.01 or _continues(a, out[j])):
					best_d = d
					best = j
			if best >= 0:
				var b: Array = out[best]
				var joined: Array = a.duplicate()
				joined.append_array(b.slice(1) if best_d < 0.01 else b)
				out[i] = joined
				out.remove_at(best)
				merged = true
				break
	return out


## Does chain b carry on from where chain a ends, in about the same direction?
static func _continues(a: Array, b: Array) -> bool:
	if a.size() < 2 or b.size() < 2:
		return true
	var dir_a := ((a[a.size() - 1] as Vector2) - (a[a.size() - 2] as Vector2)).normalized()
	var dir_b := ((b[1] as Vector2) - (b[0] as Vector2)).normalized()
	var gap := (b[0] as Vector2) - (a[a.size() - 1] as Vector2)
	if gap.length() > 0.01 and gap.normalized().dot(dir_a) < -0.2:
		return false   # b starts behind a's end (overlapping layers), not after it
	return rad_to_deg(absf(dir_a.angle_to(dir_b))) <= JOIN_MAX_TURN


## Drops near-duplicate points, then rounds the corners (Chaikin), keeping both
## ends in place. The tiles' collision edges zig-zag slightly; this lets the strip
## bend smoothly instead of kinking at every tile.
static func _smooth(chain: Array) -> Array:
	var pts: Array = [chain[0]]
	for i in range(1, chain.size()):
		var p: Vector2 = chain[i]
		if p.distance_to(pts[pts.size() - 1]) >= MIN_POINT_GAP or i == chain.size() - 1:
			pts.append(p)
	if pts.size() > 2 and (pts[pts.size() - 1] as Vector2).distance_to(pts[pts.size() - 2]) < MIN_POINT_GAP:
		pts.remove_at(pts.size() - 2)
	for _round in SMOOTHING:
		if pts.size() < 3:
			break
		var next: Array = [pts[0]]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		next.append(pts[pts.size() - 1])
		pts = next
	return pts


## The side of the surface that faces out of the ground. Strips run left to right
## with the ground underneath, so it's the left-hand normal; unlike "whichever
## normal points up", it stays on the correct side on near-vertical curves.
static func _outward(prev: Vector2, next: Vector2) -> Vector2:
	var d := (next - prev).normalized()
	return Vector2(d.y, -d.x)


## 1 where the surface is flat, 0 where it's vertical, along the strip's length
## How deep the ledge shading goes at each point of a strip, 0..1 of its full depth.
## It's for under ledges, so it thins out as the surface gets steep (gone by ~84
## degrees); over a peak it's kept no deeper than the bend is round (or it folds over
## itself into a dark wedge); and it stops where the drawn ground underneath ends
## (a cliff edge, a thin wall), so it never pokes out into the air.
static func _shade_factors(pts: PackedVector2Array, shade_width: float, below_strip: float, layer: TileMapLayer) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(pts.size())
	for i in pts.size():
		var up := _outward(pts[max(i - 1, 0)], pts[min(i + 1, pts.size() - 1)])
		var f := clampf((-up.y - 0.5) / 0.4, 0.0, 1.0)
		f = minf(f, _bend_room(pts, i) / shade_width)
		f = minf(f, _ground_depth(layer, pts[i] - up * below_strip, -up, shade_width) / shade_width)
		out[i] = f
	# Fade in and out at the strip's ends (a band starting at full depth right at a
	# corner reads as a dark block)
	var total := 0.0
	var along := PackedFloat32Array()
	along.resize(pts.size())
	for i in pts.size():
		if i > 0:
			total += pts[i - 1].distance_to(pts[i])
		along[i] = total
	var fade := shade_width * 0.9
	for i in pts.size():
		var from_end := minf(along[i], total - along[i])
		out[i] = minf(out[i], smoothstep(0.0, fade, from_end))
	# Ease the changes, so the band changes depth gradually (sudden jumps make it
	# zig-zag and overlap itself in dark streaks); never deeper than allowed
	var eased := out.duplicate()
	for _pass in 6:
		var prev := eased.duplicate()
		for i in range(1, pts.size() - 1):
			eased[i] = minf(out[i] + 0.15, (prev[i - 1] + prev[i] * 2.0 + prev[i + 1]) * 0.25)
		eased[0] = minf(eased[0], out[0])
		eased[pts.size() - 1] = minf(eased[pts.size() - 1], out[pts.size() - 1])
	for i in pts.size():
		eased[i] = minf(eased[i], out[i] + 0.15)
	return eased


## A width curve for a Line2D: values at each point, spread by distance along it
static func _curve_along(pts: PackedVector2Array, values: PackedFloat32Array) -> Curve:
	var c := Curve.new()
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	if total <= 0.0:
		c.add_point(Vector2(0, values[0] if values.size() > 0 else 1.0))
		c.add_point(Vector2(1, values[0] if values.size() > 0 else 1.0))
		return c
	var run := 0.0
	for i in pts.size():
		if i > 0:
			run += pts[i - 1].distance_to(pts[i])
		c.add_point(Vector2(run / total, values[i]))
	return c


## How deep the shading can go at point i before it folds over: the radius of the
## surface's bend there, looked at over a short stretch either side (convex bends
## only; a dip has all the room it needs)
static func _bend_room(pts: PackedVector2Array, i: int) -> float:
	const SPAN := 5
	var a := pts[max(i - SPAN, 0)]
	var b := pts[i]
	var c := pts[min(i + SPAN, pts.size() - 1)]
	var d1 := b - a
	var d2 := c - b
	if d1.length() < 0.01 or d2.length() < 0.01:
		return INF
	var turn := d1.angle_to(d2)   # (y points down on screen) positive = bending downward: a peak
	if turn <= 0.05:
		return INF
	return (d1.length() + d2.length()) * 0.5 / absf(turn) * 0.45


## Is there ground drawn at this point? Goes by the tile's own picture (its alpha),
## not its collision shape, which can be a rough wedge inside a solid-looking tile
static var _atlas_images := {}
static func _drawn_solid(layer: TileMapLayer, p: Vector2) -> bool:
	var cell := layer.local_to_map(p)
	var src_id := layer.get_cell_source_id(cell)
	if src_id == -1:
		return false
	var src := layer.tile_set.get_source(src_id) as TileSetAtlasSource
	if src == null or src.texture == null:
		return true
	var img: Image = _atlas_images.get(src.texture)
	if img == null:
		img = src.texture.get_image()
		if img == null:
			return true
		if img.is_compressed():
			img.decompress()
		_atlas_images[src.texture] = img
	var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
	var ts := Vector2(layer.tile_set.tile_size)
	var local := p - (layer.map_to_local(cell) - ts * 0.5)          # 0..tile size inside the cell
	var alt := layer.get_cell_alternative_tile(cell)
	if alt & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
		local = Vector2(local.y, local.x)
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_H:
		local.x = ts.x - local.x
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_V:
		local.y = ts.y - local.y
	var px := Vector2i(region.position) + Vector2i((local / ts * Vector2(region.size)).floor())
	px = px.clamp(Vector2i(region.position), Vector2i(region.position + region.size) - Vector2i.ONE)
	return img.get_pixelv(px).a > 0.5


## How far down into drawn ground you can go from a surface point (up to max_depth)
static func _ground_depth(layer: TileMapLayer, p: Vector2, inward: Vector2, max_depth: float) -> float:
	const STEPS := 8
	for k in range(1, STEPS + 1):
		var d := max_depth * float(k) / STEPS
		if not _drawn_solid(layer, p + inward * d):
			return max_depth * float(k - 1) / STEPS
	return max_depth


static func _length(chain: Array) -> float:
	var total := 0.0
	for i in chain.size() - 1:
		total += (chain[i] as Vector2).distance_to(chain[i + 1])
	return total


static var _shade_tex: Texture2D

static func _shade_texture() -> Texture2D:
	# 1 x N vertical fade: dark under the ledge, clear further down.
	# Stepped in 4 bands so it stays pixel-art crisp rather than a smooth gradient.
	if _shade_tex:
		return _shade_tex
	var img := Image.create(1, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		var band := float(int(y / 4)) / 4.0
		img.set_pixel(0, y, Color(0.05, 0.03, 0.08, SHADE_STRENGTH * (1.0 - band)))
	_shade_tex = ImageTexture.create_from_image(img)
	return _shade_tex
