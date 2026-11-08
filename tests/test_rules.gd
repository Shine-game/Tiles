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
		var groups: Array = game.eligible_groups()
		check(groups.size() == 4, "all four size categories initially eligible")
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
			check(not Rules.first_physical_move(game.board, game.piece()).is_empty(), "undo rerolls a physically fitting piece")
			check(game.current_color == snapshots[i].color, "undo restores selected color")
			check(game.restored_cells == game.piece().cells, "rerolled piece starts in its own orientation")
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
	check(not rescued_game.symmetry_blocked, "safe placement search considers both colors")
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
	check(not rescued_game.symmetry_blocked, "safe placement search considers reflected orientations")
	var full_game = Game.new()
	for row: Array in full_game.board:
		row.fill(Rules.BLUE)
	full_game._refresh_over()
	check(full_game.over, "full board ends game")
	# Measure both levels of randomness without changing the board between draws.
	var sampler = Game.new(9, 124578)
	var groups: Array = sampler.eligible_groups()
	var counts := [0, 0, 0, 0]
	var shape_counts: Dictionary = {}
	for i in range(28000):
		var name: String = sampler._choose_from_groups(groups)
		counts[Rules.PIECES[name].cells.size() - 1] += 1
		shape_counts[name] = shape_counts.get(name, 0) + 1
	for count: int in counts:
		check(absi(count - 7000) < 400, "each size receives approximately 25 percent")
	check(absi(shape_counts.I3 - shape_counts.L3) < 400, "triominoes are uniform within size")
	for name: String in ["I", "O", "S", "T", "J", "L", "Z"]:
		check(absi(shape_counts[name] - 1000) < 150, "tetrominoes are uniform within size")
	print("Generation sample by size (28,000 draws): ", counts)
	# Two isolated holes have enough area for a domino but no matching cavity.
	sampler.board = Rules.empty_board(9)
	for row: Array in sampler.board:
		row.fill(Rules.BLUE)
	sampler.board[1][1] = 0
	sampler.board[7][7] = 0
	check(sampler.eligible_groups() == [["Dot"]], "fragmented free area excludes physically impossible shapes")
	for i in range(20):
		check(sampler._draw_piece() == "Dot", "generation falls back to the only fitting size")
	# A mirrored cavity must admit J as well as L because the player can flip.
	sampler.board = Rules.empty_board(9)
	for row: Array in sampler.board:
		row.fill(Rules.BLUE)
	for cell: Vector2i in [Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]:
		sampler.board[cell.y][cell.x] = 0
	groups = sampler.eligible_groups()
	check(groups[3].has("J") and groups[3].has("L"), "physical filter includes flipped fits")
	check(not groups[3].has("O"), "physical filter excludes square from L-shaped cavity")
	# A physically fitting domino needs two different colors to preserve the
	# only remaining reflection, so drawing it must still be allowed to end play.
	sampler.board = Rules.empty_board(9)
	for y in range(9):
		for x in range(9):
			var mirrored_x: int = mini(x, 8 - x)
			sampler.board[y][x] = Rules.CORAL if (mirrored_x * 3 + y * 7 + mirrored_x * y) % 3 == 0 else Rules.BLUE
	sampler.board[1][7] = Rules.BLUE
	sampler.board[1][6] = Rules.CORAL
	sampler.board[1][1] = 0
	sampler.board[1][2] = 0
	check(Rules.symmetry_states(sampler.board)[0].possible, "fixture still permits vertical symmetry")
	check(not Rules.first_physical_move(sampler.board, Rules.PIECES.Domino).is_empty(), "domino physically fits cavity")
	check(Rules.first_legal_move(sampler.board, Rules.PIECES.Domino).is_empty(), "domino cannot preserve any symmetry in either color")
	groups = sampler.eligible_groups()
	check(groups == [["Dot"], ["Domino"]], "symmetry-breaking piece stays eligible")
	var drew_fatal := false
	for i in range(20):
		if sampler._draw_piece() == "Domino":
			drew_fatal = true
	check(drew_fatal, "generator actually offers symmetry-breaking pieces")
	sampler.queue[sampler.index] = "Domino"
	sampler._refresh_over()
	check(not sampler.over and sampler.symmetry_blocked, "symmetry-blocked draw remains draggable until confirmed")
	var fatal_move: Dictionary = Rules.first_physical_move(sampler.board, sampler.piece())
	var before_fatal: Array = sampler.board.duplicate(true)
	check(sampler.place(fatal_move.cells, fatal_move.anchor).ok, "physically fitting symmetry conflict can be confirmed")
	check(sampler.over and sampler.lost, "confirmed symmetry conflict ends game")
	check(sampler.undo() and not sampler.over and sampler.board == before_fatal, "fatal placement can be undone")
	# Filling the final hole produces a completed board, without offering an impossible piece.
	var finisher = Game.new(9, 777)
	finisher.board = Rules.empty_board(9)
	for row: Array in finisher.board:
		row.fill(Rules.BLUE)
	finisher.board[1][2] = 0
	finisher.queue[finisher.index] = "Dot"
	finisher._refresh_over()
	check(finisher.place(Rules.PIECES.Dot.cells, Vector2i(2, 1)).ok, "final physical space can be filled")
	check(finisher.over and finisher.no_space and finisher.piece().cells.is_empty(), "full grid completes without an impossible next piece")
	check(finisher.undo() and not finisher.over and finisher.queue[finisher.index] == "Dot", "completion can be undone")
	# Back restores the board but rerolls the current offer. It must not rewind
	# the random stream, otherwise replaying a move repeats the unwanted draw.
	var replay = Game.new(9, 888)
	var replay_move: Dictionary = Rules.first_legal_move(replay.board, replay.piece())
	replay.current_color = replay_move.color
	var restored_board: Array = replay.board.duplicate(true)
	replay.place(replay_move.cells, replay_move.anchor)
	var old_offer: String = replay.queue[replay.index]
	var random_state: int = replay.rng.state
	check(replay.undo(), "reroll undo succeeds")
	check(replay.board == restored_board, "reroll restores the board before last placement")
	check(replay.queue[replay.index] != old_offer, "Back offers a different shape when alternatives fit")
	check(replay.rng.state != random_state, "Back consumes fresh randomness")
	check(not Rules.first_physical_move(replay.board, replay.piece()).is_empty(), "rerolled piece physically fits restored board")
	var replacement: Dictionary = Rules.first_legal_move(replay.board, replay.piece())
	replay.current_color = replacement.color
	check(replay.place(replacement.cells, replacement.anchor).ok, "rerolled piece can be played")
	# Only Dot fits: a reroll must repeat it rather than produce an impossible shape.
	var forced = Game.new(9, 456)
	forced.board = Rules.empty_board(9)
	for row: Array in forced.board:
		row.fill(Rules.BLUE)
	forced.board[1][2] = 0
	forced.queue[forced.index] = "Dot"
	forced._refresh_over()
	forced.place(Rules.PIECES.Dot.cells, Vector2i(2, 1))
	check(forced.undo() and forced.queue[forced.index] == "Dot", "reroll repeats the only physically fitting shape")
	print("Rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
