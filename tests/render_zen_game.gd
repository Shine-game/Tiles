extends SceneTree

const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
const ROWS = ["000010000", "011111110", "010010010", "011111110", "100010000", "011111110", "010010010", "011111110", "000010000"]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	check(Palette.theme_id() == "zen_garden" and Palette.THEMES[0] == "zen_garden", "Zen is the default and first listed theme")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4): await process_frame
	check(scene.board_view.zen_garden and scene.zen_background.visible, "Main game uses Zen's board and full-screen background")
	check(scene.board_view.surface_depth() == 4 and scene.piece_view.get_node("PieceSlab").depth_pixels == 4, "Playing and incoming cells share the same lip")
	check(scene.theme_options[0].text.contains("Zen Garden"), "Existing Themes menu lists Zen first")
	check(scene.piece_view.get_node("PieceSlab/ZenSand").visible, "Incoming piece is a plain sand surface")
	DirAccess.make_dir_recursive_absolute("res://build/zen-game")
	await capture("new-game")
	for n: int in [9, 11]:
		for color in [1, 2]:
			var board: Array = Rules.empty_board(n)
			var offset := (n - 9) / 2
			for y in range(9):
				for x in range(9): board[y + int(offset)][x + int(offset)] = color if ROWS[y][x] == "1" else 0
			scene.game.board = board
			scene.game._refresh_over()
			scene.board_view.show_settled(board)
			scene._layout()
			scene._refresh()
			await capture("field-%d-%d" % [n, color])
			check(scene.board_view.zen_visuals.registry.size() == scene.board_view.pattern.arrivals.size(), "Zen decorates only occupied cells")
			check(scene.board_view.pattern.flowers.is_empty() and scene.board_view.pattern.components.is_empty(), "No borrowed Coral or vine artwork/events")
	var tees := Rules.empty_board(9)
	for i in range(4):
		var center: Vector2i = [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6)][i]
		tees[center.y][center.x] = 1
		var mask: int = preload("res://scripts/zen_geometry.gd").rotate_mask(11, i)
		for d in range(4):
			if mask & (1 << d):
				var cell: Vector2i = center + preload("res://scripts/zen_geometry.gd").OFFSETS[d]
				tees[cell.y][cell.x] = 1
	scene.game.board = tees
	scene.game._refresh_over()
	scene.board_view.show_settled(tees)
	scene._refresh()
	await capture("t-junctions")
	# Overlapping 2x2 landmarks share one sand surface and replace ordinary art.
	var unfinished := Rules.empty_board(9)
	for y in range(3, 5):
		for x in range(3, 6): unfinished[y][x] = 1
	scene.game.board = unfinished
	scene.board_view.show_settled(unfinished)
	scene._layout()
	scene._refresh()
	check(scene.board_view.zen_visuals.formation_cells.size() == 6 and scene.board_view.zen_visuals.landmarks.size() == 2, "Every eligible overlapping 2x2 has its landmark")
	for group: Node in scene.board_view.zen_visuals.registry.values():
		check(group.get_child_count() == 2, "Raked formations preserve their sand pattern under the lantern")
	check(scene.game.board == unfinished, "Landmarks do not change the logical board")
	await capture("overlapping-landmarks")
	unfinished[3][3] = 0
	unfinished[3][5] = 0
	scene.board_view.show_settled(unfinished, true)
	check(scene.board_view.zen_visuals.formation_cells.is_empty() and scene.board_view.zen_visuals.landmarks.is_empty(), "Removing formation support restores ordinary cells")
	scene._select_theme("coral_reef")
	check(not scene.board_view.zen_visuals.visible and not scene.zen_background.visible, "Changing theme hides Zen layers")
	scene._select_theme("zen_garden")
	check(scene.board_view.zen_visuals.visible and scene.game.moves == 0, "Selecting Zen uses the existing new-game flow")
	var original: Array = scene.game.board.duplicate(true)
	scene.game.queue[scene.game.index] = "Dot"
	scene.cells = [Vector2i.ZERO]
	scene.selected = Vector2i(4, 3)
	scene.has_hover = true
	scene._refresh()
	scene._place()
	check(scene.game.moves == 1 and scene.board_view.growing, "Place starts the normal game's Zen growth clock")
	scene.board_view.advance_growth(100)
	check(not scene.board_view.growing and scene.board_view.zen_visuals.pending.is_empty(), "Zen growth completes and unlocks placement")
	scene._undo()
	check(scene.game.board == original and scene.board_view.zen_visuals.registry.size() == 1, "Undo restores both the board and Zen decoration")
	scene._erase(Vector2i(4, 4))
	check(scene.game.board[4][4] == 0 and scene.board_view.zen_visuals.registry.is_empty(), "Erase removes the Zen tile and its decoration")
	scene._reset()
	scene._show_menu("Themes")
	await capture("themes")
	scene.palette_menu.hide()
	# Exercise the existing save button, with axes enabled in the live game.
	scene.board_view.show_axes = true
	scene.gallery.directory = "user://zen-game-test-%d" % Time.get_ticks_usec()
	if DisplayServer.get_name() != "headless":
		scene.indicators[0].panel.pressed.emit()
		while scene.saving: await process_frame
		var records: Array = scene.gallery.entries()
		check(records.size() == 1 and records[0].theme == "zen_garden", "Existing symmetry button saves Zen artwork")
		if not records.is_empty(): scene.gallery.picture(records[0]).get_image().save_png("res://build/zen-game/artwork.png")
	if DirAccess.dir_exists_absolute(scene.gallery.directory):
		for file: String in DirAccess.open(scene.gallery.directory).get_files():
			DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
		DirAccess.remove_absolute(scene.gallery.directory)
	root.content_scale_size = Vector2i(720, 1100)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(540, 825)
	await capture("phone")
	scene.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print("Zen main game: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://build/zen-game/%s.png" % name) == OK, "Saved game render " + name)
