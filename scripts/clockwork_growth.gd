class_name ClockworkGrowth
extends "res://scripts/growth.gd"

const Assembly = preload("res://scripts/pattern/assembly.gd")
const Ordinary = preload("res://scripts/clockwork_sets.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const ROOT := "res://art/themes/clockwork_workshop/"
const HALF_TRAVEL := 0.20
const REVEAL_TAIL := 0.035
const CORE_EMIT_DELAY := 0.15
const DIRS = Topology.DIRECTIONS
const NAMES := ["N", "E", "S", "W"]
static var manifest: Dictionary = {}
var components: Dictionary = {}
var mechanisms: Dictionary = {}
var chains: Dictionary = {}
var powered: Dictionary = {}
var pins: Array = []
var dismantling := false

static func specification() -> Dictionary:
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "theme.json"))
	return manifest

static func key(id: String, color: int, cell: Vector2i) -> String:
	return "%s/%d/%d/%d" % [id, color, cell.y, cell.x]

static func connection_mask(grid: Array, cell: Vector2i) -> int:
	return Topology.neighbor_mask(grid, cell)

static func has_wheel(grid: Array, cell: Vector2i) -> bool:
	# Isolated cells, endpoints, bends, Ts and crosses carry the full assembly.
	# Only two opposite same-color connections make a tube-only straight cell.
	return value(grid, cell) != 0 and not Ordinary.centers(connection_mask(grid, cell)).is_empty()

static func cap_for(directions: Array) -> String:
	if directions.size() < 2:
		return "H00_plain_hatch"
	if directions.size() > 2:
		return "H03_exhaust"
	return "H01_valve" if directions[0] == -directions[1] else "H02_rotating"

static func ground_choice(cell: Vector2i) -> Dictionary:
	var h: int = ((cell.x * 73856093) ^ (cell.y * 19349663) ^ 1409) & 0xffffffff
	return {"variant": h % 2 + 1, "rotation": (h >> 8) % 4}

func add_part(id: String, color: int, cell: Vector2i, center: Vector2, old: bool, start: float, seconds: float, rotation: float = 0, identity: String = "") -> Dictionary:
	var meta: Dictionary = Ordinary.part(id) if Ordinary.owns(id) else specification().components[id]
	var event := {"id": id, "color": color, "cell": cell, "center": center, "old": old, "start": -100.0 if old else start, "seconds": seconds, "end": -100.0 if old else start + seconds, "rotation": rotation, "key": key(id, color, cell) if identity.is_empty() else identity, "layer": meta.layer}
	components[event.key] = event
	if not old:
		duration = maxf(duration, event.end)
	return event

# Arrival means the incoming edge-to-center front is fully visible, not just
# that its first half has reached the shared cell boundary.
func _schedule_centers(before: Array) -> void:
	var travel: float = Ordinary.vine().animation.duration_seconds
	var tail: float = Ordinary.vine().animation.tail_seconds
	var emit_delay: float = Ordinary.vine().animation.center_emit_delay_seconds
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in arrivals:
		if arrivals[cell] < 0 or is_zero_approx(arrivals[cell]):
			# Existing cells, and every bud in a source-free component, retain
			# the established independent-start rule from the base graph.
			continue
		arrivals[cell] = INF
		for direction: Vector2i in DIRS:
			if value(before, cell + direction) == value(board, cell):
				arrivals[cell] = 2.0 * travel + tail
				frontier.append(cell)
				break
	var cursor := 0
	while cursor < frontier.size():
		var cell: Vector2i = frontier[cursor]
		cursor += 1
		for direction: Vector2i in DIRS:
			var other := cell + direction
			if value(board, other) != value(board, cell): continue
			var reached: float = arrivals[cell] + emit_delay + 2.0 * travel + tail
			if float(arrivals[other]) > reached:
				arrivals[other] = reached
				frontier.append(other)

func _emission(cell: Vector2i) -> float:
	return 0.0 if arrivals[cell] < 0 else float(arrivals[cell]) + float(Ordinary.vine().animation.center_emit_delay_seconds)

static func arm_arrival(arm: Dictionary, u: float) -> float:
	return Timing.front_arrival(arm.start, arm.edge_start, arm.seconds, true, u)

func build(before: Array, after: Array) -> void:
	super.build(before, after)
	components.clear()
	mechanisms.clear()
	chains.clear()
	powered.clear()
	pins.clear()
	duration = 0
	_schedule_centers(before)
	var vine: Dictionary = Ordinary.vine()
	var join: Dictionary = Ordinary.join()
	var travel: float = vine.animation.duration_seconds
	var tail: float = vine.animation.tail_seconds
	for cell: Vector2i in arrivals:
		var color: int = value(after, cell)
		var old: bool = value(before, cell) == color
		var at: float = -100 if old else float(arrivals[cell])
		var centers := Ordinary.centers(connection_mask(after, cell))
		if not centers.is_empty():
			var old_wheel := old and has_wheel(before, cell)
			for id: String in centers:
				var part: Dictionary = centers[id]
				add_part(id, color, cell, Cells.anchor(cell, part.anchor), old_wheel, maxf(0, at) + float(part.animation.delay_seconds), part.animation.duration_seconds)
		for direction in range(4):
			var other: Vector2i = cell + DIRS[direction]
			if value(after, other) != color:
				continue
			var old_arm: bool = old and value(before, other) == color
			var arm := add_part("T01", color, cell, Cells.anchor(cell, vine.anchor), old_arm, _emission(cell), travel + tail, Assembly.port_turns(direction, int(vine.orientation_base_port)) * PI / 2, key("T01_" + NAMES[direction], color, cell))
			arm.direction = direction
			# Always use the canonical core field; shader supplies its reverse front.
			arm.edge_start = -100.0 if old_arm else _emission(other) + travel
			arm.seconds = travel
			arm.end = -100.0 if old_arm else Timing.front_end(arm.start, arm.edge_start, arm.seconds, true, tail)
			if not old_arm:
				duration = maxf(duration, arm.end)
			if Cells.forward_port(direction):
				var coupling := add_part("T03", color, cell, Cells.anchor(cell, join.anchor, direction), old_arm, arm_arrival(arm, 1.0) + tail, join.animation.duration_seconds, arm.rotation)
				coupling.key = key("T03_" + NAMES[direction], color, cell)
				components.erase(key("T03", color, cell))
				components[coupling.key] = coupling
	var formations := Formations.collect(before, after)
	for cell: Vector2i in formations:
		var formation: Dictionary = formations[cell]
		var corner := cell + Vector2i.ONE
		var flower: Dictionary = flowers[corner]
		var start := Formations.prerequisite_ready(formation, components, key, Ordinary.tier2)
		var events := Formations.assemble(formation, Ordinary.formation_parts(), start, _emit_formation)
		var mechanism := {"origin": cell, "center": Vector2(corner), "color": flower.color, "old": flower.old, "start": -100.0 if flower.old else start, "ready": -100.0 if flower.old else Formations.completion(Ordinary.tier2, start, events), "directions": [], "chain_end": -100.0}
		mechanisms[cell] = mechanism
		flower.start = mechanism.start
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			var core: Vector2i = cell + offset
			if not powered.has(core):
				powered[core] = []
			powered[core].append(cell)
	for pair: Dictionary in Topology.adjacent_pairs(mechanisms):
		var cell: Vector2i = pair.a
		var other: Vector2i = pair.b
		var direction := other - cell
		var a: Dictionary = mechanisms[cell]
		var b: Dictionary = mechanisms[other]
		var old: bool = a.old and b.old
		var begin: float = -100.0 if old else maxf(maxf(0, a.ready), maxf(0, b.ready))
		var identity := key("chain_%d_%d" % [other.y, other.x], a.color, cell)
		var chain := {"key": identity, "a": cell, "b": other, "color": a.color, "old": old, "start": begin, "end": -100.0 if old else begin + 0.45, "seconds": 0.45, "center": a.center, "rotation": 0.0 if direction == Vector2i.RIGHT else PI / 2, "id": "chain", "layer": 55}
		chains[identity] = chain
		a.directions.append(direction)
		b.directions.append(-direction)
		a.chain_end = maxf(a.chain_end, chain.end)
		b.chain_end = maxf(b.chain_end, chain.end)
		if not old:
			duration = maxf(duration, chain.end)
	for cell: Vector2i in mechanisms:
		var mechanism: Dictionary = mechanisms[cell]
		if mechanism.directions.is_empty():
			continue
		var id := cap_for(mechanism.directions)
		var old_directions: Array = []
		for direction: Vector2i in DIRS:
			if is_flower(before, cell + Vector2i.ONE, mechanism.color) and is_flower(before, cell + direction + Vector2i.ONE, mechanism.color):
				old_directions.append(direction)
		var old_cap: bool = not old_directions.is_empty() and cap_for(old_directions) == id
		var begin: float = maxf(0, mechanism.chain_end)
		var housing := add_part("J00_chain_junction", mechanism.color, cell, mechanism.center, not old_directions.is_empty(), maxf(0, mechanism.chain_end - 0.45), 0.15)
		var cap := add_part(id, mechanism.color, cell, mechanism.center, old_cap, begin, 0.20, 0, key("terminal_" + id, mechanism.color, cell))
		if id == "H03_exhaust":
			for extra: String in ["H03_opaque_underlay", "H03_shutters_left", "H03_shutters_right"]:
				var part := add_part(extra, mechanism.color, cell, mechanism.center, old_cap, begin, 0.20)
				part.mechanism = cell
		cap.mechanism = cell
		cap.terminal = true
		mechanism.cap = id
		mechanism.cap_end = cap.end
	# Only true exposed contour turns receive a plate rivet; mixed-color ties
	# are resolved by row/column rather than placement order.
	for y in range(board.size() + 1):
		for x in range(board.size() + 1):
			var candidates: Array = []
			for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
				var support := Vector2i(x, y) + offset
				if value(board, support) != 0:
					candidates.append(support)
			var diagonal: bool = candidates.size() == 2 and absi(candidates[0].x - candidates[1].x) == 1 and absi(candidates[0].y - candidates[1].y) == 1
			if candidates.size() in [1, 3] or diagonal:
				var eligible: Array = []
				for support: Vector2i in candidates:
					var dx: int = 1 if support.x < x else -1
					var dy: int = 1 if support.y < y else -1
					if value(board, support + Vector2i(dx, 0)) == 0 or value(board, support + Vector2i(0, dy)) == 0:
						eligible.append(support)
				var support: Vector2i = eligible[0]
				pins.append({"corner": Vector2(x, y), "color": value(board, support), "support": support})

	# Exact visible completion, including two-front tube meeting points.
	duration = 0
	for event: Dictionary in components.values():
		if not event.old: duration = maxf(duration, event.end)
	for chain: Dictionary in chains.values():
		if not chain.old: duration = maxf(duration, chain.end)

func _emit_formation(id: String, spec: Dictionary, formation: Dictionary, at: float, seconds: float) -> Dictionary:
	var event := add_part(id, formation.color, formation.origin, formation.center, formation.old, at, seconds, 0, key(spec.get("identity_kind", id), formation.color, formation.origin))
	event.mechanism = formation.origin
	return event

func tier2_records() -> Dictionary:
	var records := Formations.bind_records(board, mechanisms, "ready")
	for origin: Vector2i in records:
		var record: Dictionary = records[origin]
		record.children = []
		for id: String in Ordinary.formation_parts():
			record.children.append("clockwork/part/" + key(Ordinary.part(id).get("identity_kind", id), record.color, origin))
	return records
