class_name ClockworkGrowth
extends "res://scripts/growth.gd"

const ROOT := "res://art/themes/clockwork_workshop/"
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
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
	var meta: Dictionary = specification().components[id]
	var event := {"id": id, "color": color, "cell": cell, "center": center, "old": old, "start": -100.0 if old else start, "seconds": seconds, "end": -100.0 if old else start + seconds, "rotation": rotation, "key": key(id, color, cell) if identity.is_empty() else identity, "layer": meta.layer}
	components[event.key] = event
	if not old:
		duration = maxf(duration, event.end)
	return event

func build(before: Array, after: Array) -> void:
	super.build(before, after)
	components.clear()
	mechanisms.clear()
	chains.clear()
	powered.clear()
	pins.clear()
	duration = 0
	for cell: Vector2i in arrivals:
		arrivals[cell] = float(arrivals[cell]) * 0.20 / STEP if arrivals[cell] >= 0 else -100.0
	for cell: Vector2i in arrivals:
		var color: int = value(after, cell)
		var old: bool = value(before, cell) == color
		var at: float = -100 if old else float(arrivals[cell])
		for id: String in ["C01", "C02", "C03"]:
			add_part(id, color, cell, Vector2(cell) + Vector2.ONE * 0.5, old, maxf(0, at) + (0.05 if id != "C01" else 0), 0.35)
		for direction in range(4):
			var other: Vector2i = cell + DIRS[direction]
			if value(after, other) != color:
				continue
			var old_arm: bool = old and value(before, other) == color
			var arm := add_part("T01", color, cell, Vector2(cell) + Vector2.ONE * 0.5, old_arm, maxf(0, at) + (0.0 if old else 0.15), 0.235, (direction - 1) * PI / 2, key("T01_" + NAMES[direction], color, cell))
			arm.direction = direction
			# Always use the canonical core field; shader supplies its reverse front.
			var neighbor_start: float = 0.0 if value(before, other) == color else maxf(0, float(arrivals.get(other, 0))) + 0.15
			arm.edge_start = -100.0 if old_arm else neighbor_start + 0.20
			arm.seconds = 0.20
			var peak: float = clampf((arm.edge_start + arm.seconds - arm.start) / (2 * arm.seconds), 0, 1)
			arm.end = -100.0 if old_arm else minf(arm.start + peak * arm.seconds, arm.edge_start + (1.0 - peak) * arm.seconds) + 0.035
			if not old_arm:
				duration = maxf(duration, arm.end)
			add_part("T02", color, cell, arm.center, old_arm, maxf(0, arm.start) + 0.12, 0.13, arm.rotation, key("T02_" + NAMES[direction], color, cell))
			if direction in [1, 2]:
				var coupling := add_part("T03", color, cell, Vector2(cell) + Vector2.ONE * 0.5 + Vector2(DIRS[direction]) * 0.5, old_arm, minf(maxf(0, arm.start) + 0.20, maxf(0, arm.edge_start)), 0.14, arm.rotation)
				coupling.key = key("T03_" + NAMES[direction], color, cell)
				components.erase(key("T03", color, cell))
				components[coupling.key] = coupling
	for corner: Vector2i in flowers:
		var cell := corner - Vector2i.ONE
		var flower: Dictionary = flowers[corner]
		var start := 0.0
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			start = maxf(start, float(components[key("C02", flower.color, cell + offset)].end))
			for direction in range(4):
				var neighbor: Vector2i = offset + DIRS[direction]
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x > 1 or neighbor.y > 1: continue
				var arm_key := key("T01_" + NAMES[direction], flower.color, cell + offset)
				if components.has(arm_key):
					start = maxf(start, float(components[arm_key].end))
		var mechanism := {"origin": cell, "center": Vector2(corner), "color": flower.color, "old": flower.old, "start": -100.0 if flower.old else start, "ready": -100.0 if flower.old else start + 1.95, "directions": [], "chain_end": -100.0}
		mechanisms[cell] = mechanism
		flower.start = mechanism.start
		for id: String in ["L01", "L02", "L03", "H00_plain_hatch"]:
			var begin: float = {"L01": 0.0, "L02": 0.85, "L03": 1.20, "H00_plain_hatch": 1.70}[id]
			var seconds: float = {"L01": 0.40, "L02": 0.35, "L03": 0.50, "H00_plain_hatch": 0.25}[id]
			var part := add_part(id, flower.color, cell, Vector2(corner), flower.old, start + begin, seconds, 0, key("hatch" if id == "H00_plain_hatch" else id, flower.color, cell))
			part.mechanism = cell
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			var core: Vector2i = cell + offset
			if not powered.has(core):
				powered[core] = []
			powered[core].append(cell)
	for cell: Vector2i in mechanisms:
		var a: Dictionary = mechanisms[cell]
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other := cell + direction
			if not mechanisms.has(other) or mechanisms[other].color != a.color:
				continue
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
