extends SceneTree
const Model = preload("res://scripts/tutorial_model.gd")
const Intro = preload("res://scripts/introduction.gd")
const Rules = preload("res://scripts/rules.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func click_place(intro) -> void:
	var point: Vector2 = intro.place.get_global_rect().get_center()
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
	intro.update_controls()
	check(intro.place.is_pressed(), "Tutorial refresh preserves a held Place press")
	click.pressed = false
	click.button_mask = 0
	root.push_input(click,true)
	await process_frame

func drag_piece(intro, destination: Vector2i) -> void:
	var point: Vector2
	var grabbed: Vector2i = intro.cells[0]
	if intro.selected:
		point = intro.board_rect.position+(Vector2(intro.anchor+grabbed)+Vector2.ONE/2)*intro.board_rect.size.x/5
	else:
		var geometry: Dictionary = intro.tray_geometry()
		point = geometry.origin+(Vector2(grabbed)+Vector2.ONE/2)*geometry.unit
	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = true
	intro._gui_input(touch)
	var movement := InputEventScreenDrag.new()
	movement.position = intro.board_rect.position+(Vector2(destination+grabbed)+Vector2.ONE/2)*intro.board_rect.size.x/5
	intro._gui_input(movement)
	touch.position = movement.position
	touch.pressed = false
	intro._gui_input(touch)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://intro-test.cfg"
	DirAccess.remove_absolute(path)
	check(not Model.progress(path).done, "Fresh installation needs tutorial")
	for stage in [5,6,7,8,9,10]:
		var puzzle := Model.recipe(stage)
		check(Rules.symmetry_states(puzzle.target)[puzzle.symmetry].complete, "Target has promised symmetry")
		check(Model.accepts(puzzle,puzzle.solution,puzzle.anchor,2), "Authored placement solves puzzle")
		check(not Model.accepts(puzzle,puzzle.solution,puzzle.anchor,1), "Wrong color cannot solve puzzle")
		check(not Model.accepts(puzzle,puzzle.solution,Vector2i(-1,-1),2), "Out of bounds rejected")
		check(not Model.accepts(puzzle,puzzle.solution,Vector2i.ZERO,2), "Wrong location rejected")
		var reachable := false
		for variant: Dictionary in Rules.orientations(puzzle.offered):
			if Model.accepts(puzzle,variant.cells,puzzle.anchor,2): reachable = true
		check(reachable, "Available rotations and flips can solve puzzle")
	for stage in [9,10]:
		check(Model.recipe(stage).board == Model.recipe(8).board and Model.recipe(stage).offered == Model.recipe(8).offered, "Independent exercises share starting tiles and offered shape")
		check(Model.recipe(stage).target != Model.recipe(8).target, "Requested symmetry changes the solution")
	for stage in [8,9,10]:
		var exercise := Model.recipe(stage)
		var solutions := {}
		for variant: Dictionary in Rules.orientations(exercise.offered):
			for y in range(5):
				for x in range(5):
					for pigment in [1,2]:
						var trial: Array = exercise.board.duplicate(true)
						var fits := true
						for offset: Vector2i in variant.cells:
							var cell := Vector2i(x,y)+offset
							if cell.x >= 5 or cell.y >= 5 or trial[cell.y][cell.x] != 0:
								fits = false
								break
							trial[cell.y][cell.x] = pigment
						if fits and Rules.symmetry_states(trial)[exercise.symmetry].complete:
							solutions[JSON.stringify(trial)] = true
		check(solutions.size() == 1 and solutions.has(JSON.stringify(exercise.target)), "Requested symmetry has exactly one completed board")
	var demonstration := Model.recipe(5)
	var unflipped: Array = demonstration.solution.duplicate()
	var mirrored: Array = Rules.flip(unflipped)
	var same_by_rotation := false
	for turn in range(4):
		if unflipped.all(func(cell):return mirrored.has(cell)): same_by_rotation = true
		unflipped = Rules.rotate(unflipped)
	check(not same_by_rotation, "Flip demonstration uses a genuinely chiral piece")
	var game = Main.new()
	root.add_child(game)
	await process_frame
	var board: Array = game.game.board.duplicate(true)
	var original_game = game.game
	game.intro_progress_path = path
	game._start_introduction()
	var intro = game.introduction
	game.size = Vector2(390,844)
	game._layout()
	intro.layout()
	check(paused, "Tutorial pauses underlying game")
	check(not game.erase_button.visible and not game.undo_button.visible and not game.skip_button.visible, "Tutorial hides all jokers")
	check(intro.forward == game.palette_button and intro.skip == game.replay_button and intro.place == game.place_button, "Navigation reuses existing button positions")
	check(intro.place.text == "" and intro.place.get_child(0).visible, "Place retains its normal hand icon")
	intro._process(7.1)
	check(intro.text.text == Intro.RESTORE_TEXT and intro.restore_prompt and intro.cells == [Vector2i.ZERO] and intro.guide_cells() == [Vector2i(1,1)], "Restore prompt immediately offers its matching tile and fixed target")
	drag_piece(intro,Vector2i(1,1))
	await click_place(intro)
	check(intro.succeeding and intro.grid == intro.puzzle.target, "Introductory missing tile can actually be restored")
	intro._process(2.4)
	check(intro.stage == 2, "Restoration hands off to rotation lesson")
	intro._process(3.1)
	drag_piece(intro,Vector2i(1,1))
	check(intro.selected, "Piece can enter board before learning transforms")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = intro.board_rect.position+(Vector2(intro.anchor+intro.cells[0])+Vector2.ONE/2)*intro.board_rect.size.x/5
	tap.pressed = true
	intro._gui_input(tap)
	tap.pressed = false
	intro._gui_input(tap)
	check(intro.stage == 3 and intro.selected, "Tap rotates the live board piece without sending it back to tray")
	intro._process(2.1)
	intro.flip.pressed.emit()
	check(intro.stage == 4 and intro.selected, "Flip keeps the exercise piece on the board")
	intro._process(2.1)
	intro.recolor.pressed.emit()
	intro._process(1.4)
	check(intro.stage == 5, "Player color change unlocks first puzzle")
	for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(540,825),Vector2(720,1100)]:
		game.size = dimensions
		game._layout()
		intro.layout()
		check(intro.board_rect.is_equal_approx(Rect2(game.board_view.position+game.board_view.field.position,game.board_view.field.size)), "Five-by-five occupies the existing grid opening")
		check(intro.text.position.y >= intro.progress_label.get_rect().end.y and intro.text.get_rect().end.y <= intro.tray_rect.position.y, "Comments sit below step count and above offered piece")
		check(intro.text.get_theme_font_size("font_size") == 2*clampi(roundi(dimensions.x*0.028),12,18), "Tutorial font remains doubled at every phone size")
		var bounds := Rect2(Vector2.ZERO,dimensions)
		check(bounds.encloses(intro.board_rect) and bounds.encloses(intro.tray_rect), "Phone layout fits")
		for control in [intro.skip,intro.flip,intro.place,intro.recolor]: check(bounds.encloses(control.get_rect()), "Tutorial controls fit phone")
	intro.selected = true
	intro.anchor = Vector2i.ZERO
	var instruction: String = intro.text.text
	intro.try_place()
	intro.try_place()
	check(not intro.hint_offered and intro.text.text == instruction and intro.grid == intro.puzzle.board, "Wrong Place presses have no visible reaction")
	intro.idle = 18.1
	intro._process(0.1)
	check(intro.hint_offered, "Inactivity can still offer a hint")
	intro.hint.pressed.emit()
	check(intro.hint_visible, "Hint reveals missing footprint")
	intro.enter(5)
	intro.demo = false
	intro.color = 1
	intro.cells = intro.puzzle.offered.duplicate()
	var guide: Array = intro.guide_cells()
	var original_cells: Array = intro.cells.duplicate()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = intro.board_rect.position+(Vector2(guide[0])+Vector2.ONE/2)*intro.board_rect.size.x/5
	click.pressed = true
	intro._gui_input(click)
	click.pressed = false
	intro._gui_input(click)
	check(not intro.selected and intro.cells == original_cells and intro.guide_cells() == guide, "Clicking fixed target does not select or transform anything")
	drag_piece(intro,Vector2i(1,0))
	check(intro.selected and intro.anchor == Vector2i(1,0) and intro.color == 1, "Unprepared piece can move onto arbitrary board position")
	drag_piece(intro,Vector2i(0,2))
	check(intro.anchor == Vector2i(0,2), "Piece can be picked up and moved again on board")
	intro.transform_piece("rotate")
	intro.flip.pressed.emit()
	intro.recolor.pressed.emit()
	check(intro.selected and intro.color == 2 and intro.grid == intro.puzzle.board, "On-board transforms preserve piece and do not commit grid")
	check(intro.guide_cells() == guide, "Target guide never moves with the exercise tile")
	for stage in [5,6,7,8,9,10]:
		intro.enter(stage)
		intro.demo = false
		if stage == 8: check(not intro.hint_visible and intro.puzzle.symmetry == 0, "Independent puzzle requests a specific symmetry")
		intro.cells = intro.puzzle.solution.duplicate()
		intro.anchor = intro.puzzle.anchor
		intro.color = 2
		drag_piece(intro,intro.puzzle.anchor)
		intro.place.pressed.emit()
		check(intro.succeeding and intro.grid == intro.puzzle.target, "Correct player placement completes exercise")
		check(game.indicators[0].icon.complete[intro.puzzle.symmetry], "Existing symmetry button responds to placement")
		intro._process(2.4)
		check(intro.stage == stage+1, "Success advances exercise")
	check(intro.showcase != null and intro.showcase.board.size() == 9, "Final step uses actual theme artwork")
	check(Model.progress(path).step == 11 and not Model.progress(path).done, "Progress resumes unfinished introduction")
	var restored_board: Rect2 = intro.normal_board_rect
	intro.next_step()
	await process_frame
	check(game.board_view.get_rect().is_equal_approx(restored_board), "Ending tutorial restores normal playing field geometry")
	check(not paused and Model.progress(path).done, "Begin marks complete and releases game")
	check(game.game == original_game and game.game.board == board, "Tutorial never overwrites game state")
	game._start_introduction()
	var replay = game.introduction
	check(replay.stage == 1, "Replay starts at beginning")
	replay.forward.pressed.emit()
	check(replay.stage == 2, "Forward advances even without completing the current exercise")
	replay.skip.pressed.emit()
	await process_frame
	check(not paused and Model.progress(path).done, "Skip works during demonstration")
	check(game.erase_button.visible and game.undo_button.visible and game.skip_button.visible and game.palette_button.text == "" and game.replay_button.text == "" and game.palette_button.get_child(0).kind == "settings" and game.replay_button.get_child(0).kind == "replay" and game.replay_button.tooltip_text == "Start new game", "Ending tutorial restores normal controls")
	game.intro_progress_path = path
	DirAccess.remove_absolute(path)
	game._maybe_introduction(false)
	check(game.introduction != null and game.introduction.stage == 1, "First launch opens introduction")
	game.introduction.finish(true)
	await process_frame
	game._maybe_introduction(false)
	check(game.introduction == null, "Completed or skipped introduction stays dismissed")
	Model.save_progress(6,false,path)
	game._maybe_introduction(true)
	check(game.introduction != null and game.introduction.stage == 6, "Unfinished introduction resumes after closing")
	game.introduction.finish(true)
	await process_frame
	DirAccess.remove_absolute(path)
	game._maybe_introduction(true)
	check(game.introduction == null and Model.progress(path).done, "Existing players continue normally")
	game.settings_options[4].pressed.emit()
	check(game.introduction != null and game.introduction.stage == 1, "Tutorial is replayable from Settings")
	game.introduction.finish(true)
	await process_frame
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Interactive introduction: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
