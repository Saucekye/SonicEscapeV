## Builds the basic Salvage corridor chunks (used once to make the chunk scenes in
## this folder, and by salvage.gd if no chunk fits a spot). Plain boxes in the
## facility's materials, laid out by the rules in salvage_chunk.gd.

const CELL := 4.0
const WALL_H := 3.2
const STEP := 1.6
const T := 0.15

static var _mats := {}


static func mat(key: String) -> Material:
	if not _mats.has(key):
		_mats[key] = load("res://Scenes/Salvage/Materials/%s.tres" % key)
	return _mats[key]


## A chunk with these open sides (north, south, east, west), or a staircase
static func build(n: bool, s: bool, e: bool, w: bool, stairs := false) -> Node3D:
	var root := Node3D.new()
	root.set_script(load("res://Scenes/Salvage/Chunks/salvage_chunk.gd"))
	root.open_north = n
	root.open_south = s
	root.open_east = e
	root.open_west = w
	root.stairs = stairs
	var body := StaticBody3D.new()
	body.name = "Collision"
	root.add_child(body)
	var h := CELL * 0.5
	var top := WALL_H + (STEP if stairs else 0.0)
	# Floor (or the stairs)
	if stairs:
		var steps := 8
		for i in steps:
			var z0 := -h + CELL * i / steps
			var z1 := -h + CELL * (i + 1) / steps
			_box(root, null, "Step%d" % (i + 1), Vector3(-h, -0.3, z0), Vector3(h, STEP * (i + 1) / steps, z1), "stairs")
		# The ramp you actually walk on, under the steps
		var length := sqrt(CELL * CELL + STEP * STEP)
		var ramp := CollisionShape3D.new()
		ramp.name = "Ramp"
		var bs := BoxShape3D.new()
		bs.size = Vector3(CELL, 0.2, length)
		ramp.shape = bs
		ramp.position = Vector3(0, STEP * 0.5 - 0.1, 0)
		ramp.rotation.x = -atan2(STEP, CELL)
		body.add_child(ramp)
		# Above the bottom doorway, up to the higher ceiling
		_box(root, body, "Header", Vector3(-h - T, WALL_H, -h - T), Vector3(h + T, top + 0.2, -h + T), "wall")
	else:
		_box(root, body, "Floor", Vector3(-h, -0.3, -h), Vector3(h, 0, h), "floor")
	_box(root, body, "Ceiling", Vector3(-h, top, -h), Vector3(h, top + 0.2, h), "ceiling")
	# Walls on the closed sides, posts in the corners
	if not n: _box(root, body, "WallNorth", Vector3(-h - T, -0.3, -h - T), Vector3(h + T, top, -h + T), "wall")
	if not s: _box(root, body, "WallSouth", Vector3(-h - T, -0.3, h - T), Vector3(h + T, top, h + T), "wall")
	if not e: _box(root, body, "WallEast", Vector3(h - T, -0.3, -h - T), Vector3(h + T, top, h + T), "wall")
	if not w: _box(root, body, "WallWest", Vector3(-h - T, -0.3, -h - T), Vector3(-h + T, top, h + T), "wall")
	var k := 1
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, body, "Post%d" % k, Vector3(sx * h - T, -0.3, sz * h - T), Vector3(sx * h + T, top, sz * h + T), "wall")
			k += 1
	var lamp := Marker3D.new()
	lamp.name = "LampSpot"
	lamp.position = Vector3(0, top, 0)
	lamp.add_to_group("lamp_spot", true)
	root.add_child(lamp)
	return root


static func _box(root: Node3D, body: Node, n: String, a: Vector3, b: Vector3, m: String) -> void:
	var size := (b - a).abs()
	var center := (a + b) * 0.5
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	bm.subdivide_width = int(clamp(size.x / 2.0, 0, 8))
	bm.subdivide_depth = int(clamp(size.z / 2.0, 0, 8))
	bm.subdivide_height = int(clamp(size.y / 2.0, 0, 4))
	mi.mesh = bm
	mi.material_override = mat(m)
	mi.position = center
	root.add_child(mi)
	if body:
		var cs := CollisionShape3D.new()
		cs.name = n + "Shape"
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = center
		body.add_child(cs)
