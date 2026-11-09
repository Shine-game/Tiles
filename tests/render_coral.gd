extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	Palette.select_theme("coral_reef")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var rows: Array = ["000010000", "011101110", "011101110", "000010000", "111111111", "000010000", "022202220", "022202220", "000010000"]
	var board: Array = Rules.empty_board(9)
	for y in range(9):
		for x in range(9):
			board[y][x] = int(rows[y][x])
	# One final square closes two neighboring 2x2 colonies and their reef shelf.
	board[2][6] = 0
	scene.game.board = board
	scene.game.queue[scene.game.index] = "Dot"
	scene.game.current_color = 1
	scene.game._refresh_over()
	scene.cells = Rules.PIECES.Dot.cells
	scene.selected = Vector2i(6, 2)
	scene.has_hover = true
	scene._refresh()
	DirAccess.make_dir_recursive_absolute("res://build/coral-frames")
	for frame in range(75):
		if frame == 6:
			scene._place()
			scene.board_view.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/coral-frames/%03d.png" % frame)
		if frame >= 6:
			scene.board_view.advance_growth(1.0 / 30.0)
	root.get_texture().get_image().save_png("res://build/coral-preview.png")
	if scene.board_view.growing or not scene._can_save():
		push_error("Coral did not reach a savable symmetric final state")
		quit(1)
		return
	scene.gallery.directory = "user://coral-preview-%d" % Time.get_ticks_usec()
	await scene._save_design()
	var entries: Array = scene.gallery.entries()
	if entries.size() != 1 or entries[0].theme != "coral_reef":
		push_error("Coral gallery save failed")
		quit(1)
		return
	scene.gallery.picture(entries[0]).get_image().save_png("res://build/coral-artwork.png")
	# Verify persistent component reconciliation after the saved placement is undone.
	var preserved: Dictionary = scene.board_view.coral_visuals.ordinals.duplicate()
	scene._undo()
	if scene.board_view.pattern.unions.size() != 3:
		push_error("Undo failed to reconcile coral shelves")
		quit(1)
		return
	for name: String in DirAccess.open(scene.gallery.directory).get_files():
		DirAccess.remove_absolute(scene.gallery.directory.path_join(name))
	DirAccess.remove_absolute(scene.gallery.directory)
	print("Coral shader, growth, gallery, and undo rendered successfully; saved order entries: ", preserved.size())
	scene.queue_free()
	await create_timer(0.12).timeout
	quit()
