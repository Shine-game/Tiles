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
	intro._process(7.1)
	check(intro.text.text == "Can you restore it?" and not intro.advance.disabled, "Principle demonstration ends with missing tile")
	intro.next_step()
	intro._process(3.1)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = intro.tray_rect.get_center()
	tap.pressed = true
	intro._gui_input(tap)
	tap.pressed = false
	intro._gui_input(tap)
	check(intro.stage == 3, "Player tap completes rotation lesson")
	intro._process(2.1)
	intro.flip.pressed.emit()
	check(intro.stage == 4, "Player flip completes reflection lesson")
	intro._process(2.1)
	intro.recolor.pressed.emit()
	intro._process(1.4)
	check(intro.stage == 5, "Player color change unlocks first puzzle")
	for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(540,825),Vector2(720,1100)]:
		game.size = dimensions
		game._layout()
		intro.layout()
		check(intro.board_rect.is_equal_approx(Rect2(game.board_view.position+game.board_view.field.position,game.board_view.field.size)), "Five-by-five occupies the existing grid opening")
		var bounds := Rect2(Vector2.ZERO,dimensions)
		check(bounds.encloses(intro.board_rect) and bounds.encloses(intro.tray_rect), "Phone layout fits")
		for control in [intro.skip,intro.flip,intro.place,intro.recolor]: check(bounds.encloses(control.get_rect()), "Tutorial controls fit phone")
	intro.selected = true
	intro.anchor = Vector2i.ZERO
	intro.try_place()
	intro.try_place()
	check(intro.hint_offered and intro.grid == intro.puzzle.board, "Failed attempts offer hint without changing board")
	intro.hint.pressed.emit()
	check(intro.hint_visible, "Hint reveals missing footprint")
	for stage in [5,6,7,8,9,10]:
		intro.enter(stage)
		intro.demo = false
		if stage == 8: check(not intro.hint_visible and intro.puzzle.symmetry == 0, "Independent puzzle requests a specific symmetry")
		intro.cells = intro.puzzle.solution.duplicate()
		intro.anchor = intro.puzzle.anchor
		intro.color = 2
		var touch := InputEventScreenTouch.new()
		touch.position = intro.board_rect.position+(Vector2(intro.puzzle.anchor)+Vector2.ONE*0.2)*intro.board_rect.size.x/5
		touch.pressed = true
		intro._gui_input(touch)
		intro.place.pressed.emit()
		check(intro.succeeding and intro.grid == intro.puzzle.target, "Correct player placement completes exercise")
		check(game.indicators[0].icon.complete[intro.puzzle.symmetry], "Existing symmetry button responds to placement")
		intro._process(2.4)
		check(intro.stage == stage+1, "Success advances exercise")
	check(intro.showcase != null and intro.showcase.board.size() == 9, "Final step uses actual theme artwork")
	check(Model.progress(path).step == 11 and not Model.progress(path).done, "Progress resumes unfinished introduction")
	intro.next_step()
	await process_frame
	check(not paused and Model.progress(path).done, "Begin marks complete and releases game")
	check(game.game == original_game and game.game.board == board, "Tutorial never overwrites game state")
	game._start_introduction()
	var replay = game.introduction
	check(replay.stage == 1, "Replay starts at beginning")
	replay.skip.pressed.emit()
	await process_frame
	check(not paused and Model.progress(path).done, "Skip works during demonstration")
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
