extends SceneTree

# Run --main-pack from an empty directory with this script's absolute path.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize(): run.call_deferred()
func run():
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://project.godot")):
		push_error("Run the exported startup test outside the source checkout.")
		quit(1)
		return
	var Themes = load("res://scripts/pattern/theme_registry.gd")
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/themes/themes.json"))
	var errors: Array = Themes.validate(registry)
	check(errors.is_empty(), "Exported theme registry must initialize: " + str(errors))
	if not errors.is_empty():
		quit(1)
		return
	var remapped_audio := 0
	for theme: Dictionary in registry.themes.values():
		for channel: String in ["ambience","place"]:
			var path: String = theme.soundscape[channel].path
			check(load(path) is AudioStreamOggVorbis, "Packaged recording loads: " + path)
			if not FileAccess.file_exists(path): remapped_audio += 1
	var Palette = load("res://scripts/palette.gd")
	root.size = Vector2i(540,825)
	for id: String in registry.order:
		check(Palette.select_theme(id), "Packaged theme is selectable: " + id)
		var game = load("res://main.tscn").instantiate()
		game.session_enabled = false
		game.intro_progress_path = "user://exported-ui-smoke.cfg"
		root.add_child(game)
		for i in range(3): await process_frame
		check(game.theme.default_font is FontFile, "UI font loaded: " + id)
		for button: Button in game._controls():
			check(button.visible and button.size.x > 0 and button.size.y > 0, "UI control has a visible layout: " + id)
			check(button.get_theme_stylebox("normal").bg_color == Color(registry.themes[id].ui.controls), "UI face uses its authored color: " + id)
			check(game.button_icon(button) != null, "UI icon exists: " + id)
		var product: String = Themes.play_product(id)
		if not product.is_empty():
			game.theme_store.owned[product] = true
		game._start_introduction()
		for i in range(3): await process_frame
		check(game.introduction != null and not game.introduction.text.text.is_empty(), "Tutorial text initializes: " + id)
		check(game.place_button.visible and game.palette_button.visible and game.blue_button.visible, "Tutorial preserves the existing UI: " + id)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/exported-ui-"+id+".png")
		game.queue_free()
		await process_frame
	print("Exported startup/UI: ",checks," checks, ",failures," failures; ",remapped_audio," recordings have no raw source file")
	quit(1 if failures else 0)
