extends SceneTree
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/tutorial_model.gd")
const Game = preload("res://scripts/game.gd")
const Session = preload("res://scripts/game_session.gd")
var checks := 0
var failures := 0
class Ticker extends Node:
	var ticks := 0
	func _process(_delta: float) -> void: ticks += 1

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(540,825)
	var game = Main.new()
	root.add_child(game)
	game.intro_progress_path = "/tmp/tutorial-lifecycle-%d.cfg" % Time.get_ticks_usec()
	var ticker := Ticker.new()
	root.add_child(ticker)
	await process_frame
	var snapshot := JSON.stringify(Session.pack(game.game))
	var original_board_mode: int = game.board_view.process_mode
	var original_actions: int = game.player_actions.completed.get_connections().size()
	game.erase_mode = true
	game._start_introduction()
	var intro = game.introduction
	var ticks: int = ticker.ticks
	await process_frame
	check(not paused and ticker.ticks > ticks,"Unrelated app nodes keep processing during practice")
	check(game.board_view.process_mode == Node.PROCESS_MODE_DISABLED,"Only underlying artwork is suspended")
	check(game.player_actions.completed.get_connections().size() == original_actions+1,"Tutorial owns one action subscription")
	intro.update_controls()
	var updates: int = intro.guidance_updates
	for frame in range(10): intro._process(0.01)
	check(intro.guidance_updates == updates,"Idle pulse frames do not recalculate guidance")
	var stranger = Game.new(9,11)
	game.player_actions.execute("rotate",stranger,{"cells":[Vector2i.ZERO,Vector2i.RIGHT]})
	check(intro.lesson_id == "rotate","Commands from another session cannot advance a lesson")
	game.player_actions.execute("rotate",intro.practice_game,{"cells":intro.cells,"source":"scenario"})
	check(intro.lesson_id == "rotate","Scenario setup cannot advance a player lesson")
	game.player_actions.execute("flip",intro.practice_game,{"cells":intro.cells})
	check(intro.lesson_id == "rotate","A completion event for a disallowed action cannot advance the lesson")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	check(game.erase_mode,"Tutorial keyboard handling does not change the live erase tool")
	intro.transform_piece("rotate")
	check(intro.lesson_id == "rotate","Beginning an animation does not advance a lesson")
	intro._process(intro.ANIMATION_SECONDS+0.01)
	check(intro.lesson_id == "flip","Completed action event advances exactly one lesson")
	intro.ui_scope.allow_theme_menu(202)
	intro.queue_free()
	await process_frame
	await process_frame
	check(game.introduction == null and not paused,"Unexpected removal clears the host reference without changing pause state")
	check(game.board_view.process_mode == original_board_mode,"Unexpected removal restores artwork processing")
	check(game.palette_menu.process_mode == Node.PROCESS_MODE_INHERIT and game.palette_menu.z_index == 80,"Unexpected removal restores menu ownership")
	check(game.button_icon(game.palette_button).kind == "settings" and game.button_icon(game.replay_button).kind == "replay" and not game.palette_button.disabled,"Unexpected removal restores real controls")
	check(game.player_actions.completed.get_connections().size() == original_actions,"Unexpected removal disconnects action callbacks")
	check(not Model.progress(game.intro_progress_path).done,"Unexpected removal retains resumable unfinished progress")
	check(JSON.stringify(Session.pack(game.game)) == snapshot,"Teardown leaves the live session unchanged")
	# A queued old tutorial must not overwrite a newer tutorial's overrides.
	game._start_introduction()
	intro = game.introduction
	intro.finish(true)
	intro.finish(true)
	game._start_introduction()
	var replacement = game.introduction
	await process_frame
	check(game.introduction == replacement and replacement != intro and game.board_view.process_mode == Node.PROCESS_MODE_DISABLED,"Old cleanup cannot release a newer tutorial's scope")
	check(game.button_icon(game.palette_button).kind == "skip","New tutorial retains its own navigation override")
	replacement.finish(true)
	await process_frame
	check(game.introduction == null and game.player_actions.completed.get_connections().size() == original_actions,"Repeated normal cleanup is idempotent")
	paused = true
	game._start_introduction()
	intro = game.introduction
	intro.finish(true)
	check(paused,"Tutorial does not unpause an application paused by someone else")
	paused = false
	await process_frame
	game._start_introduction()
	var path: String = game.intro_progress_path
	game.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(game) and not paused,"Host deletion during practice exits safely")
	ticker.queue_free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".tmp")
	print("Tutorial lifecycle: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
