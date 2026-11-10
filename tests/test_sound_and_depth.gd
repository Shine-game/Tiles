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
	check(not scene.sounds.active and not scene.sounds.whisper.playing, "idle garden is silent")
	check(scene.sounds.bells.size() == 5, "flower bells use five harmonious pitches")
	check(scene.sounds.whisper.stream.get_length() > 1, "foliage audio is loaded")
	check(scene.sounds.bells[0].stream.get_length() > 1, "bell audio is loaded")
	var before: Array = Rules.empty_board(9)
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		before[cell.y][cell.x] = Rules.BLUE
	var after: Array = before.duplicate(true)
	after[2][2] = Rules.BLUE
	scene.board_view.animate_growth(before, after)
	scene.board_view.set_process(false)
	check(scene.sounds.active and scene.sounds.whisper.playing, "growth starts the foliage whisper")
	check(scene.sounds.note_count == 0, "no bell before a flower opens")
	var flower: Dictionary = scene.board_view.pattern.flowers[Vector2i(2, 2)]
	var event_time: float = flower.start + Growth.FLOWER_POP * 0.12
	scene.board_view.advance_growth(event_time - 0.001)
	check(scene.sounds.note_count == 0, "bell waits for visible petal opening")
	scene.board_view.advance_growth(0.002)
	check(scene.sounds.note_count == 1, "new flower sounds once at opening")
	scene.board_view.advance_growth(0.01)
	check(scene.sounds.note_count == 1, "subsequent frames do not repeat the bell")
	scene.board_view.advance_growth(100)
	check(not scene.sounds.active, "resolved growth ends the whisper")
	# Beginning another move must cancel the old fade-out callback.
	scene.board_view.animate_growth(before, after)
	scene.board_view.set_process(false)
	await create_timer(0.16).timeout
	check(scene.sounds.active and scene.sounds.whisper.playing, "a previous fade cannot stop the next growth sound")
	scene.board_view.show_settled(before)
	check(not scene.sounds.active and not scene.sounds.whisper.playing, "Back or reset cancels foliage sound")
	for bell: AudioStreamPlayer in scene.sounds.bells:
		check(not bell.playing, "Back or reset cancels bell tails")
	# Restoring established flowers produces no sound events.
	scene.board_view.show_settled(after)
	scene.board_view.advance_growth(100)
	check(not scene.sounds.active, "restored flowers remain silent")
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
	scene.sounds.cancel()
	scene.queue_free()
	await create_timer(0.12).timeout
	await process_frame
	print("Sound/depth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
