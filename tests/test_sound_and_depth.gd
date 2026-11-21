extends SceneTree

const Palette = preload("res://scripts/palette.gd")

const Rules = preload("res://scripts/rules.gd")
const Growth = preload("res://scripts/growth.gd")
const Surface = preload("res://scripts/tile_surface.gd")
const Floating = preload("res://scripts/floating_piece.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Palette.select_theme("vines")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4):
		await process_frame
	check(scene.sounds.ambience.playing and not scene.sounds.place_click.playing,"Idle board plays ambience without a placement click")
	var before: Array = Rules.empty_board(9)
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		before[cell.y][cell.x] = Rules.BLUE
	var after: Array = before.duplicate(true)
	after[2][2] = Rules.BLUE
	scene.board_view.animate_growth(before, after)
	scene.board_view.set_process(false)
	check(not scene.sounds.place_click.playing, "Growth animation alone never triggers a click")
	var flower: Dictionary = scene.board_view.pattern.flowers[Vector2i(2, 2)]
	scene.board_view.advance_growth(maxf(0,flower.start-0.001))
	check(not scene.sounds.place_click.playing, "No sound is scheduled before a flower appears")
	scene.board_view.advance_growth(0.002)
	check(not scene.sounds.place_click.playing, "Flowers form silently")
	scene.board_view.advance_growth(100)
	check(scene.sounds.ambience.playing and not scene.sounds.place_click.playing,"growth ends while ambience continues")
	scene.board_view.show_settled(before)
	check(not scene.sounds.place_click.playing, "Reset is silent")
	scene.board_view.show_settled(after)
	check(not scene.sounds.place_click.playing, "Restored flowers are silent")
	var cell := Vector2(1.5, 1.5)
	scene.board_view.update_geometry()
	var ground: Vector2 = scene.board_view._floor_point(cell)
	var garden: Vector2 = scene.board_view._point(cell)
	check(garden.y < ground.y and is_equal_approx(garden.x, ground.x), "garden artwork sits above the unfilled floor")
	check(is_equal_approx(ground.y - garden.y, scene.board_view.surface_depth()), "art and terrace use the same depth")
	scene.grabbed_cell = Vector2i.ZERO
	scene._drag_to(scene.board_view.get_global_transform_with_canvas() * ground)
	check(scene.selected == Vector2i(1, 1), "height does not change logical placement coordinates")
	for unit: float in [20, 45, 70, 120]:
		check(Surface.depth(unit) > 0 and Surface.depth(unit) < unit * 0.15, "tile thickness stays subtle at different sizes")
	var floating = Floating.new()
	floating.cells = Rules.PIECES.O.cells
	floating.origin = Vector2(100, 100)
	floating.pitch = 50
	var top: Vector2 = floating.origin - Vector2(0, Surface.depth(50))
	check(floating.cell_at(top + Vector2(4, 1)) == Vector2i.ZERO, "raised top edge remains a draggable part of the tile")
	check(floating.cell_at(top + Vector2(54, 51)) == Vector2i(1, 1), "raised non-anchor square keeps its grab offset")
	floating.free()
	scene.game.queue[scene.game.index] = "Dot"
	scene.cells = Rules.PIECES.Dot.cells
	scene.selected = Vector2i(2, 2)
	scene.has_hover = true
	scene._refresh()
	var rim: Vector2 = scene.board_view._floor_point(Vector2(2, 2)) + Vector2(scene.board_view.pitch / 2, 1 - scene.board_view.surface_depth())
	rim = scene.board_view.get_global_transform_with_canvas() * rim
	check(scene._start_drag(rim, 0), "raised top rim starts a normal drag")
	check(scene.selected == Vector2i(2, 2), "grabbing a raised top rim does not jump up a grid row")
	scene._clear_selection()
	scene.sounds.deactivate()
	await create_timer(0.1).timeout
	scene.queue_free()
	await create_timer(0.12).timeout
	await process_frame
	print("Sound/depth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
