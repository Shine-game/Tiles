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
	check(Rules.PIECES.size() == 7, "seven standard shapes")
	for piece: Dictionary in Rules.PIECES.values():
		check(piece.cells.size() == 4, "four cells per tetromino")
		var cells: Array = piece.cells
		for i in range(4):
			cells = Rules.rotate(cells)
		for cell: Vector2i in piece.cells:
			check(cells.has(cell), "four turns restore original shape")
	var board: Array = Rules.empty_board(9)
	board[2][1] = Rules.GREEN
	check(Rules.symmetry_states(board)[0].possible, "asymmetric patterns remain possible")
	check(not Rules.symmetry_states(board)[0].complete, "asymmetric is not complete")
	board[2][7] = Rules.YELLOW
	check(not Rules.symmetry_states(board)[0].possible, "opposite colors conflict")
	board[2][7] = Rules.GREEN
	check(Rules.symmetry_states(board)[0].complete, "matching reflected colors complete")
	board = Rules.empty_board(9)
	board[1][2] = Rules.GREEN
	board[7][6] = Rules.YELLOW
	check(not Rules.symmetry_states(board)[4].possible, "90-degree orbit detects nonadjacent colors")
	check(not Rules.symmetry_states(board)[6].possible, "270-degree orbit detects nonadjacent colors")
	board = Rules.create_board()
	var square: Array = Rules.PIECES.O.cells
	check(not Rules.placement(board, square, Rules.GREEN, Vector2i(8, 8)).ok, "bounds enforced")
	check(not Rules.placement(board, square, Rules.GREEN, Vector2i(4, 4)).ok, "overlap rejected")
	check(not Rules.placement(board, square, Rules.GREEN, Vector2i(0, 0)).ok, "contact required")
	check(Rules.placement(board, square, Rules.GREEN, Vector2i(2, 2)).ok, "corner contact allowed")
	check(board[2][2] == 0, "validation does not mutate board")
	board = Rules.empty_board(9)
	for row: Array in board:
		row.fill(Rules.GREEN)
	board[1][2] = 0
	check(not Rules.placement(board, [Vector2i.ZERO], Rules.YELLOW, Vector2i(2, 1)).ok, "last possible symmetry protected")
	for seed_value in range(20):
		var game = Game.new(9, seed_value)
		var snapshots: Array = []
		var initial_names: Array = game.queue.duplicate()
		initial_names.sort()
		var expected: Array = Rules.PIECES.keys()
		expected.sort()
		check(initial_names == expected, "bag includes each piece once")
		for i in range(4):
			snapshots.append({"board": game.board.duplicate(true), "piece": game.queue[game.index]})
			var move: Dictionary = Rules.first_legal_move(game.board, game.piece())
			check(not move.is_empty(), "initial sequence can be played")
			if move.is_empty():
				break
			check(game.place(move.cells, move.anchor).ok, "legal placement succeeds")
		check(game.history.size() == 3, "undo stores three placements")
		for i in range(3, 0, -1):
			check(game.undo(), "undo succeeds")
			check(game.board == snapshots[i].board, "undo restores board")
			check(game.queue[game.index] == snapshots[i].piece, "undo restores offered piece")
		check(not game.undo(), "fourth undo unavailable")
		check(game.moves == 1, "three undos retrace three moves")
	var full_game = Game.new()
	for row: Array in full_game.board:
		row.fill(Rules.GREEN)
	full_game._refresh_over()
	check(full_game.over, "full board ends game")
	print("Rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
