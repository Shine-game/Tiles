extends SceneTree

const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.indicators.size() == 7, "all seven symmetry indicators present")
	check(scene.undo_button.disabled, "undo initially disabled")
	check(scene.board_view.size.x > 0 and scene.board_view.size.y > 0, "board laid out")
	scene.game.queue[scene.game.index] = "J"
	scene.cells = Rules.PIECES.J.cells
	scene._refresh()
	scene.coral_button.pressed.emit()
	check(scene.game.current_color == Rules.CORAL, "color button changes selected piece color")
	var unflipped: Array = scene.cells.duplicate()
	scene.flip_button.pressed.emit()
	check(scene.cells == Rules.flip(unflipped), "Flip button mirrors piece")
	var original: Array = scene.game.board.duplicate(true)
	var original_piece: String = scene.game.queue[scene.game.index]
	var move: Dictionary = Rules.first_legal_move(scene.game.board, {"cells": scene.cells, "color": scene.game.current_color}, false, false)
	for i in range(move.rotation):
		scene.rotate_button.pressed.emit()
	var placed_cells: Array = scene.cells.duplicate()
	# Exercise the actual screen-touch handler, not just the model API.
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = scene.board_view.field.position + Vector2(8, 8) + (Vector2(move.anchor) + Vector2(0.5, 0.5)) * scene.board_view.pitch
	scene.board_view._gui_input(event)
	check(scene.game.moves == 0, "first tap previews without committing")
	check(not scene.place_button.disabled, "valid preview enables Place")
	scene.board_view._gui_input(event)
	check(scene.game.moves == 1, "second tap commits exactly one piece")
	check(not scene.undo_button.disabled, "placement enables Back")
	scene.undo_button.pressed.emit()
	check(scene.game.board == original, "Back restores board")
	check(scene.game.queue[scene.game.index] == original_piece, "Back restores next piece")
	check(scene.game.current_color == Rules.CORAL, "Back restores chosen color")
	check(scene.cells == placed_cells, "Back restores flipped orientation")
	scene._select_anchor(Vector2i(0, 0))
	check(scene.place_button.disabled, "disconnected placement disabled")
	scene.game.board = Rules.empty_board(9)
	for row: Array in scene.game.board:
		row.fill(Rules.BLUE)
	scene.game.board[1][2] = 0
	scene.game.queue[scene.game.index] = "Dot"
	scene.cells = Rules.PIECES.Dot.cells
	scene.game.current_color = Rules.CORAL
	scene.game._refresh_over()
	scene._clear_selection()
	scene._refresh()
	scene._select_anchor(Vector2i(2, 1))
	check(not scene.board_view.preview_valid and scene.place_button.disabled, "incompatible color is rejected")
	check(Palette.INVALID.r == Palette.INVALID.g or absf(Palette.INVALID.r - Palette.INVALID.g) < 0.02, "invalid preview uses dull gray")
	scene.blue_button.pressed.emit()
	check(scene.board_view.preview_valid and not scene.place_button.disabled, "changing color revalidates selected placement")
	check(scene.piece_view.color == Rules.BLUE, "piece preview updates immediately")
	scene.place_button.pressed.emit()
	check(scene.game.no_space and scene.game.over, "filling last cell completes garden")
	check(scene.cells.is_empty() and scene.piece_label.text == "Garden complete", "completion clears incoming piece")
	check(scene.status.text.contains("full"), "completion has specific message")
	scene.undo_button.pressed.emit()
	check(not scene.game.over and scene.cells.size() == 1, "Back reopens completed garden")
	scene.requested_size = 11
	scene._reset()
	check(scene.game.board.size() == 11, "11 by 11 reset works")
	scene.requested_size = 9
	scene._reset()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/tiles-godot.png")
	scene.queue_free()
	await process_frame
	print("UI: color changes, flips, touch placement, undo, gray invalid preview, size reset; %d failures" % failures)
	quit(1 if failures else 0)
