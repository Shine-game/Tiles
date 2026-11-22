extends SceneTree

const Palette = preload("res://scripts/palette.gd")
const Session = preload("res://scripts/game_session.gd")
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
	return scene.piece_view.get_global_transform_with_canvas() * (layout.origin + (Vector2(scene.piece_view.display_cell(cell)) + Vector2(0.5, 0.5)) * layout.unit)

func click_button(button: Button) -> void:
	if DisplayServer.get_name() == "headless":
		check(not button.disabled, "Button wiring is enabled")
		button.pressed.emit()
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = true
		root.push_input(event,true)
		await process_frame
		event.pressed = false
		root.push_input(event,true)
	await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Palette.select_theme("vines")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4):
		await process_frame
	check(scene.palette_options.size() == 5, "palette button offers exactly five pairs")
	check(scene.palette_button.get_global_rect().get_center().x > scene.get_viewport_rect().size.x * 0.8, "palette button is at top right")
	check(scene.palette_button.position.y >= scene._layout_insets(scene.size).y, "settings is safely inset from the screen's top edge")
	check(absf(scene.piece_view.get_global_rect().get_center().x - scene.get_viewport_rect().size.x / 2) < 0.1, "active piece is centered at top")
	var unchanged_board: Array = scene.game.board.duplicate(true)
	for option: Button in scene.theme_options:
		await click_button(scene.palette_button)
		check(scene.palette_menu.visible and scene.menu_page == "Settings", "Settings opens from the game")
		await click_button(scene.settings_options[0])
		check(scene.menu_page == "Themes", "Themes opens inside the same menu")
		await click_button(option)
		check(Palette.theme_id() == option.get_meta("theme_id") and scene.menu_page == "Themes" and not scene.confirmation.visible, "Each available theme applies directly before play")
		check(scene.game.board == unchanged_board, "Theme choice preserves the initial board")
		scene._close_menu()
	Palette.select_theme("vines")
	for i in range(5):
		check(Palette.select(i), "Existing palette data remains valid")
		check(Palette.pigment(1) == Palette.tile(1) and Palette.blossom(1) == Palette.tile(2), "Pure palette reaches vines and inverted flowers")
		for color: Color in Palette.PAIRS[i].colors:
			check(is_equal_approx(color.v, 1), "Palette colors have full brightness")
			check(color == Color.WHITE or color.s > 0.7, "Palette colors are saturated or pure snow white")
		check(Palette.floor_color() == Color("FFF9F3"), "Artwork palettes retain the authored pale empty tiles")
	check(not Palette.select(-1) and not Palette.select(5), "invalid palette indices are rejected")
	scene._choose_palette(0)
	check(scene.indicators.size() == 1, "one combined symmetry graphic")
	check(scene.indicators[0].icon.available == [true, true, true, true, true, true, true], "reflection graphic lights all four initial axes")
	check(scene.indicators[0].icon.available.slice(4) == [true, true, true], "rotation graphic initially available")
	var partial: Array = Rules.empty_board(9)
	partial[1][1] = Rules.BLUE
	partial[1][7] = Rules.BLUE
	partial[7][1] = Rules.CORAL
	partial[7][7] = Rules.CORAL
	scene._update_summaries(partial)
	check(scene.indicators[0].icon.available == [true, false, false, false, false, false, false], "each axis is highlighted independently")
	check(not scene.indicators[0].icon.available.slice(4).any(func(value): return value), "rotation graphic is off when all rotations conflict")
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
	check(is_equal_approx(scene.place_button.size.x, scene.place_button.size.y) and is_equal_approx(scene.flip_button.size.x, scene.flip_button.size.y) and is_equal_approx(scene.place_button.size.x, scene.place_button.size.y), "Place and Flip remain square buttons")
	check(scene.board_view.position.y >= scene.piece_view.get_rect().end.y, "field sits below header without overlap")
	for palette_index in range(5):
		Palette.select(palette_index)
		check(Palette.background() == Palette.floor_color(), "Vines repaints the surrounding screen with its palette")
	Palette.select(0)
	check(scene.board_view.field.size.x <= scene.get_viewport_rect().size.x, "board fits the phone width")
	check(scene.place_button.get_global_rect().position.x > scene.undo_button.get_global_rect().position.x, "Place is at bottom right")
	check(scene.place_button.get_global_rect().end.y <= scene.get_viewport_rect().size.y, "Place dock stays within screen")
	scene.game.queue[scene.game.index] = "J"
	scene.cells = Rules.PIECES.J.cells
	scene._refresh()
	scene.blue_button.pressed.emit()
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
	check(not scene.floating_piece.valid and not scene.place_button.disabled, "off-field hover cannot be placed")
	# The tray is gone after moving: regrab the floating piece to restore a valid hover.
	touch(scene, off_field, true)
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
	check(not scene.place_button.disabled and not scene._action_available("place",{}), "Place remains pressable but cannot place during growth")
	var committed_moves: int = scene.game.moves
	scene._place()
	check(scene.game.moves == committed_moves, "controller rejects early placement even without a button click")
	var committed_flowers: int = scene.board_view.pattern.flowers.size()
	var growth_clock: float = scene.board_view.clock
	scene._choose_palette(1)
	check(scene.board_view.growing and is_equal_approx(scene.board_view.clock, growth_clock), "palette switching does not restart active growth")
	check(not scene.place_button.disabled and not scene._action_available("place",{}), "palette switching cannot bypass growth gate")
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
	check(not scene.floating_piece.valid and not scene.place_button.disabled, "symmetry-breaking physical fit remains placeable")
	check(not scene.indicators[0].icon.available.any(func(value): return value), "hover predicts destruction of all symmetries")
	check(not scene.indicators[0].icon.complete.any(func(value): return value), "missing square does not light existing reflection")
	check(not scene.indicators[0].icon.complete.slice(4).any(func(value): return value), "symmetry-breaking hover does not light rotations")
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
	check(scene.find_children("*", "ScrollContainer", true, false).all(func(control): return not control.is_visible_in_tree()), "Gameplay has no visible scrolling containers")
	check(not scene.menu_title.is_visible_in_tree(), "menu title is hidden during play")
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(360, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(640, 360), Vector2i(240, 320)]:
		root.size = dimensions
		for i in range(4):
			await process_frame
		check(absf(scene.piece_view.get_global_rect().get_center().x - scene.get_viewport_rect().size.x / 2) < 0.1, "piece remains centered at " + str(dimensions))
		scene._show_menu("Themes")
		await process_frame
		var menu_bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1)
		check(menu_bounds.encloses(scene.palette_menu.get_global_rect()), "palette choices fit without scrolling at " + str(dimensions))
		for option: Button in scene.theme_options + [scene.back_button]:
			check(menu_bounds.encloses(option.get_global_rect()), "every palette row is visible at " + str(dimensions))
		scene.palette_menu.hide()
		var bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1)
		for control: Control in scene._controls() + [scene.board_view, scene.piece_view, scene.indicators[0].panel]:
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
	await click_button(scene.skip_button)
	check(scene.game.skip_left == 2 and scene.game.board == before_skip and scene.game.queue[scene.game.index] != offered, "native skip button spends one use and changes only offer")
	await click_button(scene.erase_button)
	check(scene.erase_mode and not scene.place_button.disabled and not scene._action_available("place",{}), "erase helper arms square selection and blocks Place")
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
	check(scene.game.over and scene._can_save() and scene.indicators[0].icon.complete.slice(4).all(func(value): return value), "full completed garden keeps save available")
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
	check(scene.piece_view.geometry().unit <= scene.board_view.pitch, "source cells fit within board pitch")
	check(scene.piece_view.geometry().unit <= scene.board_view.pitch, "source preview fits its header")
	scene.cells = Rules.rotate(Rules.PIECES.I.cells)
	scene._refresh()
	check(scene.piece_view.geometry().unit <= scene.board_view.pitch, "vertical I fits the header")
	scene._clear_selection()
	scene._preview()
	var tall_cells: Array = scene.cells.duplicate()
	var tray_cells: Array = scene.piece_view.display_cells()
	for index in range(tall_cells.size()):
		var point := source_point(scene, tall_cells[index])
		check(scene.piece_view.cell_at(scene.piece_view.get_global_transform_with_canvas().affine_inverse() * point) == tall_cells[index], "sideways preview maps each square to the original piece")
	var tray_grab: Vector2i = tall_cells.back()
	var displayed_grab: Vector2i = tray_cells.back()
	check(scene._start_drag(source_point(scene, tray_grab), -1), "tall tray piece can be picked up")
	scene._move_gesture(board_point(scene, Vector2i(2, 2) + displayed_grab))
	check(scene.cells == tray_cells and scene.grabbed_cell == displayed_grab, "drag adopts the sideways tray orientation and keeps the grabbed square")
	check(scene.selected == Vector2i(2, 2), "sideways tray piece lands at the requested anchor")
	scene.dragging = false
	scene._rotate()
	check(scene.cells == Rules.rotate(tray_cells), "hovering piece rotates in its displayed orientation")
	scene._clear_selection()
	root.size = original_window_size
	scene.cells = scene.game.piece().cells
	scene._refresh()
	for i in range(4):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/tiles-godot.png")
	# Pressable controls must still leave unavailable actions entirely inert.
	scene.game.undo_left = 0
	scene.game.skip_left = 0
	scene.game.erase_left = 0
	scene.cells = []
	scene._clear_selection()
	scene._refresh()
	var unchanged := JSON.stringify(Session.pack(scene.game))
	for button: Button in scene._controls():
		check(not button.disabled, "All main-game buttons remain pressable")
	for button: Button in [scene.flip_button,scene.blue_button,scene.place_button,scene.undo_button,scene.skip_button,scene.erase_button]:
		button.pressed.emit()
		check(JSON.stringify(Session.pack(scene.game)) == unchanged and scene.cells.is_empty() and not scene.erase_mode, "Unavailable button press changes no piece, board, history or joker")
	scene.game.over = true
	scene._refresh()
	unchanged = JSON.stringify(Session.pack(scene.game))
	for button: Button in [scene.flip_button,scene.blue_button,scene.place_button,scene.skip_button]:
		check(not button.disabled, "Game-over controls remain pressable")
		button.pressed.emit()
		check(JSON.stringify(Session.pack(scene.game)) == unchanged, "Game-over piece actions do nothing")

	scene.queue_free()
	await process_frame
	print("UI: %d checks, %d failures (drag, hover, summaries, placement, undo, resize)" % [checks, failures])
	quit(1 if failures else 0)
