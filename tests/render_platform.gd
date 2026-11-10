# Native shader assertions plus actual all-theme raised-platform review images.
extends SceneTree

const Platform = preload("res://scripts/occupied_platform.gd")
const Rules = preload("res://scripts/rules.gd")
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

func capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var platform = Platform.new()
	viewport.add_child(platform)
	var grid: Array = Rules.empty_board(9)
	platform.sync(grid)
	platform.configure(Vector2(20, 20), 64, Color("edd7ad"))
	var shot: Image = await capture(viewport)
	check(is_zero_approx(shot.get_pixel(180, 180).a), "empty board has no shader paper or shadow")
	grid[2][2] = 1
	platform.sync(grid)
	shot = await capture(viewport)
	var upper: Color = shot.get_pixel(180, 212)
	var lower: Color = shot.get_pixel(180, 217)
	check(upper.a > 0.99 and lower.a > 0.99, "native shader draws all six pixels of requested extrusion")
	check(upper.r > lower.r, "sidewall shades softly from upper lip toward base")
	check(shot.get_pixel(180, 180).a < 0.001, "shader leaves top interiors to original ground textures")
	check(shot.get_pixel(147, 180).a > 0 and shot.get_pixel(147, 180).a < 0.8, "upper perimeter lip is narrow and translucent")
	check(shot.get_pixel(180, 218).a > shot.get_pixel(180, 219).a and shot.get_pixel(180, 219).a > 0, "contact shadow fades down onto surrounding surface")
	check(is_zero_approx(shot.get_pixel(180, 222).a), "shadow becomes fully transparent away from platform")
	grid[3][2] = 2
	grid[2][3] = 2
	platform.sync(grid)
	shot = await capture(viewport)
	check(shot.get_pixel(180, 215).a < 0.001, "different-color lower neighbor removes shared wall in shader")
	check(shot.get_pixel(213, 180).a < 0.001, "different-color side neighbor has no internal rim")
	check(shot.get_pixel(244, 215).a > 0.99, "stepped exposed lower segment stays raised")
	var original: PackedByteArray = shot.get_data()
	grid[3][2] = 1
	grid[2][3] = 1
	platform.sync(grid)
	shot = await capture(viewport)
	check(shot.get_data() == original, "occupancy shader is pixel-identical for either player color")
	grid = Rules.empty_board(9)
	for y in range(5, 8):
		for x in range(5, 8):
			grid[y][x] = 1
	grid[6][6] = 0
	platform.sync(grid)
	shot = await capture(viewport)
	check(shot.get_pixel(436, 407).a > 0.99, "inner-hole upper boundary draws vertical sidewall")
	check(shot.get_pixel(436, 436).a < 0.001, "inner-hole center stays transparent")
	grid[6][6] = 2
	platform.sync(grid)
	shot = await capture(viewport)
	check(shot.get_pixel(436, 407).a < 0.001, "hole closure removes rim and wall immediately")
	grid[8][8] = 1
	platform.sync(grid)
	shot = await capture(viewport)
	check(shot.get_pixel(564, 599).a > 0.99, "outer board bottom extrusion is not clipped")
	check(shot.get_pixel(564, 607).a < 0.001, "no opaque shader rectangle beyond the contact shadow")
	DirAccess.make_dir_recursive_absolute("res://build")
	shot.save_png("res://build/platform-edge-validation.png")
	viewport.queue_free()
	# Verify shader/tree stacking with actual textures and all botanical renderers.
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var garden: Array = Rules.empty_board(9)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4)]:
		garden[cell.y][cell.x] = 1
	for cell: Vector2i in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6), Vector2i(5, 6), Vector2i(5, 7), Vector2i(6, 7)]:
		garden[cell.y][cell.x] = 2
	for theme: String in ["vines", "labyrinth", "coral_reef"]:
		scene._select_theme(theme)
		scene.game.board = garden.duplicate(true)
		scene.board_view.show_settled(scene.game.board)
		scene._refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png("res://build/platform-%s.png" % theme)
		var view = scene.board_view
		var side_point: Vector2 = view.global_position + view._point(Vector2(2.5, 5)) + Vector2(0, view.surface_depth() * 0.5)
		var contact: Color = image.get_pixelv(Vector2i(side_point))
		check(contact.r < 0.98 or contact.g < 0.98 or contact.b < 0.98, theme + ": sidewall remains visible below actual ground and plants")
	scene.queue_free()
	await create_timer(0.12).timeout
	print("Native platform: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
