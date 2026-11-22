extends SceneTree
var paths: Array[String] = []
func scan(folder: String) -> void:
	for file: String in DirAccess.get_files_at(folder): paths.append(folder.path_join(file))
	for child: String in DirAccess.get_directories_at(folder): scan(folder.path_join(child))
func _initialize():
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/themes/themes.json"))
	var Manifest = load("res://scripts/pattern/asset_manifest.gd")
	var Themes = load("res://scripts/pattern/theme_registry.gd")
	var inventory: Dictionary = Manifest.collect(registry)
	var failures: Array = inventory.errors + Themes.validate(registry)
	scan("res://")
	var expected := {}
	var images := 0
	var audio := 0
	for file: String in inventory.files:
		if file.get_extension() in ["png","svg","ogg","ttf"]:
			if load(file) == null: failures.append("Cannot load " + file)
		if file.get_extension() in ["png","svg"]: images += 1
		if file.get_extension() == "ogg": audio += 1
	var regex := RegEx.new()
	regex.compile('res://\\.godot/imported/[^"\\r\\n]+')
	for file: String in paths:
		if file.ends_with(".import"):
			if not inventory.files.has(file.trim_suffix(".import")): failures.append("Unlisted source import: " + file)
			for match in regex.search_all(FileAccess.get_file_as_string(file)): expected[match.get_string()] = true
		if file.begins_with("res://art/"): failures.append("Legacy artwork packed: " + file)
	for file: String in paths:
		if file.begins_with("res://.godot/imported/") and not expected.has(file): failures.append("Orphan import: " + file)
	print("Exported pack: ",images," images, ",audio," OGG recordings; ",expected.size()," import artifacts; failures: ", failures)
	quit(0 if failures.is_empty() else 1)
