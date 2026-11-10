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
	return scene.board_view.get_global_transform_with_canvas() * scene.board_view._floor_point(Vector2(cell) + Vector2(0.5, 0.5))

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
	check(scene.palette_options.size() == 5, "palette button offers exactly five pairs")
	check(scene.palette_button.get_global_rect().get_center().x > scene.get_viewport_rect().size.x * 0.8, "palette button is at top right")
	check(scene.palette_button.position.y < 30, "palette button sits at the top edge")
	check(absf(scene.piece_view.get_global_rect().get_center().x - scene.get_viewport_rect().size.x / 2) < 1, "active piece is centered at top")
	var unchanged_board: Array = scene.game.board.duplicate(true)
	for i in range(5):
		touch(scene, scene.palette_button.get_global_rect().get_center(), true)
		touch(scene, scene.palette_button.get_global_rect().get_center(), false)
		check(scene.palette_menu.visible, "touch opens palette choices")
		await process_frame
		touch(scene, scene.palette_options[i].get_global_rect().get_center(), true)
		touch(scene, scene.palette_options[i].get_global_rect().get_center(), false)
		check(Palette.selected_index == i and not scene.palette_menu.visible, "touch selects each palette and closes choices")
		check(scene.game.board == unchanged_board, "palette selection preserves logical cell colors")
		check(Palette.pigment(1) == Palette.tile(1) and Palette.blossom(1) == Palette.tile(2), "pure palette reaches vines and inverted flowers")
		for color: Color in Palette.PAIRS[i].colors:
			check(is_equal_approx(color.v, 1), "palette colors have full brightness")
			check(color == Color.WHITE or color.s > 0.7, "palette colors are saturated or pure snow white")
		if Palette.PAIRS[i].colors.has(Color.WHITE):
			check(Palette.dark() and Palette.floor_color().get_luminance() < 0.3, "snow-white artwork has a contrasting field")
	check(not Palette.select(-1) and not Palette.select(5), "invalid palette indices are rejected")
	scene._choose_palette(0)
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

	# A tap rotates; drag always translates, including after a stationary hold.
	scene.cells = Rules.PIECES.J.cells.duplicate()
	scene._refresh()
	var tap_point := source_point(scene, scene.cells[0])
	var gesture_cells: Array = scene.cells.duplicate()
	touch(scene, tap_point, true)
	touch(scene, tap_point + Vector2(2, 1), false)
	check(scene.cells == Rules.rotate(gesture_cells), "short tap rotates source by 90 degrees")
	check(not scene.has_hover and scene.game.moves == 0, "tap does not move or commit source")
	scene.cells = gesture_cells.duplicate()
	scene._refresh()
	tap_point = source_point(scene, scene.cells[0])
	touch(scene, tap_point, true)
	var canceled := InputEventScreenTouch.new()
	canceled.position = tap_point
	canceled.index = 0
	canceled.pressed = false
	canceled.canceled = true
	root.push_input(canceled, true)
	check(scene.cells == gesture_cells and not scene.dragging, "system-canceled touch never rotates")
	touch(scene, tap_point, true)
	scene.gesture_age = 0.5
	touch(scene, tap_point, false)
	check(scene.cells == gesture_cells and not scene.has_hover, "stationary long hold does nothing")
	touch(scene, tap_point, true)
	scene.gesture_age = 0.5
	drag(scene, board_point(scene, Vector2i(2, 2)))
	touch(scene, board_point(scene, Vector2i(2, 2)), false)
	check(scene.cells == gesture_cells and scene.has_hover, "drag after a hold still moves without rotating")
	scene._clear_selection()
	scene._preview()
	check(is_equal_approx(scene.place_button.size.y, scene.flip_button.size.y * 2), "Place is twice normal button height")
	check(scene.board_view.position.y <= scene.piece_view.get_rect().end.y + 13, "field sits directly below header")
	for palette_index in range(5):
		Palette.select(palette_index)
		check(Palette.background() == Color.WHITE, "surrounding screen remains white in every palette")
	Palette.select(0)
	check(absf(scene.board_view.field.size.x - scene.get_viewport_rect().size.x) < 1, "board spans full phone width")
	check(scene.place_button.get_global_rect().position.x > scene.undo_button.get_global_rect().position.x, "Place is at bottom right")
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
		scene._rotate()
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
	var hover_anchor: Vector2i = scene.selected
	var floating_tap := board_point(scene, hover_anchor + placed_cells[0])
	touch(scene, floating_tap, true)
	touch(scene, floating_tap, false)
	check(scene.cells == Rules.rotate(placed_cells) and scene.selected == hover_anchor, "tap rotates hovering piece in place")
	check(scene.game.board == original_board and scene.has_hover, "hover rotation never commits")
	scene.cells = placed_cells.duplicate()
	scene._refresh()
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
	var growth_clock: float = scene.board_view.clock
	scene._choose_palette(1)
	check(scene.board_view.growing and is_equal_approx(scene.board_view.clock, growth_clock), "palette switching does not restart active growth")
	check(scene.place_button.disabled, "palette switching cannot bypass growth gate")
	scene._choose_palette(0)

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
	check(scene.indicators[0].icon.available.all(func(value): return value), "hover does not change committed possibilities")
	check(not scene.indicators[0].icon.complete.any(func(value): return value), "missing square does not light existing reflection")
	check(not scene.indicators[1].icon.complete.any(func(value): return value), "hover never lights a completed rotation")
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
		check(absf(scene.piece_view.get_global_rect().get_center().x - scene.get_viewport_rect().size.x / 2) < 1, "piece remains centered at " + str(dimensions))
		scene._toggle_palette_menu()
		await process_frame
		var menu_bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1)
		check(menu_bounds.encloses(scene.palette_menu.get_global_rect()), "palette choices fit without scrolling at " + str(dimensions))
		for option: Button in scene.palette_options + [scene.theme_button, scene.size_picker, scene.new_button, scene.gallery_button]:
			check(menu_bounds.encloses(option.get_global_rect()), "every palette row is visible at " + str(dimensions))
		scene.palette_menu.hide()
		var bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1)
		for control: Control in scene._controls() + [scene.board_view, scene.piece_view, scene.indicators[0].panel, scene.indicators[1].panel]:
			check(bounds.encloses(control.get_global_rect()), "every element fits " + str(dimensions))
		check(absf(scene.board_view.size.x - scene.board_view.size.y) < 1, "board remains square at " + str(dimensions))
		for first in range(scene._controls().size()):
			for second in range(first + 1, scene._controls().size()):
				check(not scene._controls()[first].get_global_rect().intersects(scene._controls()[second].get_global_rect()), "controls do not overlap at " + str(dimensions))
	# Helpers are routed through native buttons; erasing is armed then confirmed on a square.
	scene.requested_size = 9
	scene._reset()
	var before_skip: Array = scene.game.board.duplicate(true)
	var offered: String = scene.game.queue[scene.game.index]
	touch(scene, scene.skip_button.get_global_rect().get_center(), true)
	touch(scene, scene.skip_button.get_global_rect().get_center(), false)
	check(scene.game.skip_left == 2 and scene.game.board == before_skip and scene.game.queue[scene.game.index] != offered, "native skip button spends one use and changes only offer")
	touch(scene, scene.erase_button.get_global_rect().get_center(), true)
	touch(scene, scene.erase_button.get_global_rect().get_center(), false)
	check(scene.erase_mode and scene.place_button.disabled, "erase helper arms square selection and blocks Place")
	touch(scene, board_point(scene, Vector2i.ZERO), true)
	touch(scene, board_point(scene, Vector2i.ZERO), false)
	check(scene.erase_mode and scene.game.erase_left == 3, "empty selection does not waste eraser")
	touch(scene, board_point(scene, Vector2i(4, 4)), true)
	touch(scene, board_point(scene, Vector2i(4, 4)), false)
	check(not scene.erase_mode and scene.game.erase_left == 2 and scene.game.board == Rules.empty_board(9), "erase removes original square and exits selection")
	check(not scene._can_save(), "empty board cannot be saved")
	check(not scene.indicators[0].icon.complete.any(func(value): return value), "empty board does not glow")
	scene._toggle_erase()
	scene._toggle_erase()
	check(not scene.erase_mode and scene.game.erase_left == 2, "canceling erase is free")
	scene.game.board = Rules.empty_board(9)
	scene.game.board[1][2] = Rules.BLUE
	scene._refresh()
	check(not scene._can_save() and not scene.indicators[0].icon.complete.any(func(value): return value) and scene.indicators[0].icon.available.all(func(value): return value), "possible symmetry stays dim when not yet present")
	scene.game.board[1][6] = Rules.BLUE
	scene._refresh()
	check(scene._can_save() and scene.indicators[0].icon.complete[0], "symmetric partial board lights save even with empty spaces")
	for row: Array in scene.game.board:
		row.fill(Rules.BLUE)
	scene.game.queue[scene.game.index] = ""
	scene.game._refresh_over()
	scene._refresh()
	check(scene.game.over and scene._can_save() and scene.indicators[1].icon.complete.all(func(value): return value), "full completed garden keeps save available")
	scene._open_gallery()
	check(scene.gallery_panel.visible, "gallery is available through settings")
	scene.gallery_panel.hide()
	scene._reset()
	check(scene.game.undo_left == 3 and scene.game.skip_left == 3 and scene.game.erase_left == 3, "restart resets helper uses")
	root.size = Vector2i(720, 1100)
	for i in range(4):
		await process_frame
	scene.cells = Rules.PIECES.J.cells
	scene._refresh()
	check(absf(scene.piece_view.geometry().unit - 51) < 0.01, "normal source squares grow from 34 to 51 pixels, exactly 50 percent")
	check(absf((scene.piece_view.geometry().unit - 4 * scene.piece_view.geometry().scale) - 45) < 0.01, "filled square and its gap scale together by 50 percent")
	scene.cells = Rules.rotate(Rules.PIECES.I.cells)
	scene._refresh()
	check(absf(scene.piece_view.geometry().unit - 39) < 0.01, "vertical I grows from 26 to 39 pixels without clipping")
	root.size = original_window_size
	scene.cells = scene.game.piece().cells
	scene._refresh()
	for i in range(4):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/tiles-godot.png")
	scene.queue_free()
	await process_frame
	print("UI: %d checks, %d failures (drag, hover, summaries, placement, undo, resize)" % [checks, failures])
	quit(1 if failures else 0)
