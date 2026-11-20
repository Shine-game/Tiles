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

	root.size = Vector2i(720,1100)
	Palette.select_theme("clockwork")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(4): await process_frame
	click(scene.palette_button)
	check(scene.palette_menu.visible and scene.menu_page == "Settings", "Settings opens")
	check(scene.settings_options.map(func(button):return button.text) == ["Themes","Gameplay","Gallery","Audio","Tutorial"],"Settings has the requested sections")
	click(scene.settings_options[0])
	check(scene.menu_page == "Themes" and scene.theme_options.all(func(button):return button.visible),"Themes lists available themes")
	click(scene.theme_options[0])
	check(Palette.theme_id() == "vines" and not scene.confirmation.visible and scene.menu_page == "Themes", "Before playing, theme applies immediately")
	scene._show_menu("Gameplay", false)
	for expected: int in [Game.Difficulty.EASY, Game.Difficulty.MODERATE, Game.Difficulty.DIFFICULT]:
		click(scene.gameplay_options[0])
		check(scene.game.difficulty == expected and scene.difficulty == expected and scene.menu_page == "Gameplay" and not scene.confirmation.visible, "Difficulty cycles and applies directly")
	for expected: int in [11,9]:
		click(scene.size_picker)
		check(scene.game.board.size() == expected and scene.requested_size == expected and not scene.confirmation.visible, "Size applies directly")
	var axes: bool = scene.board_view.show_axes
	click(scene.axes_button)
	check(scene.board_view.show_axes != axes and not scene.confirmation.visible, "Axes apply directly before play")
	var shape: Dictionary = Rules.PIECES[scene.game.queue[scene.game.index]]
	var move := Rules.first_physical_move(scene.game.board, shape, scene.game.requires_contact())
	check(not move.is_empty() and scene.game.place(move.cells, move.anchor).ok and scene._game_started(), "A placed tile starts the game")
	for control: Button in [scene.gameplay_options[0], scene.size_picker, scene.axes_button, scene.theme_options[1]]:
		check(scene.game.skip(), "Start playing with a joker")
		var previous = scene.game
		var board: Array = scene.game.board.duplicate(true)
		var old_theme: String = Palette.theme_id()
		var old_axes: bool = scene.board_view.show_axes
		click(control)
		check(scene.confirmation.visible and scene.confirmation.dialog_text == "Start new game" and scene.confirmation.ok_button_text == "Confirm" and scene.confirmation.cancel_button_text == "Go back", "Started game requires shared confirmation")
		check(scene.game == previous and scene.game.board == board and Palette.theme_id() == old_theme and scene.board_view.show_axes == old_axes, "Changes wait for confirmation")
		scene.confirmation.hide()
		scene.confirmation.canceled.emit()
		check(scene.game == previous and scene.game.board == board, "Go back preserves game")
		click(control)
		scene.confirmation.hide()
		scene.confirmation.confirmed.emit()
		check(scene.game != previous and not scene._game_started(), "Confirm applies change and starts a fresh board")
	scene._close_menu()
	click(scene.palette_button)
	click(scene.settings_options[2])
	check(scene.gallery_panel.visible and not scene.palette_menu.visible,"Gallery opens from Settings")
	check(scene.gallery_back.position.x < scene.gallery_close.position.x and scene.gallery_back.position.y == scene.gallery_close.position.y,"Gallery has Back upper left and Close upper right")
	click(scene.gallery_back)
	check(scene.menu_page == "Settings" and scene.palette_menu.visible and not scene.gallery_panel.visible,"Gallery Back returns to Settings")
	click(scene.settings_options[2])
	click(scene.gallery_close)
	check(not scene.gallery_panel.visible and not scene.palette_menu.visible,"Gallery Close returns to the game")
	click(scene.palette_button)
	click(scene.settings_options[3])
	check(scene.menu_page == "Audio" and scene.ambience_volume_row.visible and scene.effects_volume_row.visible,"Audio shows both volume controls")
	check(not scene.background_button.visible and not scene.effects_button.visible,"Audio has volume controls without old toggle rows")
	var background: float = scene.sounds.background_volume
	var effects: float = scene.sounds.effects_volume
	scene.ambience_volume_slider.value = 37
	scene.effects_volume_slider.value = 62
	check(is_equal_approx(scene.sounds.background_volume,0.37) and is_equal_approx(scene.sounds.effects_volume,0.62),"Independent volume sliders work")
	scene.sounds.set_background_volume(background)
	scene.sounds.set_effects_volume(effects)
	click(scene.back_button)
	click(scene.back_button)
	check(not scene.palette_menu.visible,"Settings Back returns to the game")
	for theme: String in Palette.THEMES:
		scene._select_theme(theme)
		for dimensions in [Vector2(320,568),Vector2(390,844),Vector2(720,1100),Vector2(844,390)]:
			scene.size = dimensions
			scene._layout()
			var bounds := Rect2(Vector2.ZERO,dimensions).grow(0.2)
			for page in ["Settings","Themes","Gameplay","Audio"]:
				scene._show_menu(page)
				for frame in range(2): await process_frame
				check(bounds.encloses(scene.palette_menu.get_rect()),"Every menu fits every viewport")
				check(scene.back_button.visible and scene.menu_close.visible and scene.back_button.position.x < scene.menu_close.position.x and scene.back_button.position.y == scene.menu_close.position.y,"Every window has top-corner navigation")
				for control: Control in scene.menu_buttons:
					if control.visible:
						check(scene.palette_menu.get_global_rect().grow(0.2).encloses(control.get_global_rect()),"Visible menu controls fit: %s %s %s" % [theme,page,dimensions])
				scene._close_menu()
	var active_game = scene.game
	var active_size: int = scene.game.board.size()
	var active_level: int = scene.game.difficulty
	var active_theme: String = Palette.theme_id()
	scene.requested_size = 9 if active_size == 11 else 11
	scene.difficulty = Game.Difficulty.DIFFICULT if active_level == Game.Difficulty.EASY else Game.Difficulty.EASY
	var preset_size: int = scene.requested_size
	var preset_level: int = scene.difficulty
	scene.replay_button.pressed.emit()
	check(scene.confirmation.visible and scene.game == active_game,"Restart waits for confirmation")
	scene.confirmation.hide()
	scene.confirmation.confirmed.emit()
	check(scene.game != active_game and scene.game.moves == 0 and scene.game.history.is_empty(),"Replay restarts the current game")
	check(scene.game.board.size() == active_size and scene.game.difficulty == active_level and Palette.theme_id() == active_theme,"Replay keeps the active game theme, size and difficulty")
	check(scene.requested_size == preset_size and scene.difficulty == preset_level,"Replay preserves pending New Game presets")
	check(scene.replay_button.position.x == scene.palette_button.position.x and scene.replay_button.position.y > scene.palette_button.position.y and scene.replay_button.position.y < scene.flip_button.position.y,"Replay sits between Settings and Flip in the upper-right column")
	scene.queue_free()
	await process_frame
	print("Settings/difficulty: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
