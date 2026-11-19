extends SceneTree

const Palette = preload("res://scripts/palette.gd")
const Interface = preload("res://scripts/interface_palette.gd")
const Rules = preload("res://scripts/rules.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const Floating = preload("res://scripts/floating_piece.gd")
const Piece = preload("res://scripts/piece_view.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(320, 320)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4): await process_frame
	scene.size = Vector2(720, 1100)
	scene._layout()
	check(scene.indicators.size() == 1, "combined symmetry and save control")
	check(scene.indicators[0].panel.position.y > scene.board_view.get_rect().end.y, "symmetry control lives below the board")
	check(scene.erase_button.position.y < scene.undo_button.position.y and scene.undo_button.position.y < scene.skip_button.position.y, "joker stack follows the mockup")
	check(is_equal_approx(scene.piece_view.get_rect().get_center().x, 360), "preview is centered on the screen")
	for theme: String in Palette.THEMES:
		scene._select_theme(theme)
		for button: Button in [scene.flip_button, scene.place_button, scene.new_button, scene.size_picker, scene.skip_button]:
			check(button.get_theme_stylebox("normal").bg_color == Interface.controls().lerp(Interface.accent(1), 0.20), "ordinary buttons share the tinted symmetry background")
		var active: StyleBoxFlat = scene.blue_button.get_theme_stylebox("normal")
		var symmetry: StyleBoxFlat = scene.indicators[0].panel.get_theme_stylebox("normal")
		check(active.border_width_left == 3 and symmetry.border_width_left >= 2, "selected color button shares active symmetry styling")
		check(scene.blue_button.get_theme_stylebox("hover_pressed").border_width_left == 3, "selected color remains outlined while pressed")
		for button: Button in scene.themed_buttons:
			for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var style: StyleBoxFlat = button.get_theme_stylebox(state)
				check(style.border_width_left >= 2 and style.border_width_right >= 2 and style.border_width_top >= 2 and style.border_width_bottom >= 2, "every button has a visible border, including disabled and menu controls")
				check(style.bg_color != Interface.controls() and style.bg_color.a == 1.0, "every button retains its theme tint in every state")
		for page: String in ["Settings", "Themes", "Difficulty", "Sound Settings", "Vine colors"]:
			scene._show_menu(page)
			for button: Control in scene.menu_buttons:
				if button.visible and button is Button:
					check(button.get_theme_stylebox("normal").border_width_left >= 2, "opening a menu preserves entry outlines")
			scene.palette_menu.hide()
		var source_view := viewport()
		var floating_view := viewport()
		var placed_view := viewport()
		var source = Piece.new()
		source.cells = Rules.PIECES.L3.cells
		source.cell_pitch = 64
		source.position = Vector2(64, 64)
		source.size = Vector2(128, 128)
		source_view.add_child(source)
		var floating = Floating.new()
		floating.cells = Rules.PIECES.L3.cells
		floating.pitch = 64
		floating.valid = true
		floating.origin = Vector2(64, 64 + (4.0 if Palette.clockwork or Palette.zen_garden else Platform.depth(64)))
		floating_view.add_child(floating)
		var placed = Platform.new()
		placed_view.add_child(placed)
		placed.sync([[1, 0], [1, 1]])
		# Use equal ink to isolate geometry, depth, edge lighting and shadow.
		placed.configure(Vector2(64, 64), 64, Palette.platform_color() if Palette.zen_garden else Palette.tile(1), Palette.coral_reef, 4 if Palette.clockwork or Palette.zen_garden else -1, not Palette.zen_garden)
		for i in range(4): await process_frame
		var source_slab = source.get_node("PieceSlab")
		var floating_slab = floating.get_node("PieceSlab")
		check(source_slab.cell_pixels == placed.cell_pixels and floating_slab.cell_pixels == placed.cell_pixels, "unplaced faces use full playing-cell width")
		check(source_slab.depth_pixels == placed.depth_pixels and floating_slab.depth_pixels == placed.depth_pixels, "unplaced depth exactly matches placed depth")
		check(source_slab.occupancy_bytes == placed.occupancy_bytes and floating_slab.occupancy_bytes == placed.occupancy_bytes, "unplaced squares fuse at shared boundaries")
		for slab in [source_slab, floating_slab]:
			check(not slab.side_at(Vector2(0.5, 1.02)), "no internal sidewall or duplicate shadow between joined squares")
			check(slab.material.shader == placed.material.shader, "unplaced pieces use the placed shadow and edge shader")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if Palette.zen_garden:
				check(source_view.get_texture().get_image().get_data() == floating_view.get_texture().get_image().get_data(), "Zen incoming and hover pieces have identical sand, clipping, depth and shadows")
				check(source_slab.get_node("ZenSand").visible and floating_slab.get_node("ZenSand").visible, "Zen incoming and hover faces use sand rather than a logical-color fill")
			else:
				var reference: PackedByteArray = placed_view.get_texture().get_image().get_data()
				check(source_view.get_texture().get_image().get_data() == reference, "source face, thickness, rounded joins and shadow match placed pixels: " + theme)
				check(floating_view.get_texture().get_image().get_data() == reference, "hover face, thickness, rounded joins and shadow match placed pixels: " + theme)
		for view: SubViewport in [source_view, floating_view, placed_view]: view.queue_free()
		await process_frame
	scene.queue_free()
	await process_frame
	print("Piece surface/style: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
