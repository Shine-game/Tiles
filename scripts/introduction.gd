extends Control
signal finished
const Model = preload("res://scripts/tutorial_model.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/interface_theme.gd")
const Board = preload("res://scripts/board_view.gd")
const TEXT := ["", "The beauty of symmetry.", "Rotate your tile.\nTap the tile.", "Or flip it.", "Change its colors.", "Make both sides match.\nDrag your tile, then tap Place.", "Now match top and bottom.", "Some patterns match after a half-turn.", "Your turn: restore vertical symmetry.", "Same tiles: restore horizontal symmetry.", "Same tiles: restore half-turn symmetry.", "Every move matters.\nPreserve the symmetry."]
var progress_path := Model.PATH
var persist := true
var stage := 1
var elapsed := 0.0
var idle := 0.0
var demo := false
var succeeding := false
var attempts := 0
var hint_offered := false
var hint_visible := false
var puzzle := {}
var grid: Array = []
var cells: Array = []
var color := 1
var anchor := Vector2i(-10,-10)
var selected := false
var drag := false
var drag_start := Vector2.ZERO
var grabbed := Vector2i.ZERO
var held := false
var board_rect := Rect2()
var tray_rect := Rect2()
var board_angle := 0.0
var mirror_amount := 0.0
var success_elapsed := 0.0
var text: Label
var progress_label: Label
var skip: Button
var flip: Button
var recolor: Button
var place: Button
var advance: Button
var hint: Button
var tray: Control
var showcase: Control
var previous_pause := false
var host: Control
var saved_controls: Array = []
var saved_visibility := {}
var saved_place_text := ""
var saved_skip_tooltip := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_pause = get_tree().paused
	get_tree().paused = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	theme = UI.build()
	text = Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color",Color("303C39"))
	add_child(text)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color",Color("55615C"))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_label)
	assert(host != null, "Introduction uses the existing game interface")
	skip = host.skip_button
	flip = host.flip_button
	recolor = host.blue_button
	place = host.place_button
	advance = place
	hint = host.indicators[0].panel
	tray = host.piece_view
	saved_place_text = place.text
	saved_skip_tooltip = skip.tooltip_text
	skip.tooltip_text = "Skip tutorial"
	for control: Button in host._controls():
		saved_controls.append({"node":control,"mode":control.process_mode,"disabled":control.disabled})
		control.process_mode = Node.PROCESS_MODE_ALWAYS
		control.disabled = true
	for control: Control in [host.piece_view,host.floating_piece]:
		saved_visibility[control] = control.visible
		control.hide()
	skip.disabled = false
	host.resized.connect(layout)

	resized.connect(layout)
	enter(stage)

func enter(step: int) -> void:
	var keep_piece := stage in [2,3,4] and step == stage+1
	stage = step
	elapsed = 0
	idle = 0
	attempts = 0
	hint_visible = false
	hint_offered = false
	succeeding = false
	if not keep_piece: selected = false
	drag = false
	held = false
	board_angle = 0
	mirror_amount = 0
	if persist: Model.save_progress(stage,false,progress_path)
	if stage == 1:
		grid = Rules.empty_board(5)
		for cell in [Vector2i(1,1),Vector2i(3,1),Vector2i(1,3),Vector2i(3,3)]: grid[cell.y][cell.x] = 2
		for cell in [Vector2i(2,1),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(2,3)]: grid[cell.y][cell.x] = 1
	elif stage == 2 or (stage >= 6 and stage <= 10) or puzzle.is_empty():
		puzzle = Model.recipe(stage)
		grid = puzzle.board.duplicate(true)
		cells = puzzle.offered.duplicate()
		color = 1
	text.text = TEXT[stage]
	progress_label.text = "%d / 11" % stage
	demo = stage in [1,2,3,4,7]
	if stage == 11:
		demo = false
		show_art()
	layout()
	update_controls()
	queue_redraw()

func layout() -> void:
	if text == null or host == null: return
	var field: Rect2 = host.board_view.field
	board_rect = Rect2(host.board_view.position+field.position,field.size)
	tray_rect = host.piece_view.get_rect()
	text.position = Vector2(16,host.board_view.get_rect().end.y+3)
	text.size = Vector2(host.size.x-32,maxf(30,place.position.y-text.position.y-4))
	text.add_theme_font_size_override("font_size",clampi(roundi(host.size.x*0.033),12,21))
	progress_label.position = Vector2(tray_rect.position.x,tray_rect.position.y-8)
	progress_label.size = Vector2(tray_rect.size.x,18)
	progress_label.add_theme_font_size_override("font_size",12)
	if showcase != null:
		showcase.position = host.board_view.position
		showcase.size = host.board_view.size
		showcase.update_geometry()
	queue_redraw()

func update_controls() -> void:
	flip.disabled = demo or succeeding or stage < 3 or stage == 11
	recolor.disabled = demo or succeeding or stage < 4 or stage == 11
	place.disabled = demo or succeeding or stage < 5 or not selected
	if stage in [1,11]: place.disabled = stage == 1 and elapsed < 7
	place.text = ("Begin" if stage == 11 else "Continue") if stage in [1,11] else saved_place_text
	place.get_child(0).visible = stage not in [1,11]
	hint.disabled = stage < 5 or stage == 11
	skip.disabled = false
	skip.get_child(0).count = -1
	skip.get_child(0).queue_redraw()
	recolor.get_child(0).color = color
	recolor.get_child(0).queue_redraw()
	var prediction: Array = grid.duplicate(true)
	if selected and not succeeding:
		for offset: Vector2i in cells:
			var cell := anchor+offset
			if cell.x in range(5) and cell.y in range(5): prediction[cell.y][cell.x] = color
	var states := Rules.symmetry_states(prediction)
	var icon = host.indicators[0].icon
	icon.available = states.map(func(state): return state.possible)
	icon.complete = states.map(func(state): return state.complete)
	icon.saved = false
	icon.queue_redraw()

func ink(index: int) -> Color:
	return Palette.tile(index)

func transform_piece(operation: String) -> void:
	if demo or succeeding or stage < 2 or stage > 10: return
	if operation == "flip" and stage < 3: return
	if operation == "color" and stage < 4: return
	match operation:
		"rotate": cells = Rules.rotate(cells)
		"flip": cells = Rules.flip(cells)
		"color": color = 3-color
	if selected: clamp_anchor()
	idle = 0
	if (stage == 2 and operation == "rotate") or (stage == 3 and operation == "flip"):
		enter(stage+1)
	elif stage == 4 and operation == "color":
		text.text = "Now find the perfect fit."
		succeeding = true
		success_elapsed = 0
	update_controls()
	queue_redraw()

func offer_hint() -> void:
	hint_offered = true
	text.text = "Need a hint? Tap the symmetry button."
	update_controls()

func show_hint() -> void:
	hint_visible = true
	text.text = "Match the hatched spaces.\nTap to rotate; flip and change color as needed."
	queue_redraw()

func try_place() -> void:
	if stage in [1,11]:
		next_step()
		return
	if stage < 5 or stage > 10 or demo or succeeding or not selected: return
	idle = 0
	if Model.accepts(puzzle,cells,anchor,color):
		grid = puzzle.target.duplicate(true)
		selected = false
		succeeding = true
		success_elapsed = 0
	else:
		attempts += 1
		text.text = "Try another fit."
		if attempts >= 2: offer_hint()
	update_controls()
	queue_redraw()

func next_step() -> void:
	if stage == 11: finish(false)
	elif stage == 1 and elapsed >= 7: enter(2)

func finish(_skipped: bool) -> void:
	if persist: Model.save_progress(stage,true,progress_path)
	for record: Dictionary in saved_controls:
		record.node.process_mode = record.mode
		record.node.disabled = record.disabled
	for control: Control in saved_visibility: control.visible = saved_visibility[control]
	place.text = saved_place_text
	place.get_child(0).show()
	skip.tooltip_text = saved_skip_tooltip
	get_tree().paused = previous_pause
	finished.emit()
	host._refresh()
	queue_free()

func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null: tree.paused = previous_pause

func _process(delta: float) -> void:
	elapsed += delta
	idle += delta
	if stage == 1:
		if elapsed > 3 and elapsed < 5: board_angle = PI*smoothstep(3,5,elapsed)
		elif elapsed >= 5: board_angle = PI
		if elapsed >= 6:
			grid[1][1] = 0
			text.text = "Can you restore it?"
		demo = elapsed < 7
	elif stage == 2 and demo and elapsed >= 3:
		cells = Rules.rotate(Rules.rotate(cells))
		demo = false
	elif stage == 3 and demo and elapsed >= 2:
		cells = Rules.flip(cells)
		demo = false
	elif stage == 4 and demo and elapsed >= 2: demo = false
	elif stage == 7 and demo:
		mirror_amount = clampf(elapsed/2.0,0,1)
		if elapsed >= 2.5: demo = false
	if succeeding:
		success_elapsed += delta
		if stage == 7: board_angle = PI*smoothstep(0.2,1.8,success_elapsed)
		if stage == 6: mirror_amount = sin(clampf(success_elapsed/2,0,1)*PI)
		if success_elapsed > (1.3 if stage == 4 else 2.3): enter(stage+1)
	elif stage in range(5,11) and idle > 18 and not hint_offered: offer_hint()
	update_controls()
	queue_redraw()

func tray_geometry() -> Dictionary:
	var extent := Vector2i.ONE
	for cell: Vector2i in cells: extent = extent.max(cell+Vector2i.ONE)
	var unit := minf(tray_rect.size.x/maxi(4,extent.x),tray_rect.size.y/maxi(2,extent.y))*0.85
	return {"unit":unit,"origin":tray_rect.get_center()-Vector2(extent)*unit/2}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		var point: Vector2 = event.position
		if held or board_rect.has_point(point) or tray_rect.has_point(point): _gui_input(event)

func _gui_input(event: InputEvent) -> void:
	if demo or succeeding or stage < 2 or stage > 10: return
	var point := Vector2.ZERO
	var pressed := false
	var motion := false
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index != 0: return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1: return # Touch-generated mouse duplicate.
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT: return
		point = event.position
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		point = event.position
		pressed = event.pressed
	elif event is InputEventMouseMotion:
		point = event.position
		motion = true
	elif event is InputEventScreenDrag:
		point = event.position
		motion = true
	else: return
	if motion:
		if held and point.distance_to(drag_start) > 10:
			drag = true
			select_at(point)
		return
	if pressed:
		var hit := piece_cell_at(point)
		if hit.x < 0: return # The guide and empty board never pick up or move a tile.
		held = true
		drag_start = point
		grabbed = hit
	else:
		if held and not drag: transform_piece("rotate")
		held = false
		drag = false
	accept_event()

func piece_cell_at(point: Vector2) -> Vector2i:
	var local: Vector2
	if selected:
		if not board_rect.has_point(point): return Vector2i(-1,-1)
		local = (point-board_rect.position)/(board_rect.size.x/5)-Vector2(anchor)
	else:
		var geometry := tray_geometry()
		local = (point-geometry.origin)/geometry.unit
	var cell := Vector2i(floori(local.x),floori(local.y))
	return cell if cell in cells else Vector2i(-1,-1)

func clamp_anchor() -> void:
	var extent := Vector2i.ONE
	for cell: Vector2i in cells: extent = extent.max(cell+Vector2i.ONE)
	anchor = Vector2i(clampi(anchor.x,0,5-extent.x),clampi(anchor.y,0,5-extent.y))

func select_at(point: Vector2) -> void:
	if tray_rect.has_point(point):
		selected = false
	elif board_rect.has_point(point):
		var relative := (point-board_rect.position)/(board_rect.size.x/5)
		anchor = Vector2i(floori(relative.x),floori(relative.y))-grabbed
		clamp_anchor()
		selected = true
	else: return
	idle = 0
	update_controls()
	queue_redraw()

func guide_cells() -> Array:
	return puzzle.missing.duplicate() if not succeeding and (stage in [5,6,7] or (stage in [8,9,10] and hint_visible)) else []

func hatched_guide(rect: Rect2) -> void:
	var bounds := rect.grow(-4)
	var width := bounds.size.x
	var height := bounds.size.y
	var stroke := Color("477D76",0.2)
	draw_rect(bounds,Color("477D76",0.3),false,1)
	var diagonal := 0.0
	while diagonal <= width+height:
		var a := Vector2(maxf(0,diagonal-height),minf(height,diagonal))
		var b := Vector2(minf(width,diagonal),maxf(0,diagonal-width))
		draw_line(bounds.position+a,bounds.position+b,stroke,1,true)
		diagonal += 9

func tile(rect: Rect2, ink: Color, opacity: float = 1.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ink,opacity)
	style.set_corner_radius_all(4)
	draw_style_box(style,rect.grow(-1.5))

func _draw() -> void:
	draw_rect(board_rect,Color("FFF9F3"))
	if grid.is_empty() or stage == 11: return
	var unit := board_rect.size.x/5
	var center := board_rect.get_center()
	for y in range(5):
		for x in range(5):
			tile(Rect2(board_rect.position+Vector2(x,y)*unit,Vector2.ONE*unit),Color("F1E7EB"))
	# Keep the playing field fixed while the pattern makes its half-turn.
	var fit := 1.0/(absf(cos(board_angle))+absf(sin(board_angle)))
	draw_set_transform(center,board_angle,Vector2.ONE*fit)
	for y in range(5):
		for x in range(5):
			if grid[y][x] > 0:
				tile(Rect2(Vector2(x,y)*unit-board_rect.size/2,Vector2.ONE*unit),ink(grid[y][x]))
	draw_set_transform(center)
	var axis := -1
	if stage == 1 and elapsed < 6: axis = 0 if elapsed < 1.5 else 1
	elif stage in [5,6,7,8,9,10] and (not succeeding or stage in [5,8,9,10]): axis = puzzle.symmetry
	if axis in [0,1]:
		var a := Vector2(0,-board_rect.size.y/2) if axis == 0 else Vector2(-board_rect.size.x/2,0)
		var b := -a
		draw_dashed_line(a,b,Color("477D76"),3 if succeeding else 2,7)
	if axis == 5:
		draw_circle(Vector2.ZERO,6,Color("477D76"))
		draw_arc(Vector2.ZERO,unit*0.35,-PI/2,PI/2,20,Color("477D76"),2,true)
	draw_set_transform(Vector2.ZERO)
	if stage in range(2,11) and not succeeding:
		var geometry := tray_geometry()
		var rotation := 0.0
		if stage == 2 and demo:
			rotation = (PI/2 if elapsed > 0.8 else 0) + (PI/2 if elapsed > 2 else 0)
		var flip_x := -1.0 if stage == 3 and demo and elapsed > 0.8 else 1.0
		var demo_color := 3-color if stage == 4 and demo and elapsed > 0.8 else color
		if not selected:
			draw_set_transform(tray_rect.get_center(),rotation,Vector2(flip_x,1))
			for cell: Vector2i in cells:
				tile(Rect2(geometry.origin-tray_rect.get_center()+Vector2(cell)*geometry.unit,Vector2.ONE*geometry.unit),ink(demo_color))
			draw_set_transform(Vector2.ZERO)
		if stage == 2:
			var focus := board_rect if selected else tray_rect
			draw_rect(focus.grow(3),Color("477D76",0.6+sin(elapsed*4)*0.3),false,2)
		for cell: Vector2i in guide_cells():
			hatched_guide(Rect2(board_rect.position+Vector2(cell)*unit,Vector2.ONE*unit))
		if selected:
			var display: Array = Rules.flip(cells) if stage == 3 and demo and elapsed > 0.8 else cells
			for offset: Vector2i in display:
				var rect := Rect2(board_rect.position+Vector2(anchor+offset)*unit,Vector2.ONE*unit)
				tile(rect,ink(demo_color))
				draw_rect(rect.grow(-2),Color("303C39",0.45),false,1)
	if stage in [3,4] and not succeeding:
		var control: Button = flip if stage == 3 else recolor
		draw_rect(control.get_rect().grow(3),Color("477D76",0.6+sin(elapsed*4)*0.3),false,2)
	if stage in range(5,11) and (selected or succeeding):
		draw_rect(hint.get_rect().grow(3),Color("477D76",0.7+0.2*sin(elapsed*5)),false,3)
	if (stage == 5 and elapsed < 3) or (stage == 7 and demo) or (stage == 6 and succeeding):
		var opacity := 0.2+0.4*absf(sin(elapsed*3))
		for y in range(5):
			for x in range(5):
				if puzzle.board[y][x] == 2:
					draw_rect(Rect2(board_rect.position+Vector2(x,y)*unit,Vector2.ONE*unit).grow(-4),Color("477D76",opacity),false,2)

func show_art() -> void:
	grid = Rules.empty_board(5)
	showcase = Board.new()
	showcase.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(showcase)
	var art := Rules.create_board(9)
	for y in range(1,8):
		for x in range(1,8):
			if x in [1,2,6,7] or y in [1,2,6,7]: art[y][x] = 1
	showcase.show_settled(art)
	showcase.modulate.a = 0
	create_tween().tween_property(showcase,"modulate:a",1.0,2.0)
