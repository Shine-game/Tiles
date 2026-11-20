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
	const ExportAssets = preload("res://addons/tiles_gallery/export_assets.gd")
	const ApkCheck = preload("res://addons/tiles_gallery/apk_check.gd")
	var apk_path := ""
	var allowed_sprites := {}
	var allowed_audio := {}
	func _collect_audio(value: Variant) -> void:
		if value is Dictionary:
			for item in value.values(): _collect_audio(item)
		elif value is Array:
			for item in value: _collect_audio(item)
		elif value is String and value.begins_with("res://") and value.get_extension() in ["wav", "ogg", "mp3"]:
			allowed_audio[value] = true
	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		# Explicit sprite inventory also rejects obsolete local/untracked artwork.
		if path.get_extension().to_lower() == "png" and not allowed_sprites.has(path): skip()
		if path.get_extension().to_lower() in ["wav", "ogg", "mp3"] and not allowed_audio.has(path): skip()
	func _get_export_options_overrides(platform: EditorExportPlatform) -> Dictionary:
		return {"gradle_build/use_gradle_build":true} if platform is EditorExportPlatformAndroid else {}
	func _export_begin(features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
		allowed_audio.clear()
		_collect_audio(JSON.parse_string(FileAccess.get_file_as_string("res://assets/themes/themes.json")))
		# Shared fallback and the existing workshop compatibility player.
		for clip: String in ["shared/shared_tier_1.wav", "shared/shared_tier_2.wav", "clockwork/clockwork_ambient_legacy.wav", "clockwork/clockwork_tier_1_legacy.wav", "clockwork/clockwork_tier_2_legacy.wav", "clockwork/clockwork_tier_3_legacy.wav"]:
			allowed_audio["res://assets/audio/" + clip] = true
		allowed_sprites.clear()
		var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/audit.json"))
		for sprite: String in inventory.runtime_pngs: allowed_sprites["res://" + sprite] = true
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
