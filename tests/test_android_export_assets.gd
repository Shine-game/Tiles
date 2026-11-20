extends SceneTree
const Assets = preload("res://addons/tiles_gallery/export_assets.gd")
func _initialize() -> void:
	var root := "user://android-export-clean-test"
	var folder := root + "/android/build/assets/.godot/imported"
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder + "/obsolete.ctex", FileAccess.WRITE)
	file.store_string("stale")
	file.close()
	var custom := root + "/android/build/assets/custom.txt"
	file = FileAccess.open(custom, FileAccess.WRITE)
	file.store_string("preserve")
	file.close()
	var result := Assets.clean_import_staging(root)
	assert(result.removed == 1 and result.errors.is_empty())
	assert(FileAccess.file_exists(custom))
	assert(Assets.clean_import_staging(root).removed == 0)
	var files := PackedStringArray(["assets/art/current.png.import", "assets/.godot/imported/current.ctex", "assets/.godot/imported/obsolete.ctex"])
	var orphan := Assets.orphan_imports(files, func(_path): return 'path="res://.godot/imported/current.ctex"'.to_utf8_buffer())
	assert(orphan == ["assets/.godot/imported/obsolete.ctex"])
	DirAccess.remove_absolute(custom)
	print("Android export assets: stale imports removed; custom assets preserved; orphan detection passed")
	quit()
