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
	check((button.disabled != expect_press) if button.toggle_mode else (button.is_pressed() == expect_press),"Native press remains available across refresh; toggle controls may change their latched state")
	click.pressed = false
	click.button_mask = 0
	root.push_input(click,true)
	await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://intro-sequence-test.cfg"
	DirAccess.remove_absolute(path)
	check(not Model.progress(path).done,"First launch needs introduction")
	for stage in [5,6,7,8]:
		var puzzle := Model.recipe(stage)
		check(Model.accepts(puzzle,puzzle.solution,puzzle.anchor,puzzle.color),"Puzzle has a verified solution")
		check(not Model.accepts(puzzle,puzzle.solution,puzzle.anchor,3-puzzle.color),"Wrong color fails")
		check(not Model.accepts(puzzle,puzzle.solution,Vector2i(-1,-1),puzzle.color),"Out-of-bounds fails")
		var reachable := false
		for variant: Dictionary in Rules.orientations(puzzle.offered):
			if Model.accepts(puzzle,variant.cells,puzzle.anchor,puzzle.color): reachable = true
		check(reachable,"Rotate and flip can reach the solution")
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
	check(intro.text.get_theme_font("normal_font") == Intro.TUTORIAL_FONT and Intro.TUTORIAL_FONT.get_font_name() == "Lora" and Intro.TUTORIAL_FONT.get_font_style_name() == "Regular","Tutorial uses the bundled Lora Regular face")
	check(intro.progress_label.get_theme_font("font") == Intro.TUTORIAL_FONT and intro.repair_header.get_theme_font("normal_font") == Intro.TUTORIAL_FONT,"Step counter and persistent header share Lora Regular")
	for label in [intro.text,intro.repair_header]:
		check(label.get_theme_constant("line_separation") == 0 and label.get_theme_constant("paragraph_separation") == 0,"Text uses plain line breaks without added paragraph spacing")
	intro.set_caption("Line one\n\nLine two")
	check(intro.text.get_parsed_text() == "Line one\nLine two","Blank paragraph jumps are normalized to single line breaks")
	intro.set_caption(Intro.TEXT[intro.stage])

	for button in [game.erase_button,game.undo_button,game.skip_button]:
		check(button.visible and button.disabled,"Jokers remain visible but disabled")
	check(intro.forward == game.palette_button and intro.skip == game.replay_button,"Tutorial reuses navigation positions")
	check(intro.stage == 2 and intro.cells.size() == 3 and intro.place.disabled and intro.progress_label.text == "1 / 9","Tutorial opens directly on rotation as the first of nine cards")
	var preparation_board: Array = intro.grid.duplicate(true)
	var stationary: Array = intro.cells.duplicate()
	intro._process(1)
	check(intro.stage == 2 and intro.cells == stationary and intro.animation.is_empty(),"L stays stationary before a player tap")
	intro.transform_piece("flip")
	intro.try_place()
	check(intro.animation.is_empty() and intro.stage == 2,"Only rotation is enabled in step two")
	intro.transform_piece("rotate")
	intro._process(Intro.ANIMATION_SECONDS/2)
	check(intro.stage == 2,"Rotation finishes before advancing")
	intro._process(Intro.ANIMATION_SECONDS/2+0.01)
	check(intro.stage == 3 and intro.cells == Rules.rotate(stationary) and intro.grid == preparation_board,"Same L and pattern persist into Flip")
	var normal: Color = intro.pulse_bases[intro.flip].normal.base.bg_color
	intro.elapsed = Intro.PULSE_SECONDS/2
	intro.animate_pulses()
	check(intro.flip.get_theme_stylebox("normal").bg_color.get_luminance() > normal.get_luminance(),"Highlight lightens button background")
	check(intro.flip.get_theme_stylebox("normal").bg_color.is_equal_approx(Color.WHITE) and Intro.PULSE_SECONDS < 2.6,"Button pulse reaches white and runs faster")
	intro.elapsed = Intro.PULSE_SECONDS
	intro.animate_pulses()
	check(intro.flip.get_theme_stylebox("normal").bg_color.is_equal_approx(normal),"Faster pulse returns to normal background")
	var unflipped: Array = intro.cells.duplicate()
	intro.transform_piece("rotate")
	check(intro.animation.is_empty(),"Rotate is locked while Flip is taught")
	await click_control(intro.flip)
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.stage == 4 and intro.cells == Rules.flip(unflipped) and intro.grid == preparation_board,"Same L and board persist into Color")
	var old_color: int = intro.color
	intro._process(1)
	check(intro.color == old_color and intro.stage == 4,"Color changes only on player action")
	await click_control(intro.recolor)
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.stage == 5 and intro.grid == preparation_board and intro.color == 2,"Color lesson advances to Place without replacing the L or pattern")
	check(Model.accepts(intro.puzzle,intro.cells,intro.puzzle.anchor,intro.color),"One rotation, mirror, and recolor prepare the exact fitting L")
	drag_piece(intro,intro.puzzle.anchor)
	await click_control(intro.place)
	check(intro.stage == 6,"Prepared L placement advances immediately to symmetry exercises")
	for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(540,825),Vector2(720,1100)]:
		game.size = dimensions
		game._layout()
		var controls: Array = game._controls().map(func(button):return button.get_rect())
		intro.layout()
		check(intro.text.get_theme_font_size("font_size") <= 2*clampi(roundi(dimensions.x*0.028),12,18) and intro.text.get_theme_font_size("font_size") == 16,"Tutorial type stays fixed at sixteen pixels on every screen")
		check(intro.text.get_rect().end.y <= intro.tray_rect.position.y and intro.tray_rect.end.y < intro.board_rect.position.y,"Text, offered piece and board do not overlap")
		check(Rect2(Vector2.ZERO,dimensions).encloses(intro.board_rect),"Practice grid fits the phone")
		check(is_equal_approx(intro.adjusted_board_rect.end.y,intro.normal_board_rect.end.y),"Tutorial board shares the normal board bottom")
		check(is_equal_approx(intro.tray_rect.size.y,2*intro.board_rect.size.x/5),"Exactly two tile heights are reserved for the offer")
		check(controls == game._controls().map(func(button):return button.get_rect()),"Tutorial proportions never move any original button")
		check(is_equal_approx(intro.text.position.x,game.piece_view.position.x+2) and is_equal_approx(intro.text.size.x,game.piece_view.size.x-4) and is_equal_approx(intro.text.get_rect().get_center().y,intro.caption_rect.get_center().y),"Caption is centered between the two button columns")
		check(intro.text.get_theme_color("font_color") == intro.Ink.text(),"Caption uses the button drawing color")
		for caption: String in Intro.TEXT.slice(1,9):
			intro.set_caption(caption)
			intro.layout()
			check(intro.text.get_rect().end.y <= intro.tray_rect.position.y+0.1,"Caption fit %s %s text end %s tray top %s" % [dimensions,caption,intro.text.get_rect().end.y,intro.tray_rect.position.y])
		intro.set_caption(Intro.TEXT[intro.stage])


		var fixed_board: Rect2 = intro.board_rect
		for piece: Dictionary in Rules.PIECES.values():
			intro.cells = intro.laid_cells(piece.cells)
			var bounds := Vector2i.ONE
			for cell: Vector2i in intro.cells: bounds = bounds.max(cell+Vector2i.ONE)
			check(bounds.x >= bounds.y,"Every new offer lies horizontally")
			var presented: Dictionary = intro.tray_geometry()
			check(presented.origin.y+bounds.y*presented.unit <= intro.adjusted_board_rect.position.y-11.9,"Every presented offer clears the outer frame by twelve pixels")

			for turn in range(4):
				var geometry: Dictionary = intro.tray_geometry()
				check(is_equal_approx(geometry.unit,intro.board_rect.size.x/5),"Offer and board use identical tile sizes in every orientation")
				check(geometry.origin.y >= intro.tray_rect.position.y,"Tall rotations extend downward, below the text")
				check(intro.board_rect == fixed_board,"Rotating offered shapes never moves the board")
				intro.cells = Rules.rotate(intro.cells)

	# Every card shares the same fitted type size and centered text window.
	var reference_font := -1
	for card in [2,3,4,5,6,7,8,10,11]:
		intro.enter(card)
		if reference_font < 0: reference_font = intro.text.get_theme_font_size("font_size")
		check(intro.text.get_theme_font_size("font_size") == reference_font,"Type size is consistent across the whole tutorial")
		check(intro.caption_rect.encloses(intro.text.get_rect()),"Centered cue stays inside its reserved window")
		if card != 10:
			check(is_equal_approx(intro.text.get_rect().get_center().y,intro.caption_rect.get_center().y),"Short cues are vertically centered too")
	intro.finish(true)
	await process_frame
	# Continue the practice exercise on the original saved game.
	game.game = original_game
	Palette.select_theme("clockwork")
	game._refresh()
	game._start_introduction(6)
	intro = game.introduction
	# Restore actual viewport size before exercising native controls.
	game.size = Vector2(540,825)
	game._layout()
	intro.layout()
	for stage in [6,7,8]:
		if intro.stage != stage: intro.enter(stage)
		check(intro.guide_cells().is_empty() and intro.hint not in intro.pulsing and intro.place not in intro.pulsing,"Neither symmetry nor Place pulses before the exercise is solved")
		var original_grid: Array = intro.grid.duplicate(true)
		intro.grid[0][0] = 1
		var partner := Rules.transform(Vector2i.ZERO,intro.puzzle.symmetry,5)
		intro.grid[partner.y][partner.x] = 2
		intro.selected = false
		check(not Rules.symmetry_states(intro.grid)[intro.puzzle.symmetry].possible and intro.exercise_axis_state().possible and not intro.exercise_axis_state().complete,"Early exercise axis stays visible and unchanged even for an impossible hover")
		intro.grid = original_grid
		intro.show_hint()
		check(intro.guide_cells().is_empty(),"No shadow before a wrong placement")
		drag_piece(intro,Vector2i.ZERO)
		var before: Array = intro.grid.duplicate(true)
		intro.try_place()
		check(intro.stage == stage and intro.hint_visible and intro.guide_cells() == intro.puzzle.missing and intro.grid == before,"Wrong placement reveals the fixed pulsing target")
		intro.cells = intro.puzzle.solution.duplicate()
		intro.color = intro.puzzle.color
		drag_piece(intro,intro.puzzle.anchor)
		check(not game.indicators[0].icon.complete.any(func(value):return value) and intro.hint not in intro.pulsing,"Symmetry button stays neutral during the introductory exercises")
		check(intro.place in intro.pulsing,"Only Place pulses when orientation, color, and position are correct")
		drag_piece(intro,Vector2i.ZERO)
		check(intro.place not in intro.pulsing,"Place stops highlighting when moved away from the correct position")
		drag_piece(intro,intro.puzzle.anchor)
		intro.place.pressed.emit()
		check(intro.stage == (10 if stage == 8 else stage+1),"Correct symmetry placement advances instantly and skips removed card")
	check(intro.stage == 10 and intro.repair_phase == 2 and intro.progress_label.text == "8 / 9","Axes lesson follows the three exercises with nine-card numbering")
	intro.enter(9)
	check(intro.stage == 10 and intro.repair_phase == 2,"Old saved axes-card progress resumes at destruction lesson")
	for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(540,825),Vector2(720,1100)]:
		game.size = dimensions
		game._layout()
		var normal_frame: Rect2 = game.board_view.get_rect()
		var normal_field: Rect2 = Rect2(game.board_view.position+game.board_view.field.position,game.board_view.field.size)
		var controls: Array = game._controls().map(func(button):return button.get_rect())
		var shared_preview_unit := -1.0
		var shared_font_size := -1
		var single_square_center := Vector2.ZERO
		for phase in range(2,Intro.REPAIR_TEXT.size()):
			intro.repair_phase = phase
			intro.prepare_repair()
			intro.layout()
			intro.update_controls()
			check(intro.hint in intro.pulsing,"Hint pulses throughout every part of card eight")
			if phase == 3:
				check(intro.repair_header.visible and intro.repair_header.get_parsed_text() == "Save the pattern","Only the first repair step shows Save the pattern")
				check("Save the pattern" not in intro.text.get_parsed_text() and intro.text.position.y >= intro.repair_header.get_rect().end.y,"The first repair instruction sits under its header without repeating it")
			else:
				check(not intro.repair_header.visible,"Save the pattern is not repeated on subsequent repair steps")
			if phase == 4: check(intro.text.get_parsed_text() == "Erase a square.","Erase cue omits the removed instruction sentence")
			if shared_preview_unit < 0: shared_preview_unit = intro.tray_geometry().unit
			if shared_font_size < 0: shared_font_size = intro.text.get_theme_font_size("font_size")
			check(shared_font_size == intro.text.get_theme_font_size("font_size"),"Every cue uses the same font fitted to the longest text")
			check(intro.caption_rect.encloses(intro.text.get_rect()),"Cue fit %s phase %d window %s text %s" % [dimensions,phase,intro.caption_rect,intro.text.get_rect()])
			check(is_equal_approx(shared_preview_unit,intro.tray_geometry().unit),"All previews keep the same standard tile size")
			check(intro.text.get_theme_font_size("font_size") == 16,"Shared cue formatting fits the reserved text window")
			check(game.board_view.get_rect().is_equal_approx(normal_frame) and intro.board_rect.is_equal_approx(normal_field),"Tutorial nine-square frame and field exactly match normal geometry")
			check(controls == game._controls().map(func(button):return button.get_rect()),"Full-size tutorial field keeps every normal button fixed")
			if not intro.cells.is_empty():
				var geometry: Dictionary = intro.tray_geometry()
				var extent := Vector2i.ONE
				for cell: Vector2i in intro.cells: extent = extent.max(cell+Vector2i.ONE)
				check(not intro.offer_over_board and not intro.selected,"Each piece is presented outside the playing field")
				check(intro.piece_overlay.z_index > intro.text.z_index and intro.piece_overlay.z_index > intro.repair_header.z_index,"Live piece draws above the caption and repair header")
				check(is_equal_approx(geometry.unit,intro.board_rect.size.x/9),"Preview uses standard board-square size instead of shrinking")
			check(intro.text.get_content_height() <= intro.text.size.y+1,"Plain cue fits: %s phase %d content %d height %f" % [dimensions,phase,intro.text.get_content_height(),intro.text.size.y])
			if phase in [2,5]:
				var geometry: Dictionary = intro.tray_geometry()
				check(is_equal_approx(geometry.origin.y+geometry.unit,normal_frame.position.y-4),"Offer sits just above the outer frame")
				if phase == 2: single_square_center = geometry.origin+Vector2.ONE*geometry.unit/2
				else: check((geometry.origin+Vector2(1.5,0.5)*geometry.unit).is_equal_approx(single_square_center),"Three-square offer is centered exactly where the single square appeared")
			else:
				check(intro.tray_rect.is_equal_approx(game.piece_view.get_rect()),"Other previews retain their central header position")
	game.size = Vector2(540,825)
	game._layout()
	intro.enter(10)
	check(intro.grid == Model.repair_board(2) and Rules.symmetry_states(intro.grid)[0].possible and not Rules.symmetry_states(intro.grid)[0].complete,"Merged hint lesson starts with the first wrong piece already placed")
	check(intro.grid.size() == 9 and intro.guide_cells().size() == 1 and intro.cells == [Vector2i.ZERO],"Merged hint card offers the second, single-square piece directly")
	var target: Vector2i = intro.guide_cells()[0]
	intro.elapsed = 0
	check(intro.target_color(target) == Color("F1E7EB"),"Placement target starts at its normal tile color")
	intro.elapsed = Intro.PULSE_SECONDS/2
	check(intro.target_color(target).is_equal_approx(Color.WHITE),"Placement target reaches white on the same pulse as the buttons")
	intro.elapsed = Intro.PULSE_SECONDS
	check(intro.target_color(target).is_equal_approx(Color("F1E7EB")),"Placement target returns to its normal color without permanent shading")

	check(Model.repair_board(7) == Model.replay_board(Model.replay_steps().size()),"Replay includes both colors through the correct final placement")
	intro._process(3.1)
	check(intro.repair_phase == 2,"Axes exploration waits for the player instead of advancing automatically")

	check("[b]" not in intro.text.text and "[b]" not in str(Intro.TEXT) and "[b]" not in str(Intro.REPAIR_TEXT),"All tutorial wording uses regular text")
	intro.set_caption("[b]Regular lettering[/b]")
	check("[b]" not in intro.text.text,"Future cues cannot introduce bold markup")
	intro.set_caption(Intro.REPAIR_TEXT[2])
	check(not intro.flip.disabled and not intro.recolor.disabled and intro.place.disabled,"Piece controls are unlocked while Place waits for the required configuration")
	check(intro.hint in intro.pulsing and intro.place not in intro.pulsing and "The hint button shows achievable symmetries." in intro.text.get_parsed_text(),"Hint pulses continuously while Place stays quiet at an incorrect position")

	var saved_repair: Array = intro.grid.duplicate(true)
	drag_piece(intro,Vector2i(3,3))
	check(not Rules.symmetry_states(intro.prediction_board())[0].complete and not game.indicators[0].icon.complete[0],"Colliding floating piece no longer shows the committed board's present symmetry")
	check(intro.grid == saved_repair and intro.place.disabled,"Colliding preview never changes committed tiles or enables Place")
	intro.transform_piece("rotate")
	check(intro.hint in intro.pulsing,"Hint keeps pulsing even during a tile transformation")
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.stage == 10 and intro.repair_phase == 2,"Free rotation does not advance the axes lesson")
	await click_control(intro.flip)
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	await click_control(intro.recolor)
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.repair_phase == 2 and intro.color == 2 and intro.place.disabled,"Mirroring and recoloring are free and incorrect configuration stays disabled")
	intro.cells = Model.repair_offers()[1].cells.duplicate()
	intro.color = Model.repair_offers()[1].color
	intro.selected = false
	intro.update_controls()
	check(intro.forward.disabled,"Forward cannot bypass the repair exercise")
	intro.next_step()
	check(intro.stage == 10,"Forward handler cannot skip repair")
	for phase in [2]:
		var offer: Dictionary = Model.repair_offers()[phase-1]
		check(intro.guide_cells().size() == offer.cells.size(),"Wrong placement is marked explicitly")
		drag_piece(intro,Vector2i(4,4))
		intro.try_place()
		check(intro.repair_phase == phase,"Unmarked placement cannot progress")
		check(intro.place.disabled,"Place remains disabled away from the required configuration")

		drag_piece(intro,offer.anchor)
		check(not intro.place.disabled,"Place enables only at the required geometry, location, and color")
		check(intro.hint in intro.pulsing and intro.place in intro.pulsing,"Symmetry and Place highlight together only for the required second-piece placement")

		await click_control(intro.place)
		check(intro.repair_phase == phase+1 and intro.grid == Model.repair_board(phase+1),"Player must commit the forced wrong piece")

	check(not Rules.symmetry_states(intro.grid).any(func(state):return state.complete),"Player's two wrong moves leave no completed symmetry")
	check(not Rules.symmetry_states(intro.grid).any(func(state):return state.possible),"Broken pattern cannot be repaired by adding tiles, regardless of remaining jokers")
	check(not game.indicators[0].icon.available.any(func(value):return value),"No possible axes remain on the button in the broken setup")
	check(not game.indicators[0].icon.complete.any(func(value):return value),"No present axes remain in the broken setup")

	check(not game.undo_button.disabled and game.erase_button.disabled and game.skip_button.disabled and game.undo_button in intro.pulsing,"Undo alone is enabled and highlighted")
	intro.joker_action("erase")
	check(intro.repair_phase == 3,"Out-of-order joker does nothing")
	await click_control(game.undo_button)
	check(intro.repair_phase == 4 and intro.grid[2][6] == 0 and intro.grid[1][1] == 2,"Undo removes only the last single-square placement")
	var recovered: Array = Rules.symmetry_states(intro.grid)
	check(recovered[0].possible and not recovered[0].complete and recovered.filter(func(state):return state.possible).size() == 1,"Undo brings back only the thin possible vertical axis")

	check(not game.erase_button.disabled and game.undo_button.disabled and game.erase_button in intro.pulsing,"Erase is enabled after Undo")
	var tap := InputEventScreenTouch.new()
	tap.position = intro.board_rect.position+Vector2(1.5,1.5)*intro.board_rect.size.x/9
	tap.pressed = true
	intro._gui_input(tap)
	check(intro.repair_phase == 4,"Erasing requires activating its joker first")
	await click_control(game.erase_button)
	tap.position = intro.board_rect.get_center()
	intro._gui_input(tap)
	check(intro.repair_phase == 4 and intro.grid[4][4] == 1,"Wrong erase target does not damage the pattern")
	tap.position = intro.board_rect.position+Vector2(1.5,1.5)*intro.board_rect.size.x/9
	intro._gui_input(tap)
	check(intro.repair_phase == 5 and intro.grid[1][1] == 0,"Tapping marked square erases exactly that square")
	check(intro.cells.size() == 3 and not game.skip_button.disabled and game.skip_button in intro.pulsing,"Replacement joker is enabled with unsuitable three-square offer")
	await click_control(game.skip_button)
	check(intro.repair_phase == 6 and intro.cells == Model.repair_offers()[2].cells,"Replacement joker provides the fitting domino")
	check(intro.guide_cells() == [Vector2i(6,2),Vector2i(7,2)],"Replacement destination is marked")
	drag_piece(intro,Vector2i(0,4))
	intro.try_place()
	check(intro.repair_phase == 6,"Incorrect replacement placement cannot finish")
	drag_piece(intro,Model.repair_offers()[2].anchor)
	await click_control(intro.place)
	check(intro.repair_phase == 7 and Rules.symmetry_states(intro.grid)[0].complete and game.indicators[0].icon.complete[0],"Replacement domino restores and highlights vertical symmetry")
	check("Bold axis! Your board is symmetrical right now." in intro.text.text and "Save a picture and continue playing." in intro.text.text,"Recovered pattern explains the bold axis and saving a picture")

	check(intro.ink(1) == Palette.tile(1) and game.game == original_game and game.game.board == original_board,"Repair practice preserves colors and the saved game")
	intro._process(5.1)
	check(intro.stage == 11 and Palette.theme_id() == "vines" and intro.seed_index == 0,"Final step opens a real Vines game")
	check(game.game.board == Model.replay_board(0) and intro.cells.is_empty() and intro.place.disabled,"Automatic replay offers no player-controlled tile")
	check(game.board_view.tutorial_underlay == Model.repair_board(7),"Replay retains the full simple two-color tile arrangement from the exercise")
	check(game.board_view.tutorial_tile_layer.z_index < game.board_view.tier1_layer.z_index and game.board_view.tutorial_tile_layer.z_index < game.board_view.junction_layer.z_index,"Retained tile background draws beneath tier-one vines and junctions")
	check(not game.board_view.occupied_platform.visible,"Normal platform cannot cover the retained simple tiles")

	check(intro.prediction_board() == Model.repair_board(7),"Replay axes describe the retained visible tiles while artwork is built")

	intro._process(0)
	check(game.game.moves == 1 and game.game.board == Model.replay_board(1) and intro.seed_index == 1,"Replay automatically commits its first legal placement")
	check(not game.board_view.pattern.tier2_records().is_empty(),"Replay creates real 2x2 artwork")
	check(Model.progress(path).seed_index == 1,"Automatic replay progress is saved")
	intro.update_replay(10)
	check(game.game.moves == 1,"Replay waits for running artwork animation")
	intro.finish(true)
	await process_frame
	Model.save_progress(11,false,path,1)
	game.game = Session.unpack(JSON.parse_string(JSON.stringify(Session.pack(game.game))))
	var partial_game = game.game
	game._maybe_introduction(true)
	intro = game.introduction
	check(intro.stage == 11 and intro.seed_index == 1 and game.game == partial_game,"Automatic replay resumes its saved construction")
	for index in range(1,Model.replay_steps().size()):
		game.board_view.show_settled(game.game.board)
		intro.update_replay(0)
		check(game.game.board == Model.replay_board(index+1),"Every replayed move matches the intended construction")
		check(game.board_view.tutorial_underlay == Model.repair_board(7),"The retained tiles remain unchanged under each artwork reveal")

	check(game.introduction != null and intro.replay_finishing,"Replay does not hand off before final artwork finishes")
	var full_replay_frame: Rect2 = game.board_view.get_rect()
	check(full_replay_frame == intro.normal_board_rect and game.game.board[2][1] == 2 and game.game.board[2][7] == 2,"Replay retains normal field size and reaches the two-color restored pattern")

	game.board_view.show_settled(game.game.board)
	intro._process(0.7)
	check(not game.palette_button.disabled,"Final tutorial update cannot disable Settings again")
	await process_frame
	check(game.introduction == null and not paused,"Completed automatic replay hands control to the player")
	check(game.board_view.tutorial_underlay.is_empty(),"Normal board presentation is restored at handoff")
	check(not game.board_view.tutorial_tile_layer.visible and game.board_view.occupied_platform.visible,"Normal platform visibility returns at handoff")

	check(game.board_view.get_rect().is_equal_approx(full_replay_frame),"Handoff does not resize the nine-square playing field")

	check(game.game.moves == Model.replay_steps().size() and game.game.board == Model.repair_board(7) and not game.game.over,"Exact demonstration pattern becomes the playable game")
	check(Rules.symmetry_states(game.game.board)[0].complete,"Replayed pattern preserves vertical symmetry")
	check(Session.valid_game(Session.pack(game.game)),"Replayed game is valid for normal save/resume")
	check(Model.progress(path).done,"Tutorial completion is saved")
	check(game.palette_button.get_child(0).kind == "settings" and game.replay_button.get_child(0).kind == "replay","Real-game controls are restored")
	for button: Button in [game.palette_button,game.replay_button,game.flip_button,game.blue_button,game.erase_button,game.undo_button,game.skip_button]:
		check(button.visible and not button.disabled,"Normal available controls are active immediately after handoff")
	await click_control(game.palette_button)
	check(game.palette_menu.visible and game.menu_page == "Settings","Native Settings click opens menu after tutorial completion")
	game._close_menu()
	var playable := Rules.first_physical_move(game.game.board,game.game.piece())
	game.cells = playable.cells
	game.selected = playable.anchor
	game.has_hover = true
	game._preview()
	check(not game.place_button.disabled,"Place activates for a valid floating piece after handoff")
	game.has_hover = false
	game._preview()

	for button in [game.erase_button,game.undo_button,game.skip_button]: check(button.visible,"Jokers remain in the real UI")
	game._start_introduction()
	intro = game.introduction
	check(intro.stage == 2 and intro.progress_label.text == "1 / 9","Replay starts directly on the rotation card")
	intro.skip.pressed.emit()
	await process_frame
	check(not paused and game.introduction == null,"End tutorial exits at any time")
	Model.save_progress(11,false,path,0)
	game._start_introduction(11)
	intro = game.introduction
	for tick in range(1600):
		if game.introduction == null: break
		game.board_view.advance_growth(0.25)
		intro._process(0.25)
	check(game.introduction == null and game.game.board == Model.repair_board(7),"Automatic replay completes through real growth and delayed-reveal clocks without settling shortcuts")
	check(not game.palette_button.disabled and not game.replay_button.disabled and not game.flip_button.disabled and not game.blue_button.disabled,"Natural replay completion leaves the full normal UI active")

	await process_frame

	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Interactive introduction: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
