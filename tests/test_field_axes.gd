extends SceneTree

const Palette = preload("res://scripts/palette.gd")
const Board = preload("res://scripts/board_view.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func click(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)

func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4): await process_frame
	check(not scene.board_view.show_axes and scene.board_view.axes_overlay == null, "axes are off by default")
	scene._show_menu("Difficulty")
	await process_frame
	check(scene.axes_button.visible and scene.axes_button.text == "Show axes on field: Off", "Difficulty contains the axes toggle")
	var original: Array = scene.game.board.duplicate(true)
	var original_game = scene.game
	click(scene.axes_button)
	check(scene.board_view.show_axes and scene.axes_button.button_pressed, "axes option enables the overlay immediately")
	check(scene.game == original_game and scene.game.board == original, "axes toggle preserves the current game")
	click(scene.menu_close)
	for theme: String in Palette.THEMES:
		scene._select_theme(theme)
		check(scene.board_view.show_axes, "axes preference survives theme changes")
		for n in [9, 11]:
			scene.requested_size = n
			scene._reset()
			scene.board_view.advance_growth(100)
			for dimensions: Vector2 in [Vector2(240, 320), Vector2(390, 844), Vector2(720, 1100), Vector2(844, 390)]:
				scene.size = dimensions
				scene._layout()
				var view = scene.board_view
				var overlay = view.axes_overlay
				check(overlay.visible and overlay.axes().size() == 4, "all four reflection axes remain visible for every theme, size and orientation")
				var rect := Rect2(view._point(Vector2.ZERO), Vector2.ONE * n * view.pitch)
				check(overlay.get_rect().is_equal_approx(rect), "axes align with the playing grid's raised surface")
				for axis: Array in overlay.axes():
					check(((axis[0] + axis[1]) / 2).is_equal_approx(overlay.size / 2), "each axis crosses the exact field center")
				check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "axes do not intercept tile input")
				check(overlay.z_index + view.z_index > scene.floating_piece.z_index, "axes draw above hovering tiles as well as placed artwork")
				var art = Board.new()
				art.show_guides = false
				art.complete_background = true
				art.show_axes = true
				art.size = Vector2(900, 900)
				root.add_child(art)
				art.show_settled(scene.game.board)
				check(art.axes_overlay == null or not art.axes_overlay.visible, "clean artwork cannot display axes even if accidentally enabled")
				art.queue_free()
				await process_frame
		if DisplayServer.get_name() != "headless":
			scene.size = Vector2(720, 1100)
			scene._layout()
			scene.board_view.show_settled(scene.game.board)
			scene.board_view.advance_growth(100)
			if scene.board_view.reef_water != null: scene.board_view.reef_water.freeze_phase(0)
			scene.board_view.show_axes = false
			var before: Image = await capture()
			scene.board_view.show_axes = true
			var after: Image = await capture()
			var overlay = scene.board_view.axes_overlay
			for axis: Array in overlay.axes():
				var changed := 0
				for i in range(10, 90):
					var point: Vector2i = Vector2i(overlay.global_position + axis[0].lerp(axis[1], i / 100.0))
					if not before.get_pixelv(point).is_equal_approx(after.get_pixelv(point)): changed += 1
				check(changed > 20, "native overlay visibly draws every axis on " + theme)
			var preview_dir := OS.get_environment("TILES_TEST_PREVIEW_DIR")
			if not preview_dir.is_empty():
				DirAccess.make_dir_recursive_absolute(preview_dir)
				after.save_png(preview_dir.path_join("axes-%s.png" % theme))
	# A real save must remain free of axes while the live preference stays enabled.
	scene._select_theme("vines")
	scene.requested_size = 9
	scene._reset()
	scene.board_view.show_axes = true
	if DisplayServer.get_name() != "headless":
		scene.gallery.directory = "user://axes-test-%d" % Time.get_ticks_usec()
		scene.indicators[0].panel.pressed.emit()
		while scene.saving: await process_frame
		var records: Array = scene.gallery.entries()
		check(records.size() == 1, "symmetric artwork saves with the overlay enabled")
		check(scene.board_view.show_axes and scene.board_view.axes_overlay.visible, "saving preserves the live overlay preference")
		var viewport := SubViewport.new()
		viewport.size = Vector2i(900, 900)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var art = Board.new()
		art.size = Vector2(900, 900)
		art.show_guides = false
		art.complete_background = true
		viewport.add_child(art)
		art.show_settled(scene.game.board)
		await process_frame
		await RenderingServer.frame_post_draw
		check(scene.gallery.picture(records[0]).get_image().get_data() == viewport.get_texture().get_image().get_data(), "saved PNG matches an axis-free artwork pixel for pixel")
		var fingerprint: String = scene._design_fingerprint()
		scene._toggle_axes()
		check(not scene.board_view.axes_overlay.visible and scene._design_fingerprint() == fingerprint, "disabling axes hides them without changing artwork identity")
		viewport.queue_free()
		for file: String in DirAccess.open(scene.gallery.directory).get_files():
			DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
		DirAccess.remove_absolute(scene.gallery.directory)
	else:
		scene._toggle_axes()
		check(not scene.board_view.axes_overlay.visible, "disabling axes hides all four lines immediately")
	scene.queue_free()
	await process_frame
	print("Field axes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
