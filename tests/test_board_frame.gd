extends SceneTree

const Frame = preload("res://scripts/board_frame.gd")
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func fixture() -> Texture2D:
	# Technical color patches test nine-slice geometry; never used as theme art.
	var image := Image.create(256, 266, false, Image.FORMAT_RGBA8)
	image.fill(Color("c7b78f"))
	image.fill_rect(Rect2i(0, 256, 256, 10), Color("5d716a"))
	image.fill_rect(Rect2i(14, 14, 228, 228), Color.TRANSPARENT)
	image.fill_rect(Rect2i(0, 0, 4, 4), Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)

func _run() -> void:
	var frame := Frame.new()
	root.add_child(frame)
	check(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE and not frame.draw_center, "frame is input-transparent with no painted center")
	check(frame.patch_margin_left == 14 and frame.patch_margin_top == 14 and frame.patch_margin_right == 14 and frame.patch_margin_bottom == 24, "one shared 14px rim and 10px sidewall contract")
	check(frame.axis_stretch_horizontal == NinePatchRect.AXIS_STRETCH_MODE_STRETCH and frame.axis_stretch_vertical == NinePatchRect.AXIS_STRETCH_MODE_STRETCH, "edges stretch without repeating the grain")
	check(frame.region_rect == Rect2() and frame.scale == Vector2.ONE, "full source and unit node scale preserve the cross section")
	var has_art: bool = ResourceLoader.exists(Frame.profile("coral_reef").texture, "Texture2D")
	check(frame.apply_theme("coral_reef") == has_art, "production frame is enabled only when original artwork exists")
	print("Original Coral Reef frame PNG available: ", has_art)
	if has_art:
		check(frame.texture.get_size() == Vector2(256, 266), "production artwork has the exact source dimensions")
		check(frame.texture.get_image().get_region(Rect2i(14, 14, 228, 228)).is_invisible(), "lossless import preserves the fully transparent production opening")
	var artwork := fixture()
	check(frame.apply_theme("coral_reef", artwork), "injected geometry fixture enables the common renderer")
	for available: Rect2 in [Rect2(10, 20, 240, 160), Rect2(0, 0, 900, 900), Rect2(0, 0, 320, 440)]:
		var opening := Frame.fit(available)
		frame.surround(opening)
		check(is_equal_approx(opening.size.x, opening.size.y), "frame keeps the playable opening square")
		check(available.grow(0.001).encloses(frame.get_rect()), "all rim and sidewall pixels fit in the reserved area")
		check(is_equal_approx(frame.size.y - frame.size.x, 10), "bottom sidewall adds 10 UI units rather than source-cell-scaled depth")
		check(frame.position + Vector2(14, 14) == opening.position and frame.size - Vector2(28, 38) == opening.size, "nine-patch opening exactly surrounds the board rectangle")
	frame.queue_free()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for step in range(4):
		await process_frame
	scene._select_theme("coral_reef")
	var view = scene.board_view
	view.board_frame.apply_theme("coral_reef", artwork)
	for board_size in [9, 11]:
		scene._ask_reset(board_size)
		for dimensions: Vector2 in [Vector2(240, 320), Vector2(390, 844), Vector2(720, 1100), Vector2(844, 390)]:
			scene.size = dimensions
			scene._layout()
			check(Rect2(Vector2.ZERO, view.size).grow(0.001).encloses(view.board_frame.get_rect()), "frame fits without overlapping controls at " + str(dimensions))
			check(view.reef_water.floor_plane.get_rect() == view.field and view.reef_water.light_plane.get_rect() == view.board_frame.get_rect(), "one caustic field covers board and frame while lagoon fills only the opening")
			check(view.reef_water.light_plane.material.get_shader_parameter("cell_origin").is_equal_approx(view._point(Vector2.ZERO) - view.board_frame.position), "frame and board share the exact lighting coordinate origin")
			scene.grabbed_cell = Vector2i.ZERO
			for cell: Vector2i in [Vector2i.ZERO, Vector2i(board_size - 1, board_size - 1)]:
				var point: Vector2 = view.get_global_transform_with_canvas() * view._point(Vector2(cell) + Vector2(0.5, 0.5))
				scene._drag_to(point)
				check(scene.selected == cell, "frame fit preserves edge-cell drag transforms")
	check(scene._surface_revision("coral_reef").ends_with("/frame-bleached-wreck-timber-v1"), "framed gallery designs have a distinct appearance identity")
	if DisplayServer.get_name() != "headless":
		var viewport := SubViewport.new()
		viewport.size = Vector2i(360, 360)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var rendered := Frame.new()
		viewport.add_child(rendered)
		rendered.apply_theme("coral_reef", artwork)
		rendered.surround(Rect2(30, 30, 300, 300))
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		check(image.get_pixel(180, 180).a == 0 and image.get_pixel(30, 30).a == 0, "native nine-patch leaves the entire playable opening transparent")
		check(image.get_pixel(20, 180).a > 0.99 and image.get_pixel(180, 20).a > 0.99, "native frame paints side and upper rim")
		check(image.get_pixel(180, 350).is_equal_approx(Color("5d716a")), "native frame preserves the bottom sidewall color and 10-row source region")
		check(image.get_pixel(180, 355).a == 0, "sidewall ends at reserved bounds without clipping or duplicate extrusion")
		var water = load("res://scripts/reef_water.gd").new()
		viewport.add_child(water)
		water.configure(Rect2(30, 30, 300, 300), Vector2(30, 30), 300.0 / 9.0, rendered.get_rect(), artwork)
		water.floor_plane.hide()
		water.freeze_phase(2)
		await process_frame
		await RenderingServer.frame_post_draw
		image = viewport.get_texture().get_image()
		check(image.get_pixel(17, 17).a == 0, "shared caustics preserve transparent frame corners and surrounding interface")
		viewport.queue_free()
		scene.size = Vector2(720, 1100)
		scene._layout()
		scene._ask_reset(9)
		scene.gallery.directory = "user://frame-test-%d" % Time.get_ticks_usec()
		await scene._save_design()
		var records: Array = scene.gallery.entries()
		check(records.size() == 1 and records[0].get("surface_revision", "").ends_with("/frame-bleached-wreck-timber-v1"), "native gallery records the framed appearance")
		if records.size() == 1:
			var saved: Image = scene.gallery.picture(records[0]).get_image()
			check(saved.get_pixel(450, 7).get_luminance() < 0.88, "native gallery includes the same frame artwork around the design")
		for file: String in DirAccess.open(scene.gallery.directory).get_files():
			DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
		DirAccess.remove_absolute(scene.gallery.directory)
	scene.queue_free()
	var deadline := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < deadline:
		await process_frame
	Palette.select_theme("vines")
	print("Board frame: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
