@tool
extends EditorPlugin

var android_export: EditorExportPlugin

func _enter_tree() -> void:
	android_export = GalleryAndroidExport.new()
	add_export_plugin(android_export)

func _exit_tree() -> void:
	remove_export_plugin(android_export)
	android_export = null

class GalleryAndroidExport extends EditorExportPlugin:
	const Manifest = preload("res://scripts/pattern/asset_manifest.gd")
	const ExportAssets = preload("res://addons/tiles_gallery/export_assets.gd")
	const ApkCheck = preload("res://addons/tiles_gallery/apk_check.gd")
	var apk_path := ""
	var allowed_files := {}
	var allowed_sprites := {}
	var allowed_audio := {}
	func _export_file(path: String, type: String, _features: PackedStringArray) -> void:
		if (path.begins_with("res://assets/") or path.begins_with("res://art/")) and not allowed_files.has(path):
			skip()
			return
		# Explicit manifests also reject obsolete local/untracked artwork.
		if (type == "Texture2D" or path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "ktx", "dds"]) and not allowed_sprites.has(path): skip()
		if path.get_extension().to_lower() in ["wav", "ogg", "mp3"] and not allowed_audio.has(path): skip()
	func _get_export_options_overrides(platform: EditorExportPlatform) -> Dictionary:
		return {"gradle_build/use_gradle_build":true} if platform is EditorExportPlatformAndroid else {}
	func _export_begin(features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
		var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/themes/themes.json"))
		var collected := Manifest.collect(registry)
		for error: String in collected.errors: push_error(error)
		allowed_files = collected.files
		allowed_audio.clear()
		allowed_sprites.clear()
		for file: String in allowed_files:
			if file.get_extension() in ["png","jpg","jpeg","webp","svg"]: allowed_sprites[file] = true
			elif file.get_extension() == "ogg": allowed_audio[file] = true
		if features.has("Android") or features.has("android"):
			var cleanup := ExportAssets.clean_import_staging(ProjectSettings.globalize_path("res://"))
			for error: String in cleanup.errors: push_error(error)
			if cleanup.removed > 0: print("Tiles: cleared %d staged Android imports before export" % cleanup.removed)
		apk_path = path if path.to_lower().ends_with(".apk") and (features.has("Android") or features.has("android")) else ""
	func _export_end() -> void:
		if apk_path.is_empty() or not FileAccess.file_exists(apk_path): return
		var result := ApkCheck.inspect(apk_path)
		if result.ok:
			print("TilesGallery: verified Photos and Share plugin in "+apk_path)
		else:
			push_error("Android APK validation failed. Rebuild with Gradle after clearing generated Android import staging.\n"+"\n".join(result.errors))
		apk_path = ""
	func _get_name() -> String:
		return "TilesGallery"
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid
	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["tiles_gallery/bin/tiles-gallery.aar"])
