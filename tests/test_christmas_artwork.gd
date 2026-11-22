extends SceneTree

const Assets = preload("res://scripts/pattern/asset_library.gd")
const Rules = preload("res://scripts/rules.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Presenter = preload("res://scripts/pattern/sprite_presenter.gd")
const THEME := "christmas_joy"
const SNOW := "res://assets/themes/christmas_joy/sprites/tier1/christmas_joy_tier1_snow_color"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.session_enabled = false
	root.add_child(game)
	for n: int in [9, 11]:
		game._select_theme("vines")
		game.requested_size = n
		game._reset()
		game.theme_games.erase(THEME)
		game._select_theme(THEME)
		var view = game.board_view
		var board := Rules.empty_board(n)
		for position: int in range(1, 6):
			board[1][position] = 1
			board[position][7] = 2
		# A 2×2 block previously inherited a purple Vines flower.
		for y: int in [4, 5]:
			for x: int in [2, 3]:
				board[y][x] = 1
		view.animate_growth(Rules.empty_board(n), board)
		view.advance_growth(100.0)
		check(view.tier1_layer.diagnostics.is_empty(), str(view.tier1_layer.diagnostics))
		check(view.junction_layer.diagnostics.is_empty(), str(view.junction_layer.diagnostics))
		check(view.tier1_layer.z_index > view.occupied_platform.z_index, "Snow paths draw above the platform")
		check(view.tier1_layer.plans.size() == 24, "Straight lines and the block use both halves of every snow connection")
		for id: String in view.tier1_layer.plans:
			var color := id.get_slice("/", 1)
			var expected := SNOW + color + ("_02.png" if color == "1" else "_01.png")
			var sprite = view.tier1_layer.presenter.renderer.nodes.get(Presenter.ROOT + "/" + id + "/base")
			check(view.tier1_layer.plans[id].base.image_path == expected and sprite != null and sprite.visible and sprite.texture == Assets.texture(expected), "Connected cells show the supplied snow texture")
		check(view.junction_layer.specs.size() == 4, "Only the endpoints of the two straight lines have end motifs")
		check(not view.construction_state.records.keys().any(func(id: String): return id.begins_with("vines/center/")), "Snow junctions have no inherited Vines leaves")
		check(view.pattern.flowers.is_empty() and view.pattern.links.is_empty() and (view.vines_formations == null or not view.vines_formations.visible), "Christmas does not schedule Vines flowers or links")
		var profile := Themes.profile(THEME)
		check(view.board_frame.artwork_texture() == Assets.texture(profile.frame.texture) and view.board_frame.is_present(), "Christmas displays the ice frame")
		var background := Assets.texture(profile.environment.background)
		check(background != null and background.get_size() == Vector2(1080, 1650), "The snowy background loads")
	game.sounds.deactivate()
	game.queue_free()
	await process_frame
	print("Christmas artwork: %d failures" % failures)
	quit(1 if failures else 0)
