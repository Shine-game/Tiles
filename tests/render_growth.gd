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
	var before: Array = Rules.create_board(9)
	for y in range(1, 3):
		for x in range(3, 6):
			before[y][x] = Rules.BLUE
	for y in range(5, 8):
		for x in range(3, 6):
			before[y][x] = Rules.CORAL
	scene.game.board = before
	scene.game.queue[scene.game.index] = "I3"
	scene.game.current_color = Rules.BLUE
	scene.game._refresh_over()
	scene.cells = Rules.PIECES.I3.cells
	scene.selected = Vector2i(3, 3)
	scene.has_hover = true
	scene._refresh()
	DirAccess.make_dir_recursive_absolute("res://build/growth-frames")
	FileAccess.open("res://build/.gdignore", FileAccess.WRITE).close()
	for i in range(48):
		if i == 6:
			scene._place()
			scene.board_view.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/growth-frames/%03d.png" % i)
		if i >= 6:
			scene.board_view.advance_growth(1.0 / 30.0)
	root.get_texture().get_image().save_png("res://build/growth-preview.png")
	print("Captured 48 frames; Place triggered the new growth. Resolved: ", not scene.board_view.growing)
	scene.queue_free()
	await process_frame
	quit()
