extends RefCounted

const SCHEMA := "tiles.asset-manifest.v1"

# Shared by runtime registry validation and the exporter. No folder scanning or
# historical audit report can silently add an asset to the packaged game.
static func collect(registry: Dictionary) -> Dictionary:
	var files := {"res://assets/themes/themes.json": true}
	var errors: Array[String] = []
	var manifests := {"shared": registry.get("shared_manifest", "")}
	for id: String in registry.get("themes", {}):
		manifests[id] = registry.themes[id].get("manifest", "")
	for id: String in manifests:
		var path: Variant = manifests[id]
		if not path is String or not path.begins_with("res://") or not FileAccess.file_exists(path):
			errors.append("Missing asset manifest for " + id)
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.get("schema") != SCHEMA or data.get("theme_id") != id or not data.get("files") is Array:
			errors.append("Invalid asset manifest: " + path)
			continue
		files[path] = true
		var seen := {}
		var prefix := "res://assets/shared/" if id == "shared" else "res://assets/themes/" + id + "/"
		for file: Variant in data.files:
			if not file is String or not file.begins_with(prefix) or file.contains("/../") or seen.has(file) or not (FileAccess.file_exists(file) or ResourceLoader.exists(file)):
				errors.append("Invalid, missing or duplicate manifest asset: " + str(file))
				continue
			seen[file] = true
			files[file] = true
	return {"files": files, "errors": errors}
