extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(720,1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for theme in ["vines","clockwork","coral_reef"]:
		scene._select_theme(theme)
		var board_rect: Rect2 = scene.board_view.get_rect()
		scene.cells = [Vector2i.ZERO]
		scene.has_hover = true
		scene.tray_moved = true
		for anchor in [Vector2i(-1,-1),Vector2i(5,4)]:
			scene.selected = anchor
			for color in [Rules.BLUE,Rules.CORAL,Rules.BLUE]:
				scene._choose_color(color)
				for frame in range(2): await process_frame
				var slab = scene.floating_piece.get_node_or_null("PieceSlab")
				check(slab != null,"Floating preview is rendered")
				if slab != null:
					check(slab.material.get_shader_parameter("ground_color").is_equal_approx(Palette.tile(color)),"Rendered preview keeps selected color even when placement is invalid: " + theme)
				check(not scene.place_button.disabled,"Color changes preserve placement rules")
				check(scene.board_view.get_rect().is_equal_approx(board_rect),"Hover and color changes cannot move the board")
		scene._clear_selection()
		scene._skip()
		check(scene.board_view.get_rect().is_equal_approx(board_rect),"Skipping to a new offer keeps the board fixed")
	scene.queue_free()
	await process_frame
	print("Preview colors and board stability: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
