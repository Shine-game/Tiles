extends SceneTree
const Model = preload("res://scripts/tutorial_model.gd")
const Intro = preload("res://scripts/introduction.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Session = preload("res://scripts/game_session.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func drag_piece(intro, destination: Vector2i) -> void:
	var point: Vector2
	var grabbed: Vector2i = intro.cells[0]
	var unit: float = intro.board_rect.size.x/intro.grid_size()
	if intro.selected: point = intro.board_rect.position+(Vector2(intro.anchor+grabbed)+Vector2.ONE/2)*unit
	else:
		var geometry: Dictionary = intro.tray_geometry()
		point = geometry.origin+(Vector2(grabbed)+Vector2.ONE/2)*geometry.unit
	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = true
	intro._gui_input(touch)
	var movement := InputEventScreenDrag.new()
	movement.position = intro.board_rect.position+(Vector2(destination+grabbed)+Vector2.ONE/2)*unit
	intro._gui_input(movement)
	touch.position = movement.position
	touch.pressed = false
	intro._gui_input(touch)
func click_control(button: Button, expect_press: bool = true) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	root.push_input(click,true)
	await process_frame
	check(button.is_pressed() == expect_press,"Held native press survives refresh, or stays disabled")
	click.pressed = false
	click.button_mask = 0
	root.push_input(click,true)
	await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://intro-sequence-test.cfg"
	DirAccess.remove_absolute(path)
	check(not Model.progress(path).done,"First launch needs introduction")
	for stage in [2,6,7,8]:
		var puzzle := Model.recipe(stage)
		check(Model.accepts(puzzle,puzzle.solution,puzzle.anchor,puzzle.color),"Puzzle has a verified solution")
		check(not Model.accepts(puzzle,puzzle.solution,puzzle.anchor,3-puzzle.color),"Wrong color fails")
		check(not Model.accepts(puzzle,puzzle.solution,Vector2i(-1,-1),puzzle.color),"Out-of-bounds fails")
		var reachable := false
		for variant: Dictionary in Rules.orientations(puzzle.offered):
			if Model.accepts(puzzle,variant.cells,puzzle.anchor,puzzle.color): reachable = true
		check(reachable,"Rotate and flip can reach the solution")
	var fixture := Model.axis_demo_board()
	check(Rules.symmetry_states(fixture)[0].complete,"Axes demonstration starts with vertical symmetry")
	var half := Model.placed(fixture,[Vector2i.ZERO,Vector2i.RIGHT],Vector2i(1,1),1)
	check(Rules.symmetry_states(half)[0].possible and not Rules.symmetry_states(half)[0].complete,"Unfinished symmetry remains possible")
	var broken := Model.placed(half,[Vector2i.ZERO],Vector2i(3,1),2)
	check(not Rules.symmetry_states(broken).any(func(state):return state.possible),"Bad placement breaks every remaining symmetry")
	root.size = Vector2i(540,825)
	Palette.select_theme("clockwork")
	var game = Main.new()
	root.add_child(game)
	game.size = Vector2(540,825)
	game._layout()
	await process_frame
	var original_game = game.game
	var original_board: Array = game.game.board.duplicate(true)
	game.intro_progress_path = path
	game._start_introduction()
	var intro = game.introduction
	check(paused,"Practice pauses the real game")
	for button in [game.erase_button,game.undo_button,game.skip_button]:
		check(button.visible and button.disabled,"Jokers remain visible but disabled")
	check(intro.forward == game.palette_button and intro.skip == game.replay_button,"Tutorial reuses navigation positions")
	var static_grid: Array = intro.grid.duplicate(true)
	intro._process(0.8)
	check(intro.stage == 1 and intro.grid == static_grid and intro.cells.is_empty(),"First step is a static symmetric pattern")
	intro._process(1.3)
	check(intro.stage == 2 and intro.cells == [Vector2i.ZERO] and intro.place in intro.pulsing,"Step two offers a tile and pulses Place")
	drag_piece(intro,intro.puzzle.anchor)
	await click_control(intro.place)
	check(intro.stage == 3,"Correct placement advances immediately on release")
	var stationary: Array = intro.cells.duplicate()
	intro._process(3)
	check(intro.stage == 3 and intro.cells == stationary and intro.animation.is_empty(),"Tile never rotates automatically")
	intro.transform_piece("rotate")
	check(intro.stage == 3 and intro.animation == "rotate","Player starts a rotation animation")
	intro._process(Intro.ANIMATION_SECONDS/2)
	check(intro.stage == 3 and intro.cells == stationary,"Rotation completes before moving on")
	intro._process(Intro.ANIMATION_SECONDS/2+0.01)
	check(intro.stage == 4 and intro.cells == Rules.rotate(stationary),"Finished rotation advances to flip")
	var normal: Color = intro.pulse_bases[intro.flip].normal.base.bg_color
	intro.elapsed = 1.3
	intro.animate_pulses()
	check(intro.flip.get_theme_stylebox("normal").bg_color.get_luminance() > normal.get_luminance(),"Highlight lightens button background")
	intro.elapsed = 2.6
	intro.animate_pulses()
	check(intro.flip.get_theme_stylebox("normal").bg_color.is_equal_approx(normal),"Slow pulse returns to normal background")
	var unflipped: Array = intro.cells.duplicate()
	intro.flip.pressed.emit()
	check(intro.stage == 4 and intro.animation == "flip","Flip starts only on player action")
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.stage == 5 and intro.cells == Rules.flip(unflipped),"Flip animation finishes before advancing")
	var old_color: int = intro.color
	intro._process(3)
	check(intro.color == old_color and intro.stage == 5,"Color never changes automatically")
	intro.recolor.pressed.emit()
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.stage == 6 and intro.recolor in game._controls(),"Color animation leads to the first symmetry exercise")
	for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(540,825),Vector2(720,1100)]:
		game.size = dimensions
		game._layout()
		intro.layout()
		check(intro.text.get_theme_font_size("font_size") == 2*clampi(roundi(dimensions.x*0.028),12,18),"Tutorial text stays doubled")
		check(intro.text.get_rect().end.y <= intro.tray_rect.position.y and intro.tray_rect.end.y < intro.board_rect.position.y,"Text, offered piece and board do not overlap")
		check(Rect2(Vector2.ZERO,dimensions).encloses(intro.board_rect),"Practice grid fits the phone")
	# Restore actual viewport size before exercising native controls.
	game.size = Vector2(540,825)
	game._layout()
	intro.layout()
	for stage in [6,7,8]:
		if intro.stage != stage: intro.enter(stage)
		check(intro.guide_cells().is_empty() and intro.hint in intro.pulsing,"Symmetry button pulses without giving away the placement")
		intro.show_hint()
		check(intro.guide_cells().is_empty(),"No shadow before a wrong placement")
		drag_piece(intro,Vector2i.ZERO)
		var before: Array = intro.grid.duplicate(true)
		intro.try_place()
		check(intro.stage == stage and intro.hint_visible and intro.guide_cells() == intro.puzzle.missing and intro.grid == before,"Wrong placement reveals a fixed hatched hint")
		intro.cells = intro.puzzle.solution.duplicate()
		intro.color = intro.puzzle.color
		drag_piece(intro,intro.puzzle.anchor)
		check(game.indicators[0].icon.complete[intro.puzzle.symmetry],"Symmetry indicator responds to correct hover")
		intro.place.pressed.emit()
		check(intro.stage == stage+1,"Correct symmetry placement advances instantly")
	intro.elapsed = 1.1
	intro.update_axis_demo()
	intro.update_controls()
	check(game.indicators[0].icon.complete[0],"Demonstration lights an existing axis")
	intro.elapsed = 3.2
	intro.update_axis_demo()
	intro.update_controls()
	check(not game.indicators[0].icon.complete[0] and game.indicators[0].icon.available[0],"Hover/rotation changes active axes")
	intro.elapsed = 6.5
	intro.update_axis_demo()
	intro.update_controls()
	check(not game.indicators[0].icon.available.any(func(value):return value),"Irrevocably broken axes disappear")
	intro.elapsed = 7.9
	intro.update_axis_demo()
	check(intro.demo_lost and intro.desaturation == 0,"Bad placement retains original board colors")
	intro._process(2.2)
	check(intro.stage == 10 and intro.repair_phase == 0 and intro.desaturation == 0,"Repair lesson starts with a colored symmetric board")
	check(Rules.symmetry_states(intro.grid)[0].complete,"Repair pattern starts with vertical symmetry")
	check(intro.forward.disabled,"Forward cannot bypass the repair exercise")
	intro.next_step()
	check(intro.stage == 10,"Forward handler cannot skip repair")
	for phase in [0,1]:
		var offer: Dictionary = Model.repair_offers()[phase]
		check(intro.guide_cells().size() == offer.cells.size(),"Wrong placement is marked explicitly")
		drag_piece(intro,Vector2i(4,4))
		intro.try_place()
		check(intro.repair_phase == phase,"Unmarked placement cannot progress")
		drag_piece(intro,offer.anchor)
		await click_control(intro.place)
		check(intro.repair_phase == phase+1 and intro.grid == Model.repair_board(phase+1),"Player must commit the forced wrong piece")
	check(not Rules.symmetry_states(intro.grid).any(func(state):return state.complete),"Player's two wrong moves leave no completed symmetry")
	check(not game.undo_button.disabled and game.erase_button.disabled and game.skip_button.disabled and game.undo_button in intro.pulsing,"Undo alone is enabled and highlighted")
	intro.joker_action("erase")
	check(intro.repair_phase == 2,"Out-of-order joker does nothing")
	await click_control(game.undo_button)
	check(intro.repair_phase == 3 and intro.grid[3][3] == 0 and intro.grid[0][0] == 1,"Undo removes only the last single-square placement")
	check(not game.erase_button.disabled and game.undo_button.disabled and game.erase_button in intro.pulsing,"Erase is enabled after Undo")
	var tap := InputEventScreenTouch.new()
	tap.position = intro.board_rect.position+Vector2.ONE*intro.board_rect.size.x/10
	tap.pressed = true
	intro._gui_input(tap)
	check(intro.repair_phase == 3,"Erasing requires activating its joker first")
	await click_control(game.erase_button)
	tap.position = intro.board_rect.get_center()
	intro._gui_input(tap)
	check(intro.repair_phase == 3 and intro.grid[2][2] == 1,"Wrong erase target does not damage the pattern")
	tap.position = intro.board_rect.position+Vector2.ONE*intro.board_rect.size.x/10
	intro._gui_input(tap)
	check(intro.repair_phase == 4 and intro.grid[0][0] == 0,"Tapping marked square erases exactly that square")
	check(intro.cells.size() == 3 and not game.skip_button.disabled and game.skip_button in intro.pulsing,"Replacement joker is enabled with unsuitable three-square offer")
	await click_control(game.skip_button)
	check(intro.repair_phase == 5 and intro.cells == Model.repair_offers()[2].cells,"Replacement joker provides the fitting domino")
	check(intro.guide_cells() == [Vector2i(3,1),Vector2i(4,1)],"Replacement destination is marked")
	drag_piece(intro,Vector2i(0,4))
	intro.try_place()
	check(intro.repair_phase == 5,"Incorrect replacement placement cannot finish")
	drag_piece(intro,Model.repair_offers()[2].anchor)
	await click_control(intro.place)
	check(intro.repair_phase == 6 and Rules.symmetry_states(intro.grid)[0].complete and game.indicators[0].icon.complete[0],"Replacement domino restores and highlights vertical symmetry")
	check(intro.desaturation == 0 and game.game == original_game and game.game.board == original_board,"Repair practice preserves colors and the saved game")
	intro._process(1.3)
	check(intro.stage == 11 and Palette.theme_id() == "vines" and intro.seed_index == 0,"Final step opens a real Vines game")
	check(game.game.board == Model.seed_board(0) and game.game.queue[game.game.index] == "L3" and intro.forward.disabled,"Real seed forces the next piece and cannot be skipped with Forward")
	var first: Dictionary = Model.seed_steps()[0]
	check(intro.guide_cells().size() == 3,"Seed placement is explicitly marked")
	drag_piece(intro,Vector2i.ZERO)
	intro.try_place()
	check(game.game.moves == 0,"Wrong seed placement does not commit")
	intro.cells = first.cells.duplicate()
	drag_piece(intro,first.anchor)
	intro.place.pressed.emit()
	check(game.game.moves == 1 and game.game.board == Model.seed_board(1) and intro.seed_index == 1,"First forced placement is committed to the real game")
	check(not game.board_view.pattern.tier2_records().is_empty(),"First forced placement creates a 2x2 artwork formation")
	check(Model.progress(path).seed_index == 1,"Seed progress is saved")
	# Simulate reopening an in-progress seed using the restored real-game state.
	intro.finish(true)
	await process_frame
	Model.save_progress(11,false,path,1)
	game.game = Session.unpack(JSON.parse_string(JSON.stringify(Session.pack(game.game))))
	var partial_game = game.game
	game._maybe_introduction(true)
	intro = game.introduction
	check(intro.stage == 11 and intro.seed_index == 1 and game.game == partial_game,"Partial real-game seed resumes without resetting the board")
	for index in [1,2]:
		game.board_view.show_settled(game.game.board)
		var step: Dictionary = Model.seed_steps()[index]
		intro.cells = step.cells.duplicate()
		intro.color = 1
		drag_piece(intro,step.anchor)
		intro.try_place()
	await process_frame
	check(game.introduction == null and not paused,"Completing the seed hands control to the real game")
	check(game.game.moves == 3 and game.game.board == Model.seed_board(3) and not game.game.over,"Small design remains playable")
	var final_states := Rules.symmetry_states(game.game.board)
	check(final_states[0].complete and final_states[1].complete and final_states[5].complete,"Seeded design is perfectly symmetric")
	check(Session.valid_game(Session.pack(game.game)),"Seeded game is valid for normal save/resume")
	check(Model.progress(path).done,"Tutorial completion is saved")
	check(game.palette_button.get_child(0).kind == "settings" and game.replay_button.get_child(0).kind == "replay","Real-game controls are restored")
	for button in [game.erase_button,game.undo_button,game.skip_button]: check(button.visible,"Jokers remain in the real UI")
	game._start_introduction()
	intro = game.introduction
	check(intro.stage == 1,"Replay starts from the beginning")
	intro.skip.pressed.emit()
	await process_frame
	check(not paused and game.introduction == null,"End tutorial exits at any time")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Interactive introduction: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
