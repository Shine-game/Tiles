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
	func _get_export_options_overrides(platform: EditorExportPlatform) -> Dictionary:
		return {"gradle_build/use_gradle_build":true} if platform is EditorExportPlatformAndroid else {}
	func _export_begin(features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
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
