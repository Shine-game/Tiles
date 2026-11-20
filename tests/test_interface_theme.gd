extends SceneTree
const Palette = preload("res://scripts/palette.gd")
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
	var palettes := {"coral_reef":["C6B99E","DFD4BC","9B8C72","303C39"],"clockwork":["B8AD98","D2C7B2","8B806D","362F28"],"vines":["B0BAA5","CBD2C1","808D75","303A2D"]}
	for id: String in palettes:
		Palette.select_theme(id)
		game._refresh_theme()
		var normal: StyleBoxFlat = game.theme.get_stylebox("normal", "Button")
		var pressed: StyleBoxFlat = game.theme.get_stylebox("pressed", "Button")
		check(normal.bg_color == Color(palettes[id][0]), id + " surface")
		check(normal.border_color == Color(palettes[id][1]), id + " light edge")
		check(pressed.border_color == Color(palettes[id][2]), id + " depressed edge")
		check(game.theme.get_color("font_color", "Button") == Color(palettes[id][3]), id + " labels")
		check(pressed.shadow_size < normal.shadow_size and pressed.content_margin_top - normal.content_margin_top == UI.TRAVEL, "shared press geometry")
		check(game.confirmation.theme == game.theme, "dialog inherits shared theme")
		check(game.gallery_panel.get_theme_stylebox("panel").bg_color == normal.bg_color, "gallery inherits surface")
		game._show_menu("Audio")
		check(game.palette_menu.get_theme_stylebox("panel").bg_color == normal.bg_color, "settings surface")
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
