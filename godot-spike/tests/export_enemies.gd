extends SceneTree
## dumps the enemy roster as JSON for tools/export_enemies.py:  godot --headless -s tests/export_enemies.gd -- /tmp/roster.json
const ENM = preload("res://src/enemies.gd")
func _initialize() -> void:
	var rows: Array = []
	for fac in range(1, 6):
		for lvl in range(1, 11):
			rows.append(ENM.row(fac, lvl))
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	quit()
