extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Interface = preload("res://scripts/interface_palette.gd")
const UI = preload("res://scripts/interface_theme.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = Main.new()
	root.add_child(game)
	await process_frame
	var palettes := {"coral_reef":["DCEFED","F4FCFA","A8C9C5","2E4846"],"clockwork":["F1D6A6","FBE8C4","C6A16D","4B3324"],"vines":["F9E5DD","FFF5EF","D4B5BB","513D49"]}
	for id: String in palettes:
		Palette.select_theme(id)
		game._refresh_theme()
		check(game.reef_background.visible == (id == "coral_reef"), "Coral background artwork remains enabled")
		var normal: StyleBoxFlat = game.theme.get_stylebox("normal", "Button")
		var pressed: StyleBoxFlat = game.theme.get_stylebox("pressed", "Button")
		check(normal.bg_color == Color(palettes[id][0]), id + " surface")
		check(normal.border_color == Color(palettes[id][2]), id + " bevel edge")
		if id == "vines":
			check(normal.shadow_color.is_equal_approx(Color("A98796", 0.65)), "Vines mauve shadow")
			check(Interface.muted() == Color("A68C96"), "Vines disabled mauve")
			check(Interface.light() == Color("FFF5EF") and game.place_button.get_node("BevelHighlight").visible, "Vines ivory highlight")
		if id == "coral_reef":
			check(normal.shadow_color.is_equal_approx(Color("749B97", 0.65)), "Coral aqua shadow")
			check(Interface.muted() == Color("829F9C"), "Coral disabled sea green")
			check(Interface.light() == Color("F4FCFA") and game.place_button.get_node("BevelHighlight").visible, "Coral top-left highlight")
		if id == "clockwork":
			check(normal.shadow_color.is_equal_approx(Color("896447", 0.65)), "walnut shadow")
			check(Interface.muted() == Color("A08863"), "disabled sepia")
			check(Interface.light() == Color("FBE8C4") and game.place_button.get_node("BevelHighlight").visible, "top-left highlight")
		check(pressed.border_color == Color(palettes[id][2]), id + " depressed edge")
		check(game.theme.get_color("font_color", "Button") == Color(palettes[id][3]), id + " labels")
		check(pressed.shadow_size < normal.shadow_size and pressed.content_margin_top - normal.content_margin_top == UI.TRAVEL, "shared press geometry")
		var disabled: StyleBoxFlat = game.theme.get_stylebox("disabled", "Button")
		check(disabled.shadow_color == normal.shadow_color and disabled.shadow_size == normal.shadow_size and disabled.shadow_offset == normal.shadow_offset, "Disabled controls preserve the resting shadow; only their content fades")
		var focus: StyleBoxFlat = game.theme.get_stylebox("focus", "Button")
		check(focus.border_width_left == 0 and focus.border_width_top == 0 and focus.border_width_right == 0 and focus.border_width_bottom == 0, "Keyboard focus never adds an extra button outline")
		check(focus.expand_margin_left < 0 and focus.expand_margin_top < 0 and focus.expand_margin_right < 0 and focus.expand_margin_bottom < 0 and focus.bg_color.a > 0, "Keyboard focus remains visible inside the face, clear of the bevel")
		game.confirmation.open()
		check(not game.confirmation.get_cancel_button().has_focus(), "Opening a confirmation does not force a different-looking Go back button")
		game.confirmation.get_cancel_button().grab_focus()
		check(game.confirmation.get_cancel_button().has_focus(), "Keyboard focus remains available on confirmation choices")
		game.confirmation.hide()

		check(game.confirmation.theme == game.theme, "dialog inherits shared theme")
		# Actual controls must match the shared relief, including those whose
		# color/symmetry/selection changes previously thickened their outlines.
		for button: Button in game.themed_buttons:
			for state: String in ["normal","hover","pressed","hover_pressed","disabled"]:
				var shared: StyleBoxFlat = game.theme.get_stylebox(state,"Button")
				var actual: StyleBoxFlat = button.get_theme_stylebox(state)
				check([actual.border_width_left,actual.border_width_top,actual.border_width_right,actual.border_width_bottom] == [shared.border_width_left,shared.border_width_top,shared.border_width_right,shared.border_width_bottom], "Every game, menu, gallery and confirmation button uses the same bevel in "+state)
				check(actual.shadow_size == shared.shadow_size and actual.shadow_offset == shared.shadow_offset and actual.shadow_color == shared.shadow_color, "Button shadows match the shared state")
		check(not game.blue_button.toggle_mode and not game.blue_button.button_pressed,"Color cycles on a normal button instead of staying sunken")
		var first_color: int = game.game.current_color
		game.blue_button.pressed.emit()
		check(game.game.current_color == 3-first_color and not game.blue_button.button_pressed,"Changing piece color leaves the button at rest")
		game._toggle_erase()
		check(game.erase_mode and game.erase_button.button_pressed,"Erase remains visibly latched only while its tool is armed")
		game._toggle_erase()
		check(not game.erase_mode and not game.erase_button.button_pressed,"Canceling Erase restores the common resting face")


		check(game.gallery_panel.get_theme_stylebox("panel").bg_color == Interface.panel_background(), "gallery retains panel background")
		for page: String in ["Settings", "Themes", "Gameplay", "Difficulty", "Size", "Audio"]:
			game._show_menu(page)
			check(game.menu_frame.is_present() and game.menu_frame.theme_id == Palette.theme_id() and not game.menu_title.visible and game.menu_title.text.is_empty(), "Nested menus use the active theme frame")
			var panel: StyleBoxFlat = game.palette_menu.get_theme_stylebox("panel")
			check(panel.bg_color == normal.bg_color and panel.border_width_top == 1 and panel.shadow_size == 0, "Menu surface matches buttons with flat thin border")
		game._show_menu("Audio")
		check(game.palette_menu.get_theme_stylebox("panel").bg_color == Interface.panel_background(), "settings retains panel background")
		var icon = game.place_button.get_child(0)
		var before: Vector2 = icon.position
		game.place_button.button_down.emit()
		check(icon.position.y == before.y + UI.TRAVEL, "custom icon travels with face")
		game.place_button.button_up.emit()
		check(icon.position == before, "custom icon restores position")
	Palette.select_theme("vines")
	game.queue_free()
	await process_frame
	print("Shared interface theme: %d checks, %d failures across all active themes" % [checks,failures])
	quit(1 if failures else 0)
