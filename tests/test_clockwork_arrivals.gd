extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	_run.call_deferred()
func turn(point: Vector2i, count: int) -> Vector2i:
	for i in range(count): point = Vector2i(-point.y, point.x)
	return point + Vector2i(4, 4)
func wait_frames(seconds: float) -> void:
	var until := Time.get_ticks_msec() + ceili(seconds * 1000)
	while Time.get_ticks_msec() < until: await process_frame
func capture(viewport: Viewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func _run() -> void:
	Palette.select_theme("clockwork")
	var model = Clock.new()
	var before: Array
	var after: Array
	# Reproduce the sourced L-shaped placement in the phone recording, then
	# rotate it through every orientation and both logical colors.
	for color in [1, 2]:
		for rotation in range(4):
			before = Rules.empty_board(9)
			var source: Vector2i = turn(Vector2i(0, -1), rotation)
			before[source.y][source.x] = color
			after = before.duplicate(true)
			var path: Array[Vector2i] = []
			for offset: Vector2i in [Vector2i.ZERO, Vector2i.DOWN, Vector2i.ONE]:
				var cell := turn(offset, rotation)
				after[cell.y][cell.x] = color
				path.append(cell)
			model.build(before, after)
			var parent: Vector2i = source
			var expected := 0.435
			for cell: Vector2i in path:
				check(is_equal_approx(model.arrivals[cell], expected), "center arrival includes both tube halves, emission delay and reveal tail")
				var direction: int = Clock.DIRS.find(parent - cell)
				var arm: Dictionary = model.components[Clock.key("T01_" + Clock.NAMES[direction], color, cell)]
				var incoming_center: float = Clock.arm_arrival(arm, 0.0) + Clock.REVEAL_TAIL
				check(is_equal_approx(model.arrivals[cell], incoming_center), "center wakes exactly when its incoming tube is fully revealed there")
				for id: String in ["C01", "C02", "C03"]:
					var core: Dictionary = model.components[Clock.key(id, color, cell)]
					check(core.start >= incoming_center - 0.000001, "socket, gear and pin cannot precede incoming pressure")
				check(arm.start >= model.arrivals[cell] + Clock.CORE_EMIT_DELAY - 0.000001, "new center cannot emit an outward front before it wakes")
				var collar: Dictionary = model.components[Clock.key("T02_" + Clock.NAMES[direction], color, cell)]
				check(is_equal_approx(collar.start, Clock.arm_arrival(arm, 88.0 / 128.0) + Clock.REVEAL_TAIL), "collar timing follows tube arrival at its painted attachment")
				parent = cell
				expected += 0.585
	# Multiple entry fronts use the earliest arrival rather than serialized buds.
	before = Rules.empty_board(9)
	before[4][2] = 1
	before[4][6] = 1
	after = before.duplicate(true)
	for x in range(3, 6): after[4][x] = 1
	model.build(before, after)
	check(is_equal_approx(model.arrivals[Vector2i(3, 4)], 0.435) and is_equal_approx(model.arrivals[Vector2i(5, 4)], 0.435), "both old entry points grow simultaneously")
	check(is_equal_approx(model.arrivals[Vector2i(4, 4)], 1.020), "opposing fronts meet at the middle core without a duplicate activation")
	# Independent components keep the explicitly agreed simultaneous-start rule.
	before = Rules.empty_board(9)
	before[3][4] = 2
	after = before.duplicate(true)
	after[4][4] = 1
	after[5][4] = 1
	model.build(before, after)
	check(model.arrivals[Vector2i(4, 4)] == 0 and model.arrivals[Vector2i(4, 5)] == 0, "a different color does not create a pressure source")
	before[3][4] = 0
	before[3][3] = 1
	after = before.duplicate(true)
	after[4][4] = 1
	model.build(before, after)
	check(model.arrivals[Vector2i(4, 4)] == 0, "corner-only contact keeps independent budding")
	# Build a real sourced path, and assert its material remains invisible
	# until arrival and its finished incoming tube never disappears afterward.
	before = Rules.empty_board(9)
	before[3][4] = 1
	after = before.duplicate(true)
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 5)]: after[cell.y][cell.x] = 1
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await wait_frames(0.05)
	scene.game.board = before
	scene.board_view.show_settled(before)
	scene.game.board = after
	scene.board_view.animate_growth(before, after)
	var view = scene.board_view
	var visuals = view.clockwork_visuals
	view.set_process(false)
	visuals.set_process(false)
	var probe: SubViewport
	var sprite: Sprite2D
	if DisplayServer.get_name() != "headless":
		probe = SubViewport.new()
		probe.size = Vector2i(256, 256)
		probe.transparent_bg = true
		probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(probe)
		sprite = Sprite2D.new()
		sprite.position = Vector2(128, 128)
		probe.add_child(sprite)
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		var arrival: float = view.pattern.arrivals[cell]
		view.advance_growth(arrival - 0.06 - view.clock)
		for id: String in ["C01", "C02", "C03"]:
			var entry: Dictionary = visuals.registry[Clock.key(id, 1, cell)]
			var visible: float = float(entry.node.material.get_shader_parameter("rise")) if id != "C03" else entry.node.modulate.a
			check(visible == 0, "real new core parts are invisible before the tube reaches the center")
		if probe != null:
			var core: Sprite2D = visuals.registry[Clock.key("C02", 1, cell)].node
			sprite.texture = core.texture
			sprite.material = core.material
			var image: Image = await capture(probe)
			check(image.is_invisible(), "GPU core is fully transparent before incoming tube arrival")
		view.advance_growth(arrival + 0.15 - view.clock)
		if probe != null:
			var image: Image = await capture(probe)
			check(not image.is_invisible(), "GPU core rises only after incoming tube arrival")
		var incoming := "W" if cell == Vector2i(5, 5) else "N"
		var tube: Sprite2D = visuals.registry[Clock.key("T01_" + incoming, 1, cell)].node
		check(tube.material == null and tube.modulate.a == 1, "completed incoming tube stays visible before its later outward emission")
	view.advance_growth(view.pattern.duration + 1)
	check(not view.growing, "Place gate includes the recalculated downstream construction")
	if probe != null: probe.queue_free()
	scene.queue_free()
	await wait_frames(0.15)
	print("Clockwork arrivals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
