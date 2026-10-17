extends SceneTree
const ISL = preload("res://src/island.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var sd: int = int(args[1]) if args.size() > 1 else 7
	var a = ISL.new(sd)
	a.overview_image(2).save_png(args[0])
	quit()
