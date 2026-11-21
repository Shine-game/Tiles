extends Control
signal finished
const Model = preload("res://scripts/tutorial_model.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Ink = preload("res://scripts/interface_palette.gd")
const Axes = preload("res://scripts/field_axes.gd")
const UI = preload("res://scripts/interface_theme.gd")
const TUTORIAL_FONT = preload("res://assets/fonts/lora/Lora-Regular.ttf")
const FONT_SIZE := 12
const TEXT := ["", "", "Tap the piece to rotate it.", "Press Flip to mirror it.", "Press Color to choose its color.", "Drag the piece into position and press Place.", "Complete the vertical symmetry.", "Complete the horizontal symmetry.", "Complete the rotational symmetry.", "", "", "From simple tiles to intricate worlds."]
const REPAIR_TEXT := [
	"",
	"",
	"The hint button shows achievable symmetries.\nMake an asymmetric placement and the game ends.",
	"Undo your last move.",
	"Erase a square.\nPress Erase, then tap the marked square.",
	"Get a different piece.\nPress the arrow joker.",
	"Restore vertical symmetry.\nPlace the new piece.",
	"Bold axis! Your board is symmetrical right now. Save a picture and continue playing."]
const ANIMATION_SECONDS := 0.32
const PULSE_SECONDS := 1.4
var progress_path := Model.PATH
var persist := true
var leaving := false
var stage := 1
var elapsed := 0.0
var host: Control
var previous_pause := false
var normal_board_rect := Rect2()
var adjusted_board_rect := Rect2()
var board_rect := Rect2()
var tray_rect := Rect2()
var offer_over_board := false
var offer_pending := false
var text: RichTextLabel
var caption_rect := Rect2()
var progress_label: Label
var repair_header: RichTextLabel
var piece_overlay: Control
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
var repair_phase := 0
var repair_erasing := false
var seed_started := false
var seed_index := 0
var replay_finishing := false
var seed_old_modes := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_pause = get_tree().paused
	get_tree().paused = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	theme = UI.build()
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = false
	text.fit_content = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color",Ink.text())
	text.add_theme_color_override("default_color",Ink.text())
	text.add_theme_font_override("normal_font",TUTORIAL_FONT)
	text.add_theme_constant_override("line_separation",0)
	text.add_theme_constant_override("paragraph_separation",0)
	add_child(text)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.add_theme_color_override("font_color",Ink.text())
	progress_label.add_theme_font_override("font",TUTORIAL_FONT)
	add_child(progress_label)
	repair_header = RichTextLabel.new()
	repair_header.bbcode_enabled = true
	repair_header.fit_content = false
	repair_header.scroll_active = false
	repair_header.text = "[center]Save the pattern[/center]"
	repair_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	repair_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	repair_header.add_theme_font_override("normal_font",TUTORIAL_FONT)
	repair_header.add_theme_constant_override("line_separation",0)
	repair_header.add_theme_constant_override("paragraph_separation",0)
	add_child(repair_header)
	piece_overlay = Control.new()
	piece_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece_overlay.z_index = 1
	piece_overlay.draw.connect(_draw_piece)
	add_child(piece_overlay)
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
	var keep_piece := stage in [2,3,4] and step == stage+1
	# Keep saved stage IDs compatible; the removed card forwards to the repair lesson.
	stage = 2 if step == 1 else (10 if step == 9 else step)
	elapsed = 0
	animation = ""
	animation_time = 0
	held = false
	drag = false
	hint_visible = false
	attempts = 0
	if not keep_piece: selected = false
	set_caption(TEXT[stage])
	progress_label.text = "%d / 9" % (stage-2 if stage >= 10 else stage-1)
	if stage in [2,3,4,5]:
		if not keep_piece:
			puzzle = Model.recipe(5)
			grid = puzzle.board.duplicate(true)
			cells = puzzle.offered.duplicate()
			color = 1
			# Direct navigation/resume reconstructs the operations already taught.
			if stage >= 3: cells = Rules.rotate(cells)
			if stage >= 4: cells = Rules.flip(cells)
			if stage >= 5: color = 2
	elif stage in [6,7,8]:
		puzzle = Model.recipe(stage)
		grid = puzzle.board.duplicate(true)
		cells = puzzle.offered.duplicate()
		color = 1
	elif stage == 10:
		repair_phase = 2
		prepare_repair()
	elif stage == 11: start_seed()
	if not keep_piece and stage in [6,7,8]: cells = laid_cells(cells)
	if persist: Model.save_progress(stage,false,progress_path,seed_index)
	choose_pulses()
	layout()
	update_controls()
	queue_redraw()

func desired_pulses() -> Array:
	if leaving or not animation.is_empty(): return []
	match stage:
		3: return [flip]
		4: return [recolor]
		5,6,7,8:
			return [place] if exercise_placement_correct() else []
		10:
			match repair_phase:
				2: return [hint,place] if repair_matches_target() else []
				1,6: return [place] if repair_matches_target() else []
				3: return [host.undo_button]
				4: return [host.erase_button]
				5: return [host.skip_button]
	return []

func exercise_placement_correct() -> bool:
	return selected and stage in [5,6,7,8] and Model.accepts(puzzle,cells,anchor,color)

func choose_pulses() -> void:
	pulsing = desired_pulses()
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
	return (1-cos(TAU*elapsed/PULSE_SECONDS))*0.5

func animate_pulses() -> void:
	for control: Button in pulse_bases:
		for state: String in pulse_bases[control]:
			var entry: Dictionary = pulse_bases[control][state]
			entry.live.bg_color = entry.base.bg_color.lerp(Color.WHITE,pulse_amount())

func set_caption(value: String) -> void:
	var plain := value.replace("[b]","").replace("[/b]","").replace("**","").replace("\r\n","\n").replace("\r","\n")
	while "\n\n" in plain: plain = plain.replace("\n\n","\n")
	text.text = "[center]"+plain+"[/center]"

func measure_caption(value: String, font: Font, font_size: int, width: float) -> float:
	var plain := value.replace("[b]","").replace("[/b]","").replace("**","").replace("[center]","").replace("[/center]","")
	while "\n\n" in plain: plain = plain.replace("\n\n","\n")
	return ceilf(font.get_multiline_string_size(plain,HORIZONTAL_ALIGNMENT_CENTER,width,font_size).y)+2

func layout() -> void:
	if text == null or host == null: return
	var current: Rect2 = host.board_view.get_rect()
	if not current.is_equal_approx(adjusted_board_rect): normal_board_rect = current
	# The central header belongs entirely to the caption; side controls never move.
	var preparation: Rect2 = host.piece_view.get_rect()
	progress_label.position = preparation.position+Vector2(0,-18)
	progress_label.z_index = 2
	progress_label.size = Vector2(preparation.size.x,16)
	progress_label.add_theme_font_size_override("font_size",12)
	progress_label.add_theme_color_override("font_color",Ink.text())
	var n := grid_size()
	var rim := maxf(0,host.board_view.size.x-host.board_view.field.size.x)
	var font := text.get_theme_font("normal_font")
	var font_size := FONT_SIZE
	var reserved := preparation.grow(-4)
	var caption_height := reserved.size.y
	for key in ["font_size","normal_font_size"]: text.add_theme_font_size_override(key,font_size)
	text.add_theme_color_override("font_color",Ink.text())
	text.add_theme_color_override("default_color",Ink.text())
	caption_rect = reserved
	var body_rect := caption_rect
	repair_header.visible = stage == 10 and repair_phase in [3,4,5,6]
	repair_header.add_theme_font_size_override("normal_font_size",font_size)
	repair_header.add_theme_color_override("default_color",Ink.text())
	if repair_header.visible:
		var header_height := measure_caption("Save the pattern",font,font_size,reserved.size.x)
		var body_height := 0.0
		for caption: String in REPAIR_TEXT.slice(3,7): body_height = maxf(body_height,measure_caption(caption,font,font_size,reserved.size.x))
		var group_top := caption_rect.position.y+maxf(0,(caption_height-header_height-body_height)/2)
		repair_header.position = Vector2(caption_rect.position.x,group_top)
		repair_header.size = Vector2(reserved.size.x,header_height)
		body_rect = Rect2(caption_rect.position.x,group_top+header_height,reserved.size.x,body_height)
	var current_height := measure_caption(text.text,font,font_size,reserved.size.x)
	text.position = body_rect.position+Vector2(0,maxf(0,(body_rect.size.y-current_height)/2))
	text.size = Vector2(reserved.size.x,current_height)
	# Split the remaining height into two offer rows and a square board.
	# Include the board frame in the calculation and anchor its bottom to the game.
	var gap := 12.0
	var content_top := maxf(normal_board_rect.position.y,caption_rect.end.y+gap)
	var available_height := normal_board_rect.end.y-content_top
	var side := maxf(60,minf(normal_board_rect.size.x,(available_height+2*rim/n-gap)/(1+2.0/n)))
	adjusted_board_rect = normal_board_rect if n == 9 else Rect2((host.size.x-side)/2,normal_board_rect.end.y-side,side,side)
	host.board_view.position = adjusted_board_rect.position
	host.board_view.size = adjusted_board_rect.size
	host.board_view.update_geometry()
	board_rect = Rect2(host.board_view.position+host.board_view.field.position,host.board_view.field.size)
	var offer_height := 2*board_rect.size.x/n
	tray_rect = Rect2(normal_board_rect.position.x,adjusted_board_rect.position.y-gap-offer_height,normal_board_rect.size.x,offer_height)
	offer_over_board = n == 9 and tray_rect.position.y < caption_rect.end.y+gap
	if offer_over_board:
		tray_rect = Rect2(board_rect.position,Vector2(board_rect.size.x,offer_height))
	if stage == 10:
		# This preview deliberately overlaps the caption at the normal tile size.
		tray_rect = preparation
		offer_over_board = false
		if repair_phase == 2:
			var unit := board_rect.size.x/9
			tray_rect = Rect2(preparation.position.x,normal_board_rect.position.y-unit-4,preparation.size.x,unit)
	if offer_pending:
		offer_pending = false
		if offer_over_board and not cells.is_empty(): spawn_offer_on_board()
	queue_redraw()

func spawn_offer_on_board() -> void:
	# Present the movable piece in empty squares; include it in the axis preview.
	for y in range(grid.size()):
		for x in range(grid.size()):
			var candidate := Vector2i(x,y)
			if Model.placed(grid,cells,candidate,color).is_empty(): continue
			anchor = candidate
			selected = true
			return

func update_controls() -> void:
	if leaving: return
	var busy := not animation.is_empty()
	flip.disabled = busy or (stage not in [3,6,7,8] and not (stage == 10 and not cells.is_empty()))
	recolor.disabled = busy or (stage not in [4,6,7,8] and not (stage == 10 and not cells.is_empty()))
	var place_disabled := busy or not selected or stage not in [5,6,7,8,10]
	if stage == 10: place_disabled = place_disabled or not repair_matches_target()
	if stage == 11: place_disabled = place_disabled or host.board_view.growing
	# Never transiently disable a held button before assigning its final state.
	place.disabled = place_disabled
	forward.disabled = true
	skip.disabled = false
	hint.disabled = stage not in [10,11]
	var jokers := [host.undo_button,host.erase_button,host.skip_button]
	for i in range(jokers.size()):
		var control: Button = jokers[i]
		control.show()
		control.disabled = stage != 10 or repair_phase != i+3
	if stage == 10:
		for button: Button in [host.undo_button,host.erase_button,host.skip_button]:
			button.get_child(0).count = 3
		if repair_phase >= 4: host.undo_button.get_child(0).count = 2
		if repair_phase >= 5: host.erase_button.get_child(0).count = 2
		if repair_phase >= 6: host.skip_button.get_child(0).count = 2
	for control: Button in jokers: control.get_child(0).queue_redraw()
	recolor.get_child(0).color = color
	recolor.get_child(0).queue_redraw()
	var prediction := prediction_board()
	var states := Rules.symmetry_states(prediction)
	if stage == 11: host.board_view.set_axis_states(states)
	var icon = host.indicators[0].icon
	icon.available = states.map(func(state): return true if stage < 10 else state.possible)
	icon.complete = states.map(func(state): return false if stage < 10 else state.complete)
	icon.saved = false
	icon.queue_redraw()
	if pulsing != desired_pulses():
		reset_pulses()
		choose_pulses()

func grid_size() -> int: return 9 if stage in [10,11] else 5

func prediction_board() -> Array:
	if stage == 11 and not host.board_view.tutorial_underlay.is_empty(): return host.board_view.tutorial_underlay
	if not selected: return grid
	# Match what is actually drawn, even while the floating piece covers an
	# occupied square. A colliding hover must not show the old board's axes.
	var predicted: Array = grid.duplicate(true)
	for offset: Vector2i in cells:
		var cell := anchor+offset
		if cell.x >= 0 and cell.y >= 0 and cell.x < grid.size() and cell.y < grid.size():
			predicted[cell.y][cell.x] = color
	return predicted

func ink(index: int) -> Color:
	return Palette.tile(index)

func transform_piece(operation: String) -> void:
	if not animation.is_empty() or stage not in [2,3,4,6,7,8,10]: return
	if cells.is_empty(): return
	if operation == "rotate" and stage not in [2,6,7,8,10]: return
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
	if (stage == 2 and operation == "rotate") or (stage == 3 and operation == "flip") or (stage == 4 and operation == "color"):
		enter(stage+1)
	else: update_controls()

func show_hint() -> void:
	if stage in [6,7,8] and attempts > 0:
		hint_visible = true
		queue_redraw()

func try_place() -> void:
	if not animation.is_empty() or not selected: return
	if stage == 10:
		place_repair()
		return
	if stage not in [5,6,7,8]: return
	if not Model.accepts(puzzle,cells,anchor,color):
		attempts += 1
		if stage in [6,7,8]: hint_visible = true
		queue_redraw()
		return
	# Placement feedback is immediate; only explicit transform animations wait.
	grid = puzzle.target.duplicate(true)
	enter(stage+1)

func next_step() -> void:
	if stage == 1: enter(2)

func _process(delta: float) -> void:
	if leaving: return
	elapsed += delta
	if not animation.is_empty():
		animation_time += delta
		if animation_time >= ANIMATION_SECONDS: complete_transform()
	elif stage == 10:
		if repair_phase == 7 and elapsed >= 5: enter(11)
	elif stage == 11:
		update_replay(delta)
	if leaving: return
	animate_pulses()
	update_controls()
	queue_redraw()

func prepare_repair() -> void:
	grid = Model.repair_board(repair_phase)
	offer_pending = true
	selected = false
	held = false
	drag = false
	repair_erasing = false
	color = 1
	elapsed = 0
	set_caption(REPAIR_TEXT[repair_phase])
	var index: int = {1:0,2:1,6:2}.get(repair_phase,-1)
	cells = laid_cells(Model.repair_offers()[index].cells) if index >= 0 else []
	color = Model.repair_offers()[index].color if index >= 0 else 2
	# The player sees the unsuitable next piece before using the replacement joker.
	if repair_phase == 5: cells = [Vector2i.ZERO,Vector2i.RIGHT,Vector2i(2,0)]

func advance_repair() -> void:
	reset_pulses()
	repair_phase += 1
	prepare_repair()
	layout()
	choose_pulses()
	update_controls()
	queue_redraw()

func repair_matches_target() -> bool:
	if not selected: return false
	var index: int = {1:0,2:1,6:2}.get(repair_phase,-1)
	if index < 0: return false
	var offer: Dictionary = Model.repair_offers()[index]
	if color != offer.color: return false
	var trial := Model.placed(grid,cells,anchor,color)
	return not trial.is_empty() and trial == Model.placed(grid,offer.cells,offer.anchor,offer.color)

func place_repair() -> void:
	if repair_matches_target(): advance_repair()

func joker_action(action: String) -> void:
	if stage != 10: return
	if action == "undo" and repair_phase == 3: advance_repair()
	elif action == "erase" and repair_phase == 4:
		repair_erasing = not repair_erasing
		set_caption(REPAIR_TEXT[4])
	elif action == "skip" and repair_phase == 5: advance_repair()

func start_seed() -> void:
	var progress := Model.progress(progress_path)
	var resume: bool = not seed_started and progress.step == 11 and progress.seed_index > 0 and progress.seed_index <= Model.replay_steps().size() and Palette.theme_id() == "vines" and host.game.board == Model.replay_board(progress.seed_index)
	seed_index = progress.seed_index if resume else 0
	seed_started = true
	if not resume:
		Palette.select_theme("vines")
		host.requested_size = 9
		host._reset(9,host.game.difficulty)
		# Reset installs the Vines UI; navigation still belongs to this tutorial.
		forward.get_child(0).kind = "skip"
		skip.get_child(0).kind = "close"
	host.board_view.tutorial_underlay = Model.repair_board(7)
	for node: Node in [host.board_view,host.sounds]:
		if not seed_old_modes.has(node): seed_old_modes[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	replay_finishing = seed_index == Model.replay_steps().size()
	grid = host.game.board.duplicate(true)
	cells = []
	selected = false
	set_caption(TEXT[11])
	if not replay_finishing: prepare_seed()

func prepare_seed() -> void:
	var step: Dictionary = Model.replay_steps()[seed_index]
	host.game.queue[host.game.index] = step.name
	host.game.current_color = step.get("color",1)
	host.cells = step.cells.duplicate()
	host.piece_view.cells = host.cells
	host.has_hover = false
	grid = host.game.board.duplicate(true)
	cells = []
	color = 1
	selected = false
	anchor = step.anchor
	set_caption(TEXT[11])
	if persist: Model.save_progress(11,false,progress_path,seed_index)
	host._autosave()

func replay_busy() -> bool:
	if host.board_view.growing: return true
	# Let delayed tier-two shimmer/reveal and its sound finish before continuing.
	var formations = host.board_view.vines_formations
	if formations != null:
		for event: Dictionary in formations.events.values():
			if not event.old and host.board_view.clock < event.start+event.duration: return true
	return false

func update_replay(_delta: float) -> void:
	if replay_busy(): return
	if replay_finishing:
		host.cells = host._offered_cells()
		host._autosave()
		finish(false)
		return
	var step: Dictionary = Model.replay_steps()[seed_index]
	var before: Array = host.game.board.duplicate(true)
	var result: Dictionary = host.game.place(step.cells,step.anchor)
	assert(result.ok,"Tutorial replay placement must remain legal")
	if not result.ok: return
	grid = host.game.board.duplicate(true)
	host.board_view.animate_growth(before,host.game.board)
	seed_index += 1
	if persist: Model.save_progress(11,false,progress_path,seed_index)
	host._autosave()
	if seed_index == Model.replay_steps().size(): replay_finishing = true
	else: prepare_seed()

func finish(_skipped: bool) -> void:
	if leaving: return
	leaving = true
	set_process(false)
	set_process_input(false)
	hide()
	reset_pulses()
	if seed_started: host.board_view.tutorial_underlay = []
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

func laid_cells(shape: Array) -> Array:
	var extent := Vector2i.ONE
	for cell: Vector2i in shape: extent = extent.max(cell+Vector2i.ONE)
	return Rules.rotate(shape) if extent.y > extent.x else shape.duplicate()

func tray_geometry() -> Dictionary:
	var extent := Vector2i.ONE
	for cell: Vector2i in cells: extent = extent.max(cell+Vector2i.ONE)
	var unit := board_rect.size.x/grid_size()
	var drawn_size := Vector2(extent)*unit
	var origin := tray_rect.position+(tray_rect.size-drawn_size)/2
	# Match the main game: full-size rotations extend down over the board.
	origin.y = maxf(tray_rect.position.y,origin.y)
	return {"unit":unit,"origin":origin}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		var point: Vector2 = event.position
		if held or board_rect.has_point(point) or tray_rect.has_point(point) or (not selected and piece_cell_at(point).x >= 0): _gui_input(event)

func _gui_input(event: InputEvent) -> void:
	if not animation.is_empty() or stage not in [2,3,4,5,6,7,8,10]: return
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
	if stage == 10 and repair_phase == 4:
		if pressed and not motion and repair_erasing and board_rect.has_point(point):
			var target := Vector2i((point-board_rect.position)/(board_rect.size.x/grid_size()))
			if target == Vector2i(1,1): advance_repair()
		accept_event()
		return
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
	if tray_rect.has_point(point) and not offer_over_board:
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
	if stage in [2,3,4,5] or (stage in [6,7,8] and hint_visible): return puzzle.missing.duplicate()
	if stage == 10:
		if repair_phase == 4: return [Vector2i(1,1)]
		var index: int = {1:0,2:1,6:2}.get(repair_phase,-1)
		if index >= 0:
			var offer: Dictionary = Model.repair_offers()[index]
			return offer.cells.map(func(cell: Vector2i): return cell+offer.anchor)
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
	if stage == 2 and animation.is_empty(): result = result.lerp(Color.WHITE,0.45*pulse_amount())
	return result

func exercise_axis_state() -> Dictionary:
	# Early axes teach the requested geometry; prediction begins in the later lesson.
	return {"possible":true,"complete":false}

func draw_exercise_axes(canvas: CanvasItem = null) -> void:
	if stage not in [2,3,4,5,6,7,8,10]: return
	var states := Rules.symmetry_states(prediction_board())
	var indices: Array = [puzzle.symmetry] if stage < 10 else [0,1,2,3,4,5,6]
	if stage < 10: states[puzzle.symmetry] = exercise_axis_state()
	Axes.paint(self if canvas == null else canvas,board_rect,states,indices)

func _draw() -> void:
	if grid.is_empty(): return
	var n := grid_size()
	var unit := board_rect.size.x/n
	if stage != 11:
		draw_rect(board_rect,Color("FFF9F3"))
		for y in range(n):
			for x in range(n):
				var rect := Rect2(board_rect.position+Vector2(x,y)*unit,Vector2.ONE*unit)
				tile(rect,Color("F1E7EB"))
				if grid[y][x] > 0: tile(rect,ink(grid[y][x]))
	for cell: Vector2i in guide_cells():
		var marker := Rect2(board_rect.position+Vector2(cell)*unit,Vector2.ONE*unit)
		hatched_guide(marker)
		if stage == 10 and repair_phase == 4:
			draw_rect(marker.grow(-5),Color.WHITE.lerp(Color("477D76"),pulse_amount()),false,4)
			draw_line(marker.position+Vector2(12,12),marker.end-Vector2(12,12),Color.WHITE,3,true)
			draw_line(Vector2(marker.end.x-12,marker.position.y+12),Vector2(marker.position.x+12,marker.end.y-12),Color.WHITE,3,true)
	if not selected or cells.is_empty(): draw_exercise_axes()
	piece_overlay.queue_redraw()

func _draw_piece() -> void:
	if cells.is_empty() or stage not in [2,3,4,5,6,7,8,10]: return
	var unit := board_rect.size.x/grid_size()
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
	if not selected:
		var half_height := piece_unit*(absf(sin(angle))*extent.x+absf(cos(angle))*extent.y)/2
		center.y = maxf(center.y,tray_rect.position.y+half_height)
	piece_overlay.draw_set_transform(center,angle,Vector2(flip_scale,1))
	for cell: Vector2i in cells:
		var style := StyleBoxFlat.new()
		style.bg_color = piece_ink()
		style.set_corner_radius_all(4)
		piece_overlay.draw_style_box(style,Rect2(Vector2(cell)*piece_unit-Vector2(extent)*piece_unit/2,Vector2.ONE*piece_unit).grow(-1.5))
	piece_overlay.draw_set_transform(Vector2.ZERO)
	if selected: draw_exercise_axes(piece_overlay)
