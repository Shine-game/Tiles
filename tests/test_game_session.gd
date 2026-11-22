extends SceneTree
const Session = preload("res://scripts/game_session.gd")
const Rules = preload("res://scripts/rules.gd")
const Game = preload("res://scripts/game.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Session.autosave_enabled(PackedStringArray()), "Normal startup enables session autosave")
	for flag in ["--script", "-s"]:
		check(not Session.autosave_enabled(PackedStringArray([flag, "test.gd"])), "Script flag %s isolates the session" % flag)
	root.size = Vector2i(720,1100)
	var path := "/tmp/tiles-session-test-%d.json" % Time.get_ticks_usec()
	Palette.select_theme("vines")
	var scene = load("res://main.tscn").instantiate()
	scene.session_enabled = true
	scene.session_store.path = path
	root.add_child(scene)
	check(FileAccess.file_exists(path),"A fresh game is saved automatically")
	for anchor in [Vector2i(5,4),Vector2i(3,4)]:
		scene.game.queue[scene.game.index] = "Dot"
		scene.cells = [Vector2i.ZERO]
		scene.has_hover = true
		scene.selected = anchor
		scene._place()
		scene.board_view.advance_growth(scene.board_view.construction_state.schedule.duration+1)
	check(scene.game.moves == 2 and scene.game.history.size()==2,"Fixture has two moves and undo history")
	scene.game.queue[scene.game.index] = "L3"
	scene.cells = Rules.rotate(Rules.PIECES.L3.cells)
	scene.game.current_color = Rules.CORAL
	scene.has_hover = true
	scene.tray_moved = true
	scene.selected = Vector2i(1,2)
	scene.requested_size = 11
	scene.difficulty = Game.Difficulty.EASY
	scene.board_view.show_axes = true
	scene._refresh()
	scene.game.skip_left = 2
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var saved: Dictionary = scene.session_store.load_state()
	check(not saved.is_empty() and saved.game.skip == 2,"Backgrounding flushes the latest state")
	var board: Array = scene.game.board.duplicate(true)
	var offered: Array = scene.cells.duplicate()
	var art: Dictionary = scene.board_view.session_art_state()
	var next_offer: String = scene.game._draw_piece()
	scene.queue_free()
	await process_frame
	Palette.select_theme("clockwork")
	var restored = load("res://main.tscn").instantiate()
	restored.session_enabled = true
	restored.session_store.path = path
	root.add_child(restored)
	check(Palette.theme_id()=="vines" and restored.game.board==board,"Reopening restores theme and exact board")
	check(restored.cells==offered and restored.game.current_color==Rules.CORAL,"Offered orientation and chosen color survive reopening")
	check(restored.has_hover and restored.tray_moved and restored.piece_on_board and restored.selected==Vector2i(1,2),"Floating piece state survives reopening")
	check(restored.game.skip_left==2 and restored.game.undo_left==3 and restored.game.erase_left==3,"Joker counts survive reopening")
	check(restored.game.moves==2 and restored.game.history.size()==2,"Moves and Undo history survive reopening")
	check(restored.game.difficulty==Game.Difficulty.DIFFICULT and restored.requested_size==11 and restored.difficulty==Game.Difficulty.EASY,"Active difficulty and next-game presets stay independent")
	check(restored.board_view.show_axes,"Axes state survives reopening")
	check(restored.board_view.session_art_state()==art,"Leaf core history and growth directions survive reopening")
	check(restored.game._draw_piece()==next_offer,"Random generator continues from the saved state")
	restored._undo()
	check(restored.game.board[4][3]==0 and restored.game.moves==1 and restored.game.undo_left==2,"Undo still works after reopening")
	restored.queue_free()
	await process_frame
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var store = Session.new()
	store.path = path
	check(not store.load_state().is_empty(),"A corrupt primary save falls back to the previous valid backup")
	var invalid := saved.duplicate(true)
	invalid.erase("offered")
	check(not Session.valid(invalid),"Incomplete saves are rejected safely")
	invalid = saved.duplicate(true)
	invalid.game.board[0][0] = 99
	check(not Session.valid(invalid),"Invalid board cells are rejected")
	invalid = saved.duplicate(true)
	invalid.game.index = 99999
	check(not Session.valid(invalid),"Invalid queue index is rejected")
	var ended := saved.duplicate(true)
	ended.game.lost = true
	ended.offered = []
	ended.hover = false
	check(Session.valid(ended) and Session.unpack(ended.game).over,"An ended game is restored as ended rather than silently restarted")
	for suffix in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(path+suffix)
	print("Game session: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
