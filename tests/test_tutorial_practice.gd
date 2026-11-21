extends SceneTree
const Model = preload("res://scripts/tutorial_model.gd")
const Actions = preload("res://scripts/player_actions.gd")
const Session = preload("res://scripts/game_session.gd")
const Game = preload("res://scripts/game.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actions = Actions.new()
	var live = Game.new(11,77,Game.Difficulty.MODERATE)
	var live_before := JSON.stringify(Session.pack(live))
	var board: Array = Model.recipe("place").board
	var isolated = Game.new(5,0,Game.Difficulty.DIFFICULT,board)
	isolated.board[0][0] = 2
	check(board[0][0] == 0,"Scenario constructor copies input rows")
	for lesson_id: String in Model.Lessons.ORDER.slice(0,7):
		var practice = Model.practice_session(lesson_id)
		var puzzle := Model.recipe(lesson_id)
		check(practice != live and practice.board == puzzle.board and practice.board.size() == 5,"Each early lesson starts an isolated real five-square game")
		check(practice.undo_left == 3 and practice.skip_left == 3 and practice.erase_left == 3,"New exercises start with real untouched joker counters")
		practice.current_color = actions.execute("color",practice,{"color":1,"choice":puzzle.color}).color
		var placed: Dictionary = actions.execute("place",practice,{"cells":puzzle.solution,"anchor":puzzle.anchor})
		check(placed.ok and not placed.lost and practice.board == puzzle.target,"Each lesson solution is accepted by actual contact and symmetry rules")
		check(practice.history.size() == 1 and practice.history[0].cells == puzzle.solution and practice.moves == 1,"Exercise placement records real history")
	for checkpoint: String in Model.Lessons.REPAIR_ORDER:
		var practice = Model.practice_session("repair",checkpoint)
		check(practice.board == Model.repair_board(checkpoint),"Checkpoint reconstruction reaches its canonical board through domain actions")
		check(practice.over == (checkpoint == "undo") and practice.lost == (checkpoint == "undo"),"Only the broken checkpoint has real game-over state")
		check(practice.undo_left == (2 if checkpoint in ["erase","replace","place_replacement","save"] else 3),"Checkpoint carries actual Undo consumption")
		check(practice.erase_left == (2 if checkpoint in ["replace","place_replacement","save"] else 3),"Checkpoint carries actual Erase consumption")
		check(practice.skip_left == (2 if checkpoint in ["place_replacement","save"] else 3),"Checkpoint carries actual Skip consumption")
		if checkpoint == "undo": check(practice.history.back().anchor == Vector2i(6,2),"The bad Dot is the actual last history entry")
		if checkpoint == "erase": check(practice.current_color == 1 and practice.restored_cells == [Vector2i.ZERO],"Undo restores the original Dot and its color")
		if checkpoint == "replace": check(practice.queue[practice.index] == "I3", "Erase checkpoint offers the unsuitable I3")
		if checkpoint == "place_replacement": check(practice.queue[practice.index] == "Domino", "Replacement checkpoint offers the actual Skip result")
	var practice = Model.practice_session("repair","wrong_placement")
	var same_session = practice
	check(actions.execute("place",practice,{"cells":[Vector2i.ZERO],"anchor":Vector2i(6,2)}).ok and practice.over,"Wrong Dot ends the practice game")
	check(actions.execute("undo",practice).ok and practice == same_session and not practice.over,"Undo reopens the same practice game")
	check(actions.execute("erase",practice,{"cell":Vector2i(1,1)}).ok and practice == same_session,"Erase edits that same game")
	check(actions.offer(practice,"I3",2),"The unsuitable offer uses the normal offer API")
	check(actions.execute("skip",practice,{"replacement":"Domino"}).ok and practice == same_session,"Real deterministic Skip retains session identity")
	check(actions.execute("place",practice,{"cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(6,2)}).ok and practice.board == Model.repair_board("save"),"Real placement restores the expected pattern")
	check(practice.undo_left == 2 and practice.erase_left == 2 and practice.skip_left == 2,"Each joker is consumed exactly once")
	check(JSON.stringify(Session.pack(live)) == live_before,"Practice leaves live board, history, queue, counters, difficulty, and RNG unchanged")
	var another = Model.practice_session("repair","wrong_placement")
	check(another.board == Model.repair_board("wrong_placement") and another.undo_left == 3,"A new practice session shares no mutable state with the previous one")
	print("Tutorial practice: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
