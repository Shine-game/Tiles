extends SceneTree
const Actions = preload("res://scripts/player_actions.gd")
const Game = preload("res://scripts/game.gd")
const Model = preload("res://scripts/tutorial_model.gd")
const Session = preload("res://scripts/game_session.gd")
var checks := 0
var failures := 0
var events: Array = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actions = Actions.new()
	actions.completed.connect(func(action,result): events.append({"action":action,"result":result}))
	var game = Game.new(9,42,Game.Difficulty.EASY)
	var before := JSON.stringify(Session.pack(game))
	var cells := [Vector2i.ZERO,Vector2i.DOWN,Vector2i.ONE]
	var rotated: Dictionary = actions.execute("rotate",game,{"cells":cells})
	check(rotated.ok and rotated.cells == [Vector2i(1,0),Vector2i.ZERO,Vector2i.DOWN],"Shared rotate returns the expected clockwise L")
	check(cells == [Vector2i.ZERO,Vector2i.DOWN,Vector2i.ONE] and JSON.stringify(Session.pack(game)) == before,"Transforms do not mutate the source cells or unrelated game")
	var flipped: Dictionary = actions.execute("flip",game,{"cells":cells})
	check(flipped.ok and flipped.cells == [Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN],"Shared flip mirrors the L")
	check(actions.execute("color",game,{"color":1}).color == 2 and actions.execute("color",game,{"color":2,"choice":1}).color == 1,"Shared color command supports toggle and explicit color")
	check(events.size() == 4 and events.all(func(event):return event.result.source == "player"),"Each successful player command emits one result")
	check(events.all(func(event):return event.result.session_id == game.get_instance_id()),"Completion events identify the exact active session")
	var policy := func(_action,_request): return false
	for action: String in Actions.COMMANDS:
		check(not actions.execute(action,game,{"cells":cells,"color":1,"anchor":Vector2i.ZERO},policy).ok,"Tutorial policy can block every command before execution")
	check(events.size() == 4 and JSON.stringify(Session.pack(game)) == before,"Denied commands never execute, emit success, or mutate the game")
	for request in [{"color":3},{"color":"1"},{"color":1,"choice":0}]:
		check(not actions.execute("color",game,request).ok,"Invalid color is rejected")
	check(not actions.execute("rotate",game,{"cells":[]}).ok and not actions.execute("place",game,{"cells":["invalid"],"anchor":Vector2i.ZERO}).ok,"Malformed pieces cannot reach game mutations")
	check(not actions.execute("unknown",game).ok,"Unknown commands cannot execute")
	check(not actions.execute("skip",game,{"replacement":12}).ok,"Invalid replacement type is rejected")
	check(events.size() == 4,"Rejected input emits no completion events")
	check(actions.offer(game,"I3",2) and game.queue[game.index] == "I3" and game.current_color == 2,"Scenario offers are deterministic through the public game API")
	check(game.moves == 0 and game.history.is_empty() and game.skip_left == 3 and events.size() == 4,"Scenario setup consumes no move or joker and emits no player event")
	before = JSON.stringify(Session.pack(game))
	check(not actions.offer(game,"missing") and not actions.offer(game,"I") and not actions.offer(game,"Dot",3),"Unknown, difficulty-ineligible, and invalid-color offers are rejected")
	check(JSON.stringify(Session.pack(game)) == before,"Rejected offers preserve all game state")
	var skipped: Dictionary = actions.execute("skip",game,{"replacement":"Domino"})
	check(skipped.ok and game.queue[game.index] == "Domino" and game.skip_left == 2 and game.current_color == 2,"Scripted replacement uses the real Skip action and counter")
	before = JSON.stringify(Session.pack(game))
	check(not actions.execute("skip",game,{"replacement":"Domino"}).ok and not actions.execute("skip",game,{"replacement":"missing"}).ok,"Invalid scripted replacements do not spend jokers")
	check(JSON.stringify(Session.pack(game)) == before,"Rejected replacements preserve queue, counters, and random state")
	# Prove the whole repair exercise can be performed by the shared real-game
	# commands used by the isolated tutorial practice session.
	game = Game.new(9,42,Game.Difficulty.EASY)
	game.board = Model.repair_board(2)
	game._refresh_over()
	check(actions.offer(game,"Dot",1),"Repair fixture can offer its forced Dot")
	var broken: Dictionary = actions.execute("place",game,{"cells":[Vector2i.ZERO],"anchor":Vector2i(6,2)})
	check(broken.ok and broken.lost and game.over and game.board == Model.repair_board(3),"A physically valid wrong placement still ends the game")
	check(actions.execute("undo",game).ok and not game.over and game.board == Model.repair_board(4) and game.undo_left == 2,"Shared Undo restores the pattern after game over")
	check(actions.execute("erase",game,{"cell":Vector2i(1,1)}).ok and game.board == Model.repair_board(5) and game.erase_left == 2,"Shared Erase removes exactly the marked square")
	check(actions.offer(game,"I3",2) and actions.execute("skip",game,{"replacement":"Domino"}).ok,"Repair replacement is deterministic while using real Skip")
	check(actions.execute("place",game,{"cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(6,2)}).ok and game.board == Model.repair_board(7) and not game.over,"Shared commands restore the canonical final pattern")
	check(Session.valid_game(Session.pack(game)),"The repaired real game remains saveable")
	var expected = Game.new(9,123,Game.Difficulty.DIFFICULT)
	var actual = Game.new(9,123,Game.Difficulty.DIFFICULT)
	expected.skip()
	check(actions.execute("skip",actual).ok and JSON.stringify(Session.pack(actual)) == JSON.stringify(Session.pack(expected)),"Ordinary random Skip preserves existing seeded game behavior")
	print("Player actions: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
