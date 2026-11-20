extends Control
signal finished
const Model = preload("res://scripts/tutorial_model.gd")
const Rules = preload("res://scripts/rules.gd")
const UI = preload("res://scripts/interface_theme.gd")
const Board = preload("res://scripts/board_view.gd")
const COLORS := [Color.TRANSPARENT,Color("468BA6"),Color("D87787")]
const TEXT := ["", "The beauty of symmetry.", "Rotate your tile.\nTap the tile.", "Or flip it.", "Change its colors.", "Make both sides match.\nDrag your tile, then tap Place.", "Now match top and bottom.", "Some patterns match after a half-turn.", "Find the symmetry. Complete the pattern.", "Every move matters.\nPreserve the symmetry."]
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
var tray: Button
var showcase: Control
var previous_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_pause = get_tree().paused
	get_tree().paused = true
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	add_child(progress_label)
	skip = button("Skip", finish.bind(true))
	flip = button("Flip", transform_piece.bind("flip"))
	recolor = button("Color", transform_piece.bind("color"))
	place = button("Place", try_place)
	advance = button("Continue", next_step)
	hint = button("Hint", show_hint)
	tray = button("", transform_piece.bind("rotate"))
	tray.tooltip_text = "Tap to rotate; drag to the board"
	for state in ["normal","hover","pressed","disabled","focus"]: tray.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	# The tray and board share one gesture handler, preserving the grabbed cell.
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(layout)
	enter(stage)

func button(caption: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = caption
	control.pressed.connect(callback)
	add_child(control)
	return control

func enter(step: int) -> void:
	stage = step
	elapsed = 0
	idle = 0
	attempts = 0
	hint_visible = false
	hint_offered = false
	succeeding = false
	selected = false
	drag = false
	held = false
	board_angle = 0
	mirror_amount = 0
	if persist: Model.save_progress(stage,false,progress_path)
	if stage == 1:
		grid = Rules.empty_board(5)
		for cell in [Vector2i(1,1),Vector2i(3,1),Vector2i(1,3),Vector2i(3,3)]: grid[cell.y][cell.x] = 2
		for cell in [Vector2i(2,1),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(2,3)]: grid[cell.y][cell.x] = 1
	elif stage == 2 or (stage >= 6 and stage <= 8) or puzzle.is_empty():
		puzzle = Model.recipe(stage)
		grid = puzzle.board.duplicate(true)
		cells = puzzle.offered.duplicate()
		color = 1
	text.text = TEXT[stage]
	progress_label.text = "%d / 9" % stage
	demo = stage in [1,2,3,4,7]
	if stage == 9:
		demo = false
		show_art()
	layout()
	update_controls()
	queue_redraw()

func layout() -> void:
	if text == null: return
	var scale_factor := clampf(size.y/825.0,0.55,1.3)
	var padding := 16.0
	var control_height := maxf(38,48*scale_factor)
	var top := 226*scale_factor
	var side := maxf(60,minf(size.x-2*padding,size.y-top-control_height-42))
	board_rect = Rect2((size.x-side)/2,top,side,side)
	tray_rect = Rect2(size.x*0.2,140*scale_factor,size.x*0.6,70*scale_factor)
	text.position = Vector2(padding,54*scale_factor)
	text.size = Vector2(size.x-2*padding,72*scale_factor)
	text.add_theme_font_size_override("font_size",clampi(roundi(24*scale_factor),17,28))
	progress_label.position = Vector2(size.x/2-35,16)
	progress_label.size = Vector2(70,30)
	skip.position = Vector2(size.x-82,12)
	skip.size = Vector2(70,36)
	hint.position = Vector2(12,12)
	hint.size = Vector2(72,36)
	tray.position = tray_rect.position
	tray.size = tray_rect.size
	var y := size.y-padding-control_height
	var width := (size.x-2*padding-20)/3.0
	for i in range(3):
		var control: Button = [recolor,place,flip][i]
		control.position = Vector2(padding+i*(width+10),y)
		control.size = Vector2(width,control_height)
	advance.position = Vector2(size.x*0.25,y)
	advance.size = Vector2(size.x*0.5,control_height)
	if showcase != null:
		showcase.position = board_rect.position
		showcase.size = board_rect.size
		showcase.update_geometry()
	queue_redraw()

func update_controls() -> void:
	for control: Button in [flip,recolor,place,tray]: control.visible = stage in range(2,9)
	flip.disabled = demo or succeeding or stage < 3
	recolor.disabled = demo or succeeding or stage < 4
	place.disabled = demo or succeeding or stage < 5 or not selected
	tray.disabled = demo or succeeding
	advance.visible = stage in [1,9]
	advance.disabled = stage == 1 and elapsed < 7
	advance.text = "Begin" if stage == 9 else "Continue"
	hint.visible = hint_offered and stage in range(5,9) and not succeeding

func transform_piece(operation: String) -> void:
	if demo or succeeding or stage < 2 or stage > 8: return
	if operation == "flip" and stage < 3: return
	if operation == "color" and stage < 4: return
	match operation:
		"rotate": cells = Rules.rotate(cells)
		"flip": cells = Rules.flip(cells)
		"color": color = 3-color
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
	text.text = "Need a hint?"
	update_controls()

func show_hint() -> void:
	hint_visible = true
	text.text = "Match the outlined spaces.\nTap to rotate; flip and change color as needed."
	queue_redraw()

func try_place() -> void:
	if stage < 5 or stage > 8 or demo or succeeding or not selected: return
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
	if stage == 9: finish(false)
	elif stage == 1 and elapsed >= 7: enter(2)

func finish(_skipped: bool) -> void:
	if persist: Model.save_progress(stage,true,progress_path)
	get_tree().paused = previous_pause
	finished.emit()
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
	elif stage in range(5,9) and idle > 18 and not hint_offered: offer_hint()
	update_controls()
	queue_redraw()

func tray_geometry() -> Dictionary:
	var extent := Vector2i.ONE
	for cell: Vector2i in cells: extent = extent.max(cell+Vector2i.ONE)
	var unit := minf(tray_rect.size.x/maxi(4,extent.x),tray_rect.size.y/maxi(2,extent.y))*0.85
	return {"unit":unit,"origin":tray_rect.get_center()-Vector2(extent)*unit/2}

func _gui_input(event: InputEvent) -> void:
	if demo or succeeding or stage < 2 or stage > 8: return
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
		if held and point.distance_to(drag_start) > 10 and stage >= 5:
			drag = true
			select_at(point)
		return
	if pressed:
		if tray_rect.has_point(point):
			held = true
			drag_start = point
			var geometry := tray_geometry()
			grabbed = Vector2i((point-geometry.origin)/geometry.unit)
			if grabbed not in cells: grabbed = cells[0]
		elif board_rect.has_point(point) and stage >= 5:
			grabbed = Vector2i.ZERO
			select_at(point)
	else:
		if held and not drag: transform_piece("rotate")
		held = false
		drag = false
	accept_event()

func select_at(point: Vector2) -> void:
	if not board_rect.has_point(point): return
	anchor = Vector2i((point-board_rect.position)/(board_rect.size.x/5))-grabbed
	selected = true
	idle = 0
	update_controls()
	queue_redraw()

func tile(rect: Rect2, ink: Color, opacity: float = 1.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ink,opacity)
	style.set_corner_radius_all(4)
	draw_style_box(style,rect.grow(-1.5))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("FFF9F3"))
	if grid.is_empty() or stage == 9: return
	var unit := board_rect.size.x/5
	var center := board_rect.get_center()
	draw_set_transform(center,board_angle)
	for y in range(5):
		for x in range(5):
			var rect := Rect2(Vector2(x,y)*unit-board_rect.size/2,Vector2.ONE*unit)
			tile(rect,Color("F1E7EB"))
			if grid[y][x] > 0: tile(rect,COLORS[grid[y][x]])
	var axis := -1
	if stage == 1 and elapsed < 6: axis = 0 if elapsed < 1.5 else 1
	elif stage in [5,6,7] and (not succeeding or stage == 5): axis = puzzle.symmetry
	if axis in [0,1]:
		var a := Vector2(0,-board_rect.size.y/2) if axis == 0 else Vector2(-board_rect.size.x/2,0)
		var b := -a
		draw_dashed_line(a,b,Color("477D76"),3 if succeeding else 2,7)
	if axis == 5:
		draw_circle(Vector2.ZERO,6,Color("477D76"))
		draw_arc(Vector2.ZERO,unit*0.35,-PI/2,PI/2,20,Color("477D76"),2,true)
	draw_set_transform(Vector2.ZERO)
	if stage in range(2,9) and not succeeding:
		var geometry := tray_geometry()
		var rotation := 0.0
		if stage == 2 and demo:
			rotation = (PI/2 if elapsed > 0.8 else 0) + (PI/2 if elapsed > 2 else 0)
		var flip_x := -1.0 if stage == 3 and demo and elapsed > 0.8 else 1.0
		var demo_color := 3-color if stage == 4 and demo and elapsed > 0.8 else color
		draw_set_transform(tray_rect.get_center(),rotation,Vector2(flip_x,1))
		for cell: Vector2i in cells:
			tile(Rect2(geometry.origin-tray_rect.get_center()+Vector2(cell)*geometry.unit,Vector2.ONE*geometry.unit),COLORS[demo_color])
		draw_set_transform(Vector2.ZERO)
		if stage == 2: draw_rect(tray_rect.grow(3),Color("477D76",0.6+sin(elapsed*4)*0.3),false,2)
		if hint_visible:
			for cell: Vector2i in puzzle.missing:
				draw_rect(Rect2(board_rect.position+Vector2(cell)*unit,Vector2.ONE*unit).grow(-3),Color("477D76"),false,2)
		if selected:
			for offset: Vector2i in cells:
				var cell := anchor+offset
				if cell.x in range(5) and cell.y in range(5): tile(Rect2(board_rect.position+Vector2(cell)*unit,Vector2.ONE*unit),COLORS[color],0.6)
	if stage in [3,4] and not succeeding:
		var control: Button = flip if stage == 3 else recolor
		draw_rect(control.get_rect().grow(3),Color("477D76",0.6+sin(elapsed*4)*0.3),false,2)
	# Short-lived reflected ghosts explain the relationship without changing cells.
	if (stage == 5 and elapsed < 3) or (stage == 7 and demo) or (stage == 6 and succeeding):
		for y in range(5):
			for x in range(5):
				if puzzle.board[y][x] != 2: continue
				var original := Vector2(x,y)+Vector2.ONE/2
				var partner := Vector2(Rules.transform(Vector2i(x,y),puzzle.symmetry,5))+Vector2.ONE/2
				var amount := (elapsed/3 if stage == 5 else mirror_amount)
				var position := original.lerp(partner,clampf(amount,0,1))
				if stage == 7: position = Vector2(2.5,2.5)+(original-Vector2(2.5,2.5)).rotated(PI*mirror_amount)
				tile(Rect2(board_rect.position+(position-Vector2.ONE/2)*unit,Vector2.ONE*unit),COLORS[2],0.3)

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
