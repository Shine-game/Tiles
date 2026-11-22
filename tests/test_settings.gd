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
	click_at(button.get_global_rect().get_center())

func click_at(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
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
	scene._show_menu("Settings")
	click(scene.settings_options[1])
	var original = scene.game
	click(scene.gameplay_options[0])
	click(scene.size_picker)
	check(scene.gameplay_options[0].text == "Difficulty: Easy" and scene.size_picker.text == "Size: 11 × 11", "Gameplay shows both pending edits")
	check(scene.game == original and scene.difficulty == Game.Difficulty.DIFFICULT and scene.requested_size == 9 and not scene.confirmation.visible, "Editing Gameplay leaves the active game and presets alone")
	var axes: bool = scene.board_view.show_axes
	click(scene.axes_button)
	check(scene.board_view.show_axes != axes and not scene.confirmation.visible, "Axes apply directly")
	click(scene.back_button)
	check(scene.menu_page == "Settings" and not scene.confirmation.visible and scene.game != original and scene.game.difficulty == Game.Difficulty.EASY and scene.game.board.size() == 11, "Leaving Gameplay applies both edits without a prompt before playing")
	click(scene.settings_options[1])
	var shape: Dictionary = Rules.PIECES[scene.game.queue[scene.game.index]]
	var move := Rules.first_physical_move(scene.game.board, shape, scene.game.requires_contact())
	check(not move.is_empty() and scene.game.place(move.cells, move.anchor).ok and scene._game_started(), "A placed tile starts the game")
	var axes_game = scene.game
	var active_board: Array = axes_game.board.duplicate(true)
	axes = scene.board_view.show_axes
	click(scene.axes_button)
	check(scene.game == axes_game and scene.game.board == active_board and scene.board_view.show_axes != axes and not scene.confirmation.visible, "Axes apply immediately and preserve an active game")
	click(scene.gameplay_options[0])
	click(scene.size_picker)
	check(not scene.confirmation.visible and scene.game == axes_game and scene.game.board == active_board, "Multiple changes in Gameplay leave the active game running")
	scene._show_menu("Size")
	click(scene.size_options[0])
	check(scene.menu_page == "Gameplay" and not scene.confirmation.visible, "Returning from a Gameplay subpage keeps editing")
	click(scene.back_button)
	check(scene.confirmation.visible and scene.confirmation.dialog_text == "Start new game" and scene.menu_page == "Gameplay", "Leaving Gameplay asks once before navigating")
	await process_frame
	click(scene.confirmation.get_cancel_button())
	check(not scene.confirmation.visible and scene.menu_page == "Gameplay" and scene.game == axes_game and scene.size_picker.text == "Size: 9 × 9", "Go back keeps the current game and pending edits")
	click_at(Vector2(2, scene.size.y - 2))
	check(scene.confirmation.visible, "Tapping outside Gameplay also asks before leaving")
	await process_frame
	click(scene.confirmation.get_ok_button())
	check(not scene.confirmation.visible and not scene.palette_menu.visible and scene.game != axes_game and not scene._game_started(), "Confirm applies the edits and finishes the requested navigation")
	check(scene.game.difficulty == Game.Difficulty.MODERATE and scene.game.board.size() == 9, "The new game uses both edited presets")

	check(scene.game.skip(), "Start playing with a joker")
	var previous = scene.game
	scene._show_menu("Gameplay")
	click(scene.size_picker)
	click(scene.size_picker)
	for i in range(3): click(scene.gameplay_options[0])
	click(scene.menu_close)
	check(not scene.confirmation.visible and not scene.palette_menu.visible and scene.game == previous, "Returning both controls to their original values closes without a restart")
	scene._show_menu("Gameplay")
	click(scene.size_picker)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	check(scene.confirmation.visible and scene.game == previous, "Escape asks before leaving with edits")
	await process_frame
	click(scene.confirmation.get_ok_button())
	check(not scene.palette_menu.visible and scene.game.board.size() == 11, "Accepting the Escape exit applies the pending size")

	check(scene.game.skip(), "Start playing again")
	scene._show_menu("Themes")
	previous = scene.game
	var old_theme: String = Palette.theme_id()
	click(scene.theme_options[1])
	check(scene.confirmation.visible and scene.game == previous and Palette.theme_id() == old_theme, "Theme changes still ask before restarting")
	await process_frame
	click(scene.confirmation.get_ok_button())
	check(scene.game != previous and not scene._game_started(), "Confirming a theme starts a fresh board")
	scene._close_menu()
	click(scene.palette_button)
	click(scene.settings_options[2])
	check(scene.gallery_panel.visible and not scene.palette_menu.visible,"Gallery opens from Settings")
	check(scene.gallery_panel.back.position.x < scene.gallery_panel.close.position.x and scene.gallery_panel.back.position.y == scene.gallery_panel.close.position.y,"Gallery has Back upper left and Close upper right")
	click(scene.gallery_panel.back)
	check(scene.menu_page == "Settings" and scene.palette_menu.visible and not scene.gallery_panel.visible,"Gallery Back returns to Settings")
	click(scene.settings_options[2])
	click(scene.gallery_panel.close)
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
				check(scene.menu_frame.get_global_rect().is_equal_approx(scene.palette_menu.get_global_rect()), "Theme frame follows the entire settings panel")
				if dimensions == Vector2(720,1100) and page == "Settings":
					var clearance: float = 30 / root.get_stretch_transform().x.length()
					var first: Rect2 = scene.settings_options[0].get_global_rect()
					var second: Rect2 = scene.settings_options[1].get_global_rect()
					var opening: Rect2 = scene.menu_frame.get_global_rect().grow(-scene.menu_frame.thin_rim)
					check(is_equal_approx(first.position.x - opening.position.x, clearance) and is_equal_approx(second.position.y - first.end.y, clearance), "Settings controls have 30 screen pixels of clearance from the frame and each other")
				check(scene.back_button.visible and scene.menu_close.visible and scene.back_button.position.x < scene.menu_close.position.x and scene.back_button.position.y == scene.menu_close.position.y,"Every window has top-corner navigation")
				for control: Control in scene.menu_buttons:
					if control.visible:
						check(scene.palette_menu.get_global_rect().grow(0.2).encloses(control.get_global_rect()),"Visible menu controls fit: %s %s %s control %s panel %s" % [theme,page,dimensions,control.get_global_rect(),scene.palette_menu.get_global_rect()])
				scene._close_menu()
	scene._select_theme("coral_reef")
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
	# Exercise the actual in-game panel buttons, including GUI event routing.
	scene.replay_button.pressed.emit()
	await process_frame
	var prior_game = scene.game
	check(is_equal_approx(scene.confirmation.size.x, scene.size.x * 0.7), "Confirmation uses the menu width")
	check(scene.confirmation.frame.is_present() and scene.confirmation.frame.theme_id == Palette.theme_id(), "New-game confirmation uses the active theme frame")
	var surface: StyleBoxFlat = scene.confirmation.get_theme_stylebox("panel")
	check(surface.bg_color == scene.palette_menu.get_theme_stylebox("panel").bg_color and surface.shadow_size == 0 and surface.border_width_top == 1, "Confirmation uses the flat menu surface")
	check(scene.confirmation.get_ok_button().text == "OK" and scene.confirmation.get_cancel_button().text == "Go back", "Confirmation presents both choices")
	click(scene.confirmation.get_cancel_button())
	check(not scene.confirmation.visible and not scene.confirmation_blocker.visible and scene.game == prior_game, "Go back closes confirmation and preserves the game")
	scene.replay_button.pressed.emit()
	await process_frame
	click(scene.confirmation.get_ok_button())
	check(not scene.confirmation.visible and not scene.confirmation_blocker.visible and scene.game != prior_game, "OK starts the new game and removes the modal shield")

	# Longer theme messages must not grow the modal past the action buttons.
	scene._show_menu("Themes")
	var offer = scene.store_dialog
	var purchase_notice := "Google Play checkout is available in an enabled Android test build."
	for dimensions: Vector2 in [Vector2(320, 568), Vector2(568, 320)]:
		scene.size = dimensions
		scene._layout()
		var screen := Rect2(Vector2.ZERO, dimensions)
		scene._store_notice(purchase_notice)
		for frame in range(2): await process_frame
		check(screen.encloses(offer.get_rect()) and offer.get_rect().encloses(offer.get_ok_button().get_global_rect()), "First checkout notice keeps OK on screen")
		check(not offer.get_cancel_button().visible, "A checkout notice has one action")
		click(offer.get_ok_button())
		check(not offer.visible and not scene.confirmation_blocker.visible, "OK dismisses the checkout notice")

	scene._store_notice(purchase_notice)
	scene.size = Vector2(320, 240)
	scene._layout()
	for frame in range(2): await process_frame
	check(offer.prompt_scroll.get_v_scroll_bar().visible and offer.get_rect().end.y <= scene.size.y, "Long checkout notices scroll after a resize")
	click(offer.get_ok_button())
	scene._close_menu()

	scene.game = easy
	scene._refresh()
	check(scene.game_over_message.visible and scene.game_over_message.text == "No symmetries left.", "Symmetry loss displays the requested message")
	check(scene.game_over_message.get_rect() == scene.piece_view.get_rect(), "Loss message is centered between upper button columns")
	check(scene.game_over_message.get_theme_font("font") == scene.menu_close.get_theme_font("font") and scene.game_over_message.get_theme_font_size("font_size") == scene.menu_close.get_theme_font_size("font_size"), "Loss message uses the menu font and size")
	check(easy.undo(), "Loss can be undone")
	scene._refresh()
	check(not scene.game_over_message.visible, "Restoring symmetry clears the loss message")

	scene.queue_free()
	await process_frame
	print("Settings/difficulty: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
