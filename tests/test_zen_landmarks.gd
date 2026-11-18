extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Geometry = preload("res://scripts/zen_geometry.gd")
const Palette = preload("res://scripts/palette.gd")
const Model = preload("res://scripts/zen_growth.gd")
const Visuals = preload("res://scripts/zen_visuals.gd")
const Landmark = preload("res://scripts/zen_landmark.gd")
const Board = preload("res://scripts/board_view.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func block(width: int, height: int, color: int, origin: Vector2i = Vector2i(2, 2), n: int = 9) -> Array:
	var grid: Array = Rules.empty_board(n)
	for y in range(height):
		for x in range(width): grid[origin.y + y][origin.x + x] = color
	return grid

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Palette.select_theme("zen_garden")
	var model := Model.new()
	var visuals := Visuals.new()
	root.add_child(visuals)
	for color in [1, 2]:
		for extent: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
			var grid := block(extent.x, extent.y, color)
			model.build(Rules.empty_board(9), grid)
			visuals.reconcile(model, true)
			check(visuals.landmarks.size() == (extent.x - 1) * (extent.y - 1), "Both colors create every eligible overlapping 2x2")
			check(visuals.formation_cells.size() == extent.x * extent.y and visuals.centerpieces.is_empty(), "Landmarks cover their supporting union without ordinary center stones")
			for cell: Vector2i in visuals.registry:
				var mask := Geometry.neighbor_mask(grid, cell)
				var halves := 0
				for d in range(4):
					if mask & (1 << d): halves += 1
				check(visuals.registry[cell].get_child_count() == (2 if color == 1 else 1 + halves), "Both landmark types preserve their basic pattern below the artwork")
			for sprite: Sprite2D in visuals.landmarks.values():
				check(sprite.color == color and sprite.rotation == 0, "Landmark preserves logical color and screen-facing lighting")
				check(sprite.texture == (Landmark.LANTERN if color == 1 else Landmark.ROCKS[sprite.variant]), "Landmark uses the supplied artwork for its color")
				check(sprite.position == (Vector2(sprite.origin) + Vector2.ONE) * 256, "Landmark anchor is centered exactly on its four cells")
				var extent_pixels: Vector2 = sprite.texture.get_size() * sprite.scale
				check(is_equal_approx(maxf(extent_pixels.x, extent_pixels.y), 256 if color == 1 else 512) and is_equal_approx(sprite.scale.x, sprite.scale.y), "Lantern is half size; rocks keep their size and aspect ratio")
				if color == 1:
					var pedestal: Vector2 = sprite.position + (Landmark.LANTERN_BASE_PIVOT - sprite.texture.get_size() * 0.5 + sprite.offset) * sprite.scale
					check(pedestal.is_equal_approx(sprite.position), "Lantern pedestal stays centered on the 2x2")
					check(sprite.material.get_shader_parameter("artwork_origin").is_equal_approx(sprite.position + (sprite.offset - sprite.texture.get_size() * 0.5) * sprite.scale), "Surface clipping follows the shifted lantern image")
			check(model.components.is_empty() and model.flowers.is_empty(), "No Coral or vine art/events are substituted")
	# Opposite-color contact and diagonals do not invent a same-color 2x2.
	var mixed := block(2, 2, 1)
	mixed[2][2] = 2
	model.build(mixed, mixed)
	visuals.reconcile(model, true)
	check(visuals.landmarks.is_empty(), "Mixed-color squares cannot create a landmark")
	var diagonal := Rules.empty_board(9)
	diagonal[2][2] = 2
	diagonal[3][3] = 2
	model.build(diagonal, diagonal)
	visuals.reconcile(model, true)
	check(visuals.landmarks.is_empty(), "Diagonal contact alone does not create a landmark")
	for n in [9, 11]:
		var dense: Array = Rules.empty_board(n)
		for row: Array in dense: row.fill(2)
		model.build(dense, dense)
		visuals.reconcile(model, true)
		check(visuals.landmarks.size() == (n - 1) * (n - 1), "Dense 9x9/11x11 boards retain all overlapping rock formations")
		var variants: Dictionary = {}
		for sprite: Sprite2D in visuals.landmarks.values(): variants[sprite.variant] = true
		check(variants.size() == 4, "All four supplied rock designs are used")
	# Add a new overlapping landmark to the LEFT of an established one. Keep
	# the old node, chosen rock and foreground order through growth and helpers.
	var before := block(2, 2, 2, Vector2i(4, 3))
	var after := block(3, 2, 2, Vector2i(3, 3))
	model.build(before, before)
	visuals.reconcile(model, true)
	var old_key := Landmark.identity(Vector2i(4, 3), 2)
	var existing: Sprite2D = visuals.landmarks[old_key]
	var old_id := existing.get_instance_id()
	var old_texture := existing.texture
	model.build(before, after)
	visuals.reconcile(model, false)
	check(visuals.landmarks[old_key].get_instance_id() == old_id and existing.texture == old_texture, "Adding a neighbor keeps the old rock node and its artwork")
	check(existing.modulate.a == 1 and existing.position == Vector2(5, 4) * 256, "Existing landmark never moves or fades on expansion")
	var new_key := Landmark.identity(Vector2i(3, 3), 2)
	var added: Sprite2D = visuals.landmarks[new_key]
	check(added.modulate.a == 0 and model.duration >= added.start + Landmark.GROW_SECONDS, "Place waits for the new landmark to appear")
	visuals.advance(model.duration)
	check(added.modulate.a == 1 and not added.growing, "Formation appearance reaches a settled state")
	check(visuals.landmark_layer.get_child(0) == existing and visuals.landmark_layer.get_child(1) == added, "Later overlapping formation is drawn above the established one")
	var clone := Visuals.new()
	root.add_child(clone)
	model.build(after, after)
	clone.reconcile(model, true, true)
	clone.copy_landmark_order(visuals)
	check(clone.landmark_order == visuals.landmark_order and clone.landmark_layer.get_child(0).origin == Vector2i(4, 3), "Gallery reconstruction copies the established landmark order")
	model.build(before, before)
	visuals.reconcile(model, true)
	check(visuals.landmarks.size() == 1 and visuals.landmarks[old_key].get_instance_id() == old_id, "Undo removes only unsupported landmarks")
	clone.queue_free()
	visuals.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await check_saved_order(before, after)
	await check_game()
	print("Zen landmarks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_saved_order(before: Array, after: Array) -> void:
	var views: Array[SubViewport] = []
	var boards: Array = []
	for i in range(2):
		var view := SubViewport.new()
		view.size = Vector2i(384, 384)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var board := Board.new()
		board.size = Vector2(384, 384)
		board.complete_background = true
		board.show_guides = false
		view.add_child(board)
		views.append(view)
		boards.append(board)
	boards[0].show_settled(before)
	boards[0].show_settled(after, true)
	boards[1].show_settled(after)
	boards[1].zen_visuals.copy_landmark_order(boards[0].zen_visuals)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(views[0].get_texture().get_image().get_data() == views[1].get_texture().get_image().get_data(), "Copying live landmark order reproduces the exact completed artwork pixels")
	for view: SubViewport in views: view.queue_free()
	await process_frame

func check_game() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	DirAccess.make_dir_recursive_absolute("res://build/zen-landmarks")
	for color in [1, 2]:
		scene._reset()
		var board := block(2, 2, color, Vector2i(4, 3))
		board[3][5] = 0
		scene.game.board = board
		scene.game.queue[scene.game.index] = "Dot"
		scene.game.current_color = color
		scene.cells = [Vector2i.ZERO]
		scene.selected = Vector2i(5, 3)
		scene.has_hover = true
		scene.game._refresh_over()
		scene.board_view.show_settled(board)
		scene._refresh()
		scene._place()
		check(scene.game.moves == 1 and scene.board_view.zen_visuals.landmarks.size() == 1, "Actual Place completes each color's 2x2 landmark")
		check(scene.board_view.growing, "Actual Place is gated by landmark growth")
		scene.board_view.set_process(false)
		var event: Dictionary = scene.board_view.pattern.colonies[Vector2i(4, 3)]
		var landmark: Sprite2D = scene.board_view.zen_visuals.landmarks[Landmark.identity(Vector2i(4, 3), color)]
		var pattern: Array = []
		for group: Node in scene.board_view.zen_visuals.registry.values():
			for child: Node in group.get_children():
				if child is Sprite2D:
					pattern.append({"sprite": child, "id": child.get_instance_id(), "texture": child.texture, "position": child.position})
		check(event.start > event.pattern_end and landmark.modulate.a == 0, "Both landmarks wait for the basic-pattern phase to complete")
		scene.board_view.advance_growth(event.pattern_end)
		check(landmark.modulate.a == 0 and pattern.all(func(item): return item.sprite.modulate.a == 1), "The full basic pattern appears alone before its 2x2 artwork")
		await capture("raked-sand-first" if color == 1 else "stepping-stones-first")
		scene.board_view.advance_growth(event.start + Landmark.GROW_SECONDS * 0.5 - scene.board_view.clock)
		check(landmark.modulate.a > 0 and landmark.modulate.a < 1 and scene.board_view.growing, "The artwork appears above the finished pattern while Place remains gated")
		check(pattern.all(func(item): return item.sprite.get_instance_id() == item.id and item.sprite.texture == item.texture and item.sprite.position == item.position and item.sprite.modulate.a == 1), "The overlay preserves every basic-pattern sprite in place")
		await capture("lantern-halfway" if color == 1 else "rocks-halfway")
		scene.board_view.advance_growth(100)
		check(not scene.board_view.growing, "Place unlocks when the landmark has finished appearing")
		await capture("formed-%d" % color)
		scene._undo()
		check(scene.board_view.zen_visuals.landmarks.is_empty() and scene.game.board[3][5] == 0, "Actual Undo restores ordinary tiles")
		if color == 1:
			check(scene.board_view.junction_layer.renderer.nodes.has("junction/zen_garden/1/4/4/bend"), "Undo restores the bend's single stone")
		else:
			check(not scene.board_view.tier1_layer.plans.is_empty(), "Undo restores ordinary stepping-stone paths")
		board[3][5] = color
		scene.game.board = board
		scene.board_view.show_settled(board)
		scene._refresh()
		scene._erase(Vector2i(5, 3))
		check(scene.board_view.zen_visuals.landmarks.is_empty(), "Actual Erase removes an unsupported landmark")
	var display := Rules.empty_board(9)
	for item: Array in [[Vector2i(1, 1), 1], [Vector2i(6, 6), 1], [Vector2i(6, 1), 2], [Vector2i(1, 6), 2]]:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			var cell: Vector2i = item[0] + offset
			display[cell.y][cell.x] = item[1]
	scene.game.board = display
	scene.game._refresh_over()
	scene.board_view.show_settled(display)
	scene._refresh()
	check(scene.board_view.zen_visuals.landmarks.size() == 4, "Both landmark types coexist in the actual game")
	await capture("both-types")
	if DisplayServer.get_name() != "headless":
		scene.gallery.directory = "user://zen-landmarks-%d" % Time.get_ticks_usec()
		await scene._save_design()
		var records: Array = scene.gallery.entries()
		check(records.size() == 1 and records[0].theme_version == Palette.theme_version(), "Gallery saves the current landmark artwork")
		if not records.is_empty(): scene.gallery.picture(records[0]).get_image().save_png("res://build/zen-landmarks/artwork.png")
		for file: String in DirAccess.open(scene.gallery.directory).get_files(): DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
		DirAccess.remove_absolute(scene.gallery.directory)
	scene.queue_free()
	await process_frame
	await create_timer(0.12).timeout

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://build/zen-landmarks/%s.png" % name) == OK, "Captured actual game " + name)
