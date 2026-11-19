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
	check(scene.settings_options.map(func(button):return button.text) == ["New Game","Gameplay","Gallery","Audio"],"Settings has the requested sections")
	var previous = scene.game
	var original_board: Array = scene.game.board.duplicate(true)
	click(scene.settings_options[0])
	check(scene.menu_page == "New Game" and scene.theme_options.all(func(button):return button.visible),"New Game lists every theme")
	click(scene.theme_options[Palette.THEMES.find("vines")])
	check(scene.menu_page == "Game Presets" and scene.game == previous and Palette.clockwork,"Choosing a theme only opens preset review")
	check("Vines" in scene.preset_summary.text and "Hard" in scene.preset_summary.text and "9 × 9" in scene.preset_summary.text,"Review shows theme and current presets")
	click(scene.change_presets_button)
	check(scene.menu_page == "Gameplay","Change opens Gameplay")
	click(scene.gameplay_options[0])
	check(scene.menu_page == "Difficulty" and scene.difficulty_options.map(func(button):return button.text.replace("✓ ","")) == ["Easy","Moderate","Hard"],"Difficulty offers Easy, Moderate and Hard")
	click(scene.difficulty_options[0])
	check(scene.menu_page == "Gameplay" and scene.difficulty == Game.Difficulty.EASY and scene.game == previous and scene.game.difficulty == Game.Difficulty.DIFFICULT,"Difficulty preset changes without resetting the current game")
	click(scene.size_picker)
	check(scene.menu_page == "Size","Size opens its own page")
	click(scene.size_options[1])
	check(scene.requested_size == 11 and scene.game.board.size() == 9 and scene.menu_page == "Gameplay","Size preset waits for Start")
	var axes: bool = scene.board_view.show_axes
	click(scene.axes_button)
	check(scene.board_view.show_axes != axes and scene.board_view.axes_overlay.visible,"Axes toggle applies immediately")
	click(scene.back_button)
	check(scene.menu_page == "Game Presets" and "Easy" in scene.preset_summary.text and "11 × 11" in scene.preset_summary.text,"Back from Change returns to updated preset review")
	click(scene.back_button)
	check(scene.menu_page == "New Game","Review Back returns to the theme list")
	click(scene.theme_options[Palette.THEMES.find("vines")])
	click(scene.menu_close)
	check(not scene.palette_menu.visible and scene.game == previous and scene.game.board == original_board,"Close cancels New Game without replacing the board")
	click(scene.palette_button)
	click(scene.settings_options[0])
	click(scene.theme_options[Palette.THEMES.find("vines")])
	click(scene.new_button)
	check(not scene.palette_menu.visible and scene.game != previous and Palette.theme_id() == "vines","Start applies the selected theme")
	check(scene.game.board.size() == 11 and scene.game.difficulty == Game.Difficulty.EASY,"Start applies size and difficulty presets")
	check(scene.board_view.show_axes != axes,"Axes setting survives Start")
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
			for page in ["Settings","New Game","Game Presets","Gameplay","Difficulty","Size","Audio"]:
				scene._show_menu(page)
				for frame in range(2): await process_frame
				check(bounds.encloses(scene.palette_menu.get_rect()),"Every menu fits every viewport")
				check(scene.back_button.visible and scene.menu_close.visible and scene.back_button.position.x < scene.menu_close.position.x and scene.back_button.position.y == scene.menu_close.position.y,"Every window has top-corner navigation")
				for control: Control in scene.menu_buttons:
					if control.visible:
						check(scene.palette_menu.get_global_rect().grow(0.2).encloses(control.get_global_rect()),"Visible menu controls fit: %s %s %s" % [theme,page,dimensions])
				scene._close_menu()
	scene.queue_free()
	await process_frame
	print("Settings/difficulty: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
