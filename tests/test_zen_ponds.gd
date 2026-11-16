extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Model = preload("res://scripts/zen_growth.gd")
const Visuals = preload("res://scripts/zen_visuals.gd")
const Pond = preload("res://scripts/zen_pond.gd")
const Landmark = preload("res://scripts/zen_landmark.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func block(w: int, h: int, color: int = 2, n: int = 9) -> Array:
	var board := Rules.empty_board(n)
	for y in range(h):
		for x in range(w): board[y + 2][x + 2] = color
	return board
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Palette.select_theme("zen_garden")
	var model := Model.new()
	var visuals := Visuals.new()
	root.add_child(visuals)
	for color in [1, 2]:
		for size in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
			var board := block(size.x, size.y, color)
			model.build(board, board)
			visuals.reconcile(model, true)
			var expected: int = 0 if color == 1 else 2 * ((size.x - 2) * (size.y - 1) + (size.y - 2) * (size.x - 1))
			check(model.ponds.size() == expected, "Only adjacent rock formations activate the facing water sectors")
			check(visuals.pond.regions.size() == expected and visuals.pond.plants.size() == expected * 2, "Every active watershed has two shoreline groups")
	# A single-tile-wide path between separate 2x2s is not a third-tier join.
	var separate := block(2, 2)
	for y in range(2, 4):
		for x in range(5, 7): separate[y][x] = 2
	separate[2][4] = 2
	model.build(separate, separate)
	check(model.colonies.size() == 2 and model.ponds.is_empty(), "A long ordinary path does not invent adjacent formations")
	var before := block(2, 2)
	var after := block(3, 2)
	model.build(before, after)
	visuals.reconcile(model, false)
	var pond = visuals.pond
	var pond_id := pond.get_instance_id()
	var event: Dictionary = model.ponds.values()[0]
	check(event.start >= model.colonies[Vector2i(2, 2)].ready and event.start >= model.colonies[Vector2i(3, 2)].ready, "Water waits for both rocky landmarks")
	check(pond.plants.values().all(func(p): return p.sprite.modulate.a == 0), "Shoreline plants start hidden")
	visuals.advance(event.start + Pond.FILL_SECONDS * 0.5)
	check(pond.regions.values().all(func(r): return r.sprite.material.get_shader_parameter("amount") > 0 and r.sprite.material.get_shader_parameter("amount") < 1), "Water advances through the supplied masks")
	check(pond.plants.values().all(func(p): return p.sprite.modulate.a == 0), "Plants wait for water to finish")
	visuals.advance(model.duration)
	check(pond.plants.values().all(func(p): return p.sprite.modulate.a == 1), "Place waits until shoreline growth completes")
	var old_nodes: Dictionary = {}
	for key: String in pond.plants: old_nodes[key] = {"id": pond.plants[key].sprite.get_instance_id(), "position": pond.plants[key].sprite.position}
	var expanded := block(3, 3)
	model.build(after, expanded)
	visuals.reconcile(model, false)
	check(visuals.pond.get_instance_id() == pond_id, "Expansion retains the pond layer")
	for key: String in old_nodes:
		check(pond.plants[key].sprite.get_instance_id() == old_nodes[key].id and pond.plants[key].sprite.position == old_nodes[key].position and pond.plants[key].sprite.modulate.a == 1, "Existing shore plants remain in place and visible")
	for key: String in ["2/2/1", "2/3/3"]:
		check(pond.regions[key].sprite.material.get_shader_parameter("amount") == 1, "Existing water never restarts when territory expands")
	model.build(before, before)
	visuals.reconcile(model, true)
	check(pond.regions.is_empty() and pond.plants.is_empty() and not pond.visible, "Undo/Erase remove unsupported water and vegetation")
	for n in [9, 11]:
		var dense := Rules.empty_board(n)
		for row: Array in dense: row.fill(2)
		model.build(dense, dense)
		visuals.reconcile(model, true)
		check(model.ponds.size() == 4 * (n - 1) * (n - 2), "Dense boards activate only cardinal neighbors")
		check(pond.mask_view.size == Vector2i.ONE * n * 128, "Mask resolution is bounded on both board sizes")
	visuals.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await check_game()
	print("Zen ponds: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func check_game() -> void:
	root.size = Vector2i(540, 825)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var before := block(3, 2)
	before[2][4] = 0
	scene.game.board = before
	scene.game.queue[scene.game.index] = "Dot"
	scene.game.current_color = 2
	scene.cells = [Vector2i.ZERO]
	scene.selected = Vector2i(4, 2)
	scene.has_hover = true
	scene.game._refresh_over()
	scene.board_view.show_settled(before)
	scene._refresh()
	scene._place()
	check(scene.game.moves == 1 and scene.board_view.growing, "Actual Place creates a connected rocky pair")
	scene.board_view.set_process(false)
	var pond = scene.board_view.zen_visuals.pond
	var start: float = scene.board_view.pattern.ponds.values()[0].start
	scene.board_view.advance_growth(start)
	await frames()
	var dry: Image = pond.mask_view.get_texture().get_image()
	check(dry.get_pixel(400, 300).r < 0.01, "Water stays hidden until both rocks are ready")
	scene.board_view.advance_growth(100)
	await frames()
	check(not scene.board_view.growing, "Placement unlocks after pond and vegetation settle")
	var actual: Image = pond.mask_view.get_texture().get_image()
	var water_count := 0
	var dry_count := 0
	for y in range(265, 500, 11):
		for x in range(265, 630, 11):
			var expected := 0.0
			for e: Dictionary in scene.board_view.pattern.ponds.values():
				var uv := (Vector2(x, y) + Vector2.ONE * 0.5 - Vector2(e.origin) * 128.0) * 2.0
				if uv.x < 0 or uv.y < 0 or uv.x >= 512 or uv.y >= 512: continue
				var mask := Pond.source(Pond.mask_path(Landmark.rock_variant(e.origin), "water_" + Pond.DIRECTIONS[e.direction])).get_image()
				expected = 1.0 - (1.0 - expected) * (1.0 - sample_mask(mask, uv))
			for origin: Vector2i in scene.board_view.pattern.colonies:
				var uv := (Vector2(x, y) + Vector2.ONE * 0.5 - Vector2(origin) * 128.0) * 2.0
				if uv.x < 0 or uv.y < 0 or uv.x >= 512 or uv.y >= 512: continue
				var mask := Pond.source(Pond.mask_path(Landmark.rock_variant(origin), "rock_occlusion")).get_image()
				expected *= 1.0 - sample_mask(mask, uv)
			if expected > 0.98:
				water_count += 1
				check(actual.get_pixel(x, y).r > 0.9, "Supplied water regions remain flooded even over lower rock faces")
			elif expected < 0.01:
				dry_count += 1
				check(actual.get_pixel(x, y).r < 0.1, "Supplied occlusion protects exposed peaks")
	check(water_count > 10 and dry_count > 10, "Rendered pond contains both water and protected dry rock")
	DirAccess.make_dir_recursive_absolute("res://build/zen-ponds")
	root.get_texture().get_image().save_png("res://build/zen-ponds/game.png")
	actual.save_png("res://build/zen-ponds/flood-mask.png")
	# Center the connected block so it satisfies the existing save symmetry rule.
	var symmetric := Rules.empty_board(9)
	for y in range(3, 6):
		for x in range(3, 6): symmetric[y][x] = 2
	scene.game.board = symmetric
	scene.board_view.show_settled(symmetric)
	scene._refresh()
	await frames()
	root.get_texture().get_image().save_png("res://build/zen-ponds/expanded.png")
	scene.gallery.directory = "user://zen-ponds-%d" % Time.get_ticks_usec()
	await scene._save_design()
	var records: Array = scene.gallery.entries()
	check(records.size() == 1 and records[0].theme_version == "0.7", "Actual save captures the pond theme version")
	if not records.is_empty():
		var picture: Image = scene.gallery.picture(records[0]).get_image()
		picture.save_png("res://build/zen-ponds/saved.png")
		var blue := 0
		for y in range(0, picture.get_height(), 3):
			for x in range(0, picture.get_width(), 3):
				var ink := picture.get_pixel(x, y)
				if ink.b > ink.r + 0.05 and ink.g > ink.r + 0.05: blue += 1
		check(blue > 100, "Saved artwork includes the rendered blue-grey pond")
	if DirAccess.dir_exists_absolute(scene.gallery.directory):
		for file: String in DirAccess.open(scene.gallery.directory).get_files(): DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
	DirAccess.remove_absolute(scene.gallery.directory)
	scene.game.board = block(3, 2)
	scene.board_view.show_settled(scene.game.board)
	scene._undo()
	check(scene.board_view.zen_visuals.pond.regions.is_empty(), "Actual Undo removes the new connection's pond")
	scene.game.board = block(3, 2)
	scene.board_view.show_settled(scene.game.board)
	scene._refresh()
	scene._erase(Vector2i(4, 2))
	check(scene.board_view.zen_visuals.pond.regions.is_empty(), "Actual Erase removes unsupported pond sectors")
	scene.queue_free()
	await process_frame

func sample_mask(image: Image, uv: Vector2) -> float:
	# Each 128px/cell target pixel covers four source-mask texels.
	var p := Vector2i(uv) - Vector2i.ONE
	return (image.get_pixelv(p).r + image.get_pixelv(p + Vector2i.RIGHT).r + image.get_pixelv(p + Vector2i.DOWN).r + image.get_pixelv(p + Vector2i.ONE).r) * 0.25
