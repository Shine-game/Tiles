extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Game = preload("res://scripts/game.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	for n in [9, 11]:
		for state: Dictionary in Rules.symmetry_states(Rules.create_board(n)):
			check(state.possible and state.complete, "center seed supports every symmetry")
	check(Rules.PIECES.size() == 11, "seven tetrominoes plus four smaller shapes")
	var sizes := {"Dot": 1, "Domino": 2, "I3": 3, "L3": 3}
	for piece: Dictionary in Rules.PIECES.values():
		check(piece.cells.size() >= 1 and piece.cells.size() <= 4, "pieces contain one to four cells")
		check(Rules.flip(Rules.flip(piece.cells)) == piece.cells, "two mirror flips restore shape")
		var cells: Array = piece.cells
		for i in range(4):
			cells = Rules.rotate(cells)
		for cell: Vector2i in piece.cells:
			check(cells.has(cell), "four turns restore original shape")
	for name: String in sizes:
		check(Rules.PIECES[name].cells.size() == sizes[name], "small shape has expected size")
	var board: Array = Rules.empty_board(9)
	board[2][1] = Rules.BLUE
	check(Rules.symmetry_states(board)[0].possible, "asymmetric patterns remain possible")
	check(not Rules.symmetry_states(board)[0].complete, "asymmetric is not complete")
	board[2][7] = Rules.CORAL
	check(not Rules.symmetry_states(board)[0].possible, "opposite colors conflict")
	board[2][7] = Rules.BLUE
	check(Rules.symmetry_states(board)[0].complete, "matching reflected colors complete")
	board = Rules.empty_board(9)
	board[1][2] = Rules.BLUE
	board[7][6] = Rules.CORAL
	check(not Rules.symmetry_states(board)[4].possible, "90-degree orbit detects nonadjacent colors")
	check(not Rules.symmetry_states(board)[6].possible, "270-degree orbit detects nonadjacent colors")
	board = Rules.create_board()
	var square: Array = Rules.PIECES.O.cells
	check(not Rules.placement(board, square, Rules.BLUE, Vector2i(8, 8)).ok, "bounds enforced")
	check(not Rules.placement(board, square, Rules.BLUE, Vector2i(4, 4)).ok, "overlap rejected")
	check(not Rules.placement(board, square, Rules.BLUE, Vector2i(0, 0)).ok, "contact required")
	check(Rules.placement(board, square, Rules.BLUE, Vector2i(2, 2)).ok, "corner contact allowed")
	check(board[2][2] == 0, "validation does not mutate board")
	board = Rules.empty_board(9)
	for row: Array in board:
		row.fill(Rules.BLUE)
	board[1][2] = 0
	check(not Rules.placement(board, [Vector2i.ZERO], Rules.CORAL, Vector2i(2, 1)).ok, "last possible symmetry protected")
	for seed_value in range(20):
		var game = Game.new(9, seed_value)
		var snapshots: Array = []
		var initial_names: Array = game.queue.duplicate()
		initial_names.sort()
		var expected: Array = Rules.PIECES.keys()
		expected.sort()
		check(initial_names == expected, "bag includes each piece once")
		for i in range(4):
			snapshots.append({"board": game.board.duplicate(true), "piece": game.queue[game.index], "color": game.current_color})
			var move: Dictionary = Rules.first_legal_move(game.board, game.piece())
			check(not move.is_empty(), "initial sequence can be played")
			if move.is_empty():
				break
			game.current_color = move.color
			snapshots[i].color = move.color
			snapshots[i].cells = move.cells.duplicate()
			check(game.place(move.cells, move.anchor).ok, "legal placement succeeds")
		check(game.history.size() == 3, "undo stores three placements")
		for i in range(3, 0, -1):
			check(game.undo(), "undo succeeds")
			check(game.board == snapshots[i].board, "undo restores board")
			check(game.queue[game.index] == snapshots[i].piece, "undo restores offered piece")
			check(game.current_color == snapshots[i].color, "undo restores selected color")
			check(game.restored_cells == snapshots[i].cells, "undo restores flipped or rotated orientation")
		check(not game.undo(), "fourth undo unavailable")
		check(game.moves == 1, "three undos retrace three moves")
	# A one-cell hole in an otherwise blue board can only accept blue.
	board = Rules.empty_board(9)
	for row: Array in board:
		row.fill(Rules.BLUE)
	board[1][2] = 0
	var coral_dot := {"cells": Rules.PIECES.Dot.cells, "color": Rules.CORAL}
	check(Rules.first_legal_move(board, coral_dot, false).is_empty(), "current color alone has no safe placement")
	var rescue: Dictionary = Rules.first_legal_move(board, coral_dot)
	check(not rescue.is_empty() and rescue.color == Rules.BLUE, "color switch rescues position")
	var rescued_game = Game.new()
	rescued_game.board = board
	rescued_game.queue[rescued_game.index] = "Dot"
	rescued_game.current_color = Rules.CORAL
	rescued_game._refresh_over()
	check(not rescued_game.over, "game over considers both colors")
	# The only four empty cells form L, while the incoming piece is J.
	board = Rules.empty_board(9)
	for row: Array in board:
		row.fill(Rules.BLUE)
	for cell: Vector2i in [Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]:
		board[cell.y][cell.x] = 0
	var blue_j := {"cells": Rules.PIECES.J.cells, "color": Rules.BLUE}
	check(Rules.first_legal_move(board, blue_j, true, false).is_empty(), "rotations cannot fill a mirrored J cavity")
	rescue = Rules.first_legal_move(board, blue_j)
	check(not rescue.is_empty() and rescue.flipped, "mirror flip rescues cavity")
	rescued_game.board = board
	rescued_game.queue[rescued_game.index] = "J"
	rescued_game._refresh_over()
	check(not rescued_game.over, "game over considers reflected orientations")
	var full_game = Game.new()
	for row: Array in full_game.board:
		row.fill(Rules.BLUE)
	full_game._refresh_over()
	check(full_game.over, "full board ends game")
	print("Rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
