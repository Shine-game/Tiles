extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const Visuals = preload("res://scripts/clockwork_visuals.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Palette.select_theme("clockwork")
	var model := Clock.new()
	var visuals := Visuals.new()
	root.add_child(visuals)
	visuals.hide()
	var center := Vector2i(4, 4)
	for color in [1, 2]:
		for mask in range(16):
			var board: Array = Rules.empty_board(9)
			board[4][4] = color
			for d in range(4):
				if mask & (1 << d):
					var cell: Vector2i = center + Clock.DIRS[d]
					board[cell.y][cell.x] = color
			model.build(board, board)
			visuals.reconcile(model, true, false)
			var wheel := mask not in [5, 10]
			check(Clock.connection_mask(board, center) == mask, "Connectivity covers every shape in both colors")
			for id: String in ["C01", "C02", "C03"]:
				var key := Clock.key(id, color, center)
				check(model.components.has(key) == wheel and visuals.registry.has(key) == wheel, "Only straight cells omit the entire wheel assembly")
			check(visuals.core_angles.has(center) == wheel, "Straight cells have no phantom wheel motion")
			for d in range(4):
				var key := Clock.key("T01_" + Clock.NAMES[d], color, center)
				check(model.components.has(key) == bool(mask & (1 << d)), "Tubes still follow every same-color connection")
				if model.components.has(key):
					check(visuals.registry[key].node.flip_v == (not wheel and d in [2, 3]), "Straight shading stays aligned and resets for bends/endpoints")
			if DisplayServer.get_name() != "headless" and not wheel:
				await check_tube_join(visuals, color, center, mask)
	check(not Clock.has_wheel(Rules.empty_board(9), center), "An empty cell cannot carry a wheel")
	var mixed: Array = Rules.empty_board(9)
	mixed[4][4] = 1
	mixed[4][3] = 1
	mixed[4][5] = 2
	check(Clock.has_wheel(mixed, center) and Clock.connection_mask(mixed, center) == 8, "A different color cannot turn an endpoint into a straight")
	# Adding a branch must build a new wheel even when the cell itself is old.
	var before: Array = Rules.empty_board(9)
	for x in range(3, 6): before[4][x] = 1
	model.build(before, before)
	visuals.reconcile(model, true, false)
	var after: Array = before.duplicate(true)
	after[3][4] = 1
	model.build(before, after)
	visuals.reconcile(model, false, true)
	for id: String in ["C01", "C02", "C03"]:
		var key := Clock.key(id, 1, center)
		check(model.components.has(key) and not model.components[key].old, "Straight-to-T promotes the old cell with newly assembled wheel parts")
	visuals.advance(model.duration + 1)
	model.build(after, before)
	visuals.reconcile(model, true, true, true)
	visuals.advance(2)
	check(not visuals.registry.has(Clock.key("C02", 1, center)) and not visuals.core_angles.has(center), "Removing the branch retires the wheel and its motion")
	for n in [9, 11]:
		var dense: Array = Rules.empty_board(n)
		for row: Array in dense: row.fill(1)
		model.build(dense, dense)
		check(model.mechanisms.size() == (n - 1) * (n - 1), "Dense mechanism detection is unchanged")
		for cell: Vector2i in model.powered:
			check(model.components.has(Clock.key("C02", 1, cell)), "Every 2x2 mechanism keeps all supporting wheels")
	visuals.queue_free()
	await process_frame
	await check_game()
	print("Clockwork wheel rule: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_tube_join(visuals, color: int, center: Vector2i, mask: int) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for d in range(4):
		if not mask & (1 << d): continue
		var source: Sprite2D = visuals.registry[Clock.key("T01_" + Clock.NAMES[d], color, center)].node
		var copy := Sprite2D.new()
		copy.texture = source.texture
		copy.rotation = source.rotation
		copy.flip_v = source.flip_v
		copy.texture_filter = source.texture_filter
		copy.position = Vector2(128, 128)
		view.add_child(copy)
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	var source_pixels: Image = visuals.registry[Clock.key("T01_" + ("E" if mask == 10 else "N"), color, center)].node.texture.get_image()
	var continuous := true
	var difference := 0.0
	for across in range(80, 177):
		var a := pixels.get_pixel(127, across) if mask == 10 else pixels.get_pixel(across, 127)
		var b := pixels.get_pixel(128, across) if mask == 10 else pixels.get_pixel(across, 128)
		# Preserve the source art's existing translucent highlight detail, while
		# rejecting any extra gap introduced by the exposed center join.
		var expected_alpha := source_pixels.get_pixel(128, across).a
		continuous = continuous and absf(a.a - b.a) <= 1.01 / 255.0 and absf(a.a - expected_alpha) <= 1.01 / 255.0
		difference = maxf(difference, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	check(continuous, "GPU straight join preserves the original tube coverage without added gaps")
	check(difference <= 1.01 / 255.0, "GPU straight tube shading matches across the center seam")
	view.queue_free()
	await process_frame

func check_game() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for cell: Vector2i in [Vector2i(5, 4), Vector2i(6, 4)]:
		scene.game.queue[scene.game.index] = "Dot"
		scene.game.current_color = 1
		scene.cells = [Vector2i.ZERO]
		scene.selected = cell
		scene.has_hover = true
		scene._refresh()
		scene._place()
		scene.board_view.advance_growth(100)
	var middle_key := Clock.key("C02", 1, Vector2i(5, 4))
	check(scene.game.moves == 2 and not scene.board_view.clockwork_visuals.registry.has(middle_key), "Extending an endpoint into a straight removes its wheel in the actual game")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://build/clockwork-wheel-rule")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/clockwork-wheel-rule/straight.png")
	scene._undo()
	scene.board_view.advance_growth(100)
	check(scene.board_view.clockwork_visuals.registry.has(middle_key), "Undo restores the endpoint wheel")
	scene.game.queue[scene.game.index] = "Dot"
	scene.game.current_color = 1
	scene.cells = [Vector2i.ZERO]
	scene.selected = Vector2i(6, 4)
	scene.has_hover = true
	scene._refresh()
	scene._place()
	scene.board_view.advance_growth(100)
	scene._erase(Vector2i(6, 4))
	scene.board_view.advance_growth(100)
	check(scene.board_view.clockwork_visuals.registry.has(middle_key), "Erase restores the endpoint wheel")
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
