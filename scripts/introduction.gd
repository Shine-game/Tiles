extends Control
signal finished
const Geometry = preload("res://scripts/piece_geometry.gd")
const Gesture = preload("res://scripts/piece_gesture.gd")
const Preview = preload("res://scripts/placement_preview.gd")
const Surface = preload("res://scripts/tile_surface.gd")
var piece_gesture = Gesture.new()
const UIScope = preload("res://scripts/tutorial_ui_scope.gd")
const Model = preload("res://scripts/tutorial_model.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Ink = preload("res://scripts/interface_palette.gd")
const Axes = preload("res://scripts/field_axes.gd")
const UI = preload("res://scripts/interface_theme.gd")
const TUTORIAL_FONT = preload("res://assets/fonts/lora/Lora-Regular.ttf")
const FONT_SIZE := 20
const Lessons = preload("res://scripts/tutorial_lessons.gd")
const ANIMATION_SECONDS := 0.32
const PULSE_SECONDS := 1.4
const SAVE_FAILED_TEXT := "Couldn't save the picture. Press Save to retry."
var progress_path := Model.PATH
var persist := true
var leaving := false
var stage := 1
var initial_checkpoint := ""
var elapsed := 0.0
var host: Control
var ui_scope
var cleaned := false
var guidance_dirty := true
var cached_axis_states: Array = []
var guidance_updates := 0
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
var pulse_bases := {}
var pulsing: Array = []
var grid: Array = []
var practice_game
var puzzle := {}
var cells: Array = []
var color := 1
var anchor := Vector2i.ZERO
var selected := false
var held: bool:
	get: return piece_gesture.active
	set(value):
		if not value: piece_gesture.cancel()
var drag: bool:
	get: return piece_gesture.active and piece_gesture.mode == "move"
	set(value):
		if not value: piece_gesture.cancel()
var grabbed: Vector2i:
	get: return piece_gesture.grabbed
	set(value): piece_gesture.grabbed = value
var hint_visible := false
var attempts := 0
var animation := ""
var animation_time := 0.0
var animation_color := 1
var repair_phase := 0
var repair_erasing := false
var seed_started := false
var seed_index := 0
var reveal_save_state := "idle"
var reveal_fingerprint := ""
var reveal_session_id := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	repair_header.text = ""
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
	ui_scope = UIScope.new(host)
	host.player_actions.completed.connect(_on_action_completed)
	host.interface_changed.connect(invalidate_guidance)
	host.design_save_finished.connect(_on_design_save_finished)
	host.button_icon(forward).kind = "skip"
	host.button_icon(forward).count = -1
	forward.tooltip_text = "Forward"
	host.button_icon(skip).kind = "close"
	skip.tooltip_text = "End tutorial"
	host.resized.connect(layout)
	resized.connect(layout)
	enter(stage)

func enter(step: Variant) -> void:
	reset_pulses()
	var keep_piece := stage in [2,3,4] and Lessons.legacy(step) == stage+1
	# Numeric stage is a temporary adapter for the current rendering controller.
	stage = Lessons.legacy(step)
	elapsed = 0
	animation = ""
	animation_time = 0
	held = false
	drag = false
	hint_visible = false
	attempts = 0
	if not keep_piece: selected = false
	set_caption(Lessons.definition(stage).caption)
	if stage in [2,3,4,5]:
		if not keep_piece:
			puzzle = Model.recipe(5)
			practice_game = Model.practice_session(stage)
			grid = practice_game.board.duplicate(true)
			cells = puzzle.offered.duplicate()
			color = 1
			# Direct navigation/resume reconstructs the operations already taught.
			if stage >= 3: cells = Rules.rotate(cells)
			if stage >= 4: cells = Rules.flip(cells)
			if stage >= 5: color = 2
	elif stage in [6,7,8]:
		puzzle = Model.recipe(stage)
		practice_game = Model.practice_session(stage)
		grid = practice_game.board.duplicate(true)
		cells = puzzle.offered.duplicate()
		color = 1
	elif stage == 10:
		repair_phase = Lessons.phase(initial_checkpoint)
		initial_checkpoint = ""
		prepare_repair()
	elif stage == 11: start_seed()
	if not keep_piece and stage in [6,7,8]: cells = laid_cells(cells)
	if practice_game != null and stage != 11: practice_game.current_color = color
	save_checkpoint()
	layout()
	update_controls()
	queue_redraw()

func save_checkpoint(done: bool = false) -> void:
	if not persist: return
	var checkpoint := Lessons.checkpoint_for_phase(repair_phase) if stage == 10 else ""
	var error := Model.save_checkpoint(Lessons.id(stage),done,progress_path,checkpoint,seed_index)
	if error != OK: push_warning("Could not save tutorial progress: "+error_string(error))

func allowed(action: String) -> bool:
	return action in Lessons.definition(stage,repair_phase).actions

func desired_pulses() -> Array:
	if leaving: return []
	if stage == 11:
		if reveal_save_state == "failed": return [hint]
		if reveal_save_state != "saved" or host.saving: return []
		if not host.palette_menu.visible: return [forward]
		return [host.settings_options[0]] if host.menu_page == "Settings" else []
	if stage == 10:
		var targets: Array = [hint] if repair_phase == 7 else []
		if not animation.is_empty(): return targets
		match repair_phase:
			1,2,6:
				if repair_matches_target(): targets.append(place)
			3: targets.append(host.undo_button)
			4: targets.append(host.erase_button)
			5: targets.append(host.skip_button)
		return targets
	if not animation.is_empty(): return []
	match stage:
		3: return [flip]
		4: return [recolor]
		5,6,7,8: return [place] if exercise_placement_correct() else []
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
	animate_pulses()

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
	if leaving or text == null or host == null: return
	invalidate_guidance()
	var current: Rect2 = host.board_view.get_rect()
	if not current.is_equal_approx(adjusted_board_rect): normal_board_rect = current
	progress_label.text = "%d / %d" % [Lessons.definition(stage,repair_phase).number,Lessons.CARD_COUNT]
	# The central header belongs entirely to the caption; side controls never move.
	var preparation: Rect2 = host.piece_view.get_rect()
	progress_label.position = preparation.position+Vector2(0,-18)
	progress_label.z_index = 2
	progress_label.size = Vector2(preparation.size.x,16)
	progress_label.add_theme_font_size_override("font_size",FONT_SIZE)
	progress_label.add_theme_color_override("font_color",Ink.text())
	var n := grid_size()
	var rim := maxf(0,host.board_view.size.x-host.board_view.field.size.x)
	var font_size := FONT_SIZE
	var reserved := preparation.grow(-2)
	for key in ["font_size","normal_font_size"]: text.add_theme_font_size_override(key,font_size)
	text.add_theme_color_override("font_color",Ink.text())
	text.add_theme_color_override("default_color",Ink.text())
	# Keep every cue at the requested size, with one shared area tall enough
	# for the longest instruction on this screen. The board keeps its geometry.
	for cue: String in Lessons.captions():
		reserved.size.y = maxf(reserved.size.y,measure_caption(cue,TUTORIAL_FONT,font_size,reserved.size.x))
	var caption_height := reserved.size.y
	caption_rect = reserved
	var body_rect := caption_rect
	var heading: String = Lessons.definition(stage,repair_phase).get("header","")
	repair_header.text = "[center]"+heading+"[/center]"
	repair_header.visible = not heading.is_empty()
	repair_header.add_theme_font_size_override("normal_font_size",font_size)
	repair_header.add_theme_color_override("default_color",Ink.text())
	if repair_header.visible:
		repair_header.size.x = reserved.size.x
		text.size.x = reserved.size.x
		var header_height := float(repair_header.get_content_height())+2
		var body_height := float(text.get_content_height())+2
		var group_top := caption_rect.position.y+maxf(0,(caption_height-header_height-body_height)/2)
		repair_header.position = Vector2(caption_rect.position.x,group_top)
		repair_header.size = Vector2(reserved.size.x,header_height)
		body_rect = Rect2(caption_rect.position.x,group_top+header_height,reserved.size.x,body_height)
	text.size.x = reserved.size.x
	var current_height := float(text.get_content_height())+2
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
		if repair_phase in [2,5,6]:
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

func invalidate_guidance(restyled: bool = false) -> void:
	if leaving: return
	if restyled:
		# The root supplied fresh theme styles, so old pulse overrides no longer own them.
		pulse_bases.clear()
		pulsing.clear()
	guidance_dirty = true

func update_controls() -> void:
	if leaving: return
	guidance_dirty = false
	guidance_updates += 1
	var busy := not animation.is_empty()
	flip.disabled = busy or not allowed("flip") or cells.is_empty()
	recolor.disabled = busy or not allowed("color") or cells.is_empty()
	var place_disabled := busy or not selected or not allowed("place")
	if stage == 10: place_disabled = place_disabled or not repair_matches_target()
	if stage == 11: place_disabled = place_disabled or host.board_view.growing
	# Never transiently disable a held button before assigning its final state.
	place.disabled = place_disabled
	forward.disabled = stage != 11 or reveal_save_state != "saved" or host.saving
	skip.disabled = false
	hint.disabled = stage not in [10,11] or (stage == 11 and reveal_save_state != "failed")
	var jokers := [host.undo_button,host.erase_button,host.skip_button]
	for i in range(jokers.size()):
		var control: Button = jokers[i]
		control.show()
		control.disabled = stage != 10 or repair_phase != i+3
	if practice_game != null and stage != 11:
		host.button_icon(host.undo_button).count = practice_game.undo_left
		host.button_icon(host.erase_button).count = practice_game.erase_left
		host.button_icon(host.skip_button).count = practice_game.skip_left
	for control: Button in jokers: host.button_icon(control).queue_redraw()
	host.button_icon(recolor).color = color
	host.button_icon(recolor).queue_redraw()
	var prediction := prediction_board()
	var states := Rules.symmetry_states(prediction)
	cached_axis_states = states.duplicate(true)
	if stage < 10 and puzzle.has("symmetry"): cached_axis_states[puzzle.symmetry] = exercise_axis_state()
	if stage == 11: host.board_view.set_axis_states(states)
	var icon = host.indicators[0].icon
	icon.available = states.map(func(state): return true if stage < 10 else state.possible)
	icon.complete = states.map(func(state): return false if stage < 10 else state.complete)
	icon.saved = stage == 11 and reveal_save_state == "saved" and host.saved_fingerprint == reveal_fingerprint
	icon.queue_redraw()
	if pulsing != desired_pulses():
		reset_pulses()
		choose_pulses()

func grid_size() -> int: return 9 if stage in [10,11] else 5

func prediction_board() -> Array:
	return Preview.board(grid,cells,anchor,color,selected)

func ink(index: int) -> Color:
	return Palette.tile(index)

func request_action(action: String, parameters: Dictionary = {}) -> Dictionary:
	var request := {"cells":cells.duplicate(),"color":color,"anchor":anchor}
	if parameters.has("cell"): request.cell = parameters.cell
	if action in ["rotate","flip","color"]:
		if not _practice_action_available(action,request): return host.player_actions.failure(action,"Action is not available.")
		piece_gesture.cancel()
		animation = action
		animation_time = 0
		animation_color = color
		update_controls()
		# Execution/completion is deferred until the teaching animation finishes.
		return {"ok":true,"tutorial":true,"pending":true}
	if action == "place" and stage in [5,6,7,8] and selected and allowed("place") and animation.is_empty() and not Model.accepts(puzzle,cells,anchor,color):
		attempts += 1
		if stage in [6,7,8]: hint_visible = true
		invalidate_guidance()
		queue_redraw()
	# Lesson gates run before synchronizing even the practice color.
	if not _practice_action_available(action,request): return host.player_actions.failure(action,"Use the required action or target.")
	if action == "place": practice_game.current_color = color
	if action == "skip": request.replacement = "Domino"
	var result: Dictionary = host.player_actions.execute(action,practice_game,request,_practice_action_available)
	result.tutorial = true
	return result

func _practice_action_available(action: String, request: Dictionary) -> bool:
	if leaving or practice_game == null or not animation.is_empty() or not allowed(action): return false
	if action in ["rotate","flip","color"]: return not cells.is_empty()
	if action == "place": return selected and (repair_matches_target() if stage == 10 else Model.accepts(puzzle,cells,anchor,color))
	if action == "erase": return repair_erasing and request.get("cell") == Vector2i(1,1)
	return true

func transform_piece(operation: String) -> void:
	if operation in ["rotate","flip","color"]: request_action(operation)

func complete_transform() -> void:
	var operation := animation
	animation = ""
	var result: Dictionary = host.player_actions.execute(operation,practice_game,{"cells":cells,"color":color},_practice_action_available)
	if not result.ok:
		update_controls()
		return

func _on_action_completed(action: String, result: Dictionary) -> void:
	if leaving or practice_game == null or not allowed(action) or result.get("source") != "player" or result.get("session_id") != practice_game.get_instance_id(): return
	if result.has("cells"): cells = result.cells
	if result.has("color"):
		color = result.color
		practice_game.current_color = color
	if action in ["rotate","flip","color"]:
		if stage in [2,3,4]: enter(Lessons.LESSONS[Lessons.id(stage)].next)
		else: update_controls()
		return
	grid = practice_game.board.duplicate(true)
	if stage == 10: advance_repair()
	else: enter(Lessons.LESSONS[Lessons.id(stage)].next)

func show_hint() -> void:
	if stage == 11 and reveal_save_state == "failed":
		request_reveal_save()
		return
	if stage == 10 and repair_phase == 7:
		enter(11)
		return
	if stage in [6,7,8] and attempts > 0:
		hint_visible = true
		queue_redraw()

func try_place() -> void:
	request_action("place")


func next_step() -> void:
	if stage == 1: enter(2)

func _process(delta: float) -> void:
	if leaving: return
	elapsed += delta
	piece_gesture.tick(delta)
	if not animation.is_empty():
		animation_time += delta
		if animation_time >= ANIMATION_SECONDS: complete_transform()
	if leaving: return
	if guidance_dirty: update_controls()
	animate_pulses()
	if not animation.is_empty() or not pulsing.is_empty() or not guide_cells().is_empty() or stage == 2:
		queue_redraw()

func prepare_repair(reset_session: bool = true) -> void:
	if reset_session: practice_game = Model.practice_session(10,repair_phase)
	# The lesson offers I3 after the real erase; replacement itself uses real Skip.
	elif Lessons.checkpoint_for_phase(repair_phase) == "replace":
		var offered: bool = host.player_actions.offer(practice_game,"I3",2)
		assert(offered)
	grid = practice_game.board.duplicate(true)
	offer_pending = true
	selected = false
	held = false
	drag = false
	repair_erasing = false
	color = practice_game.current_color
	elapsed = 0
	set_caption(Lessons.definition(stage,repair_phase).caption)
	var index: int = Lessons.definition(stage,repair_phase).get("offer",-1)
	cells = laid_cells(practice_game.piece().cells) if index >= 0 else []
	# The player sees the unsuitable next piece before using the replacement joker.
	if repair_phase == 5: cells = laid_cells(practice_game.piece().cells)

func advance_repair() -> void:
	reset_pulses()
	repair_phase = Lessons.phase(Lessons.definition(stage,repair_phase).next)
	prepare_repair(false)
	save_checkpoint()
	layout()
	choose_pulses()
	update_controls()
	queue_redraw()

func repair_matches_target() -> bool:
	if not selected: return false
	var index: int = Lessons.definition(stage,repair_phase).get("offer",-1)
	if index < 0: return false
	var offer: Dictionary = Model.repair_offers()[index]
	if color != offer.color: return false
	var trial := Model.placed(grid,cells,anchor,color)
	return not trial.is_empty() and trial == Model.placed(grid,offer.cells,offer.anchor,offer.color)

func joker_action(action: String) -> void:
	if action == "erase":
		# Selecting the erase tool is UI state, not a square-erasure command.
		if not leaving and animation.is_empty() and allowed("erase"):
			repair_erasing = not repair_erasing
			invalidate_guidance()
		return
	if action in ["undo","skip"]: request_action(action)

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
		host.button_icon(forward).kind = "skip"
		host.button_icon(skip).kind = "close"
	# Build the same legal, two-color design in one action. No timed placements.
	var steps := Model.replay_steps()
	while seed_index < steps.size():
		var step: Dictionary = steps[seed_index]
		var offered: bool = host.player_actions.offer(host.game,step.name,step.get("color",1))
		assert(offered,"Tutorial design offer must remain available")
		if not offered: return
		var result: Dictionary = host.player_actions.execute("place",host.game,{"cells":step.cells,"anchor":step.anchor,"source":"scenario"})
		assert(result.ok,"Tutorial design placement must remain legal")
		if not result.ok: return
		seed_index += 1
	host.board_view.tutorial_underlay = []
	host.board_view.show_settled(host.game.board)
	grid = host.game.board.duplicate(true)
	cells = []
	selected = false
	set_caption(Lessons.LESSONS.reveal.caption)
	save_checkpoint()
	host.cells = host._offered_cells()
	host._autosave()
	# Use the existing menu while keeping the tutorial active until a theme is chosen.
	ui_scope.allow_theme_menu(z_index+2)
	host.button_icon(forward).kind = "settings"
	forward.tooltip_text = "Settings"
	request_reveal_save()

func request_reveal_save() -> void:
	if leaving or stage != 11 or reveal_save_state == "saving": return
	reveal_fingerprint = host._design_fingerprint()
	reveal_session_id = host.game.get_instance_id()
	reveal_save_state = "waiting" if host.saving else "saving"
	set_caption(Lessons.LESSONS.reveal.caption)
	invalidate_guidance()
	if not host.saving: host.save_current_design()
	update_controls()

func _on_design_save_finished(result: Dictionary) -> void:
	if leaving or stage != 11: return
	if reveal_save_state == "waiting":
		request_reveal_save()
		return
	if reveal_save_state != "saving" or result.get("session_id") != reveal_session_id or result.get("fingerprint") != reveal_fingerprint: return
	reveal_save_state = "saved" if result.ok else "failed"
	set_caption(Lessons.LESSONS.reveal.caption if result.ok else SAVE_FAILED_TEXT)
	layout()
	update_controls()

func open_settings() -> void:
	if stage != 11 or reveal_save_state != "saved" or host.saving: return
	reset_pulses()
	if host.palette_menu.visible: host._close_menu()
	else: host._show_menu("Settings")
	update_controls()

func choose_theme(theme_id: String) -> void:
	if stage != 11 or reveal_save_state != "saved" or host.saving or theme_id not in host.MENU_THEMES: return
	if not Palette.select_theme(theme_id): return
	reset_pulses()
	host._close_menu()
	host._refresh_theme()
	host.board_view.show_settled(host.game.board)
	finish(false)

func finish(_skipped: bool) -> void:
	if leaving: return
	save_checkpoint(true)
	_release_ui()
	if is_instance_valid(host): host._refresh_after_tutorial()
	queue_free()

func _release_ui() -> void:
	if cleaned: return
	cleaned = true
	leaving = true
	set_process(false)
	set_process_input(false)
	piece_gesture.cancel()
	hide()
	reset_pulses()
	if is_instance_valid(host):
		if host.resized.is_connected(layout): host.resized.disconnect(layout)
		if host.player_actions.completed.is_connected(_on_action_completed): host.player_actions.completed.disconnect(_on_action_completed)
		if host.interface_changed.is_connected(invalidate_guidance): host.interface_changed.disconnect(invalidate_guidance)
		if host.design_save_finished.is_connected(_on_design_save_finished): host.design_save_finished.disconnect(_on_design_save_finished)
	if ui_scope != null: ui_scope.restore()
	finished.emit()

func _exit_tree() -> void:
	if cleaned: return
	_release_ui()
	# Unexpected removal must not rebuild UI while the tree is removing children.
	if is_instance_valid(host) and not host.is_queued_for_deletion(): host.call_deferred("_refresh_after_tutorial")

func laid_cells(shape: Array) -> Array:
	return Geometry.laying(shape)

func tray_geometry() -> Dictionary:
	return Geometry.tray(cells,tray_rect,board_rect.size.x/grid_size())

func _input(event: InputEvent) -> void:
	_gui_input(event)

func _local_pointer(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse()*point

func _pick_gesture_target(point: Vector2) -> Dictionary:
	if not animation.is_empty() or host.palette_menu.visible: return {}
	for control: Control in host._controls():
		if control.visible and control.get_global_rect().has_point(point): return {}
	var local := _local_pointer(point)
	if stage == 10 and repair_phase == 4:
		if repair_erasing and board_rect.has_point(local):
			return {"cell":Geometry.board_cell(local,board_rect.position,board_rect.size.x/grid_size()),"tool":"erase"}
		return {}
	var hit := piece_cell_at(local)
	return {} if hit.x < 0 else {"cell":hit,"from_tray":not selected}

func _gui_input(event: InputEvent) -> void:
	if leaving or stage not in [2,3,4,5,6,7,8,10]: return
	var result := piece_gesture.handle(event,_pick_gesture_target)
	if result.is_empty(): return
	var point := _local_pointer(result.point)
	if result.tool == "erase":
		if result.released and not result.canceled and board_rect.has_point(point):
			var cell := Geometry.board_cell(point,board_rect.position,board_rect.size.x/grid_size())
			if cell == result.grabbed: request_action("erase",{"cell":cell})
	else:
		if result.moving: select_at(point)
		if result.tap: transform_piece("rotate")
	accept_event()

func piece_cell_at(point: Vector2) -> Vector2i:
	var unit := board_rect.size.x/grid_size()
	var geometry := tray_geometry()
	var origin: Vector2 = board_rect.position+Vector2(anchor)*unit if selected else geometry.origin
	return Geometry.hit(cells,point,origin,unit if selected else geometry.unit)

func select_at(point: Vector2) -> void:
	anchor = Geometry.anchor(point,board_rect.position,board_rect.size.x/grid_size(),grabbed)
	selected = true
	update_controls()
	queue_redraw()

func guide_cells() -> Array:
	if stage in [2,3,4,5] or (stage in [6,7,8] and hint_visible): return puzzle.missing.duplicate()
	if stage == 10:
		if repair_phase == 4: return [Vector2i(1,1)]
		var index: int = Lessons.definition(stage,repair_phase).get("offer",-1)
		if index >= 0:
			var offer: Dictionary = Model.repair_offers()[index]
			return offer.cells.map(func(cell: Vector2i): return cell+offer.anchor)
	return []

func target_color(cell: Vector2i) -> Color:
	var pigment: int = grid[cell.y][cell.x]
	var base := ink(pigment) if pigment > 0 else Color("F1E7EB")
	return base.lerp(Color.WHITE,pulse_amount())

func tile(rect: Rect2, color_value: Color) -> void:
	Surface.draw_flat_tile(self,rect,color_value)

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
	var states := cached_axis_states
	var indices: Array = [puzzle.symmetry] if Lessons.LESSONS[Lessons.id(stage)].axis_mode == "teaching" else [0,1,2,3,4,5,6]
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
		tile(marker,target_color(cell))
		if stage == 10 and repair_phase == 4:
			draw_rect(marker.grow(-5),Color.WHITE.lerp(Color("477D76"),pulse_amount()),false,4)
			draw_line(marker.position+Vector2(12,12),marker.end-Vector2(12,12),Ink.text(),3,true)
			draw_line(Vector2(marker.end.x-12,marker.position.y+12),Vector2(marker.position.x+12,marker.end.y-12),Ink.text(),3,true)
	if not selected or cells.is_empty(): draw_exercise_axes()
	piece_overlay.queue_redraw()

func _draw_piece() -> void:
	if cells.is_empty() or stage not in [2,3,4,5,6,7,8,10]: return
	var unit := board_rect.size.x/grid_size()
	var extent := Geometry.extent(cells)
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
	Surface.draw_piece(piece_overlay,cells,-Vector2(extent)*piece_unit/2,piece_unit,piece_ink(),true)
	piece_overlay.draw_set_transform(Vector2.ZERO)
	if selected: draw_exercise_axes(piece_overlay)
