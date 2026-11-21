extends RefCounted
const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")
const Lessons = preload("res://scripts/tutorial_lessons.gd")
const PROGRESS_VERSION := 2
const PATH := "user://introduction.cfg"

static func recipe(lesson_id: String) -> Dictionary:
	assert(lesson_id in Lessons.ORDER.slice(0,7))
	var fixture: String = Lessons.LESSONS[lesson_id].fixture
	if fixture == "prepared_l":
		var board := Rules.create_board(5)
		for cell in [Vector2i(0,1),Vector2i(0,2),Vector2i(1,2)]: board[cell.y][cell.x] = 2
		var anchor := Vector2i(3,1)
		var solution: Array = [Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
		var offered: Array = Rules.flip(solution)
		for turn in range(3): offered = Rules.rotate(offered)
		return {"board":board,"target":placed(board,solution,anchor,2),"missing":solution.map(func(cell):return cell+anchor),"anchor":anchor,"solution":solution,"offered":offered,"symmetry":0,"color":2}
	var symmetry: int = {"vertical":0,"horizontal":1,"rotational":5}.get(fixture,0)
	var motif: Array = [Vector2i(0,1),Vector2i(0,2),Vector2i(0,3),Vector2i(1,3)]
	if fixture == "horizontal": motif = [Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(1,1)]
	var board := Rules.create_board(5)
	var target: Array = board.duplicate(true)
	var missing: Array = []
	for cell: Vector2i in motif:
		board[cell.y][cell.x] = 2
		target[cell.y][cell.x] = 2
		var partner := Rules.transform(cell,symmetry,5)
		target[partner.y][partner.x] = 2
		missing.append(partner)
	var anchor := Vector2i(5,5)
	for cell: Vector2i in missing: anchor = anchor.min(cell)
	var solution: Array = missing.map(func(cell: Vector2i): return cell-anchor)
	return {"board":board,"target":target,"missing":missing,"anchor":anchor,"solution":solution,
		"offered":Rules.rotate(Rules.flip(solution)),"symmetry":symmetry,"color":2}

static func placed(board: Array, cells: Array, anchor: Vector2i, color: int) -> Array:
	var trial: Array = board.duplicate(true)
	for offset: Vector2i in cells:
		var cell := anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= board.size() or cell.y >= board.size() or trial[cell.y][cell.x] != 0: return []
		trial[cell.y][cell.x] = color
	return trial

static func accepts(puzzle: Dictionary, cells: Array, anchor: Vector2i, color: int) -> bool:
	var trial := placed(puzzle.board,cells,anchor,color)
	return trial == puzzle.target and Rules.symmetry_states(trial)[puzzle.symmetry].complete

# The practice fixture and final artwork use the same canonical construction.
static func repair_base() -> Array:
	return base_board()

static func repair_offers() -> Array:
	return [
		{"cells":[Vector2i.ZERO,Vector2i.DOWN,Vector2i(1,1)],"anchor":Vector2i(1,1),"color":2},
		{"cells":[Vector2i.ZERO],"anchor":Vector2i(6,2),"color":1},
		{"cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(6,2),"color":2}]

static func repair_board(checkpoint: String) -> Array:
	assert(checkpoint in Lessons.REPAIR_ORDER)
	var board := repair_base()
	var offers := repair_offers()
	board = placed(board,offers[0].cells,offers[0].anchor,offers[0].color)
	if checkpoint == "undo": board = placed(board,offers[1].cells,offers[1].anchor,offers[1].color)
	if checkpoint in Lessons.REPAIR_ORDER.slice(3): board[1][1] = 0
	if checkpoint == "save": board = placed(board,offers[2].cells,offers[2].anchor,offers[2].color)
	return board

static func base_steps() -> Array:
	return [
		{"name":"L3","cells":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)],"anchor":Vector2i(3,3)},
		{"name":"Domino","cells":[Vector2i(0,0),Vector2i(0,1)],"anchor":Vector2i(5,3)},
		{"name":"I3","cells":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)],"anchor":Vector2i(3,5)},
		{"name":"Domino","cells":[Vector2i.ZERO,Vector2i.DOWN],"anchor":Vector2i(4,1)},
		{"name":"Domino","cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(2,1)},
		{"name":"Domino","cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(5,1)},
		{"name":"Domino","cells":[Vector2i.ZERO,Vector2i.DOWN],"anchor":Vector2i(4,6)},
		{"name":"I3","cells":[Vector2i.ZERO,Vector2i.RIGHT,Vector2i(2,0)],"anchor":Vector2i(1,7)},
		{"name":"I3","cells":[Vector2i.ZERO,Vector2i.RIGHT,Vector2i(2,0)],"anchor":Vector2i(5,7)}]

static func base_board() -> Array:
	var board := Rules.create_board(9)
	for step: Dictionary in base_steps():
		board = placed(board,step.cells,step.anchor,1)
	return board

# Construct the successful route, including its second color.
static func final_steps() -> Array:
	var steps := base_steps().duplicate(true)
	steps.append({"name":"Domino","cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(1,2),"color":2})
	steps.append({"name":"Domino","cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(6,2),"color":2})
	return steps

static func final_board() -> Array:
	var board := Rules.create_board(9)
	for step: Dictionary in final_steps():
		board = placed(board,step.cells,step.anchor,step.get("color",1))
	return board

# Initial/resumed checkpoints are assembled through the real domain actions.
# During interaction the controller keeps this same game; it never swaps boards.
static func practice_session(lesson_id: String, checkpoint: String = "wrong_placement"):
	if lesson_id != "repair":
		assert(lesson_id in Lessons.ORDER.slice(0,7))
		var puzzle := recipe(lesson_id)
		var game = Game.new(5,0,Game.Difficulty.DIFFICULT,puzzle.board)
		var offered: bool = game.offer_piece(piece_name(puzzle.offered),1)
		assert(offered,"Exercise piece must physically fit")
		return game
	assert(checkpoint in Lessons.REPAIR_ORDER)
	var game = Game.new(9,0,Game.Difficulty.DIFFICULT,repair_base())
	var offers := repair_offers()
	var offered_l: bool = game.offer_piece("L3",2)
	assert(offered_l)
	var wrong_l: Dictionary = game.place(offers[0].cells,offers[0].anchor)
	assert(wrong_l.ok)
	var offered_dot: bool = game.offer_piece("Dot",1)
	assert(offered_dot)
	if checkpoint in Lessons.REPAIR_ORDER.slice(1):
		var dot: Dictionary = game.place(offers[1].cells,offers[1].anchor)
		assert(dot.ok and dot.lost)
	if checkpoint in Lessons.REPAIR_ORDER.slice(2):
		var undone: bool = game.undo()
		assert(undone)
	if checkpoint in Lessons.REPAIR_ORDER.slice(3):
		var erased: bool = game.erase(Vector2i(1,1))
		assert(erased)
		var offered_line: bool = game.offer_piece("I3",2)
		assert(offered_line)
	if checkpoint in Lessons.REPAIR_ORDER.slice(4):
		var replaced: bool = game.skip("Domino")
		assert(replaced)
	if checkpoint == "save":
		var restored: Dictionary = game.place(offers[2].cells,offers[2].anchor)
		assert(restored.ok and not restored.lost)
	return game

static func piece_name(cells: Array) -> String:
	for name: String in Rules.PIECES:
		if Rules.PIECES[name].cells.size() != cells.size(): continue
		for variant: Dictionary in Rules.orientations(Rules.PIECES[name].cells):
			if cells.all(func(cell):return cell in variant.cells): return name
	return ""

static func _progress(lesson_id: String = "rotate", done: bool = false, started: bool = false, checkpoint: String = "") -> Dictionary:
	return {"version":PROGRESS_VERSION,"lesson_id":lesson_id,"checkpoint":Lessons.checkpoint(checkpoint) if lesson_id == "repair" else "",
		"started":started,"done":done}

static func progress(path: String = PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK: return _progress()
	var version: Variant = config.get_value("intro","version",1)
	var done: Variant = config.get_value("intro","done",false)
	var started: Variant = config.get_value("intro","started",false)
	if not version is int or version not in [1,PROGRESS_VERSION] or not done is bool or not started is bool: return _progress()
	# Validate and discard the old partial-replay cursor. Reveal now rebuilds
	# the whole canonical design before offering theme selection.
	var seed_index: Variant = config.get_value("intro","seed_index",0)
	if not seed_index is int or seed_index < 0 or seed_index > final_steps().size(): return _progress()
	if version == 1:
		var step: Variant = config.get_value("intro","step",1)
		if not step is int or step < 1 or step > 11: return _progress()
		# Removed cards migrate once at the boundary, never into lesson flow.
		var old_lessons := ["rotate","rotate","flip","color","place","vertical","horizontal","rotational","repair","repair","reveal"]
		return _progress(old_lessons[step-1],done,started)
	var lesson_id: Variant = config.get_value("intro","lesson_id","")
	var checkpoint: Variant = config.get_value("intro","checkpoint","")
	if not lesson_id is String or not Lessons.LESSONS.has(lesson_id) or not checkpoint is String: return _progress()
	if lesson_id == "repair" and checkpoint not in Lessons.REPAIR_ORDER: return _progress()
	if lesson_id != "repair" and not checkpoint.is_empty(): return _progress()
	return _progress(lesson_id,done,started,checkpoint)

static func save_checkpoint(lesson_id: String, done: bool, path: String = PATH, checkpoint: String = "") -> Error:
	if not Lessons.LESSONS.has(lesson_id): return ERR_INVALID_PARAMETER
	if lesson_id == "repair":
		if checkpoint not in Lessons.REPAIR_ORDER: return ERR_INVALID_PARAMETER
	elif not checkpoint.is_empty(): return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.set_value("intro","version",PROGRESS_VERSION)
	config.set_value("intro","started",true)
	config.set_value("intro","lesson_id",lesson_id)
	config.set_value("intro","checkpoint",checkpoint)
	config.set_value("intro","done",done)
	var error := config.save(path+".tmp")
	if error != OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)
