extends SceneTree
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Palette = preload("res://scripts/palette.gd")
const Frame = preload("res://scripts/board_frame.gd")
const Clock = preload("res://scripts/clockwork_sets.gd")
const Coral = preload("res://scripts/coral_sets.gd")
const Zen = preload("res://scripts/zen_sets.gd")
const Vines = preload("res://scripts/vines_sets.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var original := Themes.specification()
	check(Themes.validate(original).is_empty(), "production registry validates")
	check(Palette.theme_id() == "zen_garden" and Themes.ids() == ["zen_garden", "clockwork", "vines", "coral_reef"], "Zen stays default and first; no archived theme selectable")
	check(Themes.label("labyrinth") == "Labyrinth (archived)" and not Palette.select_theme("labyrinth"), "archived gallery label does not reactivate the theme")
	for installer in [Clock, Coral, Zen, Vines]: installer.install()
	for id: String in Themes.ids():
		check(Palette.select_theme(id) and Palette.theme_name() == Themes.label(id), "theme selection reads registry")
		check(Palette.theme_version() == {"zen_garden": "0.12", "clockwork": "1.2", "vines": "1.1", "coral_reef": "2.3"}[id], "Generative artwork has a distinct appearance version")
		check(int(Palette.clockwork) + int(Palette.coral_reef) + int(Palette.zen_garden) == (0 if id == "vines" else 1), "specialized flags are mutually exclusive views")
		var profile := Themes.profile(id)
		for family: String in profile.sets:
			for tier: String in profile.sets[family]:
				var loaded := Assets.load_set(Themes.pattern_set_path(id, int(tier), family))
				check(loaded.ok and loaded.definition.tier == int(tier), "each registered tier uses the shared loader and matching tier number")
		if profile.environment.has("catalog"):
			var loaded := Assets.load_set(profile.environment.catalog)
			check(loaded.ok and not Assets.catalog([loaded]).is_empty(), "environment parts use the same artwork contract")
		check(Frame.profile(id) == profile.frame, "board and menu share registry frame")
	check(Clock.special.size() == 11 and Coral.special.size() == 10, "Tier 3 catalogs include all retained specialized components")
	check(Clock.grounds.size() == 5 and Coral.grounds.size() == 6, "ground variants, pins, lip and sidewall retained")
	check(not Clock.catalog.has("T02") and not Clock.special.has("T02"), "unused wheel collar is not reintroduced")
	check(not FileAccess.file_exists("res://art/themes/coral_reef/theme.json") and not FileAccess.file_exists("res://art/themes/clockwork_workshop/theme.json"), "old runtime manifests removed")
	check(not FileAccess.file_exists("res://assets/frames/frames.json"), "frame settings have one owner")
	var changed: Dictionary = original.duplicate(true)
	changed.themes.clockwork.ui.controls = "123456"
	Themes.definition = changed
	Palette.select_theme("clockwork")
	check(Palette.controls() == Color("123456"), "editing registry UI changes live styling without a theme branch")
	Themes.definition = original
	Palette.select_theme("vines")
	for index in range(Palette.PAIRS.size()):
		check(Palette.select(index), "all existing palette pairs remain selectable")
		check(Palette.tile(1) == Palette.PAIRS[index].colors[0] and Palette.tile(2) == Palette.PAIRS[index].colors[1], "Vines preserves both palette pigments")
		check(Palette.floor_color() == Palette.PAIRS[index].floor, "palette-specific floor preserved")
		var garden: Color = Palette.floor_color().lightened(0.09) if Palette.dark() else Palette.floor_color().darkened(0.035)
		check(Palette.garden() == garden, "dark/light garden derivation preserved")
	for field: String in ["themes", "order", "frame_geometry", "palette_pairs"]:
		changed = original.duplicate(true)
		changed[field] = null
		check(not Themes.validate(changed).is_empty(), "missing required registry field is diagnosed: " + field)
	for path: Array in [["ui"], ["sets"], ["frame"], ["hooks"], ["preview"], ["environment"]]:
		changed = original.duplicate(true)
		changed.themes.clockwork[path[0]] = null
		check(not Themes.validate(changed).is_empty(), "malformed theme field is diagnosed")
	changed = original.duplicate(true)
	changed.order.append("zen_garden")
	check(not Themes.validate(changed).is_empty(), "duplicate theme entries rejected")
	changed = original.duplicate(true)
	changed.default = "labyrinth"
	check(not Themes.validate(changed).is_empty(), "archived default rejected")
	changed = original.duplicate(true)
	changed.themes.clockwork.hooks.growth = "res://scripts/main.gd"
	check(not Themes.validate(changed).is_empty(), "hook data cannot name arbitrary code")
	changed = original.duplicate(true)
	changed.themes.clockwork.sets.default["0"] = "user://theme.json"
	check(not Themes.validate(changed).is_empty(), "external set paths rejected")
	changed = original.duplicate(true)
	changed.themes.clockwork.frame.texture = "res://missing.png"
	check(not Themes.validate(changed).is_empty(), "enabled frame needs its real artwork")
	changed = original.duplicate(true)
	changed.themes.clockwork.ui.controls = "not a color"
	check(not Themes.validate(changed).is_empty(), "invalid UI colors diagnosed")
	var preset := ConfigFile.new()
	check(preset.load("res://export_presets.cfg") == OK, "export configuration loads")
	var included: String = preset.get_value("preset.0", "include_filter")
	check(Themes.PATH.trim_prefix("res://") in included and "frames.json" not in included and "theme.json" not in included, "export includes active registry without obsolete manifests")
	Palette.select(0)
	Palette.select_theme("zen_garden")
	print("Theme registry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
