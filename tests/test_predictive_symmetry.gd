extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Axes = preload("res://scripts/field_axes.gd")
const UI = preload("res://scripts/interface_palette.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(720,1100)
	Palette.select_theme("vines")
	for theme: String in Palette.THEMES:
		Palette.select_theme(theme)
		var thin := Axes.appearance(true,false)
		var thick := Axes.appearance(true,true)
		var gone := Axes.appearance(false,false)
		check(thin.visible and thick.visible and not gone.visible and thick.width > thin.width,"Axes use thin/strong/hidden states in every theme")
		check(thin.color == Color(UI.text(),0.42) and thick.color == UI.accent(1),"Board and button share exact theme ink")
	Palette.select_theme("vines")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var grid: Array = Rules.empty_board(9)
	for row: Array in grid: row.fill(Rules.BLUE)
	grid[1][2] = 0
	scene.game.board = grid
	scene.game.queue[scene.game.index] = "Dot"
	scene.cells = [Vector2i.ZERO]
	scene.board_view.show_axes = true
	scene.has_hover = true
	scene.tray_moved = true
	scene.selected = Vector2i(2,1)
	scene._choose_color(Rules.CORAL)
	var icon = scene.indicators[0].icon
	check(scene.board_view.axes_overlay.states.all(func(state):return not state.possible and not state.complete),"Field axes share the impossible hover state")
	check(not scene.place_button.disabled,"Physically fitting placement stays enabled even if it destroys symmetry")
	check(not icon.available.any(func(value):return value) and not icon.complete.any(func(value):return value),"Predictive graphic shows destruction of all symmetries")
	check(scene.game.board == grid and scene.game.board[1][2] == 0 and scene.game.moves == 0,"Prediction never changes committed cells or moves")
	check(scene.place_button.get_child(0).color == Rules.CORAL and scene.floating_piece.color == Rules.CORAL,"Place hand and floating piece use chosen color")
	scene.blue_button.pressed.emit()
	check(scene.board_view.axes_overlay.states.all(func(state):return state.complete),"Field axes immediately thicken on a restored hover")
	check(icon.available.all(func(value):return value) and icon.complete.all(func(value):return value),"Recoloring updates the predictive graphic to the restored symmetries")
	check(scene.place_button.get_child(0).color == Rules.BLUE,"Place hand follows the color toggle")
	check(not scene._can_save() and scene.indicators[0].panel.disabled,"Predicted symmetry cannot enable saving unplaced artwork")
	for anchor in [Vector2i(-1,0),Vector2i(0,0)]:
		scene.selected = anchor
		scene._preview()
		check(scene.place_button.disabled,"Out-of-bounds and overlapping placements deactivate Place")
		check(icon.available.all(func(value):return value) and not icon.complete.any(func(value):return value),"Impossible placement falls back to committed-board symmetry")
		check(scene.floating_piece.color == Rules.BLUE,"Impossible placement preserves selected color")
	scene.selected = Vector2i(2,1)
	scene.has_hover = false
	scene._preview()
	check(not icon.complete.any(func(value):return value),"Removing hover restores committed-board graphic")
	scene.has_hover = true
	scene.erase_mode = true
	scene._preview()
	check(not icon.complete.any(func(value):return value) and scene.place_button.disabled,"Erase mode suppresses prediction and placement")
	scene.queue_free()
	await process_frame
	print("Predictive symmetry: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
