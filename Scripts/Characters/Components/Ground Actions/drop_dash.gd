extends Components_Action

func action() -> void:
# ── Drop Dash Release ──────────────────────────────────────────
	if player.is_drop_dashing and player.drop_dash_charge >=  player.drop_dash_charge_time:
		if Input.is_action_pressed("ui_accept"):
			player.execute_drop_dash()
		else:
			# Button was released before landing — cancel the drop dash
			player.is_drop_dashing = false
			player.drop_dash_charge = 0.0
