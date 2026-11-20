extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const PATH := "user://introduction.cfg"

static func recipe(stage: int) -> Dictionary:
	var symmetry := 0
	var motif: Array = [Vector2i(0,1),Vector2i(0,2),Vector2i(0,3),Vector2i(1,3)]
	if stage == 6:
		symmetry = 1
		motif = [Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(1,1)]
	elif stage == 7: symmetry = 5
	elif stage in [8,9,10]:
		symmetry = {8:0,9:1,10:5}[stage]
		motif = [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]
	var board := Rules.empty_board(5)
	var target := Rules.empty_board(5)
	var missing: Array = []
	for cell: Vector2i in motif:
		board[cell.y][cell.x] = 2
		target[cell.y][cell.x] = 2
		var partner := Rules.transform(cell, symmetry, 5)
		target[partner.y][partner.x] = 2
		missing.append(partner)
	board[2][2] = 1
	target[2][2] = 1
	var anchor := Vector2i(5,5)
	for cell: Vector2i in missing: anchor = anchor.min(cell)
	var solution: Array = missing.map(func(cell: Vector2i): return cell-anchor)
	return {"board":board,"target":target,"missing":missing,"anchor":anchor,"solution":solution,
		"offered":Rules.PIECES.L3.cells.duplicate() if stage >= 8 else Rules.rotate(Rules.flip(solution)),"symmetry":symmetry,"color":2}

static func accepts(puzzle: Dictionary, cells: Array, anchor: Vector2i, color: int) -> bool:
	var trial: Array = puzzle.board.duplicate(true)
	for offset: Vector2i in cells:
		var cell := anchor + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= 5 or cell.y >= 5 or trial[cell.y][cell.x] != 0: return false
		trial[cell.y][cell.x] = color
	return trial == puzzle.target and Rules.symmetry_states(trial)[puzzle.symmetry].complete

static func progress(path: String = PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK: return {"done":false,"step":1,"started":false}
	return {"started":bool(config.get_value("intro","started",false)),"done":bool(config.get_value("intro","done",false)),"step":clampi(int(config.get_value("intro","step",1)),1,11)}

static func save_progress(step: int, done: bool, path: String = PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("intro","started",true)
	config.set_value("intro","step",step)
	config.set_value("intro","done",done)
	return config.save(path)
