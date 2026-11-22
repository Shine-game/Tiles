extends RefCounted

static func exists(path: String) -> bool:
	return ResourceLoader.exists(path, "Texture2D") or _has_source_png(path)

static func texture(path: String) -> Texture2D:
	var has_source := _has_source_png(path)
	if ResourceLoader.exists(path, "Texture2D") and (not has_source or _has_import(path)):
		var imported := ResourceLoader.load(path, "Texture2D") as Texture2D
		if imported != null: return imported
	if has_source:
		# The editor can launch with a remap from Git before its local .ctex exists.
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			return ImageTexture.create_from_image(image)
	return null

static func _has_source_png(path: String) -> bool:
	return path.begins_with("res://") and path.get_extension() == "png" and FileAccess.file_exists(path)

static func _has_import(path: String) -> bool:
	var import := ConfigFile.new()
	if import.load(path + ".import") != OK or not import.has_section("remap"): return false
	for key: String in import.get_section_keys("remap"):
		if key == "path" or key.begins_with("path."):
			if FileAccess.file_exists(import.get_value("remap", key)): return true
	return false
