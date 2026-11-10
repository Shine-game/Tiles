extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
const Model = preload("res://scripts/clockwork_growth.gd")
const Visuals = preload("res://scripts/clockwork_visuals.gd")
const CHAIN = preload("res://shaders/clockwork_chain.gdshader")
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
	while Time.get_ticks_msec() < end: await process_frame
func capture(viewport: Viewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func alpha_sum(image: Image, region: Rect2i) -> float:
	var amount := 0.0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x): amount += image.get_pixel(x, y).a
	return amount
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Native Clockwork: requires a graphical renderer; skipped headless")
		quit()
		return
	Palette.select_theme("clockwork")
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var first: Image = await capture(root)
	check(not first.get_pixel(5, 5).is_equal_approx(Color.WHITE), "drafting paper fills the surrounding interface")
	check(scene.board_view.board_frame.is_present(), "walnut frame is installed in the default scene")
	var board: Array = Rules.empty_board(9)
	for y in range(2, 6):
		for x in range(2, 6): board[y][x] = 1
	scene.game.board = board
	scene.board_view.show_settled(board)
	scene.game._refresh_over()
	scene._refresh()
	first = await capture(root)
	var view = scene.board_view
	var visuals = view.clockwork_visuals
	check(visuals.chain_nodes.size() == 12 and visuals.model.mechanisms.size() == 9, "native scene draws a complete 4x4 mechanism network")
	var center: Vector2 = view.global_position + view._point(Vector2(3, 3))
	var ink: Color = first.get_pixelv(Vector2i(center))
	check(ink.get_luminance() < 0.85, "actual clockwork artwork is visible above the plate")
	var face: Vector2 = view.global_position + view._point(Vector2(2.15, 2.5))
	check(first.get_pixelv(Vector2i(face)).get_luminance() < 0.90, "original metal floor replaces the paper within occupied cells")
	await wait_frames(0.25)
	var second: Image = await capture(root)
	check(first.get_data() != second.get_data(), "gears, chains and steam render ongoing operation while Place is unlocked")
	check(not view.growing and not scene.sounds.whisper.playing, "native operating motion does not reopen construction or legacy sound")
	# Inspect the actual batched strip shader independently from masks/housings.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(300, 180)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var strip := ColorRect.new()
	strip.position = Vector2(20, 20)
	strip.size = Vector2(256, Visuals.CHAIN_CANVAS)
	var material := ShaderMaterial.new()
	material.shader = CHAIN
	material.set_shader_parameter("link_scale", Visuals.CHAIN_LINK_SCALE)
	material.set_shader_parameter("link_art", Visuals.texture("artwork/copper/CH01_link.png"))
	material.set_shader_parameter("progress", 0.0)
	strip.material = material
	viewport.add_child(strip)
	var unbuilt: Image = await capture(viewport)
	check(alpha_sum(unbuilt, Rect2i(0, 0, 300, 180)) == 0, "chains remain invisible before their construction begins")
	material.set_shader_parameter("progress", 0.05)
	var top: Image = await capture(viewport)
	material.set_shader_parameter("reverse_run", true)
	var bottom: Image = await capture(viewport)
	var left := Rect2i(20, 20, 60, 128)
	var right := Rect2i(216, 20, 60, 128)
	check(alpha_sum(top, left) > 10 and alpha_sum(top, right) == 0, "upper chain assembles link-by-link from the left axle")
	check(alpha_sum(bottom, right) > 10 and alpha_sum(bottom, left) == 0, "lower chain assembles from the right axle")
	material.set_shader_parameter("progress", 1.0)
	first = await capture(viewport)
	material.set_shader_parameter("travel", Visuals.CHAIN_PITCH * 0.5)
	second = await capture(viewport)
	check(first.get_data() != second.get_data(), "moving link pattern shifts through the strip on the GPU")
	check(alpha_sum(second, Rect2i(0, 0, 18, 180)) == 0 and alpha_sum(second, Rect2i(278, 0, 20, 180)) == 0, "chain travel never paints outside run boundaries")
	viewport.queue_free()
	# Real Place closes a symmetric 3x3 loop, and the real helper dismantles it.
	scene._reset()
	board = Rules.empty_board(9)
	for y in range(3, 6):
		for x in range(3, 6): board[y][x] = 1
	board[5][5] = 0
	scene.game.board = board
	view.show_settled(board)
	scene.game._refresh_over()
	scene.game.queue[scene.game.index] = "Dot"
	scene.game.current_color = 1
	scene.cells = Rules.PIECES.Dot.cells
	scene.selected = Vector2i(5, 5)
	scene.has_hover = true
	scene._refresh()
	scene._place()
	check(scene.game.board[5][5] == 1 and view.growing, "real Place commits the square and starts mechanism construction")
	view.set_process(false)
	view.advance_growth(view.pattern.duration + 1)
	scene._undo()
	check(scene.game.board[5][5] == 0 and scene.game.undo_left == 2 and view.growing, "real Undo preserves its budget and reverses unsupported parts")
	view.set_process(false)
	view.advance_growth(view.pattern.duration + 1)
	scene.game.queue[scene.game.index] = "Dot"
	scene.cells = Rules.PIECES.Dot.cells
	scene.selected = Vector2i(5, 5)
	scene.has_hover = true
	scene._refresh()
	scene._place()
	view.set_process(false)
	view.advance_growth(view.pattern.duration + 1)
	check(scene._can_save(), "reconstructed symmetrical mechanism is eligible for gallery saving")
	scene.gallery.directory = "user://clockwork-native-%d" % Time.get_ticks_usec()
	await scene._save_design()
	var records: Array = scene.gallery.entries()
	check(records.size() == 1 and records[0].theme == "clockwork", "gallery saves a symmetric clockwork design with its theme")
	if records.size() == 1:
		var artwork: Image = scene.gallery.picture(records[0]).get_image()
		check(artwork.get_size() == Vector2i(900, 900) and artwork.get_pixel(450, 7).get_luminance() < 0.9, "gallery includes paper and walnut frame at full capture size")
	for file: String in DirAccess.open(scene.gallery.directory).get_files():
		DirAccess.remove_absolute(scene.gallery.directory.path_join(file))
	DirAccess.remove_absolute(scene.gallery.directory)
	# Construction shaders run through every phase on an 11x11 occupied board.
	scene._ask_reset(11)
	var dense: Array = Rules.empty_board(11)
	for row: Array in dense: row.fill(2)
	scene.game.board = dense
	view.animate_growth(Rules.empty_board(11), dense)
	view.set_process(false)
	for at: float in [0.1, 0.4, 0.8, 1.3, 1.9, 2.5, 3.5]:
		view.advance_growth(maxf(0, at - view.clock))
		await capture(root)
	check(view.pattern.mechanisms.size() == 100 and view.pattern.chains.size() == 180 and not view.growing, "dense 11x11 completes its 100 mechanisms and 180 chains")
	check(visuals.puffs.size() <= 2, "dense assembly preserves the two-puff limit")
	scene.queue_free()
	await wait_frames(0.15)
	print("Native Clockwork: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
