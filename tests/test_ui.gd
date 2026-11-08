extends SceneTree

const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func touch(scene, point: Vector2, pressed: bool, id: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = id
	root.push_input(event, true)

func drag(scene, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.index = 0
	root.push_input(event, true)

func board_point(scene, cell: Vector2i) -> Vector2:
	return scene.board_view.get_global_transform_with_canvas() * (scene.board_view.field.position + Vector2(8, 8) + (Vector2(cell) + Vector2(0.5, 0.5)) * scene.board_view.pitch)

func source_point(scene, cell: Vector2i) -> Vector2:
	var layout: Dictionary = scene.piece_view.geometry()
	return scene.piece_view.get_global_transform_with_canvas() * (layout.origin + (Vector2(cell) + Vector2(0.5, 0.5)) * layout.unit)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4):
		await process_frame
	check(scene.indicators.size() == 2, "exactly two symmetry graphics")
	check(scene.indicators[0].icon.available == [true, true, true, true], "reflection graphic lights all four initial axes")
	check(scene.indicators[1].icon.available == [true, true, true], "rotation graphic initially available")
	var partial: Array = Rules.empty_board(9)
	partial[1][1] = Rules.BLUE
	partial[1][7] = Rules.BLUE
	partial[7][1] = Rules.CORAL
	partial[7][7] = Rules.CORAL
	scene._update_summaries(partial)
	check(scene.indicators[0].icon.available == [true, false, false, false], "each axis is highlighted independently")
	check(not scene.indicators[1].icon.available.any(func(value): return value), "rotation graphic is off when all rotations conflict")
	scene._preview()

	check(absf(scene.board_view.field.size.x - scene.get_viewport_rect().size.x) < 1, "board spans full phone width")
	check(scene.place_button.get_global_rect().position.x < scene.undo_button.get_global_rect().position.x, "Place is at bottom left")
	check(scene.place_button.get_global_rect().end.y <= scene.get_viewport_rect().size.y, "Place dock stays within screen")
	scene.game.queue[scene.game.index] = "J"
	scene.cells = Rules.PIECES.J.cells
	scene._refresh()
	scene.coral_button.pressed.emit()
	check(scene.game.current_color == Rules.CORAL, "color selection changes piece")
	var original_cells: Array = scene.cells.duplicate()
	scene.flip_button.pressed.emit()
	check(scene.cells == Rules.flip(original_cells), "Flip mirrors piece")
	var move: Dictionary = Rules.first_legal_move(scene.game.board, {"cells": scene.cells, "color": scene.game.current_color}, false, false)
	for i in range(move.rotation):
		scene.rotate_button.pressed.emit()
	var placed_cells: Array = scene.cells.duplicate()
	var original_board: Array = scene.game.board.duplicate(true)
	for grab: Vector2i in placed_cells:
		scene._clear_selection()
		scene._preview()
		touch(scene, source_point(scene, grab), true)
		check(scene.dragging, "every occupied source square starts dragging")
		var target := board_point(scene, move.anchor + grab)
		drag(scene, target)
		touch(scene, target, false)
		check(scene.has_hover and not scene.dragging, "finger release leaves a hovering piece")
		check(scene.selected == move.anchor, "grabbed square retains its offset")
		check(scene.game.board == original_board and scene.game.moves == 0, "release never places automatically")
		check(not scene.place_button.disabled, "physically fitting hover enables Place")
	# Regrab a non-anchor square of the floating piece and move off the field.
	var grab: Vector2i = placed_cells.back()
	touch(scene, board_point(scene, move.anchor + grab), true)
	check(scene.dragging, "any square of the floating piece can be regrabbed")
	var off_field := board_point(scene, Vector2i(-1, -1) + grab)
	drag(scene, off_field)
	touch(scene, off_field, false)
	check(scene.has_hover and scene.floating_piece.cells.size() == 4, "invalid release keeps floating piece visible")
	check(not scene.floating_piece.valid and scene.place_button.disabled, "off-field hover is gray and cannot be placed")
	# Restore a valid hover, then confirm using the dock button.
	touch(scene, source_point(scene, grab), true)
	drag(scene, board_point(scene, move.anchor + grab))
	touch(scene, board_point(scene, move.anchor + grab), false)
	scene.place_button.pressed.emit()
	check(scene.game.moves == 1, "Place commits the hovering piece")
	check(not scene.has_hover, "commit clears floating piece")
	check(scene.board_view.growing, "Place starts the committed pattern's growth")
	var pending_move: Dictionary = Rules.first_legal_move(scene.game.board, scene.game.piece())
	scene.cells = pending_move.cells
	scene._choose_color(pending_move.color)
	var pending_grab: Vector2i = scene.cells[0]
	touch(scene, source_point(scene, pending_grab), true)
	drag(scene, board_point(scene, pending_move.anchor + pending_grab))
	touch(scene, board_point(scene, pending_move.anchor + pending_grab), false)
	check(scene.has_hover and not scene.dragging, "next piece remains draggable while growth resolves")
	check(scene.place_button.disabled, "physically valid next piece cannot be placed during growth")
	var committed_moves: int = scene.game.moves
	scene._place()
	check(scene.game.moves == committed_moves, "controller rejects early placement even without a button click")
	var committed_flowers: int = scene.board_view.pattern.flowers.size()
	scene._flip()
	scene._choose_color(3 - scene.game.current_color)
	check(scene.board_view.pattern.flowers.size() == committed_flowers, "preview changes never mutate committed growth")
	# Restore the valid hovering orientation/color and complete the timeline.
	scene.cells = pending_move.cells
	scene._choose_color(pending_move.color)
	scene.board_view.advance_growth(scene.board_view.pattern.duration + 1)
	check(not scene.board_view.growing and not scene.place_button.disabled, "Place unlocks automatically after all growth resolves")

	scene.undo_button.pressed.emit()
	check(scene.game.board == original_board and scene.cells == scene.game.piece().cells, "Back restores board and refreshes the offered piece")
	check(scene.game.current_color == Rules.CORAL, "Back restores color")
	# Geometry is allowed even when a chosen color breaks every symmetry.
	scene.game.board = Rules.empty_board(9)
	for row: Array in scene.game.board:
		row.fill(Rules.BLUE)
	scene.game.board[1][2] = 0
	scene.game.queue[scene.game.index] = "Dot"
	scene.game.current_color = Rules.CORAL
	scene.cells = Rules.PIECES.Dot.cells
	scene.game._refresh_over()
	scene._clear_selection()
	scene._refresh()
	touch(scene, source_point(scene, Vector2i.ZERO), true)
	drag(scene, board_point(scene, Vector2i(2, 1)))
	touch(scene, board_point(scene, Vector2i(2, 1)), false)
	check(not scene.floating_piece.valid and not scene.place_button.disabled, "symmetry-breaking physical fit remains placeable with gray warning")
	check(not scene.indicators[0].icon.available.any(func(value): return value), "reflection graphic previews loss of every axis")
	check(not scene.indicators[1].icon.available.any(func(value): return value), "rotation graphic previews loss of every rotation")
	scene.place_button.pressed.emit()
	check(scene.game.lost and scene.game.over, "confirming symmetry conflict ends game")
	scene.undo_button.pressed.emit()
	check(not scene.game.over, "Back reopens a lost game")
	check(not scene.board_view.growing and scene.board_view.pattern.board == scene.game.board, "Back cancels pending decoration after a loss")
	scene.blue_button.pressed.emit()
	touch(scene, source_point(scene, Vector2i.ZERO), true)
	drag(scene, board_point(scene, Vector2i(2, 1)))
	touch(scene, board_point(scene, Vector2i(2, 1)), false)
	check(scene.floating_piece.valid, "color switch allows safe placement")
	scene.place_button.pressed.emit()
	check(scene.game.no_space and not scene.game.lost, "safe final cell completes garden")
	scene.undo_button.pressed.emit()
	check(not scene.game.over, "Back reopens completed garden")
	scene.requested_size = 11
	scene._reset()
	for i in range(3):
		await process_frame
	check(scene.game.board.size() == 11, "11 by 11 reset works")
	var original_window_size := root.size
	root.size = Vector2i(390, 844)
	for i in range(4):
		await process_frame
	check(scene.board_view.get_global_rect().end.y <= scene.get_viewport_rect().size.y, "resized board remains entirely visible")
	check(scene.place_button.get_global_rect().end.y <= scene.get_viewport_rect().size.y, "Place stays docked after resize")
	root.size = original_window_size
	scene.requested_size = 9
	scene._reset()
	for i in range(4):
		await process_frame
	# Edge dragging stays within the same non-scrolling screen.
	var edge: Vector2 = Vector2(scene.get_viewport_rect().size.x / 2, scene.get_viewport_rect().size.y - 90)
	var first_cell: Vector2i = scene.cells[0]
	touch(scene, source_point(scene, first_cell), true)
	touch(scene, Vector2.ZERO, false, 1)
	check(scene.dragging, "another finger cannot release the active drag")
	drag(scene, edge)
	var board_before: Vector2 = scene.board_view.position
	scene._process(0.15)
	check(scene.board_view.position == board_before, "edge dragging never scrolls the field")
	touch(scene, edge, false)
	check(scene.has_hover and not scene.dragging, "release after scrolling preserves hover")
	# A ghost covering the dock must not steal a Place or Back button press.
	check(not scene._start_drag(scene.place_button.get_global_rect().get_center(), 0), "fixed dock has priority over floating drag hits")
	scene._clear_selection()
	scene._preview()
	for i in range(3):
		await process_frame
	# Mouse gestures use the same routed input path as touch.
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.position = source_point(scene, first_cell)
	root.push_input(mouse_press, true)
	check(scene.dragging, "mouse press picks up source piece")
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = board_point(scene, Vector2i(2, 2) + first_cell)
	root.push_input(mouse_move, true)
	mouse_press = mouse_press.duplicate()
	mouse_press.pressed = false
	mouse_press.position = mouse_move.position
	root.push_input(mouse_press, true)
	check(scene.has_hover and not scene.dragging and scene.game.moves == 0, "mouse release also hovers without committing")
	scene._clear_selection()
	scene._preview()
	# All content must stay visible, including on short and landscape screens.
	check(scene.find_children("*", "ScrollContainer", true, false).is_empty(), "screen contains no scrolling containers")
	check(scene.find_children("*", "Label", true, false).is_empty(), "screen contains no titles, instructions, or commentary labels")
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(360, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(640, 360), Vector2i(240, 320)]:
		root.size = dimensions
		for i in range(4):
			await process_frame
		var bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1)
		for control: Control in scene._controls() + [scene.board_view, scene.piece_view, scene.indicators[0].panel, scene.indicators[1].panel]:
			check(bounds.encloses(control.get_global_rect()), "every element fits " + str(dimensions))
		check(absf(scene.board_view.size.x - scene.board_view.size.y) < 1, "board remains square at " + str(dimensions))
		for first in range(scene._controls().size()):
			for second in range(first + 1, scene._controls().size()):
				check(not scene._controls()[first].get_global_rect().intersects(scene._controls()[second].get_global_rect()), "controls do not overlap at " + str(dimensions))
	root.size = original_window_size
	for i in range(4):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/tiles-godot.png")
	scene.queue_free()
	await process_frame
	print("UI: %d checks, %d failures (drag, hover, summaries, placement, undo, resize)" % [checks, failures])
	quit(1 if failures else 0)
