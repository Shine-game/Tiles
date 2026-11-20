@tool
extends RefCounted

# Only Godot-generated import staging is disposable. Never touch source artwork,
# the editor's import cache, native libraries, or custom Android assets.
static func clean_import_staging(project_root: String) -> Dictionary:
	var removed := 0
	var errors: Array[String] = []
	for relative: String in ["android/build/assets/.godot/imported", "android/build/src/main/assets/.godot/imported"]:
		var folder := project_root.path_join(relative)
		if not DirAccess.dir_exists_absolute(folder): continue
		for file: String in DirAccess.get_files_at(folder):
			var result := DirAccess.remove_absolute(folder.path_join(file))
			if result == OK: removed += 1
			else: errors.append("Could not clear generated Android import: " + folder.path_join(file))
	return {"removed": removed, "errors": errors}

static func orphan_imports(files: PackedStringArray, read_file: Callable) -> Array[String]:
	var referenced := {}
	var regex := RegEx.new()
	regex.compile('res://\\.godot/imported/[^"\\r\\n]+')
	for file: String in files:
		if not file.begins_with("assets/") or not file.ends_with(".import"): continue
		for match in regex.search_all(read_file.call(file).get_string_from_utf8()):
			referenced["assets/" + match.get_string().trim_prefix("res://")] = true
	var orphans: Array[String] = []
	for file: String in files:
		if file.begins_with("assets/.godot/imported/") and not file.ends_with("/") and not referenced.has(file):
			orphans.append(file)
	return orphans
