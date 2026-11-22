extends SceneTree
const Manifest = preload("res://scripts/pattern/asset_manifest.gd")
var sprites: Array[String] = []
func scan(path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".import") and file.trim_suffix(".import").get_extension().to_lower() in ["png","jpg","jpeg","webp","svg"]:
			sprites.append(path.path_join(file).trim_suffix(".import"))
	for folder: String in DirAccess.get_directories_at(path):
		if folder != ".godot": scan(path.path_join(folder))
func _initialize() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/themes/themes.json"))
	var inventory := Manifest.collect(registry)
	var expected: Array = inventory.files.keys().filter(func(path): return path.get_extension() in ["png","jpg","jpeg","webp","svg"])
	# The editor source tree intentionally still contains cleanup candidates.
	# An exported pack must contain only the manifest-listed imported images.
	if OS.has_feature("editor"):
		scan("res://assets/themes")
		scan("res://assets/shared")
	else: scan("res://")
	var failures: int = inventory.errors.size()
	for sprite: String in sprites:
		if sprite not in expected:
			push_error("Unexpected export sprite: " + sprite)
			failures += 1
	for sprite: String in expected:
		if sprite not in sprites:
			push_error("Missing export sprite: " + sprite)
			failures += 1
	print("Manifest sprite inventory: ", sprites.size(), " sprites, ", failures, " discrepancies")
	quit(1 if failures else 0)
