extends SceneTree
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Palette = preload("res://scripts/palette.gd")
func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Themes.PATH))
	var errors: Array = Themes.validate(data)
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	if Themes.ids().size() != 4 or Themes.play_product("christmas_joy") != "christmas_joy" or "zen_garden" in Themes.ids() or Palette.select_theme("zen_garden"):
		push_error("Archived Zen must not be active or selectable")
		quit(1)
		return
	if Palette.theme_id() != "vines":
		push_error("Vines must remain the startup theme")
		quit(1)
		return
	if "--check-export" in OS.get_cmdline_user_args():
		var has_zen := DirAccess.dir_exists_absolute("res://art/themes/zen_garden")
		for path: String in ["res://scripts", "res://shaders"]:
			for file: String in DirAccess.get_files_at(path):
				if file.begins_with("zen"): has_zen = true
		if has_zen:
			push_error("Archived Zen resources must not ship")
			quit(1)
			return

	print("Active theme resources: registry validates; four themes; Zen unavailable; Vines default")
	quit(0)
