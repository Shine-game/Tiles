extends SceneTree
var sprites: Array[String] = []
func scan(path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".import") and file.trim_suffix(".import").get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "ktx", "dds"]: sprites.append(path.path_join(file).trim_suffix(".import").trim_prefix("res://"))
	for folder: String in DirAccess.get_directories_at(path):
		if folder != ".godot": scan(path.path_join(folder))
func _initialize() -> void:
	scan("res://")
	var inventory := "res://assets/sprites/audit.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--inventory="): inventory = argument.trim_prefix("--inventory=")
	var expected: Array = JSON.parse_string(FileAccess.get_file_as_string(inventory)).runtime_pngs
	expected.append("assets/icon.svg")
	var failures := 0
	for sprite in sprites:
		if sprite not in expected:
			push_error("Unexpected export sprite: " + sprite)
			failures += 1
	for sprite in expected:
		if sprite not in sprites:
			push_error("Missing export sprite: " + sprite)
			failures += 1
	print("Packed sprite inventory: ", sprites.size(), " sprites, ", failures, " discrepancies")
	quit(1 if failures else 0)
