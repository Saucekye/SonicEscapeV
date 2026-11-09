extends Node3D
## A real mirror: shows the room and you in it, from wherever you stand.
## Place it in the editor with its front (+Z) facing out of the wall; set its size,
## resolution and tint in the Inspector. salvage.gd sets it up for each local player.
##
## How: for each local player a camera sits at their camera's reflection behind the
## mirror, looking out through it, with a frustum fitted exactly to the mirror's
## edges. What it sees goes on the glass, flipped left to right. Each player's glass
## is only seen by that player's camera (render layers 19 and 20), and it only draws
## while that player is close by. You see yourself through a copy of your character
## (layers 17 and 18) that only your reflection camera sees.

@export var size := Vector2(1.5, 2.0)              ## the glass, in metres (width, height)
@export var resolution := 220                       ## pixels across the reflection (it's scaled up, PS1 style)
@export var tint := Color(0.95, 0.97, 1.0)          ## the glass's colour over the reflection
@export var draw_distance := 9.0                    ## a player further away than this doesn't draw it
@export var frame_material: Material                ## the frame around the glass (empty = no frame)
@export var frame_width := 0.06

const BODY_LAYER_BIT := 16    # + player index: your copy, seen only by your reflection
const GLASS_LAYER_BIT := 18   # + player index: your glass, seen only by your camera

var game: Node3D
var views: Array = []         # per local player: {player, viewport, camera, glass, body}


## Bits to leave out of every player camera, and the one to add back for player i
static func camera_mask(base_mask: int, i: int) -> int:
	var mask := base_mask & ~(0xF << BODY_LAYER_BIT)
	return mask | (1 << (GLASS_LAYER_BIT + i))


func _ready() -> void:
	add_to_group("salvage_mirror")
	if frame_material:
		_build_frame()


func setup(game_node: Node3D, players: Array) -> void:
	game = game_node
	for i in players.size():
		var p = players[i]
		var vp := SubViewport.new()
		vp.size = Vector2i(resolution, maxi(roundi(resolution * size.y / size.x), 1))
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.world_3d = get_viewport().world_3d
		add_child(vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_FRUSTUM
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		# What your own camera sees, plus your copy, minus every player's glass
		cam.cull_mask = (p.cam.cull_mask & ~(0xF << BODY_LAYER_BIT)) | (1 << (BODY_LAYER_BIT + i))
		cam.far = 40.0
		vp.add_child(cam)
		cam.current = true
		# The glass this player sees
		var glass := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = size
		glass.mesh = quad
		glass.layers = 1 << (GLASS_LAYER_BIT + i)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = vp.get_texture()
		m.albedo_color = tint
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_scale = Vector3(-1, 1, 1)   # a mirror flips left and right
		m.uv1_offset = Vector3(1, 0, 0)
		glass.material_override = m
		add_child(glass)
		# Your copy, for the reflection to see
		var body = game._make_sprite(p.character, 1 << (BODY_LAYER_BIT + i))
		views.append({"player": p, "viewport": vp, "camera": cam, "glass": glass, "body": body})


func _process(delta: float) -> void:
	if views.is_empty():
		return
	var n := global_transform.basis.z.normalized()     # out of the glass
	var r := global_transform.basis.x.normalized()
	var u := global_transform.basis.y.normalized()
	var c := global_transform.origin
	for v in views:
		var p = v.player
		var vp: SubViewport = v.viewport
		var pcam: Camera3D = p.cam
		if v.body:
			v.body.visible = not p.escaped
			v.body.drive(p.global_position, v.camera, game._light_at(p.global_position + Vector3(0, 0.6, 0)), delta, p.anim_state())
		var eye := pcam.global_position
		var dist := (eye - c).dot(n)
		# Only while you're in front of it and close
		if dist <= 0.05 or eye.distance_to(c) > draw_distance or p.escaped:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var cam: Camera3D = v.camera
		# Your eye's reflection behind the glass, looking out through it
		var mirrored := eye - 2.0 * dist * n
		cam.global_transform = Transform3D(Basis(-r, u, -n), mirrored)
		# A frustum whose near plane is exactly the glass
		var to_c := c - mirrored
		var offset := Vector2(to_c.dot(-r), to_c.dot(u))
		cam.set_frustum(size.y, offset, maxf(dist, 0.05), 40.0)


func _build_frame() -> void:
	var w := frame_width
	var parts := [
		[Vector3(0, size.y * 0.5 + w * 0.5, 0), Vector3(size.x + w * 2.0, w, 0.04)],
		[Vector3(0, -size.y * 0.5 - w * 0.5, 0), Vector3(size.x + w * 2.0, w, 0.04)],
		[Vector3(-size.x * 0.5 - w * 0.5, 0, 0), Vector3(w, size.y, 0.04)],
		[Vector3(size.x * 0.5 + w * 0.5, 0, 0), Vector3(w, size.y, 0.04)],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[1]
		mi.mesh = box
		mi.position = part[0] + Vector3(0, 0, -0.01)
		mi.material_override = frame_material
		add_child(mi)
