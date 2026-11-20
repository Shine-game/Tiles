extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Interface = preload("res://scripts/interface_palette.gd")
const UI = preload("res://scripts/interface_theme.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0
func check(value: bool, message: String) -> void:
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
		check(game.confirmation.theme == game.theme, "dialog inherits shared theme")
		check(game.gallery_panel.get_theme_stylebox("panel").bg_color == Interface.panel_background(), "gallery retains panel background")
		for page: String in ["Settings", "Themes", "Gameplay", "Difficulty", "Size", "Audio"]:
			game._show_menu(page)
			check(not game.menu_frame.visible and not game.menu_title.visible and game.menu_title.text.is_empty(), "Nested menus have no frame or heading")
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
	print("Shared interface theme: ", failures, " failures across all active themes")
	quit(1 if failures else 0)
