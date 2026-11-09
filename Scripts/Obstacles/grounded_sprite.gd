extends RefCounted
## Keeps a pickup character's feet on the ground (Miku, OCs). Their sprite
## sheets have different amounts of empty space under the feet, so the drawn
## feet sat below the collision box and looked sunk into the ground. Each frame
## this finds the lowest solid pixel of the current animation frame and shifts
## the sprite (Sprite2D.offset, which no animation touches) so that row sits on
## the bottom of the collision box, like the playable characters.
## Not while carried (the riding pose is unchanged) or tumbling after a throw.
## Called every physics frame from miku.gd and ocs.gd.

static var _bottoms := {}
static var SNAP: bool = ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)   # texture path + frames -> lowest solid row per frame


static func update(body: Node2D, sprite: Sprite2D, shape: CollisionShape2D, held: bool) -> void:
	if sprite == null or sprite.texture == null or shape == null or not (shape.shape is RectangleShape2D):
		return
	var target := 0.0
	if not held and absf(wrapf(body.rotation, -PI, PI)) < 0.05:
		var rows := _rows(sprite)
		if sprite.frame < rows.size() and rows[sprite.frame] >= 0:
			var fh := float(sprite.texture.get_height()) / sprite.vframes
			# Feet, in the sprite's own pixels, measured from its centre
			var feet := float(rows[sprite.frame] + 1) - (fh * 0.5 if sprite.centered else 0.0)
			var ground := shape.position.y + (shape.shape as RectangleShape2D).size.y * 0.5   # body space
			var sy := sprite.scale.y
			# With "Snap 2D Transforms to Pixel" on, Godot draws each node at its local
			# position rounded to whole units. These scenes are built tiny and scaled up
			# 125x, so the animations' small sprite positions (like -0.08) round to 0 when
			# drawn. Use the position as it's actually drawn.
			var py := sprite.position.y
			if SNAP:
				py = roundf(py)
			if absf(sy) > 0.0:
				target = (ground - py) / sy - feet
	# Ease in, so landing upright doesn't snap the sprite
	sprite.offset.y = move_toward(sprite.offset.y, target, maxf(2.0, absf(target - sprite.offset.y) * 0.35))


static func _rows(sprite: Sprite2D) -> Array:
	var tex := sprite.texture
	var key := "%s|%d|%d" % [tex.resource_path if tex.resource_path != "" else str(tex.get_rid()), sprite.hframes, sprite.vframes]
	if _bottoms.has(key):
		return _bottoms[key]
	var rows := []
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var fw := img.get_width() / sprite.hframes
		var fh := img.get_height() / sprite.vframes
		for f in sprite.hframes * sprite.vframes:
			var fx := (f % sprite.hframes) * fw
			var fy := (f / sprite.hframes) * fh
			var used := img.get_region(Rect2i(fx, fy, fw, fh)).get_used_rect()
			rows.append(used.end.y - 1 if used.size.y > 0 else -1)
	_bottoms[key] = rows
	return rows
