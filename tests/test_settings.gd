extends SceneTree

const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func click(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for level: Game.Difficulty in [Game.Difficulty.EASY, Game.Difficulty.MODERATE, Game.Difficulty.DIFFICULT]:
		var game = Game.new(9, 1234, level)
		var sizes: Array = []
		for group: Array in game.eligible_groups():
			for name: String in group:
				sizes.append(Rules.PIECES[name].cells.size())
		check(sizes.has(4) == (level == Game.Difficulty.DIFFICULT), "four-cell eligibility follows difficulty")
		check(sizes.has(1) and sizes.has(2) and sizes.has(3), "smaller pieces remain eligible")
		for i in range(150):
			check(Rules.PIECES[game._draw_piece()].cells.size() < 4 or level == Game.Difficulty.DIFFICULT, "draws respect difficulty")
		game.queue[0] = "Dot"
		var detached: Dictionary = game.place([Vector2i.ZERO], Vector2i.ZERO)
		check(detached.ok == (level == Game.Difficulty.EASY), "only Easy accepts detached placements")
		check(not game.physical_placement([Vector2i.ZERO], Vector2i(-1, 0)).ok, "all levels reject out-of-bounds placements")
		check(not game.physical_placement([Vector2i.ZERO], Vector2i(4, 4)).ok, "all levels reject overlaps")
		if level == Game.Difficulty.EASY:
			check(game.undo() and game.board[0][0] == 0, "Undo retracts detached placements")
			check(game.skip() and game.piece().cells.size() < 4, "Easy Skip respects piece size")
			check(game.erase(Vector2i(4, 4)) and not game.requires_contact(), "Easy Erase preserves mode")
	var easy = Game.new(9, 1, Game.Difficulty.EASY)
	easy.board = Rules.empty_board(9)
	for y in range(9):
		for x in range(9):
			easy.board[y][x] = Rules.BLUE
	easy.board[1][2] = 0
	easy.queue[0] = "Dot"
	easy.current_color = Rules.CORAL
	easy._refresh_over()
	var fatal: Dictionary = easy.place([Vector2i.ZERO], Vector2i(2, 1))
	check(fatal.ok and easy.lost and easy.over, "Easy still ends on a physically valid symmetry-breaking placement")

	Palette.select_theme("clockwork")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(5): await process_frame
	check(scene.difficulty == Game.Difficulty.DIFFICULT, "Difficult retains existing default")
	click(scene.palette_button)
	await process_frame
	check(scene.palette_menu.visible and scene.menu_page == "Settings", "Settings opens floating menu")
	check(scene.settings_options.map(func(button): return button.text) == ["Themes", "Difficulty", "Gallery", "Sound Settings"], "Settings has exactly the requested entries")
	click(scene.settings_options[0])
	await process_frame
	check(scene.menu_page == "Themes" and scene.theme_options.size() == 4, "Themes lists all names and core tiles")
	var previous = scene.game
	click(scene.theme_options[3])
	await process_frame
	check(scene.confirmation.visible and scene.game == previous and Palette.clockwork, "theme waits for confirmation")
	scene.confirmation.canceled.emit()
	scene.confirmation.hide()
	check(scene.game == previous and Palette.clockwork and not scene.pending_change.is_valid(), "cancel preserves current game and theme and clears pending action")
	scene._request_theme("coral_reef")
	scene.confirmation.confirmed.emit()
	scene.confirmation.hide()
	await process_frame
	check(Palette.coral_reef and scene.game != previous and scene.game.moves == 0, "confirm switches theme and starts a new game")
	check(scene.game.undo_left == 3 and scene.game.skip_left == 3 and scene.game.erase_left == 3, "theme reset restores helper budgets")
	scene._show_menu("Difficulty")
	await process_frame
	previous = scene.game
	click(scene.difficulty_options[0])
	check(scene.confirmation.visible and scene.game == previous, "difficulty waits for confirmation")
	scene.confirmation.confirmed.emit()
	scene.confirmation.hide()
	check(scene.game.difficulty == Game.Difficulty.EASY and scene.game != previous, "difficulty reset applies Easy before drawing")
	check(scene.game.piece().cells.size() < 4, "first Easy offer has fewer than four cells")
	var before: Array = scene.game.board.duplicate(true)
	scene._show_menu("Sound Settings")
	await process_frame
	click(scene.background_button)
	check(not scene.sounds.background_enabled and scene.sounds.effects_enabled, "background toggle leaves effects on")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(scene.sounds.background_bus)), "background bus is muted immediately")
	click(scene.effects_button)
	check(not scene.sounds.effects_enabled, "effects toggle mutes effects")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(scene.sounds.effects_bus)), "effects bus is muted immediately")
	check(scene.sounds.whisper.bus == scene.sounds.background_bus and scene.sounds.workshop.ticking.bus == scene.sounds.background_bus and scene.sounds.reef.ambience.bus == scene.sounds.background_bus, "every theme routes background audio independently")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(scene.sounds.reef.bus_name)) == scene.sounds.effects_bus, "reef effects keep their limiter and route to effects bus")
	check(scene.game.board == before, "sound toggles preserve game")
	scene._select_theme("clockwork")
	check(not scene.sounds.background_enabled and not scene.sounds.effects_enabled, "mute settings survive new games and themes")
	scene._toggle_background()
	scene._toggle_effects()
	check(scene.sounds.background_enabled and scene.sounds.effects_enabled, "both categories can be re-enabled")
	scene.palette_menu.hide()
	for theme: String in Palette.THEMES:
		scene._select_theme(theme)
		for n in [9, 11]:
			scene.requested_size = n
			scene._reset()
			for dimensions: Vector2 in [Vector2(240, 320), Vector2(390, 844), Vector2(720, 1100), Vector2(844, 390)]:
				scene.size = dimensions
				scene._layout()
				var bounds := Rect2(Vector2.ZERO, dimensions).grow(0.1)
				check(bounds.encloses(scene.board_view.get_rect()), "board fits every theme/size/orientation")
				check(scene.erase_button.get_rect().end.y <= scene.board_view.position.y, "jokers stay above the board")
				check(scene.undo_button.position.y > scene.indicators[0].panel.position.y and scene.undo_button.position.x == scene.indicators[0].panel.position.x, "jokers sit below the symmetry controls")
				check(scene.find_children("ButtonFrame", "NinePatchRect", true, false).is_empty(), "only the playing field uses a frame")
				for button: Button in [scene.blue_button, scene.coral_button, scene.flip_button, scene.place_button]:
					check(button.size.is_equal_approx(scene.place_button.size) and is_equal_approx(button.size.x, button.size.y), "bottom buttons are equal squares")
					check(bounds.encloses(button.get_rect()), "bottom buttons stay on screen")
				check(scene.board_view.get_rect().end.y <= scene.blue_button.position.y + 0.1, "field stays above the large controls")
				if dimensions.y >= dimensions.x * 1.5:
					check(scene.board_view.size.x >= dimensions.x * 0.96, "portrait board nearly touches both sides")
					check(scene.blue_button.position.x <= dimensions.x * 0.02 and scene.place_button.get_rect().end.x >= dimensions.x * 0.98, "large buttons span almost the full portrait width")
				scene.cells = Rules.rotate(Rules.PIECES.I.cells)
				scene._refresh()
				check(is_equal_approx(scene.piece_view.geometry().unit, scene.board_view.pitch), "vertical active piece retains playing-cell scale")
				check(scene.piece_view.display_cells().all(func(cell): return cell.y < 2), "tall pieces fit a two-row preview")
				check(is_equal_approx(scene.piece_view.size.y, maxf(52, 2 * scene.board_view.pitch + 8)), "header reserves only two tile rows plus control minimum")
				for page: String in ["Settings", "Themes", "Vine colors", "Difficulty", "Sound Settings"]:
					scene._show_menu(page)
					check(bounds.encloses(scene.palette_menu.get_rect()), "every floating menu fits on screen")
					for button: Button in scene.menu_buttons:
						if button.visible:
							check(scene.palette_menu.get_global_rect().grow(0.1).encloses(button.get_global_rect()), "visible menu entries fit inside panel: %s %s %s" % [theme, page, button.text])
					scene.palette_menu.hide()
	scene.queue_free()
	await process_frame
	print("Settings/difficulty: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
