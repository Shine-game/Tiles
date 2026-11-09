extends SceneTree

const Coral = preload("res://scripts/coral_growth.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Gallery = preload("res://scripts/gallery.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func board_from(cells: Array, n: int = 9) -> Array:
	var board: Array = Rules.empty_board(n)
	for cell: Array in cells:
		board[int(cell[1])][int(cell[0])] = 1 if cell[2] == "salmon" else 2
	return board

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var spec := Coral.specification()
	check(spec.components.size() == 38, "32 growing components plus six ground variants")
	for id: String in spec.components:
		var meta: Dictionary = spec.components[id]
		for variant: String in ["salmon", "turquoise"]:
			var texture: Texture2D = load(Coral.ROOT + meta.artwork[variant])
			check(texture != null and texture.get_size() == Vector2(meta.size_px[0], meta.size_px[1]), "native dimensions " + id + "/" + variant)
		if not id.begins_with("ground_"):
			check(ResourceLoader.exists(Coral.ROOT + meta.reveal_mask), "growth field " + id)
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/coral_redesign_scenarios.json"))
	var model = Coral.new()
	for fixture: Dictionary in fixtures:
		var n: int = fixture.get("board_size", 9)
		var before: Array = board_from(fixture.before_cells, n)
		var after: Array = board_from(fixture.after_cells, n)
		model.build(before, after)
		check(model.colonies.size() == int(fixture.expected_colony_count), fixture.id + ": expected colony count")
		check(model.unions.size() == int(fixture.expected_anemone_count), fixture.id + ": expected anemone count")
		for join: Dictionary in fixture.expected_joins:
			var a := Vector2i(int(join.origins[0][0]), int(join.origins[0][1]))
			var b := Vector2i(int(join.origins[1][0]), int(join.origins[1][1]))
			check(model.unions.values().any(func(event: Dictionary): return (event.a == a and event.b == b) or (event.a == b and event.b == a)), fixture.id + ": join at supplied pair")
		for event: Dictionary in model.unions.values():
			check(absi(event.a.x - event.b.x) + absi(event.a.y - event.b.y) == 1, fixture.id + ": no diagonal or intervening-colony joins")
		for event: Dictionary in model.components.values():
			if event.id.begins_with("ground_"):
				check(event.old and event.instant, fixture.id + ": occupied ground is immediate")
	for y in range(-3, 4):
		for x in range(-3, 4):
			var layout := Coral.union_layout(Vector2i(x, y))
			check(not layout.is_empty() == (absi(x) + absi(y) == 1), "immediate-neighbor predicate " + str(Vector2i(x, y)))
	var empty: Array = Rules.empty_board(9)
	var after: Array = empty.duplicate(true)
	after[4][4] = 1
	after[4][5] = 1
	model.build(empty, after)
	check(model.arrivals[Vector2i(4, 4)] == 0 and model.arrivals[Vector2i(5, 4)] == 0, "independent buds begin together")
	var before: Array = after.duplicate(true)
	before[4][4] = 0
	before[4][5] = 0
	before[4][3] = 1
	after[4][3] = 1
	model.build(before, after)
	check(is_equal_approx(model.arrivals[Vector2i(4, 4)], 0.2) and is_equal_approx(model.arrivals[Vector2i(5, 4)], 0.4), "outside growth propagates cell by cell")
	var inward: Dictionary = model.components[Coral.key("arm_w", 1, Vector2i(4, 4))]
	check(Coral.arrival(inward, 1) < Coral.arrival(inward, 0), "incoming arm enters from boundary")
	var outward: Dictionary = model.components[Coral.key("arm_e", 1, Vector2i(4, 4))]
	var finger: Dictionary = model.components[Coral.key("fingers_e_0", 1, Vector2i(4, 4))]
	var attachment: Dictionary = spec.components.fingers_e_0.animation.dependencies[0]
	check(is_equal_approx(finger.start, Coral.arrival(outward, attachment.at_mask_u) + attachment.delay_seconds), "fingers use supplied attachment values")
	var block: Array = Rules.empty_board(9)
	for y in range(2, 5):
		for x in range(2, 5):
			block[y][x] = 1
	before = block.duplicate(true)
	before[2][2] = 0
	model.build(before, block)
	check(model.colonies.size() == 4 and model.unions.size() == 4, "3x3 gives four colonies and four anemones")
	var origin := Vector2i(2, 2)
	var body: Dictionary = model.components[Coral.key("colony_body", 1, origin)]
	var fold: Dictionary = model.components[Coral.key("colony_fold_ne", 1, origin)]
	check(is_equal_approx(fold.start, Coral.arrival(body, 0) + 0.06), "folds branch from body attachment")
	for join: Dictionary in model.unions.values():
		if model.colonies[join.a].old and model.colonies[join.b].old:
			continue
		check(join.start >= maxf(model.colonies[join.a].end, model.colonies[join.b].end), "anemone waits for both complete colonies")
		var foot: Dictionary = model.components[join.feature + "/foot"]
		var disc: Dictionary = model.components[join.feature + "/disc"]
		check(is_equal_approx(disc.start, Coral.arrival(foot, 0) + 0.04), "disc follows foot center")
		for region in range(8):
			var crown: Dictionary = model.components[join.feature + "/region_%d" % region]
			check(is_equal_approx(crown.start, disc.end) and is_equal_approx(crown.stroke, 0.28), "all crown partitions share one schedule")
		check(model.duration >= join.end, "Place gate includes complete crown and reveal tail")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	scene._toggle_theme()
	scene._toggle_theme()
	check(Palette.theme_id() == "coral_reef" and Palette.theme_version() == "2.0", "third theme is redesigned Coral Reef")
	check(is_zero_approx(scene.board_view.surface_depth()) and scene.board_view.coral_visuals.position == scene.board_view._floor_point(Vector2.ZERO), "flat reef floor aligns exactly with placement grid")
	check(scene.game.moves == 0 and scene.game.undo_left == 3, "theme does not change gameplay or helper budgets")
	scene.game.board = block
	scene.board_view.show_settled(before)
	var core_key := Coral.key("core", 1, Vector2i(3, 3))
	var core: Sprite2D = scene.board_view.coral_visuals.registry[core_key]
	scene.board_view.animate_growth(before, block)
	scene.board_view.set_process(false)
	check(scene.board_view.growing and core.material == null, "old core remains settled during additions")
	check(scene.board_view.coral_visuals.registry[core_key] == core and core.scale == Vector2.ONE, "retained core uses supplied native proportions")
	var ground_key := Coral.key(Coral.ground_choice(origin).id, 1, origin)
	var ground: Sprite2D = scene.board_view.coral_visuals.registry[ground_key]
	check(ground.material == null, "new occupied ground does not wait for coral")
	for event: Dictionary in scene.board_view.pattern.components.values():
		var sprite: Sprite2D = scene.board_view.coral_visuals.registry[event.key]
		check(sprite.scale == Vector2.ONE, "no old scaling workaround: " + event.id)
		if event.id.begins_with("arm_") or event.id.begins_with("fingers_") or event.id.begins_with("junction_"):
			var used := Rect2(sprite.texture.get_image().get_used_rect())
			used.position -= Vector2(128, 128)
			var bounds := Rect2((event.center - Vector2(0.5, 0.5)) * 256, Vector2(256, 256)).grow(0.01)
			check(bounds.encloses(sprite.transform * used), "painted ordinary coral stays in its owning cell")
	scene.has_hover = true
	scene.selected = Vector2i(1, 2)
	scene.cells = Rules.PIECES.Dot.cells
	scene._preview()
	check(scene.place_button.disabled, "Place remains disabled during growth")
	var rim_point: Vector2 = scene.floating_piece.origin + Vector2(1, 1)
	check(scene._start_drag(rim_point, 0), "flat reef hover can be grabbed at its upper rim")
	scene._move_gesture(rim_point + Vector2(scene.board_view.pitch, 0))
	scene._finish_gesture(rim_point + Vector2(scene.board_view.pitch, 0))
	check(scene.selected == Vector2i(2, 2), "flat reef regrab preserves row and grabbed-cell offset")
	scene.board_view.advance_growth(scene.board_view.pattern.duration + 1)
	check(not scene.board_view.growing and scene.board_view.coral_visuals.active.is_empty(), "all crown layers resolve and release updates")
	var order: Dictionary = scene.board_view.coral_visuals.ordinals.duplicate()
	scene.board_view.show_settled(before, true)
	check(scene.board_view.pattern.colonies.size() == 3 and scene.board_view.pattern.unions.size() == 2, "erase removes only affected colonies and incident joins")
	check(scene.board_view.coral_visuals.registry[core_key] == core, "erase preserves surviving artwork")
	scene.board_view.show_settled(block, true)
	check(scene.board_view.coral_visuals.ordinals == order, "restoration preserves feature order")
	check(scene.board_view.coral_visuals.registry[ground_key].rotation == ground.rotation, "ground selection stays fixed after restoration")
	check(Gallery.fingerprint(block, 0, "coral_reef", "2.0") != Gallery.fingerprint(block, 0, "coral_reef"), "new art can be saved beside an old reef design")
	for dimensions: Vector2i in [Vector2i(240, 320), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		for frame in range(4):
			await process_frame
		scene._toggle_palette_menu()
		await process_frame
		check(Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1).encloses(scene.palette_menu.get_global_rect()), "settings fit " + str(dimensions))
		scene.palette_menu.hide()
	# Cancel additions through real helper/controller flows.
	for action: String in ["undo", "erase", "reset"]:
		scene._reset()
		scene.game.board = before.duplicate(true)
		scene.game.queue[scene.game.index] = "Dot"
		scene.game._refresh_over()
		scene.cells = Rules.PIECES.Dot.cells
		scene.board_view.show_settled(scene.game.board, true)
		scene.selected = origin
		scene.has_hover = true
		scene._refresh()
		scene._place()
		scene.board_view.set_process(false)
		check(scene.board_view.growing, "growth exists before " + action)
		if action == "undo":
			scene._undo()
		elif action == "erase":
			scene._erase(origin)
		else:
			scene._reset()
		check(not scene.board_view.growing and scene.board_view.coral_visuals.active.is_empty(), action + " cancels pending layers")
		scene.board_view.advance_growth(10)
		check(scene.board_view.pattern.colonies.size() == (0 if action == "reset" else 3), action + " cannot resurrect removed coral")
	var dense: Array = Rules.empty_board(11)
	for row: Array in dense:
		row.fill(1)
	model.build(dense, dense)
	check(model.colonies.size() == 100 and model.unions.size() == 180, "dense 11x11 reef has exactly 180 immediate-neighbor joins")
	print("Dense reef v2: %d components, 100 colonies, 180 anemones" % model.components.size())
	scene.queue_free()
	await create_timer(0.12).timeout
	Palette.select_theme("vines")
	print("Coral v2: %d checks, %d failures (%d supplied scenarios)" % [checks, failures, fixtures.size()])
	quit(1 if failures else 0)
