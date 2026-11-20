extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const PATH := "user://introduction.cfg"

static func principle() -> Array:
	var board := Rules.empty_board(5)
	for cell in [Vector2i(1,1),Vector2i(3,1),Vector2i(1,3),Vector2i(3,3)]: board[cell.y][cell.x] = 2
	for cell in [Vector2i(2,1),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(2,3)]: board[cell.y][cell.x] = 1
	return board

static func recipe(stage: int) -> Dictionary:
	if stage == 2:
		var target := principle()
		var board: Array = target.duplicate(true)
		board[1][1] = 0
		return {"board":board,"target":target,"missing":[Vector2i(1,1)],"anchor":Vector2i(1,1),"solution":[Vector2i.ZERO],"offered":[Vector2i.ZERO],"symmetry":0,"color":2}
	var symmetry: int = {6:0,7:1,8:5}.get(stage,0)
	var motif: Array = [Vector2i(0,1),Vector2i(0,2),Vector2i(0,3),Vector2i(1,3)]
	if stage == 7: motif = [Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(1,1)]
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

# The player makes two mistakes, then repairs the same board with all three jokers.
static func repair_base() -> Array:
	return [[0,0,1,0,0],[0,0,1,0,0],[0,1,1,1,0],[0,0,1,0,0],[0,0,1,0,0]]

static func repair_offers() -> Array:
	return [
		{"cells":[Vector2i.ZERO,Vector2i.DOWN,Vector2i(1,1)],"anchor":Vector2i.ZERO},
		{"cells":[Vector2i.ZERO],"anchor":Vector2i(3,3)},
		{"cells":[Vector2i.ZERO,Vector2i.RIGHT],"anchor":Vector2i(3,1)}]

static func repair_board(phase: int) -> Array:
	var board := repair_base()
	var offers := repair_offers()
	if phase >= 1: board = placed(board,offers[0].cells,offers[0].anchor,1)
	if phase == 2: board = placed(board,offers[1].cells,offers[1].anchor,1)
	if phase >= 4: board[0][0] = 0
	if phase >= 6: board = placed(board,offers[2].cells,offers[2].anchor,1)
	return board

static func seed_steps() -> Array:
	return [
		{"name":"L3","cells":[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)],"anchor":Vector2i(3,3)},
		{"name":"Domino","cells":[Vector2i(0,0),Vector2i(0,1)],"anchor":Vector2i(5,3)},
		{"name":"I3","cells":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)],"anchor":Vector2i(3,5)}]

static func seed_board(count: int) -> Array:
	var board := Rules.create_board(9)
	for i in range(mini(count,seed_steps().size())):
		var step: Dictionary = seed_steps()[i]
		board = placed(board,step.cells,step.anchor,1)
	return board

static func progress(path: String = PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK: return {"done":false,"step":1,"started":false,"seed_index":0}
	return {"started":bool(config.get_value("intro","started",false)),"done":bool(config.get_value("intro","done",false)),
		"step":clampi(int(config.get_value("intro","step",1)),1,11),"seed_index":clampi(int(config.get_value("intro","seed_index",0)),0,3)}

static func save_progress(step: int, done: bool, path: String = PATH, seed_index: int = 0) -> Error:
	var config := ConfigFile.new()
	config.set_value("intro","started",true)
	config.set_value("intro","step",step)
	config.set_value("intro","done",done)
	config.set_value("intro","seed_index",seed_index)
	return config.save(path)
