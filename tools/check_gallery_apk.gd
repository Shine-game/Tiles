extends SceneTree
const Check = preload("res://addons/tiles_gallery/apk_check.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1:
		printerr("Usage: godot --headless --path . --script tools/check_gallery_apk.gd -- /path/to/game.apk")
		quit(2)
		return
	var result := Check.inspect(args[0])
	if result.ok: print("PASS: Photos and Share plugin classes and registration are included.")
	else:
		for error: String in result.errors: printerr(error)
	quit(0 if result.ok else 1)
