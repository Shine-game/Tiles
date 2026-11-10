# Optional visual review tool. Run on a graphical display; output is ignored by Git.
extends SceneTree

const Growth = preload("res://scripts/growth.gd")
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Palette.select_theme("vines")
	var explicit_palette := -1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--palette="):
			explicit_palette = arg.get_slice("=", 1).to_int()
			Palette.select(explicit_palette)
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
		for cell: Vector2i in [Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)]:
			before[cell.y][cell.x] = 0
	scene.game.board = before
	scene.game.queue[scene.game.index] = "O" if dense else "I3"
	scene.game.current_color = Rules.CORAL if dense else Rules.BLUE
	scene.game._refresh_over()
	scene.cells = Rules.PIECES.O.cells if dense else Rules.PIECES.I3.cells
	scene.selected = Vector2i(4, 0) if dense else Vector2i(3, 3)
	scene.has_hover = true
	scene._refresh()
	var prefix: String = "dense-growth" if dense else "growth"
	if explicit_palette >= 0:
		prefix += "-palette-%d" % explicit_palette
	DirAccess.make_dir_recursive_absolute("res://build/" + prefix + "-frames")
	FileAccess.open("res://build/.gdignore", FileAccess.WRITE).close()
	for i in range(90):
		if i == 6:
			scene._place()
			scene.board_view.set_process(false)
			_write_audio_events(scene, prefix)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/%s-frames/%03d.png" % [prefix, i])
		if i >= 6:
			scene.board_view.advance_growth(1.0 / 30.0)
	root.get_texture().get_image().save_png("res://build/" + prefix + "-preview.png")
	scene._toggle_palette_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + prefix + "-palettes.png")
	scene.palette_menu.hide()
	print("Captured 90 frames; Place triggered the new growth. Resolved: ", not scene.board_view.growing)
	scene.queue_free()
	await create_timer(0.12).timeout
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

func _write_audio_events(scene, prefix: String) -> void:
	var bells: Array = []
	for corner: Vector2i in scene.board_view.pattern.flowers:
		var flower: Dictionary = scene.board_view.pattern.flowers[corner]
		if not flower.old:
			var slot: int = posmod(corner.x + corner.y * 3, scene.sounds.PITCHES.size())
			bells.append({"time": 0.2 + flower.start + Growth.FLOWER_POP * 0.12, "pitch": scene.sounds.PITCHES[slot]})
	var data := {"duration": 3.0, "whisper_start": 0.2, "whisper_stop": 0.2 + scene.board_view.pattern.duration, "whisper_db": scene.sounds.WHISPER_DB, "bell_db": scene.sounds.BELL_DB, "bells": bells}
	var file := FileAccess.open("res://build/" + prefix + "-audio-events.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
