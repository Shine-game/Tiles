# Native visual review: real Place triggers hedge, tree, shared-wall, and bench growth.
extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	Palette.labyrinth = true
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var rows: Array = ["111222111", "111222111", "101020101", "101020101", "111222111", "221111122", "221010122", "221111122", "000010000"]
	var board: Array = Rules.empty_board(9)
	for y in range(9):
		for x in range(9):
			board[y][x] = int(rows[y][x])
	for cell: Vector2i in [Vector2i(6, 0), Vector2i(7, 0), Vector2i(6, 1), Vector2i(7, 1)]:
		board[cell.y][cell.x] = 0
	scene.game.board = board
	scene.game.queue[scene.game.index] = "O"
	scene.game.current_color = Rules.BLUE
	scene.game._refresh_over()
	scene.cells = Rules.PIECES.O.cells
	scene.selected = Vector2i(6, 0)
	scene.has_hover = true
	scene._refresh()
	DirAccess.make_dir_recursive_absolute("res://build/labyrinth-frames")
	FileAccess.open("res://build/.gdignore", FileAccess.WRITE).close()
	for frame in range(60):
		if frame == 6:
			scene._place()
			scene.board_view.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/labyrinth-frames/%03d.png" % frame)
		if frame >= 6:
			scene.board_view.advance_growth(1.0 / 30.0)
	root.get_texture().get_image().save_png("res://build/labyrinth-preview.png")
	# Save through the real gallery capture path, using isolated preview storage.
	scene.gallery.directory = "user://labyrinth-preview-%d" % Time.get_ticks_usec()
	await scene._save_design()
	var records: Array = scene.gallery.entries()
	if records.size() != 1 or records[0].theme != "labyrinth":
		push_error("Labyrinth gallery capture failed")
		quit(1)
		return
	scene.gallery.picture(records[0]).get_image().save_png("res://build/labyrinth-artwork.png")
	var folder := DirAccess.open(scene.gallery.directory)
	for name: String in folder.get_files():
		DirAccess.remove_absolute(scene.gallery.directory.path_join(name))
	DirAccess.remove_absolute(scene.gallery.directory)
	print("Captured labyrinth animation, resolved: ", not scene.board_view.growing, "; saved clean artwork")
	scene.queue_free()
	await create_timer(0.12).timeout
	quit()
