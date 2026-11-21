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
	for lesson_id: String in ["place","vertical","horizontal","rotational"]:
		var puzzle := Model.recipe(lesson_id)
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
	var gallery_folder := "/tmp/tutorial-save-%d" % Time.get_ticks_usec()
	game.gallery.directory = gallery_folder
	root.add_child(game)
	game.size = Vector2(540,825)
	game._layout()
	await process_frame
	var completed_actions: Array = []
	game.player_actions.completed.connect(func(action,result): completed_actions.append({"action":action,"result":result}))
	var original_game = game.game
	var original_board: Array = game.game.board.duplicate(true)
	var original_session := JSON.stringify(Session.pack(game.game))
	game.intro_progress_path = path
	game._start_introduction()
	var intro = game.introduction
	check(not paused and game.board_view.process_mode == Node.PROCESS_MODE_DISABLED,"Practice freezes only existing artwork, without pausing the app")
	check(intro.text.get_theme_font("normal_font") == Intro.TUTORIAL_FONT and Intro.TUTORIAL_FONT.get_font_name() == "Lora" and Intro.TUTORIAL_FONT.get_font_style_name() == "Regular","Tutorial uses the bundled Lora Regular face")
	check(intro.progress_label.get_theme_font("font") == Intro.TUTORIAL_FONT and intro.repair_header.get_theme_font("normal_font") == Intro.TUTORIAL_FONT,"Step counter and persistent header share Lora Regular")
	for label in [intro.text,intro.repair_header]:
		check(label.get_theme_constant("line_separation") == 0 and label.get_theme_constant("paragraph_separation") == 0,"Text uses plain line breaks without added paragraph spacing")
	intro.set_caption("Line one\n\nLine two")
	check(intro.text.get_parsed_text() == "Line one\nLine two","Blank paragraph jumps are normalized to single line breaks")
	intro.set_caption(Intro.Lessons.definition(intro.lesson_id).caption)

	for button in [game.erase_button,game.undo_button,game.skip_button]:
		check(button.visible and button.disabled,"Jokers remain visible but disabled")
	check(intro.forward == game.palette_button and intro.skip == game.replay_button,"Tutorial reuses navigation positions")
	check(game.button_icon(intro.forward).kind == "settings" and intro.forward.disabled and intro.forward.modulate.a < 0.6,"Settings keeps its normal icon and is visibly dimmed until enabled")
	check(game.button_icon(intro.skip).kind == "replay","New Game keeps its normal icon")
	check(intro.guide_cells().is_empty(),"Destination pulse does not start during rotation")
	check(intro.lesson_id == "rotate" and intro.cells.size() == 3 and intro.place.disabled and intro.progress_label.text == "1 / 8","Tutorial opens directly on rotation as the first of eight cards")
	var preparation_board: Array = intro.grid.duplicate(true)
	var prepared_session = intro.practice_game
	check(prepared_session != game.game and prepared_session.board == intro.grid,"Early exercise uses an isolated real game")
	var stationary: Array = intro.cells.duplicate()
	var source_geometry: Dictionary = intro.tray_geometry()
	var source_point: Vector2 = source_geometry.origin+(Vector2(intro.cells[0])+Vector2.ONE/2)*source_geometry.unit
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 3
	first_touch.position = source_point
	first_touch.pressed = true
	root.push_input(first_touch,true)
	check(intro.held,"Tutorial native input accepts a first pointer with a nonzero ID")
	var other_release := InputEventScreenTouch.new()
	other_release.index = 7
	other_release.position = source_point
	other_release.pressed = false
	root.push_input(other_release,true)
	check(intro.held,"Another finger cannot release the tutorial piece")
	first_touch.pressed = false
	first_touch.canceled = true
	root.push_input(first_touch,true)
	check(not intro.held and intro.animation.is_empty() and intro.cells == stationary,"System-canceled tutorial touch never rotates")
	first_touch.canceled = false
	first_touch.pressed = true
	root.push_input(first_touch,true)
	intro._process(Intro.Gesture.TAP_LIMIT+0.1)
	first_touch.pressed = false
	root.push_input(first_touch,true)
	check(intro.animation.is_empty() and intro.cells == stationary,"Tutorial long hold follows the same non-rotation rule as the game")
	intro._process(1)
	check(intro.lesson_id == "rotate" and intro.cells == stationary and intro.animation.is_empty(),"L stays stationary before a player tap")
	intro.transform_piece("flip")
	intro.try_place()
	check(intro.animation.is_empty() and intro.lesson_id == "rotate","Only rotation is enabled in step two")
	intro.transform_piece("rotate")
	check(completed_actions.is_empty(),"Animated commands do not report completion before their animation finishes")
	intro._process(Intro.ANIMATION_SECONDS/2)
	check(intro.lesson_id == "rotate","Rotation finishes before advancing")
	intro._process(Intro.ANIMATION_SECONDS/2+0.01)
	check(completed_actions.size() == 1 and completed_actions[0].action == "rotate","Tutorial rotation completes through the shared command interface exactly once")
	check(intro.progress_label.text == "1 / 8","Flip retains the combined first-card number")
	check(intro.lesson_id == "flip" and intro.cells == Rules.rotate(stationary) and intro.grid == preparation_board,"Same L and pattern persist into Flip")
	check(intro.guide_cells().is_empty(),"Destination pulse stays off during Flip")
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
	check(intro.lesson_id == "color" and intro.cells == Rules.flip(unflipped) and intro.grid == preparation_board,"Same L and board persist into Color")
	check(intro.guide_cells().is_empty(),"Destination pulse stays off during Color")
	var old_color: int = intro.color
	intro._process(1)
	check(intro.color == old_color and intro.lesson_id == "color","Color changes only on player action")
	await click_control(intro.recolor)
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.lesson_id == "place" and intro.grid == preparation_board and intro.color == 2,"Color lesson advances to Place without replacing the L or pattern")
	check(intro.guide_cells() == intro.puzzle.missing,"Destination starts pulsing only when Drag and Place is taught")
	check(intro.practice_game == prepared_session and intro.practice_game.current_color == intro.color,"The same practice game survives all preparation operations")
	check(Model.accepts(intro.puzzle,intro.cells,intro.puzzle.anchor,intro.color),"One rotation, mirror, and recolor prepare the exact fitting L")
	drag_piece(intro,intro.puzzle.anchor)
	await click_control(intro.place)
	check(intro.lesson_id == "vertical","Prepared L placement advances immediately to symmetry exercises")
	for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(540,825),Vector2(720,1100)]:
		game.size = dimensions
		game._layout()
		var controls: Array = game._controls().map(func(button):return button.get_rect())
		intro.layout()
		check(intro.text.get_theme_font_size("font_size") <= 2*clampi(roundi(dimensions.x*0.028),12,18) and intro.text.get_theme_font_size("font_size") == 20,"Tutorial type stays fixed at twenty pixels on every screen")
		check(intro.text.get_rect().end.y <= intro.tray_rect.position.y and intro.tray_rect.end.y < intro.board_rect.position.y,"Text, offered piece and board do not overlap")
		check(Rect2(Vector2.ZERO,dimensions).encloses(intro.board_rect),"Practice grid fits the phone")
		check(is_equal_approx(intro.adjusted_board_rect.end.y,intro.normal_board_rect.end.y),"Tutorial board shares the normal board bottom")
		check(is_equal_approx(intro.tray_rect.size.y,2*intro.board_rect.size.x/5),"Exactly two tile heights are reserved for the offer")
		check(controls == game._controls().map(func(button):return button.get_rect()),"Tutorial proportions never move any original button")
		check(is_equal_approx(intro.text.position.x,game.piece_view.position.x+2) and is_equal_approx(intro.text.size.x,game.piece_view.size.x-4) and is_equal_approx(intro.text.get_rect().get_center().y,intro.caption_rect.get_center().y),"Caption is centered between the two button columns")
		check(intro.text.get_theme_color("font_color") == intro.Ink.text(),"Caption uses the button drawing color")
		for caption: String in Intro.Lessons.ORDER.slice(0,7).map(func(key):return Intro.Lessons.LESSONS[key].caption):
			intro.set_caption(caption)
			intro.layout()
			check(intro.text.get_rect().end.y <= intro.tray_rect.position.y+0.1,"Caption fit %s %s text end %s tray top %s" % [dimensions,caption,intro.text.get_rect().end.y,intro.tray_rect.position.y])
		intro.set_caption(Intro.Lessons.definition(intro.lesson_id).caption)


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
	for card: String in Intro.Lessons.ORDER:
		intro.enter(card)
		if reference_font < 0: reference_font = intro.text.get_theme_font_size("font_size")
		check(intro.text.get_theme_font_size("font_size") == reference_font,"Type size is consistent across the whole tutorial")
		check(intro.caption_rect.encloses(intro.text.get_rect()),"Centered cue stays inside its reserved window")
		if card != "repair":
			check(is_equal_approx(intro.text.get_rect().get_center().y,intro.caption_rect.get_center().y),"Short cues are vertically centered too")
	intro.finish(true)
	await process_frame
	# Continue the practice exercise on the original saved game.
	game.game = original_game
	Palette.select_theme("clockwork")
	game._refresh()
	game._start_introduction("vertical")
	intro = game.introduction
	# Restore actual viewport size before exercising native controls.
	game.size = Vector2(540,825)
	game._layout()
	intro.layout()
	for lesson_id: String in ["vertical","horizontal","rotational"]:
		if intro.lesson_id != lesson_id: intro.enter(lesson_id)
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
		check(intro.lesson_id == lesson_id and intro.hint_visible and intro.guide_cells() == intro.puzzle.missing and intro.grid == before,"Wrong placement reveals the fixed pulsing target")
		intro.cells = intro.puzzle.solution.duplicate()
		intro.color = intro.puzzle.color
		drag_piece(intro,intro.puzzle.anchor)
		check(not game.indicators[0].icon.complete.any(func(value):return value) and intro.hint not in intro.pulsing,"Symmetry button stays neutral during the introductory exercises")
		check(intro.place in intro.pulsing,"Only Place pulses when orientation, color, and position are correct")
		drag_piece(intro,Vector2i.ZERO)
		check(intro.place not in intro.pulsing,"Place stops highlighting when moved away from the correct position")
		drag_piece(intro,intro.puzzle.anchor)
		intro.place.pressed.emit()
		check(intro.lesson_id == Intro.Lessons.LESSONS[lesson_id].next,"Correct symmetry placement advances instantly and skips removed card")
	check(intro.lesson_id == "repair" and intro.repair_checkpoint == "wrong_placement" and intro.progress_label.text == "5 / 8","Axes lesson follows the three exercises with regrouped eight-card numbering")
	for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(540,825),Vector2(720,1100)]:
		game.size = dimensions
		game._layout()
		var normal_frame: Rect2 = game.board_view.get_rect()
		var normal_field: Rect2 = Rect2(game.board_view.position+game.board_view.field.position,game.board_view.field.size)
		var controls: Array = game._controls().map(func(button):return button.get_rect())
		var shared_preview_unit := -1.0
		var shared_font_size := -1
		var single_square_center := Vector2.ZERO
		for checkpoint: String in Intro.Lessons.REPAIR_ORDER:
			intro.repair_checkpoint = checkpoint
			intro.prepare_repair()
			intro.layout()
			intro.update_controls()
			check(intro.progress_label.text == "%d / 8" % Intro.Lessons.definition("repair",checkpoint).number,"Repair substeps show their grouped card number")
			check((intro.hint in intro.pulsing) == (checkpoint in ["wrong_placement","save"]),"Hint pulses in the hint explanation and saved-symmetry cue")
			if checkpoint == "undo":
				check(intro.repair_header.visible and intro.repair_header.get_parsed_text() == "Save the pattern","Only the first repair step shows Save the pattern")
				check("Save the pattern" not in intro.text.get_parsed_text() and intro.text.position.y >= intro.repair_header.get_rect().end.y,"The first repair instruction sits under its header without repeating it")
			else:
				check(not intro.repair_header.visible,"Save the pattern is not repeated on subsequent repair steps")
			if checkpoint == "erase": check(intro.text.get_parsed_text() == "Erase a square.","Erase cue omits the removed instruction sentence")
			if shared_preview_unit < 0: shared_preview_unit = intro.tray_geometry().unit
			if shared_font_size < 0: shared_font_size = intro.text.get_theme_font_size("font_size")
			check(shared_font_size == intro.text.get_theme_font_size("font_size"),"Every cue uses the same font fitted to the longest text")
			check(intro.caption_rect.encloses(intro.text.get_rect()),"Cue fit %s checkpoint %s window %s text %s" % [dimensions,checkpoint,intro.caption_rect,intro.text.get_rect()])
			check(is_equal_approx(shared_preview_unit,intro.tray_geometry().unit),"All previews keep the same standard tile size")
			check(intro.text.get_theme_font_size("font_size") == 20,"Shared cue formatting fits the reserved text window")
			check(game.board_view.get_rect().is_equal_approx(normal_frame) and intro.board_rect.is_equal_approx(normal_field),"Tutorial nine-square frame and field exactly match normal geometry")
			check(controls == game._controls().map(func(button):return button.get_rect()),"Full-size tutorial field keeps every normal button fixed")
			if not intro.cells.is_empty():
				var geometry: Dictionary = intro.tray_geometry()
				var extent := Vector2i.ONE
				for cell: Vector2i in intro.cells: extent = extent.max(cell+Vector2i.ONE)
				check(not intro.selected and geometry.origin.y+extent.y*geometry.unit <= normal_frame.position.y,"Each piece is presented outside the playing field")
				check(intro.piece_overlay.z_index > intro.text.z_index and intro.piece_overlay.z_index > intro.repair_header.z_index,"Live piece draws above the caption and repair header")
				check(is_equal_approx(geometry.unit,intro.board_rect.size.x/9),"Preview uses standard board-square size instead of shrinking")
			check(intro.text.get_content_height() <= intro.text.size.y+1,"Plain cue fits: %s checkpoint %s content %d height %f" % [dimensions,checkpoint,intro.text.get_content_height(),intro.text.size.y])
			if checkpoint in ["wrong_placement","replace","place_replacement"]:
				var geometry: Dictionary = intro.tray_geometry()
				check(is_equal_approx(geometry.origin.y+geometry.unit,normal_frame.position.y-4),"Offer sits just above the outer frame")
				if checkpoint == "wrong_placement": single_square_center = geometry.origin+Vector2.ONE*geometry.unit/2
				else: check((geometry.origin+Vector2(1.0 if checkpoint == "place_replacement" else 1.5,0.5)*geometry.unit).is_equal_approx(single_square_center),"Three-square offer is centered exactly where the single square appeared")
			else:
				check(intro.tray_rect.is_equal_approx(game.piece_view.get_rect()),"Other previews retain their central header position")
	game.size = Vector2(540,825)
	game._layout()
	intro.enter("repair")
	check(intro.grid == Model.repair_board("wrong_placement") and Rules.symmetry_states(intro.grid)[0].possible and not Rules.symmetry_states(intro.grid)[0].complete,"Merged hint lesson starts with the first wrong piece already placed")
	check(intro.grid.size() == 9 and intro.guide_cells().size() == 1 and intro.cells == [Vector2i.ZERO],"Merged hint card offers the second, single-square piece directly")
	var target: Vector2i = intro.guide_cells()[0]
	intro.elapsed = 0
	check(intro.target_color(target) == Color("F1E7EB"),"Placement target starts at its normal tile color")
	intro.elapsed = Intro.PULSE_SECONDS/2
	check(intro.target_color(target).is_equal_approx(Color.WHITE),"Placement target reaches white on the same pulse as the buttons")
	intro.elapsed = Intro.PULSE_SECONDS
	check(intro.target_color(target).is_equal_approx(Color("F1E7EB")),"Placement target returns to its normal color without permanent shading")

	check(Model.repair_board("save") == Model.final_board(),"Replay includes both colors through the correct final placement")
	intro._process(3.1)
	check(intro.repair_checkpoint == "wrong_placement","Axes exploration waits for the player instead of advancing automatically")

	check("[b]" not in intro.text.text and "[b]" not in str(Intro.Lessons.LESSONS) and "[b]" not in str(Intro.Lessons.REPAIR),"All tutorial wording uses regular text")
	intro.set_caption("[b]Regular lettering[/b]")
	check("[b]" not in intro.text.text,"Future cues cannot introduce bold markup")
	intro.set_caption(Intro.Lessons.REPAIR.wrong_placement.caption)
	check(not intro.flip.disabled and not intro.recolor.disabled and intro.place.disabled,"Piece controls are unlocked while Place waits for the required configuration")
	check(intro.hint in intro.pulsing and intro.place not in intro.pulsing and "The hint button shows achievable symmetries." in intro.text.get_parsed_text(),"Hint explanation pulses Hint while Place waits for the required placement")

	var repair_session = intro.practice_game
	var saved_repair: Array = intro.grid.duplicate(true)
	drag_piece(intro,Vector2i(3,3))
	check(not Rules.symmetry_states(intro.prediction_board())[0].complete and not game.indicators[0].icon.complete[0],"Colliding floating piece no longer shows the committed board's present symmetry")
	check(intro.grid == saved_repair and intro.place.disabled,"Colliding preview never changes committed tiles or enables Place")
	intro.transform_piece("rotate")
	check(intro.hint in intro.pulsing,"Hint continues pulsing during transformations in the hint explanation")
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.lesson_id == "repair" and intro.repair_checkpoint == "wrong_placement","Free rotation does not advance the axes lesson")
	await click_control(intro.flip)
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	await click_control(intro.recolor)
	intro._process(Intro.ANIMATION_SECONDS+0.01)
	check(intro.repair_checkpoint == "wrong_placement" and intro.color == 2 and intro.place.disabled,"Mirroring and recoloring are free and incorrect configuration stays disabled")
	intro.cells = Model.repair_offers()[1].cells.duplicate()
	intro.color = Model.repair_offers()[1].color
	intro.selected = false
	intro.update_controls()
	check(intro.forward.disabled,"Forward cannot bypass the repair exercise")
	game._toggle_palette_menu()
	check(intro.lesson_id == "repair" and not game.palette_menu.visible,"Settings cannot bypass repair")
	var offer: Dictionary = Model.repair_offers()[1]
	check(intro.guide_cells().size() == offer.cells.size(),"Wrong placement is marked explicitly")
	drag_piece(intro,Vector2i(4,4))
	intro.try_place()
	check(intro.repair_checkpoint == "wrong_placement","Unmarked placement cannot progress")
	check(intro.place.disabled,"Place remains disabled away from the required configuration")

	drag_piece(intro,offer.anchor)
	check(not intro.place.disabled,"Place enables only at the required geometry, location, and color")
	check(intro.hint in intro.pulsing and intro.place in intro.pulsing,"Hint and correctly configured Place both highlight on card five")

	await click_control(intro.place)
	check(intro.repair_checkpoint == "undo" and intro.grid == Model.repair_board("undo"),"Player must commit the forced wrong piece")

	check(not Rules.symmetry_states(intro.grid).any(func(state):return state.complete),"Player's two wrong moves leave no completed symmetry")
	check(not Rules.symmetry_states(intro.grid).any(func(state):return state.possible),"Broken pattern cannot be repaired by adding tiles, regardless of remaining jokers")
	check(not game.indicators[0].icon.available.any(func(value):return value),"No possible axes remain on the button in the broken setup")
	check(not game.indicators[0].icon.complete.any(func(value):return value),"No present axes remain in the broken setup")

	check(not game.undo_button.disabled and game.erase_button.disabled and game.skip_button.disabled and game.undo_button in intro.pulsing,"Undo alone is enabled and highlighted")
	intro.joker_action("erase")
	check(intro.practice_game == repair_session and repair_session.over and repair_session.history.back().anchor == Vector2i(6,2),"Bad placement ends the same real practice game and records its history")
	check(intro.repair_checkpoint == "undo","Out-of-order joker does nothing")
	await click_control(game.undo_button)
	check(Model.progress(path).checkpoint == "erase","Undo persists the next named checkpoint")
	check(intro.repair_checkpoint == "erase" and intro.grid[2][6] == 0 and intro.grid[1][1] == 2,"Undo removes only the last single-square placement")
	var recovered: Array = Rules.symmetry_states(intro.grid)
	check(recovered[0].possible and not recovered[0].complete and recovered.filter(func(state):return state.possible).size() == 1,"Undo brings back only the thin possible vertical axis")

	check(not game.erase_button.disabled and game.undo_button.disabled and game.erase_button in intro.pulsing,"Erase is enabled after Undo")
	var tap := InputEventScreenTouch.new()
	tap.position = intro.board_rect.position+Vector2(1.5,1.5)*intro.board_rect.size.x/9
	tap.pressed = true
	intro._gui_input(tap)
	check(intro.repair_checkpoint == "erase","Erasing requires activating its joker first")
	await click_control(game.erase_button)
	tap.position = intro.board_rect.get_center()
	intro._gui_input(tap)
	tap.pressed = false
	intro._gui_input(tap)
	check(intro.repair_checkpoint == "erase" and intro.grid[4][4] == 1,"Wrong erase target does not damage the pattern")
	tap.position = intro.board_rect.position+Vector2(1.5,1.5)*intro.board_rect.size.x/9
	tap.pressed = true
	intro._gui_input(tap)
	check(intro.repair_checkpoint == "erase","Erase waits for release like the normal game")
	tap.pressed = false
	intro._gui_input(tap)
	check(intro.repair_checkpoint == "replace" and intro.grid[1][1] == 0,"Tapping marked square erases exactly that square")
	var replacement_cue: String = intro.text.get_parsed_text()
	var replacement_center: Vector2 = intro.tray_geometry().origin+Vector2(1.5,0.5)*intro.tray_geometry().unit
	check("arrow joker" not in replacement_cue,"Removed arrow-joker instruction")
	check(intro.cells.size() == 3 and not game.skip_button.disabled and game.skip_button in intro.pulsing,"Replacement joker is enabled with unsuitable three-square offer")
	await click_control(game.skip_button)
	check(intro.repair_checkpoint == "place_replacement" and intro.cells == Model.repair_offers()[2].cells,"Replacement joker provides the fitting domino")
	check((intro.tray_geometry().origin+Vector2(1,0.5)*intro.tray_geometry().unit).is_equal_approx(replacement_center),"Replacement domino appears at exactly the three-square piece center")
	check(intro.hint not in intro.pulsing,"Hint stays quiet until replacement is placed")
	check(intro.text.get_parsed_text() == replacement_cue and "Restore vertical symmetry" not in intro.text.get_parsed_text(),"Replacement placement keeps the previous cue instead of showing the removed text")
	check(intro.guide_cells() == [Vector2i(6,2),Vector2i(7,2)],"Replacement destination is marked")
	drag_piece(intro,Vector2i(0,4))
	intro.try_place()
	check(intro.repair_checkpoint == "place_replacement","Incorrect replacement placement cannot finish")
	drag_piece(intro,Model.repair_offers()[2].anchor)
	await click_control(intro.place)
	check(intro.practice_game == repair_session and not repair_session.over and repair_session.undo_left == 2 and repair_session.erase_left == 2 and repair_session.skip_left == 2,"All three helpers use the same real session and counters")
	check(intro.grid == repair_session.board,"The rendered board is a snapshot of the real practice board")
	check(JSON.stringify(Session.pack(game.game)) == original_session,"The complete practice sequence preserves every field of the underlying live game")
	check(intro.repair_checkpoint == "save" and Rules.symmetry_states(intro.grid)[0].complete and game.indicators[0].icon.complete[0],"Replacement domino restores and highlights vertical symmetry")
	check(intro.hint in intro.pulsing,"Hint highlights once correct placement starts the Bold-axis cue")
	check("Bold axis! Your board is symmetrical right now." in intro.text.text and "You can save a picture here if you want." in intro.text.text,"Recovered pattern explains the bold axis and saving a picture")

	check(intro.ink(1) == Palette.tile(1) and game.game == original_game and game.game.board == original_board,"Repair practice preserves colors and the saved game")
	intro._process(30)
	check(intro.lesson_id == "repair" and intro.repair_checkpoint == "save" and not intro.hint.disabled,"Bold-axis card waits indefinitely for the symmetry button")
	var full_design_frame: Rect2 = game.board_view.get_rect()
	var prior_theme: String = Palette.theme_id()
	await click_control(intro.hint)
	await process_frame
	check(Palette.theme_id() == prior_theme and game.game.board == Model.repair_board("save"),"Entering theme choice keeps the current palette and canonical plain-tile board")
	check(not game.board_view.growing and game.board_view.occupied_platform.visible,"The reveal uses settled artwork and normal pale tile backgrounds")
	check(not game.board_view.pattern.tier2_records().is_empty(),"Instant design includes its 2x2 artwork")
	check(game.introduction == intro and intro.lesson_id == "reveal" and not paused and intro.progress_label.text == "8 / 8","Instant reveal opens the new eighth card and waits for theme choice")
	check(game.palette_button.get_child(0).kind == "settings","Eighth card restores the Settings icon instead of Forward")
	check(game.saving or game.saved_fingerprint == game._design_fingerprint(),"Tutorial Hint press invokes the real gallery capture")
	if DisplayServer.get_name() != "headless":
		for frame in range(120):
			if not game.saving: break
			await process_frame
		var pictures: Array = game.gallery.entries()
		check(pictures.size() == 1,"Hint press actually writes one gallery entry")
		if not pictures.is_empty():
			check(pictures[0].board == Model.repair_board("save") and pictures[0].theme == prior_theme,"Save still writes the complete pattern in the current theme")
			var image := Image.load_from_file(game.gallery.image_path(pictures[0]))
			check(image != null and image.get_size() == Vector2i(900,900),"Gallery contains a readable full-resolution artwork PNG")
		check(game.saved_fingerprint == game._design_fingerprint(),"Normal save indicator marks the tutorial design as saved")
	check(not Model.progress(path).done,"Tutorial is not complete before theme selection")
	check(game.palette_button in intro.pulsing and game.palette_button.modulate == Color.WHITE,"Card eight restores full brightness and highlights Settings")
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		var screenshot: Image = root.get_texture().get_image()
		var sample := Vector2i(intro.board_rect.position+Vector2(3.25,3.4)*intro.board_rect.size.x/9)
		check(screenshot.get_pixelv(sample).is_equal_approx(Palette.tile(1)),"Card eight displays plain colored tiles until a theme is chosen")
	var demonstrated_game = game.game
	var demonstrated_history: Array = game.game.history.duplicate(true)
	await click_control(game.palette_button)
	check(game.palette_menu.visible and game.menu_page == "Settings","Settings opens normally during card eight")
	check(game.settings_options[0] in intro.pulsing,"The Themes button highlights after Settings opens")
	await click_control(game.settings_options[0])
	check(game.menu_page == "Themes" and game.palette_menu.visible,"Highlighted Themes button opens the actual theme list")
	var vines_option: Button
	for option: Button in game.theme_options:
		if option.get_meta("theme_id") == "vines": vines_option = option
	await click_control(vines_option)
	await process_frame
	check(game.introduction == null and Palette.theme_id() == "vines" and not paused and not game.palette_menu.visible,"Only choosing a theme reveals its artwork and resumes play")
	check(game.game == demonstrated_game and game.game.history == demonstrated_history and not game.confirmation.visible,"Theme choice preserves the completed game and needs no reset confirmation")
	check(game.board_view.get_rect().is_equal_approx(full_design_frame),"Handoff does not resize the nine-square playing field")

	check(completed_actions.any(func(event):return event.result.source == "scenario"),"Scripted design commands are marked separately from player actions")
	check(game.game.moves == Model.final_steps().size() and game.game.board == Model.repair_board("save") and not game.game.over,"Exact demonstration pattern becomes the playable game")
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
	check(intro.lesson_id == "rotate" and intro.progress_label.text == "1 / 8","Replay starts directly on the rotation card")
	var before_restart = game.game
	var checkpoint_before_restart: String = intro.lesson_id
	await click_control(intro.skip)
	check(game.confirmation.visible and game.introduction == intro and game.game == before_restart,"New Game opens confirmation without exiting or resetting the tutorial")
	game.confirmation.hide()
	game.confirmation.canceled.emit()
	check(game.introduction == intro and intro.lesson_id == checkpoint_before_restart and game.game == before_restart,"Go back preserves the current tutorial and live game")
	intro.skip.pressed.emit()
	game.confirmation.hide()
	game.confirmation.confirmed.emit()
	await process_frame
	check(not paused and game.introduction == null and game.game != before_restart and game.game.moves == 0,"Confirm exits the tutorial and starts a genuinely new game")
	for checkpoint: String in Intro.Lessons.REPAIR_ORDER:
		check(Model.save_checkpoint("repair",false,path,checkpoint) == OK,"Repair checkpoint is saved before relaunch")
		game._maybe_introduction(true)
		intro = game.introduction
		check(intro != null and intro.lesson_id == "repair" and intro.repair_checkpoint == checkpoint,"Startup resumes the exact named repair checkpoint")
		check(intro.practice_game.board == intro.grid and intro.practice_game.over == (checkpoint == "undo"),"Resumed checkpoint restores real domain state as well as its drawing")
		check(intro.grid == Model.repair_board(checkpoint) and intro.text.get_parsed_text() == Intro.Lessons.REPAIR[checkpoint].caption,"Resume reconstructs the matching board and caption")
		check(Model.progress(path).checkpoint == checkpoint,"Entering a checkpoint preserves its persisted identity")
		intro.finish(true)
		await process_frame
	for theme_id: String in game.MENU_THEMES:
		Model.save_checkpoint("reveal",false,path)
		game._start_introduction("reveal")
		intro = game.introduction
		for frame in range(120):
			if not game.saving: break
			await process_frame
		check(game.introduction == intro and not Model.progress(path).done,"Resumed card eight still requires a theme choice")
		var same_game = game.game
		var same_board: Array = game.game.board.duplicate(true)
		await click_control(game.palette_button)
		await click_control(game.settings_options[0])
		var choice: Button
		for option: Button in game.theme_options:
			if option.get_meta("theme_id") == theme_id: choice = option
		await click_control(choice)
		await process_frame
		check(game.introduction == null and not paused and Palette.theme_id() == theme_id,"Each available theme can finish card eight")
		check(game.game == same_game and game.game.board == same_board and game.board_view.pattern.board == same_board,"Theme selection renders the existing pattern without replacing the game")
		check(not game.palette_button.disabled and not game.replay_button.disabled and not game.flip_button.disabled and not game.blue_button.disabled,"Choosing a theme leaves normal controls active")
		check(Model.progress(path).done and game.palette_menu.process_mode == Node.PROCESS_MODE_INHERIT and game.palette_menu.z_index == 80,"Completion saves progress and restores menu ownership")

	await process_frame

	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	var folder := DirAccess.open(gallery_folder)
	if folder != null:
		for file: String in folder.get_files(): DirAccess.remove_absolute(gallery_folder.path_join(file))
		DirAccess.remove_absolute(gallery_folder)
	print("Interactive introduction: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
