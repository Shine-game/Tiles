extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func pool_areas(image: Image, threshold: float) -> Array:
	var width := image.get_width()
	var height := image.get_height()
	var dark := PackedByteArray()
	dark.resize(width * height)
	for y in range(height):
		for x in range(width):
			dark[y * width + x] = 1 if image.get_pixel(x, y).get_luminance() < threshold else 0
	var areas: Array = []
	var offsets := PackedInt32Array([-1, 1, -width, width])
	for start in range(dark.size()):
		if dark[start] == 0:
			continue
		var queue := PackedInt32Array([start])
		dark[start] = 0
		var cursor := 0
		var border := false
		while cursor < queue.size():
			var current: int = queue[cursor]
			cursor += 1
			var x: int = current % width
			var y: int = current / width
			border = border or x == 0 or y == 0 or x == width - 1 or y == height - 1
			for offset: int in offsets:
				var next: int = current + offset
				if next >= 0 and next < dark.size() and absi(next % width - x) <= 1 and dark[next] != 0:
					dark[next] = 0
					queue.append(next)
		if not border and queue.size() >= 20:
			areas.append(queue.size())
	return areas

func check_reorganization(shader: Shader) -> void:
	# Isolate the light on a flat surface so artwork cannot masquerade as pools.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var floor_plane := ColorRect.new()
	floor_plane.size = Vector2(240, 240)
	floor_plane.color = Color(0.90, 0.94, 0.92)
	viewport.add_child(floor_plane)
	await process_frame
	await RenderingServer.frame_post_draw
	var threshold: float = viewport.get_texture().get_image().get_pixel(120, 120).get_luminance() - 0.004
	var light := ColorRect.new()
	light.size = Vector2(240, 240)
	var ink := ShaderMaterial.new()
	ink.shader = shader
	ink.set_shader_parameter("cell_pixels", 240.0 / 9.0)
	ink.set_shader_parameter("rect_pixels", Vector2(240, 240))
	light.material = ink
	viewport.add_child(light)
	var counts: Array = []
	var mixed_sizes := false
	for phase: float in [0.0, 6.0, 12.0, 18.0]:
		ink.set_shader_parameter("time_override", phase)
		await process_frame
		await RenderingServer.frame_post_draw
		var areas: Array = pool_areas(viewport.get_texture().get_image(), threshold)
		counts.append(areas.size())
		if areas.size() > 1 and float(areas.max()) > 3.0 * float(areas.min()):
			mixed_sizes = true
	check(mixed_sizes, "rendered caustics mix large and small pools")
	check(int(counts.max()) - int(counts.min()) >= 3, "rendered pool count changes as the mesh splits and merges")
	print("Reef interior pool counts at 0/6/12/18 seconds: ", counts)
	viewport.queue_free()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	check(scene.board_view.reef_water == null, "other themes do not allocate reef lighting")
	scene._select_theme("coral_reef")
	var view = scene.board_view
	var water = view.reef_water
	check(water != null and water.visible, "Coral Reef enables one continuous water environment")
	check(not view.growing and not view.is_processing(), "idle water lighting does not require the growth process")
	check(water.light_plane.material.get_shader_parameter("time_override") == -1.0, "lighting uses independent shader time")
	check(water.floor_plane.mouse_filter == Control.MOUSE_FILTER_IGNORE and water.light_plane.mouse_filter == Control.MOUSE_FILTER_IGNORE, "water layers do not intercept placement gestures")
	check(water.light_plane.z_index > view.coral_visuals.z_index, "continuous light draws over the complete coral network")
	check(view.get_children().find(water) < view.get_children().find(view.occupied_platform), "lagoon base lies below the occupied surface")
	check(view.occupied_platform.material.get_shader_parameter("submerged"), "reef platform uses submerged shading")
	check(Palette.background() == Color.WHITE, "surrounding interface remains white")
	check(Platform.surface_revision("coral_reef") != Platform.SURFACE_REVISION and Platform.surface_revision("vines") == Platform.SURFACE_REVISION, "gallery identifies the new reef environment separately")
	for size_choice in [9, 11]:
		scene._ask_reset(size_choice)
		check(water.light_plane.get_rect() == (view.board_frame.get_rect() if view.board_frame.is_present() else view.field) and water.floor_plane.get_rect() == view.field, "water covers the complete %dx%d board" % [size_choice, size_choice])
		check(is_equal_approx(view.surface_depth(), view.pitch * 24 / 256), "water does not change tile thickness")
		check(water.light_plane.material.get_shader_parameter("cell_origin").is_equal_approx(view._point(Vector2.ZERO) - water.light_plane.position), "caustics use the same board coordinates as sand and coral")
	scene._ask_reset(9)
	var garden: Array = Rules.empty_board(9)
	for y in range(2, 7):
		for x in range(2, 7):
			garden[y][x] = 1 if x < 4 else 2
	scene.game.board = garden
	scene._refresh()
	var mask_revision: int = view.occupied_platform.mask_revision
	var board_snapshot: Array = scene.game.board.duplicate(true)
	if DisplayServer.get_name() != "headless":
		water.freeze_phase(0)
		var first: Image = await capture()
		var outside: Color = first.get_pixel(5, 4)
		var empty: Color = first.get_pixelv(Vector2i(view.global_position + view._floor_point(Vector2(7.5, 7.5))))
		check(outside.is_equal_approx(Color.WHITE), "native renderer confines lagoon to the board")
		check(empty.g > empty.r + 0.025 and empty.b > empty.r + 0.015, "native empty squares read as pale lagoon water")
		water.light_plane.hide()
		var unlit: Image = await capture()
		water.light_plane.show()
		var light_rows := 0
		var shadow_rows := 0
		for y in range(int(view.global_position.y + view.field.position.y), int(view.global_position.y + view.field.end.y), 4):
			for x in range(int(view.global_position.x + view.field.position.x), int(view.global_position.x + view.field.end.x), 4):
				var difference: float = first.get_pixel(x, y).get_luminance() - unlit.get_pixel(x, y).get_luminance()
				if difference > 0.015:
					light_rows += 1
				if difference < -0.04:
					shadow_rows += 1
		check(light_rows > 100 and shadow_rows > 100, "cellular caustics produce bright filaments and shaded pools")
		water.freeze_phase(1.5)
		var second: Image = await capture()
		var empty_changes := 0
		var occupied_changes := 0
		var outside_changes := 0
		var board_rect: Rect2 = Rect2(view.global_position + water.light_plane.position, water.light_plane.size)
		for y in range(0, first.get_height(), 4):
			for x in range(0, first.get_width(), 4):
				var a: Color = first.get_pixel(x, y)
				var b: Color = second.get_pixel(x, y)
				var change: float = maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
				var p := Vector2(x, y)
				if not board_rect.has_point(p):
					if change > 1.5 / 255:
						outside_changes += 1
				elif change > 0.04:
					var cell: Vector2 = (p - view.global_position - view._point(Vector2.ZERO)) / view.pitch
					if view.occupied_platform.filled(cell):
						occupied_changes += 1
					else:
						empty_changes += 1
		check(empty_changes > 100 and occupied_changes > 100, "caustics visibly oscillate over empty water and occupied sand/coral within 1.5 seconds")
		check(outside_changes == 0, "lighting never spills onto the white interface")
		scene.gallery.directory = "user://reef-water-test-%d" % Time.get_ticks_usec()
		await scene._save_design()
		var records: Array = scene.gallery.entries()
		check(records.size() == 1 and records[0].get("surface_revision", "") == scene._surface_revision("coral_reef"), "gallery captures the new environment under its own revision")
		if records.size() == 1:
			var picture: Image = scene.gallery.picture(records[0]).get_image()
			var saved_water: Color = picture.get_pixel(790, 790)
			check(saved_water.g > saved_water.r + 0.025 and saved_water.b > saved_water.r + 0.015, "saved artwork includes the lagoon in empty areas")
		for file: String in DirAccess.open(scene.gallery.directory).get_files():
			DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
		DirAccess.remove_absolute(scene.gallery.directory)
		water.freeze_phase(-1)
		await check_reorganization(water.CAUSTICS)
	check(view.occupied_platform.mask_revision == mask_revision and scene.game.board == board_snapshot, "lighting never changes occupancy or puzzle state")
	var before: Array = garden.duplicate(true)
	garden[1][2] = 1
	scene.game.board = garden
	view.animate_growth(before, garden)
	view.set_process(false)
	check(view.reef_water == water and water.light_plane.material.get_shader_parameter("time_override") == -1.0, "Place does not recreate or restart the water environment")
	view.show_settled(before, true)
	check(view.reef_water == water and water.visible and not view.growing, "settling or removing growth leaves water lighting running")
	scene._select_theme("vines")
	check(not water.visible and not view.occupied_platform.material.get_shader_parameter("submerged"), "leaving reef restores the original environment and surface shading")
	scene.queue_free()
	var mixer_deadline := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < mixer_deadline:
		await process_frame
	Palette.select_theme("vines")
	print("Reef water: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
