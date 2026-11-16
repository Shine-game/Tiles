extends SceneTree

const Centerpiece = preload("res://scripts/zen_centerpiece.gd")
const Geometry = preload("res://scripts/zen_geometry.gd")
const Zen = preload("res://scripts/zen_visuals.gd")
const Model = preload("res://scripts/zen_growth.gd")
const Rules = preload("res://scripts/rules.gd")
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
	for turns in range(4):
		check(Centerpiece.stage_for(Geometry.rotate_mask(3, turns)) == 1, "Every bend uses the single stone")
		check(Centerpiece.stage_for(Geometry.rotate_mask(11, turns)) == 2, "Every T uses the three-stone stack")
	for mask in [0, 1, 2, 4, 5, 8, 10]:
		check(Centerpiece.stage_for(mask) == 0, "Core, endpoints and straights do not gain a centerpiece")
	check(Centerpiece.stage_for(15) == 3, "A full cross gains bamboo")
	var center := Centerpiece.new()
	root.add_child(center)
	check(Centerpiece.TEXTURES.all(func(texture): return texture.get_size() == Vector2(256, 256)), "All three supplied artworks load with matching canvases")
	center.configure(1, true)
	var base := center.artwork
	var base_id := base.get_instance_id()
	var anchor := base.position
	var scale := base.scale
	center.configure(2, false)
	check(base.get_instance_id() == base_id and base.position == anchor and base.scale == scale and base.modulate.a == 1, "Promoting to T retains the established base without fading or moving it")
	check(center.progress[1] == 0 and center.progress[0] == 1, "Only the newly added stone stack starts its growth")
	center.advance(0.15)
	check(center.progress[1] > 0 and center.progress[1] < 1, "New stones grow over the existing stone")
	center.advance(0.30)
	center.configure(3, false)
	check(base.scale == scale and center.progress[1] == 1 and center.progress[2] == 0, "Adding bamboo preserves the completed stone stack")
	check(Centerpiece.TEXTURES[1].get_image().get_pixel(128, 128) == Centerpiece.TEXTURES[2].get_image().get_pixel(128, 128), "Supplied bamboo artwork retains the foreground cairn")
	center.advance(0.30)
	center.configure(1, true)
	check(base.visible and center.progress == [1.0, 0.0, 0.0], "Undo/Erase restores the single-stone stage immediately")
	check(base.rotation == 0.0, "Centerpiece lighting orientation never rotates with the grooves")
	center.queue_free()
	if DisplayServer.get_name() != "headless":
		await check_composites()
	var visuals := Zen.new()
	root.add_child(visuals)
	var board := Rules.empty_board(9)
	board[4][4] = 1
	board[3][4] = 1
	board[4][5] = 1
	var model := Model.new()
	model.build(board, board)
	visuals.reconcile(model, true)
	var retained: Node = visuals.centerpieces[Vector2i(4, 4)]
	var retained_id := retained.get_instance_id()
	board[4][3] = 1
	model.build(model.board, board)
	visuals.reconcile(model, false)
	check(visuals.centerpieces[Vector2i(4, 4)].get_instance_id() == retained_id and retained.stage == 2, "Board reconciliation promotes the existing center node")
	check(retained.position == Vector2(4.5, 4.5) * 256 and retained.rotation == 0, "Decoration remains at the cell center in screen orientation")
	board[5][4] = 1
	model.build(model.board, board)
	visuals.reconcile(model, false)
	check(retained.stage == 3, "A new fourth connection selects the bamboo stage")
	board[5][5] = 1
	model.build(board, board)
	visuals.reconcile(model, true)
	check(not visuals.centerpieces.has(Vector2i(4, 4)), "Unfinished 2x2 landmarks keep their plain sand placeholder")
	for row: Array in board:
		for i in range(row.size()):
			if row[i] != 0: row[i] = 2
	model.build(board, board)
	visuals.reconcile(model, true)
	check(visuals.centerpieces.is_empty(), "Stepping-stone tiles never receive rake decorations")
	visuals.queue_free()
	await process_frame
	await check_game_progression()
	var missing: Array = []
	for file: String in Centerpiece.FILES:
		if not ResourceLoader.exists(Centerpiece.ROOT + file): missing.append(file)
	check(missing.is_empty(), "All original artwork files are available")
	print("Zen centerpieces: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_game_progression() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var board := Rules.empty_board(9)
	board[4][4] = 1
	board[3][4] = 1
	board[4][5] = 1
	scene.game.board = board
	scene.game._refresh_over()
	scene.board_view.show_settled(board)
	scene._refresh()
	var center: Node = scene.board_view.zen_visuals.centerpieces[Vector2i(4, 4)]
	var identity := center.get_instance_id()
	check(center.stage == 1 and center.artwork.visible, "The actual game's bend displays the supplied stone")
	for cell: Vector2i in [Vector2i(3, 4), Vector2i(4, 5)]:
		scene.game.queue[scene.game.index] = "Dot"
		scene.game.current_color = 1
		scene.cells = [Vector2i.ZERO]
		scene.selected = cell
		scene.has_hover = true
		scene._refresh()
		scene._place()
		var expected_stage := 2 if cell.x == 3 else 3
		check(center.stage == expected_stage and center.get_instance_id() == identity, "Place promotes the existing decoration to stage %d" % expected_stage)
		check(center.artwork.modulate.a == 1 and center.artwork.scale == Vector2.ONE * 0.60, "Existing base stays fully drawn during promotion")
		scene.board_view.advance_growth(100)
		check(center.growing.is_empty() and center.progress[expected_stage - 1] == 1, "Added decoration settles before Place unlocks")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/zen-centers/in-game-cross.png")
		scene.gallery.directory = "user://zen-centers-%d" % Time.get_ticks_usec()
		await scene._save_design()
		var records: Array = scene.gallery.entries()
		check(records.size() == 1 and records[0].theme_version == "0.2", "Gallery records the new decorated Zen appearance")
		if not records.is_empty(): scene.gallery.picture(records[0]).get_image().save_png("res://build/zen-centers/saved-cross.png")
		for file: String in DirAccess.open(scene.gallery.directory).get_files():
			DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
		DirAccess.remove_absolute(scene.gallery.directory)
	scene._undo()
	check(center.stage == 2 and center.progress[2] == 0, "The game's Undo removes bamboo and retains the cairn")
	scene._erase(Vector2i(3, 4))
	check(center.stage == 1 and center.progress[1] == 0, "The game's Erase restores the bend's single stone")
	scene._erase(Vector2i(5, 4))
	check(not scene.board_view.zen_visuals.centerpieces.has(Vector2i(4, 4)), "Removing the bend removes its decoration")
	scene.queue_free()
	await process_frame
	await create_timer(0.12).timeout

func check_composites() -> void:
	var actual := SubViewport.new()
	var reference := SubViewport.new()
	for view in [actual, reference]:
		view.size = Vector2i(320, 320)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var floor := ColorRect.new()
		floor.color = Color("f0ece3")
		floor.size = Vector2.ONE * 320
		view.add_child(floor)
	var center := Centerpiece.new()
	center.position = Vector2(160, 160)
	actual.add_child(center)
	var expected := Sprite2D.new()
	expected.position = center.position
	expected.scale = Vector2.ONE * 0.60
	expected.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	reference.add_child(expected)
	DirAccess.make_dir_recursive_absolute("res://build/zen-centers")
	for stage in range(1, 4):
		center.configure(stage, true)
		expected.texture = load(Centerpiece.ROOT + Centerpiece.FILES[stage - 1])
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var actual_pixels := actual.get_texture().get_image().get_data()
		var reference_pixels := reference.get_texture().get_image().get_data()
		var error := 0
		for i in range(actual_pixels.size()): error = maxi(error, absi(int(actual_pixels[i]) - int(reference_pixels[i])))
		check(error <= 1, "Stage %d preserves the supplied artwork within 1/255 (max %d)" % [stage, error])
		actual.get_texture().get_image().save_png("res://build/zen-centers/layered-%d.png" % stage)
		reference.get_texture().get_image().save_png("res://build/zen-centers/reference-%d.png" % stage)
	actual.queue_free()
	reference.queue_free()
	await process_frame
