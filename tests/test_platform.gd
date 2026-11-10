extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Palette.select_theme("vines")
	var platform = Platform.new()
	root.add_child(platform)
	var grid: Array = Rules.empty_board(9)
	platform.sync(grid)
	check(not platform.visible and not platform.filled(Vector2(4.5, 4.5)), "empty board is flat and emits no platform")
	grid[3][3] = 1
	platform.sync(grid)
	check(platform.visible and platform.filled(Vector2(3.5, 3.5)), "occupied square appears in mask immediately")
	check(platform.side_at(Vector2(3.5, 4.04)), "lower exposed edge has a downward wall")
	check(not platform.side_at(Vector2(3.5, 4.12)), "wall stops after exactly 24/256 of a cell")
	check(not platform.side_at(Vector2(3.5, 2.99)), "no upward extrusion")
	grid[4][3] = 2
	platform.sync(grid)
	check(not platform.side_at(Vector2(3.5, 4.04)), "adding a different-color neighbor removes the shared wall immediately")
	check(platform.side_at(Vector2(3.5, 5.04)), "merged surface extrudes only at new outer edge")
	var revision: int = platform.mask_revision
	grid[4][3] = 1
	platform.sync(grid)
	check(platform.mask_revision == revision, "player colors do not change occupancy or outline")
	grid[3][4] = 2
	platform.sync(grid)
	check(platform.side_at(Vector2(4.5, 4.04)) and not platform.side_at(Vector2(3.5, 4.04)), "stepped outline keeps only exposed lower segments")
	grid = Rules.empty_board(9)
	for y in range(2, 5):
		for x in range(2, 5):
			grid[y][x] = 1
	grid[3][3] = 0
	platform.sync(grid)
	check(platform.side_at(Vector2(3.5, 3.04)), "hole has an inward-facing lower wall at its upper boundary")
	check(not platform.filled(Vector2(3.5, 3.5)) and not platform.side_at(Vector2(3.5, 3.5)), "hole center stays open")
	grid[3][3] = 2
	platform.sync(grid)
	check(not platform.side_at(Vector2(3.5, 3.04)), "filling hole removes internal wall independent of color")
	grid[3][3] = 0
	platform.sync(grid)
	check(platform.side_at(Vector2(3.5, 3.04)), "removing a square restores hole immediately")
	for pitch: float in [20, 40, 60, 78.22, 120]:
		platform.configure(Vector2(20, 20), pitch, Color("edd7ad"))
		check(is_equal_approx(platform.depth_pixels / pitch, 24.0 / 256), "thickness stays 24 source pixels at every resolution")
		check(platform.position.y < platform.top_origin.y and platform.get_rect().end.y > 20 + 9 * pitch + platform.depth_pixels, "shader rectangle includes lower wall and transparent shadow")
	platform.queue_free()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	for theme: String in ["vines", "labyrinth", "coral_reef"]:
		scene._select_theme(theme)
		scene._reset()
		var view = scene.board_view
		check(is_equal_approx(view.surface_depth(), view.pitch * 24 / 256), theme + ": correct top elevation")
		var mask_before: int = view.occupied_platform.mask_revision
		scene.game.queue[scene.game.index] = "O"
		scene.cells = Rules.PIECES.O.cells
		scene.selected = Vector2i(2, 2)
		scene.has_hover = true
		scene._refresh()
		check(view.occupied_platform.mask_revision == mask_before, theme + ": hover never creates a platform")
		scene._place()
		view.set_process(false)
		check(view.growing and view.occupied_platform.filled(Vector2(2.5, 2.5)), theme + ": mask commits before growth finishes")
		mask_before = view.occupied_platform.mask_revision
		view.advance_growth(0.05)
		check(view.occupied_platform.mask_revision == mask_before, theme + ": growth clock does not rebuild mask")
		check(view._point(Vector2(2, 2)) == view._floor_point(Vector2(2, 2)) - Vector2(0, view.surface_depth()), theme + ": plants remain anchored to upper face")
		scene._undo()
		check(not view.occupied_platform.filled(Vector2(2.5, 2.5)), theme + ": Undo removes floor and wall immediately")
		scene.game.queue[scene.game.index] = "Dot"
		scene.game.restored_cells = []
		scene.cells = Rules.PIECES.Dot.cells
		scene.selected = Vector2i(4, 3)
		scene.has_hover = true
		scene._refresh()
		scene._place()
		view.set_process(false)
		scene._erase(Vector2i(4, 3))
		check(not view.occupied_platform.filled(Vector2(4.5, 3.5)), theme + ": Erase updates outline before animation")
		if theme == "coral_reef":
			check(view.coral_visuals.position == view.occupied_platform.top_origin, "coral ground and growth share shader top origin")
	for dimensions: Vector2 in [Vector2(390, 390), Vector2(720, 720), Vector2(900, 900), Vector2(1400, 1400)]:
		scene.board_view.size = dimensions
		scene.board_view.update_geometry()
		var canvas: Rect2 = scene.board_view.occupied_platform.get_rect()
		check(Rect2(Vector2.ZERO, dimensions).grow(0.01).encloses(canvas), "full raised outline fits board and gallery at " + str(dimensions))
	# All empty cells receive no surface after the original seed is erased.
	scene._reset()
	scene._erase(Vector2i(4, 4))
	check(not scene.board_view.occupied_platform.visible, "erasing final square returns to a completely flat board")
	scene.queue_free()
	# Allow the audio mixer to release stopped Ogg playback before shutdown.
	var mixer_deadline := Time.get_ticks_msec() + 120
	while Time.get_ticks_msec() < mixer_deadline:
		await process_frame
	Palette.select_theme("vines")
	print("Platform: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
