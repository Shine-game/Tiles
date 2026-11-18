class_name CoralGrowth
extends "res://scripts/growth.gd"

const Fingers = preload("res://scripts/pattern/animated_fingers.gd")
const RadialPetals = preload("res://scripts/pattern/radial_petals.gd")
const Ordinary = preload("res://scripts/coral_sets.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const ROOT := "res://art/themes/coral_reef/"
const SOFT := 0.035
const CELL_SECONDS := 0.20
const HALF_SECONDS := 0.10
const DIR_NAMES := ["n", "e", "s", "w"]
const OFFSETS = Topology.DIRECTIONS
var components: Dictionary = {}
var colonies: Dictionary = {}
var unions: Dictionary = {}

static func ground_choice(cell: Vector2i) -> Dictionary:
	var hashed: int = ((cell.x * 73856093) ^ (cell.y * 19349663) ^ 1409) & 0xffffffff
	return {"id": "ground_%02d" % [hashed % 6 + 1], "rotation": (hashed >> 8) % 4}

static func metadata(id: String) -> Dictionary:
	return Ordinary.part(id) if Ordinary.owns(id) else (Ordinary.ground_part(id) if id.begins_with("ground_") else Ordinary.special_part(id))

static func component_duration(id: String) -> float:
	return float(metadata(id).animation.duration_seconds)

static func dependent_start(id: String, parents: Dictionary) -> float:
	return Timing.dependent_start(metadata(id).animation.dependencies, parents)

static func key(kind: String, color: int, cell: Vector2i) -> String:
	return "%s/%d/%d/%d" % [kind, color, cell.y, cell.x]

static func arrival(event: Dictionary, u: float) -> float:
	return Timing.front_arrival(event.start, event.reverse, event.stroke, event.two_fronts, u)

static func end_time(start: float, reverse: float, stroke: float, two_fronts: bool) -> float:
	return Timing.front_end(start, reverse, stroke, two_fronts, SOFT)

func _add(id: String, color: int, cell: Vector2i, center: Vector2, old: bool, start: float, stroke: float, reverse: float = 0, two_fronts: bool = false, rotation: int = 0, identity: String = "") -> Dictionary:
	var meta := metadata(id)
	var tail: float = meta.animation.soft_front_seconds if Ordinary.owns(id) else SOFT
	var event := {"key": key(id, color, cell) if identity.is_empty() else identity, "id": id, "color": color, "center": center, "size": Vector2(meta.size_px[0], meta.size_px[1]), "old": old, "start": -100.0 if old else start, "stroke": stroke, "reverse": -100.0 if old else reverse, "two_fronts": two_fronts, "rotation": rotation, "end": -100.0 if old else Timing.front_end(start, reverse, stroke, two_fronts, tail), "bucket": int(meta.layer)}
	components[event.key] = event
	if not old:
		duration = maxf(duration, event.end)
	return event

static func union_layout(delta: Vector2i) -> Dictionary:
	# Immediate same-color orthogonal neighbors only. No diagonal or skipped join.
	if not Topology.is_cardinal_offset(delta):
		return {}
	return {"rotation": 0 if delta.y == 0 else 1}

func build(before: Array, after: Array) -> void:
	super.build(before, after)
	components.clear()
	colonies.clear()
	unions.clear()
	duration = 0
	var propagation := Ordinary.propagation()
	var cell_seconds: float = propagation.cell_seconds
	# Independent new components awaken every bud together. Components touching
	# old coral route simultaneous fronts from every matching outside source.
	var pending: Dictionary = {}
	var independent: Dictionary = {}
	for cell: Vector2i in arrivals:
		if value(before, cell) != value(after, cell):
			pending[cell] = true
	while not pending.is_empty():
		var first: Vector2i = pending.keys()[0]
		var group: Array = [first]
		pending.erase(first)
		var cursor := 0
		while cursor < group.size():
			var cell: Vector2i = group[cursor]
			cursor += 1
			for offset: Vector2i in OFFSETS:
				var other := cell + offset
				if pending.has(other) and value(after, cell) == value(after, other):
					pending.erase(other)
					group.append(other)
		var wave: Array = []
		for cell: Vector2i in group:
			arrivals[cell] = INF
			for offset: Vector2i in OFFSETS:
				if value(before, cell + offset) == value(after, cell):
					arrivals[cell] = cell_seconds
					wave.append(cell)
					break
		if wave.is_empty():
			for cell: Vector2i in group:
				arrivals[cell] = 0.0
				independent[cell] = true
		else:
			cursor = 0
			while cursor < wave.size():
				var cell: Vector2i = wave[cursor]
				cursor += 1
				for offset: Vector2i in OFFSETS:
					var other := cell + offset
					if group.has(other) and float(arrivals[other]) > float(arrivals[cell]) + cell_seconds:
						arrivals[other] = float(arrivals[cell]) + cell_seconds
						wave.append(other)
	for cell: Vector2i in arrivals:
		var color: int = value(after, cell)
		var old: bool = value(before, cell) == color
		var center := Cells.anchor(cell)
		var ground := ground_choice(cell)
		var floor_event := _add(ground.id, color, cell, center, true, -100, 0.01, 0, false, ground.rotation)
		floor_event.instant = true
		var mask := Topology.neighbor_mask(after, cell)
		var centers := Ordinary.centers(mask)
		var vines := Ordinary.vines(mask)
		if centers.has("core"):
			var old_core: bool = old and Ordinary.centers(Topology.neighbor_mask(before, cell)).has("core")
			_add("core", color, cell, center, old_core, maxf(0, arrivals[cell]), component_duration("core"))
		var arms: Dictionary = {}
		for direction in range(4):
			var other: Vector2i = cell + OFFSETS[direction]
			var arm_id: String = "arm_" + DIR_NAMES[direction]
			if not vines.has(arm_id): continue
			var travel := component_duration(arm_id)
			var old_arm: bool = old and value(before, other) == color
			var start: float = propagation.independent_start_seconds if independent.has(cell) else maxf(0, arrivals[cell])
			var reverse: float = propagation.independent_reverse_seconds if independent.has(cell) else maxf(0, arrivals[other]) + travel
			var arm := _add(arm_id, color, cell, center, old_arm, start, travel, reverse, true)
			arms[arm_id] = arm
			# Tiny path fingers are omitted for phone-scale readability.
		for junction: String in centers:
			if junction == "core": continue
			var dependencies: Array = centers[junction].animation.dependencies
			if arms.has(dependencies[0].component) and arms.has(dependencies[1].component):
				var old_junction: bool = arms[dependencies[0].component].old and arms[dependencies[1].component].old
				_add(junction, color, cell, center, old_junction, dependent_start(junction, arms), component_duration(junction))
	# Shared formation support and multipart scheduling retain Coral event IDs.
	var formations := Formations.collect(before, after)
	for origin: Vector2i in formations:
		var formation: Dictionary = formations[origin]
		var color: int = formation.color
		var perimeter := Formations.prerequisite_ready(formation, components, key, Ordinary.tier2)
		var events := Formations.assemble(formation, Ordinary.formation_parts(), perimeter, _emit_formation)
		var complete := Formations.completion(Ordinary.tier2, perimeter, events)
		colonies[origin] = {"origin": origin, "color": color, "old": formation.old, "start": perimeter, "ready": complete, "end": complete}
		flowers[origin + Vector2i.ONE].start = perimeter
		flowers[origin + Vector2i.ONE].old = formation.old
	for pair: Dictionary in Connections.pairs(colonies):
		var a: Vector2i = pair.a
		var b: Vector2i = pair.b
		var layout := union_layout(b - a)
		var identity := "anemone/%d/%d/%d/%d/%d" % [colonies[a].color, a.y, a.x, b.y, b.x]
		var center := (Vector2(a) + Vector2(b)) / 2 + Vector2.ONE
		var old: bool = pair.old
		var ready: float = Connections.ready(pair, colonies)
		if colonies[a].color == 1:
			var finish := ready
			var choices := Fingers.choices(a, b)
			for i in range(choices.size()):
				var event := _add("anemone_foot", 1, a, center, old, ready, Fingers.definition().growth_seconds, 0, false, layout.rotation, identity + "/finger_%d" % i)
				event.feature = identity
				event.animated_finger = choices[i]
				finish = maxf(finish, event.end)
			unions[identity] = {"a": a, "b": b, "color": 1, "start": ready, "end": finish, "rotation": layout.rotation, "feature": identity}
			continue
		var foot := _add("anemone_foot", colonies[a].color, a, center, old, ready, component_duration("anemone_foot"), 0, false, layout.rotation, identity + "/foot")
		foot.feature = identity
		var disc_start := dependent_start("anemone_oral_disc", {"anemone_foot": foot})
		var disc_end: float = -100 if old else end_time(disc_start, 0, component_duration("anemone_oral_disc"), false)
		var finish: float = foot.end
		for region in range(8):
			var id := "anemone_region_%d" % region
			var event := _add(id, colonies[a].color, a, center, old, disc_end, component_duration(id), 0, false, layout.rotation, identity + "/region_%d" % region)
			event.feature = identity
			finish = maxf(finish, event.end)
		var disc := _add("anemone_oral_disc", colonies[a].color, a, center, old, disc_start, component_duration("anemone_oral_disc"), 0, false, layout.rotation, identity + "/disc")
		disc.feature = identity
		unions[identity] = {"a": a, "b": b, "color": colonies[a].color, "start": ready, "end": maxf(finish, disc.end), "rotation": layout.rotation, "feature": identity}

func grid_visibility(a: Vector2i, b: Vector2i, time: float) -> float:
	if value(board, a) != 0 and value(board, b) == value(board, a):
		var direction: int = OFFSETS.find(b - a)
		if direction >= 0:
			var arm: Dictionary = components[key("arm_" + DIR_NAMES[direction], value(board, a), a)]
			var crossing: float = arrival(arm, 1)
			return 1.0 - smoothstep(crossing, crossing + GRID_FADE, time)
	return super.grid_visibility(a, b, time)

func _emit_formation(id: String, _spec: Dictionary, formation: Dictionary, at: float, seconds: float) -> Dictionary:
	var petal := {}
	if id.begins_with("colony_petal_"):
		petal = RadialPetals.choices(Ordinary.tier2.definition.radial_petals, formation.color, formation.origin)[int(id.get_slice("_", 2))]
		at += float(petal.get("delay", 0.0))
	var event := _add(id, formation.color, formation.origin, formation.center, formation.old, at, seconds)
	if not petal.is_empty(): event.radial_petal = petal
	return event

func tier2_records() -> Dictionary:
	return Formations.bind_records(board, colonies, "ready")
