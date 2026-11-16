extends SceneTree
const Connections = preload("res://scripts/pattern/connection_assembly.gd")
const Topology = preload("res://scripts/pattern/topology.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func feature(color: int = 1, old: bool = false, ready: float = 0.5) -> Dictionary:
	return {"color": color, "old": old, "ready": ready, "start": ready - 0.2}
func _initialize() -> void:
	for direction in range(4):
		var a := Vector2i(3, 3)
		var b: Vector2i = a + Topology.DIRECTIONS[direction]
		var features := {a: feature(), b: feature(1, false, 1.0)}
		var original := var_to_bytes(features)
		var pairs := Connections.pairs(features)
		check(pairs.size() == 1, "one cardinal join")
		var pair: Dictionary = pairs[0]
		check(pair.cells.size() == 6, "2x3 territory counts overlap once")
		check(pair.center == Topology.centroid(pair.cells), "center uses unique cells")
		check(pair.id == Connections.pair_identity(1, b, a), "pair identity is undirected")
		check(is_equal_approx(Connections.ready(pair, features), 1.0), "latest member is prerequisite")
		check(is_equal_approx(Connections.start(pair, features, "start", 0.162), 0.962), "vines use start plus fractional delay")
		var sides := Connections.directed_sides(features)
		check(sides.size() == 2, "both facing watersheds")
		check(sides[0].origin == a and sides[0].direction == direction, "first watershed faces shared base")
		check(sides[1].origin == b and sides[1].direction == posmod(direction + 2, 4), "opposite watershed faces shared base")
		check(sides[0].id == sides[1].id and sides[0].side_id != sides[1].side_id, "shared pair, distinct water sides")
		var shifted := {a + Vector2i.ONE: features[a], b + Vector2i.ONE: features[b]}
		var translated: Dictionary = Connections.pairs(shifted, Vector2i.ONE)[0]
		check(translated.id == pair.id and translated.cells == pair.cells, "legacy Vines corner keys normalize to same supports")
		var reversed := {b: features[b], a: features[a]}
		check(Connections.pairs(reversed)[0] == pair, "pair iteration independent of insertion order")
		check(var_to_bytes(features) == original, "planning never mutates model events")
		features[a].old = true
		check(not Connections.pairs(features)[0].old, "one new member keeps connection new")
		features[b].old = true
		pair = Connections.pairs(features)[0]
		check(Connections.start(pair, features) == -100.0, "old connection settles")
		check(Connections.ready(pair, features) == 1.0, "raw readiness retained for theme policies")
		features[b].color = 2
		check(Connections.pairs(features).is_empty() and Connections.directed_sides(features).is_empty(), "colors never connect")
	var diagonal := {Vector2i.ZERO: feature(), Vector2i.ONE: feature()}
	check(Connections.territories(diagonal).is_empty(), "diagonal formations do not trigger Tier 3")
	var formations := {Vector2i(1, 1): feature(), Vector2i(2, 1): feature(), Vector2i(2, 2): feature(), Vector2i(5, 5): feature(2)}
	var cluster: Dictionary = Connections.territories(formations)[0]
	check(cluster.members.size() == 3 and cluster.cells.size() == 8, "L territory preserves overlapping formations")
	check(Connections.territories(formations, 2).is_empty(), "isolated color has no Tier 3 territory")
	var structural_id: String = cluster.id
	formations[Vector2i(1, 2)] = feature()
	check(Connections.territories(formations)[0].id != structural_id, "membership identity changes on expansion; history remains theme-owned")
	for size in [9, 11]:
		var grid: Array = []
		for y in range(size):
			var row: Array = []
			for x in range(size): row.append(1)
			grid.append(row)
		formations = Topology.formations(grid)
		for origin: Vector2i in formations: formations[origin].merge(feature())
		var pairs := Connections.pairs(formations)
		check(pairs.size() == 2 * (size - 1) * (size - 2), "dense board includes every overlapping join")
		check(Connections.directed_sides(formations).size() == 2 * pairs.size(), "every dense join has two sides")
		cluster = Connections.territories(formations)[0]
		check(cluster.cells.size() == size * size and cluster.center == Vector2.ONE * (size / 2.0), "whole board unique-cell centroid")
	print("Tier 3 connections: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
