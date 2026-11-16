class_name CoralGrowth
extends "res://scripts/growth.gd"

const Ordinary = preload("res://scripts/coral_sets.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const ROOT := "res://art/themes/coral_reef/"
const SOFT := 0.035
const CELL_SECONDS := 0.20
const HALF_SECONDS := 0.10
const DIR_NAMES := ["n", "e", "s", "w"]
const OFFSETS = Topology.DIRECTIONS
static var manifest: Dictionary = {}
var components: Dictionary = {}
var colonies: Dictionary = {}
var unions: Dictionary = {}

static func specification() -> Dictionary:
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "theme.json"))
		# Normalize runtime metadata without altering the supplied manifest.
		var by_id: Dictionary = {}
		for item: Dictionary in manifest.components:
			item.size_px = item.canvas_px
			item.layer = item.draw_order
			item.reveal_mask = item.growth_mask
			by_id[item.id] = item
		for item: Dictionary in manifest.ground_components:
			item.size_px = item.canvas_px
			item.layer = 0
			item.artwork = {"salmon": item.artwork, "turquoise": item.artwork}
			by_id[item.id] = item
		manifest.components = by_id
	return manifest

static func ground_choice(cell: Vector2i) -> Dictionary:
	var hashed: int = ((cell.x * 73856093) ^ (cell.y * 19349663) ^ 1409) & 0xffffffff
	return {"id": "ground_%02d" % [hashed % 6 + 1], "rotation": (hashed >> 8) % 4}

static func metadata(id: String) -> Dictionary:
	return Ordinary.part(id) if Ordinary.owns(id) else specification().components[id]

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
	# Keep each colony's body/folds/fingers as one stable feature group.
	for y in range(board.size() - 1):
		for x in range(board.size() - 1):
			var origin := Vector2i(x, y)
			var corner := origin + Vector2i.ONE
			if not flowers.has(corner):
				continue
			var color: int = flowers[corner].color
			var old: bool = is_flower(before, corner, color)
			var perimeter := -100.0
			for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				for direction in range(4):
					var neighbor: Vector2i = offset + OFFSETS[direction]
					if neighbor.x in [0, 1] and neighbor.y in [0, 1]:
						perimeter = maxf(perimeter, components[key("arm_" + DIR_NAMES[direction], color, origin + offset)].end)
			var center := Vector2(origin) + Vector2.ONE
			var body := _add("colony_body", color, origin, center, old, perimeter, component_duration("colony_body"))
			var complete: float = body.end
			for id: String in ["colony_fold_ne", "colony_fold_sw", "colony_fingers_nw", "colony_fingers_se"]:
				var event := _add(id, color, origin, center, old, dependent_start(id, {"colony_body": body}), component_duration(id))
				complete = maxf(complete, event.end)
			colonies[origin] = {"origin": origin, "color": color, "old": old, "start": perimeter, "ready": complete, "end": complete}
			flowers[corner].start = perimeter
			flowers[corner].old = old
	for pair: Dictionary in Topology.adjacent_pairs(colonies):
		var a: Vector2i = pair.a
		var b: Vector2i = pair.b
		var layout := union_layout(b - a)
		var identity := "anemone/%d/%d/%d/%d/%d" % [colonies[a].color, a.y, a.x, b.y, b.x]
		var center := (Vector2(a) + Vector2(b)) / 2 + Vector2.ONE
		var old: bool = colonies[a].old and colonies[b].old
		var ready: float = maxf(colonies[a].ready, colonies[b].ready)
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
