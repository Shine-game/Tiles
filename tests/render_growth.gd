# Optional visual review tool. Run on a graphical display; output is ignored by Git.
extends SceneTree

const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4):
		await process_frame
	var dense: bool = OS.get_cmdline_user_args().has("--dense")
	var before: Array = Rules.create_board(9)
	for y in range(1, 3):
		for x in range(3, 6):
			before[y][x] = Rules.BLUE
	for y in range(5, 8):
		for x in range(3, 6):
			before[y][x] = Rules.CORAL
	if dense:
		scene.requested_size = 11
		scene._reset()
		before = _dense_board()
		for x in range(4, 7):
			before[2][x] = 0
	scene.game.board = before
	scene.game.queue[scene.game.index] = "I3"
	scene.game.current_color = Rules.BLUE
	scene.game._refresh_over()
	scene.cells = Rules.PIECES.I3.cells
	scene.selected = Vector2i(4, 2) if dense else Vector2i(3, 3)
	scene.has_hover = true
	scene._refresh()
	var prefix: String = "dense-growth" if dense else "growth"
	DirAccess.make_dir_recursive_absolute("res://build/" + prefix + "-frames")
	FileAccess.open("res://build/.gdignore", FileAccess.WRITE).close()
	for i in range(48):
		if i == 6:
			scene._place()
			scene.board_view.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/%s-frames/%03d.png" % [prefix, i])
		if i >= 6:
			scene.board_view.advance_growth(1.0 / 30.0)
	root.get_texture().get_image().save_png("res://build/" + prefix + "-preview.png")
	print("Captured 48 frames; Place triggered the new growth. Resolved: ", not scene.board_view.growing)
	scene.queue_free()
	await process_frame
	quit()

# A representative near-filled board with neighboring color networks, open
# placement pockets, isolated motifs, and both dense and sparse foliage.
func _dense_board() -> Array:
	var grid: Array = Rules.create_board(11)
	for left: int in [0, 8]:
		for top: int in [0, 7]:
			for y in range(top, top + 4):
				for x in range(left, left + 3):
					grid[y][x] = Rules.BLUE
	for x in range(2, 9):
		grid[2][x] = Rules.BLUE
		grid[5][x] = Rules.BLUE
	for y in range(2, 9):
		grid[y][2] = Rules.BLUE
		grid[y][8] = Rules.BLUE
		grid[y][5] = Rules.BLUE
	for x in range(2, 9):
		grid[0][x] = Rules.CORAL
	for y in range(2):
		for x in range(4, 7):
			grid[y][x] = Rules.CORAL
	for left: int in [3, 6]:
		for y in range(3, 5):
			for x in range(left, left + 2):
				grid[y][x] = Rules.CORAL
		for y in range(7, 11):
			for x in range(left, left + 2):
				grid[y][x] = Rules.CORAL
	for x in range(4, 7):
		grid[9][x] = Rules.CORAL
	for left: int in [0, 9]:
		for x in range(left, left + 2):
			grid[4][x] = Rules.CORAL
			grid[6][x] = Rules.CORAL
		grid[5][1 if left == 0 else 9] = Rules.CORAL
	grid[5][0] = Rules.BLUE
	grid[5][10] = Rules.BLUE
	return grid
