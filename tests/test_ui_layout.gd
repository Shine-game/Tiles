extends SceneTree
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
const Interface = preload("res://scripts/interface_palette.gd")
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
	await process_frame
	for theme: String in Palette.THEMES:
		scene._select_theme(theme)
		if theme == "zen_garden":
			check(Interface.background() == Color.WHITE and Interface.text() == Color("202020"), "Zen interface uses neutral colors")
			check(Interface.accent(1) == Interface.accent(2), "Zen controls have no gameplay color tint")
			check(Palette.tile(1) == Color("ab946b") and Palette.tile(2) == Color("687567"), "Zen game colors remain intact")
		else:
			check(Interface.background() == Palette.background() and Interface.accent(1) == Palette.tile(1), "Other themes keep their interface styling")
		for n in [9,11]:
			scene.requested_size = n
			scene._reset()
			for dimensions in [Vector2(360,640),Vector2(390,844),Vector2(540,825),Vector2(720,1100),Vector2(844,390)]:
				scene.size = dimensions
				scene._layout()
				var bounds := Rect2(Vector2.ZERO,dimensions).grow(0.2)
				for control: Control in scene._controls()+[scene.piece_view,scene.board_view]:
					check(bounds.encloses(control.get_rect()),"Control outside viewport: %s %s" % [theme,dimensions])
				for i in range(scene._controls().size()):
					for j in range(i+1,scene._controls().size()):
						check(not scene._controls()[i].get_rect().intersects(scene._controls()[j].get_rect()),"Controls overlap: %s %s %s %s %s %s" % [theme,dimensions,i,j,scene._controls()[i].get_rect(),scene._controls()[j].get_rect()])
				check(scene.erase_button.position.y < scene.undo_button.position.y and scene.undo_button.position.y < scene.skip_button.position.y,"Jokers ordered vertically")
				check(scene.palette_button.position.x > scene.piece_view.get_rect().end.x and scene.flip_button.position.x == scene.palette_button.position.x,"Settings and flip on right")
				check(scene.place_button.position.x > scene.blue_button.position.x and scene.place_button.position.x < scene.indicators[0].panel.position.x,"Three bottom controls ordered correctly")
				check(scene.board_view._point(Vector2.ZERO).is_equal_approx(scene.board_view.field.position),"Tile grid meets frame opening")
				check(is_equal_approx(scene.board_view.pitch*n,scene.board_view.field.size.x),"Grid fills frame opening")
				if dimensions.y > dimensions.x*1.5:
					check(is_equal_approx(scene.board_view.position.x,5) and is_equal_approx(scene.board_view.get_rect().end.x,dimensions.x-5),"Both board sizes fill portrait width with five-pixel side margins")
				check(is_equal_approx(scene.piece_view.cell_pitch,scene.board_view.pitch),"Preview tiles match grid tiles")
				check(scene.blue_button.position.x >= scene._layout_insets(dimensions).x + 6,"Buttons have extra edge clearance")
	Palette.select_theme("vines")
	scene.size = Vector2(720,1100)
	scene._reset()
	check(scene.get_children().all(func(child):return not child is Label),"Playing screen has no inscriptions")
	check(is_equal_approx(scene.board_view.board_frame.thin_rim,14),"Frame thickness doubled")
	check(is_equal_approx(scene.place_button.size.x,98.952),"Bottom buttons are 20 percent larger")
	var fixed_board: Rect2 = scene.board_view.get_rect()
	var fixed_pitch: float = scene.board_view.pitch
	for piece: Dictionary in Rules.PIECES.values():
		var shape: Array = piece.cells
		for turn in range(4):
			scene.cells = shape
			scene._refresh()
			check(scene.board_view.get_rect().is_equal_approx(fixed_board) and is_equal_approx(scene.board_view.pitch,fixed_pitch),"Every offered shape and rotation keeps the board fixed")
			var preview: Dictionary = scene.piece_view.geometry()
			check(is_equal_approx(preview.unit,scene.board_view.pitch),"All orientations retain full tile size")
			for cell: Vector2i in shape:
				var face := Rect2(preview.origin+Vector2(cell)*preview.unit,Vector2.ONE*preview.unit)
				check(Rect2(Vector2.ZERO,scene.size).grow(0.1).encloses(Rect2(scene.piece_view.position+face.position,face.size)),"Rotated preview can overlap the board but stays on screen")
			shape = Rules.rotate(shape)
	scene.cells = Rules.rotate(Rules.PIECES.I.cells)
	scene._refresh()
	var tall: Dictionary = scene.piece_view.geometry()
	check(scene.piece_view.position.y+tall.origin.y+4*tall.unit > scene.board_view.position.y,"Tall tray rotation overlaps the playing board")
	check(scene.piece_view.z_index > scene.board_view.z_index,"Tray rotations render above the playing board")
	check(scene.board_view.z_index + scene.board_view.tile_floor.z_index > 0,"Tile backgrounds draw above UI background")
	scene.cells = Rules.PIECES.J.cells.duplicate()
	scene._refresh()
	var layout: Dictionary = scene.piece_view.geometry()
	var source: Vector2 = scene.piece_view.global_position + layout.origin + (Vector2(scene.cells[0])+Vector2.ONE*0.5)*layout.unit
	var before: Array = scene.cells.duplicate()
	check(scene._start_drag(source,0),"Tray accepts touch")
	scene._finish_gesture(source)
	check(scene.cells == Rules.rotate(before),"Tap rotates preview visibly")
	check(not scene.tray_moved and not scene.piece_view.cells.is_empty(),"Tap retains tray")
	layout = scene.piece_view.geometry()
	source = scene.piece_view.global_position + layout.origin + (Vector2(scene.cells[0])+Vector2.ONE*0.5)*layout.unit
	check(scene._start_drag(source,0),"Rotated tray accepts touch")
	var target: Vector2 = scene.board_view.global_position + scene.board_view._point(Vector2(3.5,3.5))
	scene._move_gesture(target)
	check(scene.tray_moved and scene.piece_view.cells.is_empty(),"First movement removes tray drawing")
	scene._finish_gesture(target)
	scene._flip()
	scene.blue_button.pressed.emit()
	check(scene.piece_view.cells.is_empty() and scene.has_hover,"Flip and color preserve hidden tray and floating piece")
	scene._skip()
	check(not scene.tray_moved and not scene.piece_view.cells.is_empty(),"Next piece restores tray")
	check(scene.indicators.size()==1 and scene.indicators[0].icon.available.size()==7,"One button contains all seven symmetry states")
	scene.game.board = Rules.empty_board(9)
	scene._refresh()
	check(scene.indicators[0].panel.disabled,"Empty board cannot save")
	scene.game.board[4][4] = Rules.BLUE
	scene._refresh()
	check(not scene.indicators[0].panel.disabled and scene.indicators[0].icon.complete.all(func(value):return value),"Symmetric design enables save")
	scene.queue_free()
	await process_frame
	print("UI layout and gestures: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
