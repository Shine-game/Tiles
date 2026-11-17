extends SceneTree
# Visual regression harness; requires a real graphics backend.
const Board = preload("res://scripts/board_view.gd")
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: run.call_deferred()
func capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func differences(a: Image, b: Image) -> int:
	var count := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) + absf(ca.a - cb.a) > 0.03: count += 1
	return count
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/tier1-generation")
	for theme: String in Palette.THEMES:
		Palette.select_theme(theme)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720, 720)
		viewport.disable_3d = true
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var board := Board.new()
		board.size = Vector2(720, 720)
		board.show_guides = false
		viewport.add_child(board)
		var empty := Rules.empty_board(7)
		var grid := empty.duplicate(true)
		for color in [1, 2]:
			var y: int = 1 if color == 1 else 4
			for p: Vector2i in [Vector2i(1, y), Vector2i(2, y), Vector2i(3, y), Vector2i(2, y + 1), Vector2i(4, y + 1), Vector2i(5, y + 1), Vector2i(5, y)]: grid[p.y][p.x] = color
		board.show_settled(empty)
		board.animate_growth(empty, grid)
		board.set_process(false)
		var initial := await capture(viewport)
		board.advance_growth(0.15)
		var partial := await capture(viewport)
		board.advance_growth(100)
		var settled := await capture(viewport)
		check(differences(initial, partial) > 40, "Theme visibly grows: " + theme)
		check(differences(partial, settled) > 40, "Theme reaches completed art: " + theme)
		check(board.tier1_layer.diagnostics.is_empty(), "Theme renders without presentation diagnostics: " + theme)
		settled.save_png("res://build/tier1-generation/" + theme + "-settled.png")
		partial.save_png("res://build/tier1-generation/" + theme + "-partial.png")
		if theme == "vines":
			Palette.select(1)
			board._restyle()
			board.set_process(false)
			var recolored := await capture(viewport)
			check(differences(settled, recolored) > 200, "Palette change affects rendered source art")
			recolored.save_png("res://build/tier1-generation/vines-blue-snow.png")
			Palette.select(0)
		viewport.queue_free()
		await process_frame
	print("Tier 1 rendered themes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
