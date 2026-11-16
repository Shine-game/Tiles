extends SceneTree
const Topology = preload("res://scripts/pattern/topology.gd")
const Rules = preload("res://scripts/rules.gd")
const Growth = preload("res://scripts/growth.gd")
const Geometry = preload("res://scripts/zen_geometry.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const Trees = preload("res://scripts/zen_trees.gd")
const SHAPES := ["isolated", "endpoint", "endpoint", "bend", "endpoint", "straight", "bend", "t", "endpoint", "bend", "straight", "t", "bend", "t", "t", "cross"]
const CANONICAL := [[0, 0], [1, 0], [1, 1], [3, 0], [1, 2], [5, 0], [3, 1], [11, 1], [1, 3], [3, 3], [5, 1], [11, 0], [3, 2], [11, 3], [11, 2], [15, 0]]
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	for mask in range(16):
		check(Topology.shape(mask) == SHAPES[mask], "All sixteen shapes use N/E/S/W bits")
		check(Topology.canonical(mask) == {"mask": CANONICAL[mask][0], "turns": CANONICAL[mask][1]}, "Canonical representatives and first valid turns remain compatible")
		for turns in range(-4, 8):
			var expected := 0
			for bit in range(4):
				if mask & (1 << bit): expected |= 1 << posmod(bit + turns, 4)
			check(Topology.rotate_mask(mask, turns) == expected, "Positive turns rotate clockwise, including negative/wrapped turns")
			check(Geometry.rotate_mask(mask, turns) == expected, "Zen's public rotation adapter preserves its result")
		for n in [9, 11]:
			for color in [1, 2]:
				var board := Rules.empty_board(n)
				var center := Vector2i(n / 2, n / 2)
				board[center.y][center.x] = color
				for d in range(4):
					var other: Vector2i = center + [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][d]
					board[other.y][other.x] = color if mask & (1 << d) else 3 - color
				check(Topology.neighbor_mask(board, center) == mask, "Masks connect only the same logical color")
				check(Clock.connection_mask(board, center) == mask and Geometry.neighbor_mask(board, center) == mask, "Clockwork and Zen use the shared masks")
				check(Clock.has_wheel(board, center) == (SHAPES[mask] != "straight"), "Clockwork's isolated/endpoint/bend/T/cross wheel behavior is unchanged")
	check(Topology.shape(16) == "invalid" and Topology.canonical(-1).is_empty(), "Invalid masks are not classified as valid shapes")
	check(Topology.neighbor_mask([], Vector2i.ZERO) == 0 and Topology.value([], Vector2i.ZERO) == 0, "Empty and out-of-field positions are empty")
	var edge := Rules.empty_board(9)
	edge[0][0] = 1
	edge[1][1] = 1
	check(Topology.neighbor_mask(edge, Vector2i.ZERO) == 0, "Diagonal contact does not connect")
	edge[0][1] = 1
	edge[1][0] = 1
	check(Topology.neighbor_mask(edge, Vector2i.ZERO) == 6, "Board-edge masks do not wrap north or west")
	check(not Clock.has_wheel(edge, Vector2i(8, 8)), "An empty square never gets a Clockwork centerpiece")
	for n in [9, 11]:
		for color in [1, 2]:
			var dense := Rules.empty_board(n)
			for row: Array in dense: row.fill(color)
			check_graph(dense)
			var features := Topology.formations(dense)
			check(features.size() == (n - 1) * (n - 1), "Every overlapping dense 2x2 is detected")
			check(Topology.adjacent_pairs(features).size() == 2 * (n - 1) * (n - 2), "Each dense formation connection is emitted once")
			var connected := Topology.connected_formations(features)
			check(connected.size() == 1 and connected[0].cells.size() == n * n, "Connected territory counts unique support cells")
			check(connected[0].center.is_equal_approx(Vector2.ONE * n * 0.5), "Dense territory centroid is in cell coordinates")
			var reversed: Dictionary = {}
			var keys: Array = features.keys()
			keys.reverse()
			for origin: Vector2i in keys: reversed[origin] = features[origin]
			check(var_to_bytes(Topology.adjacent_pairs(features)) == var_to_bytes(Topology.adjacent_pairs(reversed)), "Pair identities/order do not depend on insertion order")
			check(var_to_bytes(connected) == var_to_bytes(Topology.connected_formations(reversed)), "Components and support order do not depend on insertion order")
	for extent in [Vector2i(3, 2), Vector2i(2, 3)]:
		var board := Rules.empty_board(9)
		for y in range(extent.y):
			for x in range(extent.x): board[y + 2][x + 2] = 1
		var features := Topology.formations(board)
		var pairs := Topology.adjacent_pairs(features)
		check(features.size() == 2 and pairs.size() == 1, "Both 2x3 orientations already connect two overlapping formations")
		check(pairs[0].direction == (1 if extent.x == 3 else 2), "Formation connections preserve horizontal/vertical direction")
		var group: Dictionary = Topology.connected_formations(features, 1, 2)[0]
		check(group.cells.size() == 6 and group.center.is_equal_approx(Vector2(2, 2) + Vector2(extent) * 0.5), "Overlapping territory centroid uses six distinct squares")
		check(Topology.connected_formations(features, 2, 2).is_empty(), "Connected territory can filter logical colors")
		var ready: Dictionary = {}
		for origin: Vector2i in features:
			ready[origin] = {"color": 1, "ready": float(origin.x + origin.y), "old": origin == Vector2i(2, 2)}
		var legacy: Dictionary = Trees.clusters(ready)[0]
		check(legacy.cells == group.cells and legacy.center.is_equal_approx(group.center * 256), "Tree adapter preserves unique support and source-pixel centroid")
		check(not legacy.old, "Tree adapter aggregates old/new state independently of topology")
		check_graph(board)
	# Explicit graph adversaries: diagonals, distant formations, opposite colors.
	var features := {Vector2i(0, 0): {"color": 1}, Vector2i(1, 1): {"color": 1}, Vector2i(4, 1): {"color": 1}, Vector2i(0, 1): {"color": 2}}
	check(Topology.adjacent_pairs(features).is_empty(), "Neither diagonal, distant nor opposite-color formations connect")
	check(Topology.connected_formations(features, 0, 2).is_empty(), "Those formations do not trigger connected territories")
	for delta in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.ONE, Vector2i.ZERO, Vector2i(2, 0)]:
		check(not Coral.union_layout(delta).is_empty() == Topology.is_cardinal_offset(delta), "Coral's compatibility layout preserves its adjacency rule")
	var rng := RandomNumberGenerator.new()
	rng.seed = 66172
	for i in range(35):
		var board := Rules.empty_board(9 if i % 2 == 0 else 11)
		for row: Array in board:
			for x in range(row.size()): row[x] = rng.randi_range(0, 2)
		check_graph(board)
	print("Pattern topology: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check_graph(board: Array) -> void:
	var expected: Dictionary = {}
	for y in range(board.size() - 1):
		for x in range(board.size() - 1):
			var c: int = board[y][x]
			if c != 0 and board[y][x + 1] == c and board[y + 1][x] == c and board[y + 1][x + 1] == c: expected[Vector2i(x, y)] = c
	var features := Topology.formations(board)
	check(features.keys() == expected.keys(), "Formation enumeration matches an independent four-cell check in row order")
	for origin: Vector2i in expected:
		check(features[origin].color == expected[origin] and features[origin].cells.size() == 4 and features[origin].center == Vector2(origin) + Vector2.ONE, "Formation metadata keeps its logical color, four supports and inner center")
		check(Growth.is_flower(board, origin + Vector2i.ONE, expected[origin]), "Legacy corner-based flower lookup delegates to origin-based detection")
	var pair_count := 0
	var origins: Array = expected.keys()
	for i in range(origins.size()):
		for j in range(i + 1, origins.size()):
			var a: Vector2i = origins[i]
			var b: Vector2i = origins[j]
			if expected[a] == expected[b] and absi(a.x - b.x) + absi(a.y - b.y) == 1: pair_count += 1
	check(Topology.adjacent_pairs(features).size() == pair_count, "Shared formation graph matches independent pair enumeration")
	check(not Topology.is_formation(board, Vector2i(-1, 0), 1), "A formation cannot extend outside the board")
