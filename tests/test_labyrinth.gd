extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Growth = preload("res://scripts/growth.gd")
const Maze = preload("res://scripts/labyrinth_growth.gd")
const Renderer = preload("res://scripts/labyrinth_renderer.gd")
const Palette = preload("res://scripts/palette.gd")
const Gallery = preload("res://scripts/gallery.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var block: Array = Rules.empty_board(9)
	for y in range(3):
		for x in range(3):
			block[y + 2][x + 2] = Rules.BLUE
	var maze = Maze.new()
	maze.build(block, block)
	check(maze.arrivals.size() == 9, "every ordinary square gets a pyramid center")
	check(maze.flowers.size() == 4 and maze.links.size() == 4, "3x3 block encloses four trees with four benches")
	check(maze.edges.size() == 12 and maze.openings.size() == 4, "four shared hedges open and eight outer hedges remain")
	for link: Dictionary in maze.links:
		var wall: Vector4i = Maze.shared_wall(link.a, link.b)
		check(maze.edges.any(func(edge: Dictionary): return Growth.edge_key(edge.a, edge.b) == wall), "bench replaces an actual enclosing wall")
		check(is_zero_approx(maze.wall_visibility(wall, 0)) and is_equal_approx(Maze.bench_progress(link, 0), 1), "settled shared wall is gone and bench exists")
		check(Maze.shared_wall(link.b, link.a) == wall, "shared wall is independent of pair order")
	var before: Array = block.duplicate(true)
	before[2][2] = 0
	maze.build(before, block)
	var new_links := 0
	for link: Dictionary in maze.links:
		if link.old:
			continue
		new_links += 1
		check(link.start >= maxf(maze.flowers[link.a].start, maze.flowers[link.b].start) + Growth.FLOWER_POP, "trees finish rising before shared wall opens")
		var wall: Vector4i = Maze.shared_wall(link.a, link.b)
		check(is_equal_approx(maze.wall_visibility(wall, link.start), 1), "shared wall starts intact")
		check(is_equal_approx(maze.wall_visibility(wall, link.start + Maze.WALL_RECEDE / 2), 0.5), "hedge recedes progressively")
		check(is_zero_approx(Maze.bench_progress(link, link.start + Maze.WALL_RECEDE)), "bench waits until wall disappears")
		check(is_equal_approx(Maze.bench_progress(link, maze.duration), 1), "Place gate includes complete bench rise")
	check(new_links == 2, "closing one corner creates two neighboring-tree transitions")
	var mixed: Array = Rules.empty_board(9)
	mixed[3][3] = Rules.BLUE
	mixed[3][4] = Rules.CORAL
	mixed[4][4] = Rules.BLUE
	maze.build(mixed, mixed)
	check(maze.edges.is_empty() and maze.flowers.is_empty() and maze.links.is_empty(), "corner and different-color contact never connect hedges")
	check(Renderer.HEDGE_WIDTH < 0.35, "hedges leave clear sandy paths between neighboring walls")
	check(Gallery.fingerprint(block, 0) != Gallery.fingerprint(block, 0, "labyrinth"), "same board in two themes has distinct gallery identity")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var original: Array = scene.game.board.duplicate(true)
	var original_piece: Array = scene.cells.duplicate()
	var original_offer: String = scene.game.queue[scene.game.index]
	scene._toggle_palette_menu()
	await process_frame
	var theme_touch := InputEventScreenTouch.new()
	theme_touch.position = scene.theme_button.get_global_rect().get_center()
	theme_touch.pressed = true
	root.push_input(theme_touch, true)
	theme_touch = theme_touch.duplicate()
	theme_touch.pressed = false
	root.push_input(theme_touch, true)
	check(Palette.labyrinth and scene.board_view.pattern is Maze, "settings switches to labyrinth renderer and schedule")
	check(scene.game.board == original and scene.cells == original_piece and scene.game.queue[scene.game.index] == original_offer, "theme switch preserves board, offer, and orientation")
	check(Palette.tile(1) == Palette.HEDGE_GREEN and Palette.tile(2) == Palette.HEDGE_ROSE, "piece swatches match green and rose hedge identities")
	check(Palette.floor_color() == Palette.SAND and Palette.background() == Color.WHITE, "sand covers paths and surrounding screen stays white")
	check(scene.palette_options.all(func(option): return not option.visible), "fixed green and rose theme hides unrelated vine palettes")
	for dimensions: Vector2i in [Vector2i(240, 320), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		for frame in range(4):
			await process_frame
		scene._toggle_palette_menu()
		await process_frame
		var bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1)
		check(bounds.encloses(scene.palette_menu.get_global_rect()), "labyrinth settings fit without scrolling at " + str(dimensions))
		for option: Control in [scene.theme_button, scene.size_picker, scene.new_button, scene.gallery_button]:
			check(bounds.encloses(option.get_global_rect()), "every labyrinth settings choice is visible")
		scene.palette_menu.hide()
	# Existing growth remains gated when changing visual themes mid-animation.
	scene.game.board = block
	scene.board_view.animate_growth(before, block)
	scene.board_view.set_process(false)
	scene.board_view.advance_growth(0.05)
	var growth_clock: float = scene.board_view.clock
	scene._select_theme("vines")
	check(not Palette.labyrinth and scene.board_view.growing and is_equal_approx(scene.board_view.clock, growth_clock), "switching to vines preserves current growth clock")
	scene.board_view.set_process(false)
	scene._toggle_theme()
	check(Palette.labyrinth and scene.board_view.growing and scene.board_view.pattern is Maze, "switching back retains scheduled tree and bench transitions")
	scene.board_view.set_process(false)
	scene.board_view.advance_growth(scene.board_view.pattern.duration + 1)
	check(not scene.board_view.growing, "labyrinth finishes only after benches resolve")
	scene.board_view.show_settled(before)
	check(scene.board_view.pattern.flowers.size() == 3, "removing a square removes its tree and restores appropriate hedge walls")
	scene._select_theme("vines")
	check(not Palette.labyrinth and scene.palette_options.all(func(option): return option.visible), "vine theme and all five palettes remain available")
	scene.queue_free()
	await create_timer(0.12).timeout
	print("Labyrinth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
