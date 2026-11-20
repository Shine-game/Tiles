extends Control
signal finished
const Model = preload("res://scripts/tutorial_model.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/interface_theme.gd")
const TEXT := ["", "The beauty of symmetry.", "Drag the piece to its position,\nthen press the place button.", "Tap the tile to rotate it.", "Press to flip.", "Press to change color.", "Find the vertical symmetry.", "Find the horizontal symmetry.", "Find the rotational symmetry.", "Watch the axes for hints.\nA completed symmetry lights its axis.\nA broken symmetry loses its axis.", "Save a wrong placement:\nerase one tile, undo a move,\nor get a new piece.", "Enjoy infinite creations.\nFollow the marked placements."]
const ANIMATION_SECONDS := 0.32
var progress_path := Model.PATH
var persist := true
var stage := 1
var elapsed := 0.0
var host: Control
var previous_pause := false
var normal_board_rect := Rect2()
var adjusted_board_rect := Rect2()
var board_rect := Rect2()
var tray_rect := Rect2()
var text: Label
var progress_label: Label
var skip: Button
var forward: Button
var flip: Button
var recolor: Button
var place: Button
var hint: Button
var saved_controls: Array = []
var saved_visibility := {}
var pulse_bases := {}
var pulsing: Array = []
var grid: Array = []
var puzzle := {}
var cells: Array = []
var color := 1
var anchor := Vector2i.ZERO
var selected := false
var held := false
var drag := false
var drag_start := Vector2.ZERO
var grabbed := Vector2i.ZERO
var hint_visible := false
var attempts := 0
var animation := ""
var animation_time := 0.0
var animation_color := 1
var demo_lost := false
var desaturation := 0.0
var seed_started := false
var seed_index := 0
var seed_old_modes := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_pause = get_tree().paused
	get_tree().paused = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	theme = UI.build()
	text = Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color",Color("303C39"))
	add_child(text)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.add_theme_color_override("font_color",Color("55615C"))
	add_child(progress_label)
	assert(host != null)
	skip = host.replay_button
	forward = host.palette_button
	flip = host.flip_button
	recolor = host.blue_button
	place = host.place_button
	hint = host.indicators[0].panel
	for control: Button in host._controls():
		saved_controls.append({"node":control,"mode":control.process_mode,"disabled":control.disabled,"visible":control.visible,"text":control.text,"tooltip":control.tooltip_text,"icon_visible":control.get_child(0).visible,"icon_kind":control.get_child(0).get("kind"),"icon_count":control.get_child(0).get("count")})
		control.process_mode = Node.PROCESS_MODE_ALWAYS
		control.show()
		control.disabled = true
	forward.get_child(0).kind = "skip"
	forward.get_child(0).count = -1
	forward.tooltip_text = "Forward"
	skip.get_child(0).kind = "close"
	skip.tooltip_text = "End tutorial"
	for control: Control in [host.piece_view,host.floating_piece]:
		saved_visibility[control] = control.visible
		control.hide()
	host.resized.connect(layout)
	resized.connect(layout)
	enter(stage)

func enter(step: int) -> void:
	reset_pulses()
	var keep_piece := stage in [3,4] and step == stage+1
	stage = step
	elapsed = 0
	animation = ""
	animation_time = 0
	held = false
	drag = false
	hint_visible = false
	attempts = 0
	if not keep_piece: selected = false
	desaturation = 0
	demo_lost = false
	text.text = TEXT[stage]
	progress_label.text = "%d / 11" % stage
	if stage == 1:
		grid = Model.principle()
		cells = []
	elif stage == 2 or stage in [6,7,8]:
		puzzle = Model.recipe(stage)
		grid = puzzle.board.duplicate(true)
		cells = puzzle.offered.duplicate()
		color = 2 if stage == 2 else 1
	elif stage in [3,4,5]:
		if not keep_piece:
			grid = Model.principle()
			cells = Rules.PIECES.J.cells.duplicate()
			color = 1
	elif stage == 9:
		grid = Model.axis_demo_board()
		cells = []
	elif stage == 10:
		grid = Model.placed(Model.axis_demo_board(),[Vector2i.ZERO,Vector2i.RIGHT],Vector2i(1,1),1)
		grid = Model.placed(grid,[Vector2i.ZERO],Vector2i(3,1),2)
		cells = []
		desaturation = 1
	elif stage == 11: start_seed()
	if persist: Model.save_progress(stage,false,progress_path,seed_index)
	choose_pulses()
	layout()
	update_controls()
	queue_redraw()

func choose_pulses() -> void:
	match stage:
		2: pulsing = [place]
		4: pulsing = [flip]
		5: pulsing = [recolor]
		6,7,8,9: pulsing = [hint]
		10: pulsing = [host.erase_button,host.undo_button,host.skip_button]
		11: pulsing = [place]
		_: pulsing = []
	for control: Button in pulsing:
		var states := {}
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:
			var base: StyleBoxFlat = control.get_theme_stylebox(state).duplicate()
			var live: StyleBoxFlat = base.duplicate()
			states[state] = {"base":base,"live":live}
			control.add_theme_stylebox_override(state,live)
		pulse_bases[control] = states

func reset_pulses() -> void:
	for control: Button in pulse_bases:
		for state: String in pulse_bases[control]:
			control.add_theme_stylebox_override(state,pulse_bases[control][state].base)
	pulse_bases.clear()
	pulsing.clear()

func pulse_amount() -> float:
	return (1-cos(TAU*elapsed/2.6))*0.5

func animate_pulses() -> void:
	for control: Button in pulse_bases:
		for state: String in pulse_bases[control]:
			var entry: Dictionary = pulse_bases[control][state]
			entry.live.bg_color = entry.base.bg_color.lerp(Color.WHITE,0.65*pulse_amount())

func layout() -> void:
	if text == null or host == null: return
	var current: Rect2 = host.board_view.get_rect()
	if not current.is_equal_approx(adjusted_board_rect): normal_board_rect = current
	var preparation: Rect2 = host.piece_view.get_rect()
	progress_label.position = Vector2(preparation.position.x,maxf(4,preparation.position.y-24))
	progress_label.size = Vector2(preparation.size.x,16)
	progress_label.add_theme_font_size_override("font_size",12)
	var font_size := 2*clampi(roundi(host.size.x*0.028),12,18)
	text.add_theme_font_size_override("font_size",font_size)
	var font := text.get_theme_font("font")
	var text_height := 0.0
	for caption: String in TEXT+["No symmetry remains.\nThe game has ended.",TEXT[11]+"\n3 / 3"]:
		text_height = maxf(text_height,font.get_multiline_string_size(caption,HORIZONTAL_ALIGNMENT_CENTER,preparation.size.x,font_size).y)
	text.position = Vector2(preparation.position.x,progress_label.get_rect().end.y+2)
	text.size = Vector2(preparation.size.x,text_height+8)
	tray_rect = Rect2(preparation.position.x,text.get_rect().end.y+4,preparation.size.x,48)
	var board_top := maxf(normal_board_rect.position.y,tray_rect.end.y+8)
	var side := maxf(60,minf(normal_board_rect.size.x,normal_board_rect.end.y-board_top))
	adjusted_board_rect = Rect2((host.size.x-side)/2,board_top,side,side)
	host.board_view.position = adjusted_board_rect.position
	host.board_view.size = adjusted_board_rect.size
	host.board_view.update_geometry()
	board_rect = Rect2(host.board_view.position+host.board_view.field.position,host.board_view.field.size)
	queue_redraw()

func update_controls() -> void:
	var busy := not animation.is_empty()
	flip.disabled = busy or stage not in [4,6,7,8,11]
	recolor.disabled = busy or stage not in [5,6,7,8,11]
	var place_disabled := busy or not selected or stage not in [2,6,7,8,11]
	if stage == 11: place_disabled = place_disabled or host.board_view.growing
	# Never transiently disable a held button before assigning its final state.
	place.disabled = place_disabled
	forward.disabled = stage == 11
	skip.disabled = false
	hint.disabled = stage not in [6,7,8,9,11]
	for control: Button in [host.erase_button,host.undo_button,host.skip_button]:
		control.show()
		control.disabled = true
	recolor.get_child(0).color = color
	recolor.get_child(0).queue_redraw()
	var prediction := prediction_board()
	var states := Rules.symmetry_states(prediction)
	var icon = host.indicators[0].icon
	icon.available = states.map(func(state): return state.possible)
	icon.complete = states.map(func(state): return state.complete)
	icon.saved = false
	icon.queue_redraw()

func grid_size() -> int: return 9 if stage == 11 else 5

func prediction_board() -> Array:
	if selected:
		var predicted := Model.placed(grid,cells,anchor,color)
		if not predicted.is_empty(): return predicted
	return grid

func ink(index: int) -> Color:
	var result := Palette.tile(index)
	return result.lerp(Color(result.get_luminance(),result.get_luminance(),result.get_luminance()),desaturation)

func transform_piece(operation: String) -> void:
	if not animation.is_empty() or stage not in [3,4,5,6,7,8,11]: return
	if operation == "flip" and flip.disabled: return
	if operation == "color" and recolor.disabled: return
	animation = operation
	animation_time = 0
	animation_color = color
	update_controls()

func complete_transform() -> void:
	var operation := animation
	match operation:
		"rotate": cells = Rules.rotate(cells)
		"flip": cells = Rules.flip(cells)
		"color": color = 3-color
	animation = ""
	if selected: clamp_anchor()
	if (stage == 3 and operation == "rotate") or (stage == 4 and operation == "flip") or (stage == 5 and operation == "color"):
		enter(stage+1)
	else: update_controls()

func show_hint() -> void:
	if stage in [6,7,8] and attempts > 0:
		hint_visible = true
		queue_redraw()

func try_place() -> void:
	if not animation.is_empty() or not selected: return
	if stage == 11:
		place_seed()
		return
	if stage not in [2,6,7,8]: return
	if not Model.accepts(puzzle,cells,anchor,color):
		attempts += 1
		if stage in [6,7,8]: hint_visible = true
		queue_redraw()
		return
	# Placement feedback is immediate; only explicit transform animations wait.
	grid = puzzle.target.duplicate(true)
	enter(stage+1)

func next_step() -> void:
	if stage < 11: enter(stage+1)

func _process(delta: float) -> void:
	elapsed += delta
	if not animation.is_empty():
		animation_time += delta
		if animation_time >= ANIMATION_SECONDS: complete_transform()
	elif stage == 1 and elapsed >= 2: enter(2)
	elif stage == 9:
		update_axis_demo()
		if elapsed >= 10: enter(10)
	animate_pulses()
	update_controls()
	queue_redraw()

func update_axis_demo() -> void:
	var base := Model.axis_demo_board()
	desaturation = 0
	demo_lost = false
	selected = elapsed >= 1 and elapsed < 5 or elapsed >= 6 and elapsed < 7
	if elapsed < 2.5:
		grid = base
		cells = [Vector2i.ZERO,Vector2i.DOWN]
		anchor = Vector2i(2,1)
		color = 1
	elif elapsed < 5:
		grid = base
		cells = [Vector2i.ZERO,Vector2i.RIGHT]
		anchor = Vector2i(1,1)
		color = 1
	else:
		grid = Model.placed(base,[Vector2i.ZERO,Vector2i.RIGHT],Vector2i(1,1),1)
		cells = [Vector2i.ZERO]
		anchor = Vector2i(3,1)
		color = 2
		if elapsed >= 7:
			grid = Model.placed(grid,cells,anchor,color)
			selected = false
			demo_lost = true
			desaturation = clampf(elapsed-7,0,1)
			text.text = "No symmetry remains.\nThe game has ended."

func start_seed() -> void:
	var progress := Model.progress(progress_path)
	var resume: bool = not seed_started and progress.step == 11 and progress.seed_index in [1,2] and Palette.theme_id() == "vines" and host.game.board == Model.seed_board(progress.seed_index)
	seed_index = progress.seed_index if resume else 0
	seed_started = true
	if not resume:
		Palette.select_theme("vines")
		host.requested_size = 9
		host._reset(9,host.game.difficulty)
		# Reset installs the Vines UI; navigation still belongs to this tutorial.
		forward.get_child(0).kind = "skip"
		skip.get_child(0).kind = "close"
	for node: Node in [host.board_view,host.sounds]:
		if not seed_old_modes.has(node): seed_old_modes[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	prepare_seed()

func prepare_seed() -> void:
	var step: Dictionary = Model.seed_steps()[seed_index]
	host.game.queue[host.game.index] = step.name
	host.game.current_color = 1
	host.cells = step.cells.duplicate()
	host.piece_view.cells = host.cells
	host.has_hover = false
	grid = host.game.board.duplicate(true)
	cells = step.cells.duplicate()
	color = 1
	selected = false
	anchor = Vector2i.ZERO
	text.text = TEXT[11]+"\n%d / %d" % [seed_index+1,Model.seed_steps().size()]
	if persist: Model.save_progress(11,false,progress_path,seed_index)
	host._autosave()

func place_seed() -> void:
	if host.board_view.growing: return
	var step: Dictionary = Model.seed_steps()[seed_index]
	var trial := Model.placed(grid,cells,anchor,color)
	if trial.is_empty() or trial != Model.seed_board(seed_index+1): return
	var before: Array = host.game.board.duplicate(true)
	var result: Dictionary = host.game.place(cells,anchor)
	if not result.ok: return
	grid = host.game.board.duplicate(true)
	host.board_view.animate_growth(before,host.game.board)
	seed_index += 1
	if seed_index == Model.seed_steps().size():
		host.cells = host._offered_cells()
		host._autosave()
		finish(false)
	else:
		prepare_seed()
		update_controls()

func finish(_skipped: bool) -> void:
	set_process(false)
	set_process_input(false)
	hide()
	reset_pulses()
	if persist: Model.save_progress(stage,true,progress_path,seed_index)
	for record: Dictionary in saved_controls:
		record.node.process_mode = record.mode
		record.node.disabled = record.disabled
		record.node.visible = record.visible
		record.node.text = record.text
		record.node.tooltip_text = record.tooltip
		record.node.get_child(0).visible = record.icon_visible
		if record.icon_kind != null: record.node.get_child(0).kind = record.icon_kind
		if record.icon_count != null: record.node.get_child(0).count = record.icon_count
	for control: Control in saved_visibility: control.visible = saved_visibility[control]
	for node: Node in seed_old_modes: node.process_mode = seed_old_modes[node]
	get_tree().paused = previous_pause
	finished.emit()
	host._layout()
	host._refresh()
	queue_free()

func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null: tree.paused = previous_pause

func tray_geometry() -> Dictionary:
	var extent := Vector2i.ONE
	for cell: Vector2i in cells: extent = extent.max(cell+Vector2i.ONE)
	var unit := minf(tray_rect.size.x/maxi(4,extent.x),tray_rect.size.y/maxi(1,extent.y))*0.85
	return {"unit":unit,"origin":tray_rect.get_center()-Vector2(extent)*unit/2}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		var point: Vector2 = event.position
		if held or board_rect.has_point(point) or tray_rect.has_point(point): _gui_input(event)

func _gui_input(event: InputEvent) -> void:
	if not animation.is_empty() or stage not in [2,3,4,5,6,7,8,11]: return
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
		local = (point-board_rect.position)/(board_rect.size.x/grid_size())-Vector2(anchor)
	else:
		var geometry := tray_geometry()
		local = (point-geometry.origin)/geometry.unit
	var cell := Vector2i(floori(local.x),floori(local.y))
	return cell if cell in cells else Vector2i(-1,-1)

func clamp_anchor() -> void:
	var extent := Vector2i.ONE
	for cell: Vector2i in cells: extent = extent.max(cell+Vector2i.ONE)
	anchor = Vector2i(clampi(anchor.x,0,grid_size()-extent.x),clampi(anchor.y,0,grid_size()-extent.y))

func select_at(point: Vector2) -> void:
	if tray_rect.has_point(point):
		selected = false
	elif board_rect.has_point(point):
		var relative := (point-board_rect.position)/(board_rect.size.x/grid_size())
		anchor = Vector2i(floori(relative.x),floori(relative.y))-grabbed
		clamp_anchor()
		selected = true
	else: return
	update_controls()
	queue_redraw()

func guide_cells() -> Array:
	if stage == 2 or (stage in [6,7,8] and hint_visible): return puzzle.missing.duplicate()
	if stage == 11:
		var step: Dictionary = Model.seed_steps()[seed_index]
		return step.cells.map(func(cell: Vector2i): return cell+step.anchor)
	return []

func hatched_guide(rect: Rect2) -> void:
	var bounds := rect.grow(-4)
	draw_rect(bounds,Color("477D76",0.3),false,1)
	var diagonal := 0.0
	while diagonal <= bounds.size.x+bounds.size.y:
		var a := Vector2(maxf(0,diagonal-bounds.size.y),minf(bounds.size.y,diagonal))
		var b := Vector2(minf(bounds.size.x,diagonal),maxf(0,diagonal-bounds.size.x))
		draw_line(bounds.position+a,bounds.position+b,Color("477D76",0.2),1,true)
		diagonal += 9

func tile(rect: Rect2, color_value: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color_value
	style.set_corner_radius_all(4)
	draw_style_box(style,rect.grow(-1.5))

func piece_ink() -> Color:
	var result := Palette.tile(color)
	if animation == "color": result = Palette.tile(animation_color).lerp(Palette.tile(3-animation_color),clampf(animation_time/ANIMATION_SECONDS,0,1))
	if stage == 3 and animation.is_empty(): result = result.lerp(Color.WHITE,0.45*pulse_amount())
	return result

func draw_axis(index: int, state: Dictionary) -> void:
	if not state.possible: return
	var center := board_rect.get_center()
	var radius := board_rect.size.x/2
	var ink_value := Color("477D76",0.95 if state.complete else 0.28)
	var width := 3.0 if state.complete else 1.2
	if index < 4:
		var direction: Vector2 = [Vector2.DOWN,Vector2.RIGHT,Vector2(1,-1),Vector2(1,1)][index]
		draw_dashed_line(center-direction*radius,center+direction*radius,ink_value,width,7)
	elif index == 5:
		draw_circle(center,4,ink_value)
		draw_arc(center,board_rect.size.x*0.08,-PI/2,PI*1.25,36,ink_value,width,true)
		var tip := center+Vector2(0,-board_rect.size.x*0.08)
		draw_line(tip,tip+Vector2(-7,4),ink_value,width,true)

func _draw() -> void:
	if grid.is_empty(): return
	var n := grid_size()
	var unit := board_rect.size.x/n
	if stage != 11:
		draw_rect(board_rect,Color("FFF9F3"))
		for y in range(n):
			for x in range(n):
				var rect := Rect2(board_rect.position+Vector2(x,y)*unit,Vector2.ONE*unit)
				tile(rect,Color("F1E7EB").lerp(Color("D9D9D9"),desaturation))
				if grid[y][x] > 0: tile(rect,ink(grid[y][x]))
	if stage in [6,7,8]:
		var index: int = puzzle.symmetry
		draw_axis(index,Rules.symmetry_states(prediction_board())[index])
	elif stage == 9:
		var states := Rules.symmetry_states(prediction_board())
		for index in [0,1,2,3,5]: draw_axis(index,states[index])
	for cell: Vector2i in guide_cells():
		hatched_guide(Rect2(board_rect.position+Vector2(cell)*unit,Vector2.ONE*unit))
	if cells.is_empty() or stage not in [2,3,4,5,6,7,8,9,11]: return
	if stage == 9 and not selected: return
	var extent := Vector2i.ONE
	for cell: Vector2i in cells: extent = extent.max(cell+Vector2i.ONE)
	var geometry := tray_geometry()
	var piece_unit: float = unit if selected else geometry.unit
	var origin: Vector2 = board_rect.position+Vector2(anchor)*unit if selected else geometry.origin
	var center := origin+Vector2(extent)*piece_unit/2
	var angle := 0.0
	var flip_scale := 1.0
	if animation == "rotate": angle = PI/2*smoothstep(0,ANIMATION_SECONDS,animation_time)
	elif animation == "flip": flip_scale = cos(PI*clampf(animation_time/ANIMATION_SECONDS,0,1))
	elif stage == 9 and elapsed >= 2.5 and elapsed < 2.5+ANIMATION_SECONDS:
		angle = PI/2*(1-smoothstep(2.5,2.5+ANIMATION_SECONDS,elapsed))
	draw_set_transform(center,angle,Vector2(flip_scale,1))
	for cell: Vector2i in cells:
		tile(Rect2(Vector2(cell)*piece_unit-Vector2(extent)*piece_unit/2,Vector2.ONE*piece_unit),piece_ink())
	draw_set_transform(Vector2.ZERO)
