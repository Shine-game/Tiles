extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	_run.call_deferred()
func wait_frames(seconds: float) -> void:
	var end := Time.get_ticks_msec() + ceili(seconds * 1000)
	while Time.get_ticks_msec() < end:
		await process_frame
func block(width: int, height: int, color: int = 1, size: int = 9) -> Array:
	var result: Array = Rules.empty_board(size)
	for y in range(height):
		for x in range(width):
			result[y + 2][x + 2] = color
	return result
func _run() -> void:
	check(Palette.clockwork and Palette.theme_id() == "clockwork" and Palette.THEMES[0] == "clockwork", "Clockwork is the initial and first theme")
	var model = Clock.new()
	var empty: Array = Rules.empty_board(9)
	for color in [1, 2]:
		for mask in range(16):
			var grid: Array = empty.duplicate(true)
			grid[4][4] = color
			for d in range(4):
				if mask & (1 << d):
					var p: Vector2i = Vector2i(4, 4) + Clock.DIRS[d]
					grid[p.y][p.x] = color
			model.build(empty, grid)
			for d in range(4):
				check(model.components.has(Clock.key("T01_" + Clock.NAMES[d], color, Vector2i(4, 4))) == bool(mask & (1 << d)), "all sixteen same-color arm topologies")
	model.build(empty, block(2, 2))
	check(model.mechanisms.size() == 1 and model.chains.is_empty(), "one 2x2 creates one mechanism without a chain")
	check(model.powered.size() == 4 and not model.mechanisms.values()[0].has("cap"), "only the four supporting wheels activate; unchained axle has no finishing terminal")
	for shape: Vector2i in [Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 4)]:
		model.build(empty, block(shape.x, shape.y))
		check(model.mechanisms.size() == (shape.x - 1) * (shape.y - 1), "every eligible overlapping 2x2 is derived")
		check(model.chains.size() == (shape.x - 2) * (shape.y - 1) + (shape.y - 2) * (shape.x - 1), "all immediate orthogonal mechanism neighbors are linked once")
		for chain: Dictionary in model.chains.values():
			check(absi(chain.a.x - chain.b.x) + absi(chain.a.y - chain.b.y) == 1, "no diagonal chains")
			check(chain.start >= maxf(model.mechanisms[chain.a].ready, model.mechanisms[chain.b].ready), "chains wait until both axles are ready")
		for mechanism: Dictionary in model.mechanisms.values():
			check(mechanism.get("cap", "") == Clock.cap_for(mechanism.directions), "cap depends on connection shape rather than position")
			check(mechanism.cap_end >= mechanism.chain_end, "terminal finishes the third tier after its chains")
	check(Clock.cap_for([Vector2i.LEFT]) == "H00_plain_hatch", "one chain has plain cap")
	check(Clock.cap_for([Vector2i.LEFT, Vector2i.RIGHT]) == "H01_valve", "straight pair has valve")
	check(Clock.cap_for([Vector2i.UP, Vector2i.RIGHT]) == "H02_rotating", "corner pair has rotating cap")
	check(Clock.cap_for(Clock.DIRS) == "H03_exhaust", "three/four chains have exhaust")
	var mixed: Array = block(4, 2)
	for y in range(2, 4):
		for x in range(4, 6): mixed[y][x] = 2
	model.build(empty, mixed)
	check(model.mechanisms.size() == 2 and model.chains.is_empty(), "different metals do not form mechanical links")
	model.build(empty, block(3, 3))
	check(model.powered[Vector2i(3, 3)].size() == 4, "overlapping mechanisms share one core with four supports")
	var couplings := 0
	for event: Dictionary in model.components.values():
		if event.id == "T03": couplings += 1
	check(couplings == 12, "one boundary coupling per unordered neighboring pair")
	var hole: Array = block(3, 3)
	hole[3][3] = 0
	var outline = Clock.new()
	outline.build(hole, hole)
	var inner: Dictionary = outline.pins.filter(func(pin: Dictionary): return pin.corner == Vector2(3, 3))[0]
	check(inner.support == Vector2i(3, 2), "concave rivets select the first actual perimeter support")
	var duration: float = model.duration
	model.build(block(3, 3), block(3, 3))
	check(model.duration == 0 and model.components.values().all(func(event: Dictionary): return event.old), "settled boards do not replay assembly")
	check(duration > 2.5 and duration < 4.0, "construction gate includes third-tier finishing without endless rotation")
	for size_choice in [9, 11]:
		var dense: Array = Rules.empty_board(size_choice)
		for row: Array in dense: row.fill(1)
		model.build(dense, dense)
		check(model.mechanisms.size() == (size_choice - 1) ** 2 and model.chains.size() == 2 * (size_choice - 1) * (size_choice - 2), "dense board topology is complete")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await wait_frames(0.10)
	var view = scene.board_view
	var visuals = view.clockwork_visuals
	check(view.clockwork and view.board_frame.is_present(), "default game loads workshop assets and walnut frame")
	check(view.surface_depth() == 4 and view.occupied_platform.depth_pixels == 4, "metal plates use four UI units of thickness")
	check(scene.sounds.workshop.active and scene.sounds.workshop.ticking.playing, "quiet clock ambience starts while idle")
	check(not scene.sounds.whisper.playing and not scene.sounds.reef.theme_active, "workshop does not play foliage or reef audio")
	var grid: Array = block(3, 3)
	grid[7][7] = 1
	scene.game.board = grid
	view.animate_growth(empty, grid)
	view.set_process(false)
	check(view.growing, "Place is gated while mechanism assembles")
	view.advance_growth(view.pattern.duration + 1)
	await wait_frames(0.15)
	check(not view.growing and visuals.motion_clock > 0, "ongoing operation never holds Place")
	check(visuals.core_angles[Vector2i(7, 7)] == 0, "unconnected wheels remain stationary")
	check(visuals.core_angles[Vector2i(3, 3)] < 0 and visuals.gear_angles[Vector2i(2, 2)] > 0, "supporting wheels and main gears turn in opposite directions")
	check(visuals.chain_nodes.size() == 4 and visuals.chain_nodes.values().all(func(entry: Dictionary): return entry.strips.size() == 2), "each chain uses exactly two batched link strips")
	var identity := Clock.key("C02", 1, Vector2i(3, 3))
	var instance: int = visuals.registry[identity].node.get_instance_id()
	var angle: float = visuals.core_angles[Vector2i(3, 3)]
	var erased: Array = grid.duplicate(true)
	erased[2][2] = 0
	scene.game.board = erased
	view.show_settled(erased, true)
	view.set_process(false)
	check(view.growing and view.pattern.dismantling, "Undo/Erase start a short reverse assembly")
	check(visuals.registry[identity].node.get_instance_id() == instance and is_equal_approx(visuals.core_angles[Vector2i(3, 3)], angle), "surviving shared core keeps its node and phase")
	check(view.pattern.duration < 0.7 and not visuals.retiring.is_empty(), "unsupported components dismantle more quickly than construction")
	view.advance_growth(1)
	check(not view.growing, "dismantling releases Place promptly")
	for i in range(6): visuals.puff(Vector2(4, 4), true)
	check(visuals.puffs.size() <= 2, "board-wide steam cap prevents clouding")
	var freeze: float = visuals.core_angles[Vector2i(3, 3)]
	paused = true
	await wait_frames(0.08)
	paused = false
	check(is_equal_approx(freeze, visuals.core_angles[Vector2i(3, 3)]), "pause freezes operating motion")
	# A helper must not finish unrelated pending construction.
	scene._reset()
	grid = block(3, 3)
	scene.game.board = grid
	view.animate_growth(empty, grid)
	view.set_process(false)
	view.advance_growth(0.18)
	var event_before: Dictionary = visuals.registry[identity].event
	var progress_before: float = visuals._progress(event_before, view.clock)
	erased = grid.duplicate(true)
	erased[2][2] = 0
	scene.game.board = erased
	view.show_settled(erased, true)
	view.set_process(false)
	check(is_equal_approx(visuals._progress(visuals.registry[identity].event, 0), progress_before), "Undo preserves the progress of supported construction")
	check(view.pattern.duration > visuals.retire_duration, "Place waits for remaining construction after a helper")
	view.advance_growth(view.pattern.duration + 1)
	# Construction puffs run independently of the future operating policy.
	visuals.puffs.clear()
	visuals.operating = false
	visuals.puff(Vector2(3, 3), true)
	await wait_frames(0.35)
	check(visuals.puffs.is_empty(), "construction steam resolves even while operation is disabled")
	visuals.operating = true
	freeze = visuals.core_angles[Vector2i(3, 3)]
	scene._select_theme("coral_reef")
	check(not visuals.visible and not scene.sounds.workshop.active, "theme change hides mechanisms and fades ticking")
	scene._select_theme("clockwork")
	check(not view.growing and view.pattern.duration == 0, "entering workshop derives completed state without construction replay")
	check(visuals.registry.has(identity) and is_equal_approx(visuals.core_angles[Vector2i(3, 3)], freeze), "returning to workshop preserves surviving phase")
	scene._reset()
	check(visuals.retiring.is_empty() and view.pattern.mechanisms.is_empty(), "reset removes stale mechanical schedules")
	scene.queue_free()
	await wait_frames(0.15)
	print("Clockwork: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
