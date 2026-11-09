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

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var spec := Coral.specification()
	check(spec.components.size() == 21, "all supplied component types are available")
	for id: String in spec.components:
		var meta: Dictionary = spec.components[id]
		for variant: String in ["salmon", "turquoise"]:
			var texture: Texture2D = load(Coral.ROOT + meta.artwork[variant])
			check(texture != null and texture.get_size() == Vector2(meta.size_px[0], meta.size_px[1]), "art dimensions " + id + "/" + variant)
		check(ResourceLoader.exists(Coral.ROOT + meta.reveal_mask), "mask present " + id)
	var before: Array = Rules.empty_board(9)
	var after: Array = before.duplicate(true)
	after[4][4] = 1
	var model = Coral.new()
	model.build(before, after)
	check(model.components.size() == 1 and model.arrivals[Vector2i(4, 4)] == 0, "isolated square grows one ordinary bud")
	after[4][5] = 1
	model.build(before, after)
	check(model.components.size() == 8, "independent domino has two buds, two half arms, and four details")
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(5, 4)]:
		check(is_zero_approx(model.arrivals[cell]), "all independent buds awaken together")
	before[4][3] = 1
	after[4][3] = 1
	model.build(before, after)
	check(is_equal_approx(model.arrivals[Vector2i(4, 4)], 0.2) and is_equal_approx(model.arrivals[Vector2i(5, 4)], 0.4), "growth travels square by square from outside coral")
	var inward: Dictionary = model.components[Coral.key("arm_w", 1, Vector2i(4, 4))]
	check(Coral.arrival(inward, 1) < Coral.arrival(inward, 0), "incoming half arm reveals edge before center")
	var outward: Dictionary = model.components[Coral.key("arm_e", 1, Vector2i(4, 4))]
	check(Coral.arrival(outward, 0) < Coral.arrival(outward, 1), "outgoing half arm reveals center before edge")
	var detail: Dictionary = model.components[Coral.key("detail_e_0", 1, Vector2i(4, 4))]
	check(is_equal_approx(detail.start, Coral.arrival(outward, 0.34) + 0.08), "detail grows after parent front reaches its attachment")
	before[4][6] = 1
	after[4][6] = 1
	model.build(before, after)
	check(is_equal_approx(model.arrivals[Vector2i(4, 4)], 0.2) and is_equal_approx(model.arrivals[Vector2i(5, 4)], 0.2), "both outside fronts are retained")
	check(model.components[Coral.key("arm_e", 1, Vector2i(3, 4))].two_fronts, "meeting fronts use one shared event per half arm")
	var mixed: Array = Rules.empty_board(9)
	mixed[3][3] = 1
	mixed[4][4] = 1
	mixed[3][4] = 2
	model.build(mixed, mixed)
	check(model.components.size() == 3 and model.colonies.is_empty(), "different colors and diagonal contact do not connect")
	var block: Array = Rules.empty_board(9)
	for y in range(2, 4):
		for x in range(2, 5):
			block[y][x] = 1
	before = block.duplicate(true)
	before[3][4] = 0
	model.build(before, block)
	check(model.colonies.size() == 2 and model.unions.size() == 1, "overlapping 2x2 colonies add a joining reef shelf")
	check(model.components.values().filter(func(event: Dictionary): return event.id == "core").size() == 6, "colonies retain constituent coral buds underneath")
	var colony: Dictionary = model.colonies[Vector2i(3, 2)]
	var finish: Dictionary = model.components[Coral.key("colony_finish", 1, Vector2i(3, 2))]
	var lobes: Dictionary = model.components[Coral.key("colony_lobes", 1, Vector2i(3, 2))]
	check(is_equal_approx(finish.start, lobes.end), "finishing glaze waits until folds are visible")
	var shelf: Dictionary = model.unions.values()[0]
	check(shelf.start >= colony.ready and model.duration >= shelf.end, "joining shelf and soft reveal tail are inside Place gate")
	check(is_equal_approx(shelf.end - shelf.start, 0.415), "two-ended shelf grows for 0.38 seconds plus soft tail")
	check(model.duration >= finish.end, "finishing glaze is included in growth completion")
	for y in range(-3, 4):
		for x in range(-3, 4):
			var delta := Vector2i(x, y)
			var expected: bool = delta != Vector2i.ZERO and ((absi(x) < 2 and absi(y) < 2) or (absi(x) == 2 and absi(y) < 2) or (absi(y) == 2 and absi(x) < 2))
			check(not Coral.union_layout(delta).is_empty() == expected, "canonical union eligibility " + str(delta))
			var layout := Coral.union_layout(delta)
			if not layout.is_empty():
				var definition: Dictionary = spec.reef_unions.canonical_layouts.filter(func(item: Dictionary): return item.id == layout.id)[0]
				var rotated := Vector2i(int(definition.colony_origin_delta[0]), int(definition.colony_origin_delta[1]))
				for turn in range(layout.rotation):
					rotated = Vector2i(-rotated.y, rotated.x)
				check(delta == rotated or delta == -rotated, "union canvas rotation matches actual colony displacement")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	scene._toggle_theme()
	check(Palette.theme_id() == "labyrinth", "first toggle retains labyrinth")
	scene._toggle_theme()
	check(Palette.theme_id() == "coral_reef" and scene.board_view.pattern is Coral, "second toggle selects third theme")
	var original: Array = scene.game.board.duplicate(true)
	var offered: Array = scene.cells.duplicate()
	scene._toggle_theme()
	check(Palette.theme_id() == "vines" and scene.game.board == original and scene.cells == offered, "third toggle returns to vines without resetting game")
	scene._select_theme("coral_reef")
	scene.game.board = block
	scene.board_view.show_settled(before)
	scene.board_view.animate_growth(before, block)
	scene.board_view.set_process(false)
	check(scene.board_view.coral_visuals.active.size() > 0 and scene.board_view.growing, "coral additions animate with independent materials")
	var old_key := Coral.key("core", 1, Vector2i(2, 2))
	var old_sprite: Sprite2D = scene.board_view.coral_visuals.registry[old_key]
	check(old_sprite.material == null, "old bud remains finished while new arms grow")
	scene.has_hover = true
	scene.selected = Vector2i(4, 1)
	scene.cells = Rules.PIECES.Dot.cells
	scene._preview()
	check(scene.place_button.disabled, "Place stays locked throughout coral growth")
	scene.board_view.advance_growth(scene.board_view.pattern.duration + 1)
	check(not scene.board_view.growing and scene.board_view.coral_visuals.active.is_empty(), "finished reef releases shader updates and placement gate")
	check(scene.board_view.coral_visuals.registry[old_key] == old_sprite, "old coral sprite identity survives growth")
	var order: Dictionary = scene.board_view.coral_visuals.ordinals.duplicate()
	scene.board_view.show_settled(before, true)
	check(scene.board_view.pattern.colonies.size() == 1 and scene.board_view.pattern.unions.is_empty(), "erasing square removes invalid colony and joining shelf")
	check(scene.board_view.coral_visuals.registry[old_key] == old_sprite, "erasure preserves valid underlying coral")
	scene.board_view.show_settled(block, true)
	check(scene.board_view.coral_visuals.ordinals == order, "undo and replay retain feature creation order")
	scene.board_view.show_settled(before, true)
	scene.board_view.animate_growth(before, block)
	scene.board_view.set_process(false)
	var reborn_key := Coral.key("colony", 1, Vector2i(3, 2))
	check(scene.board_view.coral_visuals.ordinals[reborn_key] > int(order[reborn_key]), "a genuinely new placement appends a re-grown colony above established features")
	scene.board_view.advance_growth(scene.board_view.pattern.duration + 1)
	for dimensions: Vector2i in [Vector2i(240, 320), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		for frame in range(4):
			await process_frame
		scene._toggle_palette_menu()
		await process_frame
		var bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size).grow(1)
		check(bounds.encloses(scene.palette_menu.get_global_rect()), "coral settings stay on screen " + str(dimensions))
		check(scene.palette_options.all(func(option): return not option.visible), "coral uses the supplied two fixed variants")
		scene.palette_menu.hide()
	check(Gallery.fingerprint(block, 0, "coral_reef") != Gallery.fingerprint(block, 0, "vines"), "coral gallery identity is independent")
	scene._reset()
	check(scene.board_view.coral_visuals.registry.size() == 1 and scene.board_view.coral_visuals.active.is_empty(), "reset cancels reef and starts with ordinary core")
	# Actual helper/controller flows invalidate in-flight branches and shelves.
	for action: String in ["undo", "erase", "reset"]:
		scene._reset()
		scene.game.board = before.duplicate(true)
		scene.game.queue[scene.game.index] = "Dot"
		scene.game._refresh_over()
		scene.cells = Rules.PIECES.Dot.cells
		scene.board_view.show_settled(scene.game.board, true)
		scene.selected = Vector2i(4, 3)
		scene.has_hover = true
		scene._refresh()
		scene._place()
		scene.board_view.set_process(false)
		check(scene.board_view.growing and scene.board_view.pattern.unions.size() == 1, "pending shelf exists before " + action)
		if action == "undo":
			scene._undo()
		elif action == "erase":
			scene._erase(Vector2i(4, 3))
		else:
			scene._reset()
		check(not scene.board_view.growing and scene.board_view.coral_visuals.active.is_empty(), "in-flight coral is canceled by " + action)
		check(scene.board_view.pattern.unions.is_empty(), "invalid shelf removed after " + action)
		scene.board_view.advance_growth(10)
		check(scene.board_view.pattern.unions.is_empty(), "canceled work cannot reappear after " + action)
	# Worst-case topology derives every valid feature without arbitrary truncation.
	var dense: Array = Rules.empty_board(11)
	for row: Array in dense:
		row.fill(1)
	model.build(dense, dense)
	check(model.colonies.size() == 100 and model.unions.size() > 500, "dense 11x11 reef keeps overlapping colonies and all pairwise shelves")
	print("Dense reef: %d components, %d colonies, %d shelves" % [model.components.size(), model.colonies.size(), model.unions.size()])
	scene.queue_free()
	await create_timer(0.12).timeout
	Palette.select_theme("vines")
	print("Coral: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
