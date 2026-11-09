class_name CoralGrowth
extends "res://scripts/growth.gd"

const ROOT := "res://art/themes/coral_reef/"
const SOFT := 0.035
const CELL_SECONDS := 0.20
const HALF_SECONDS := 0.10
# Enlarged side branches attach earlier along each half-arm to stay inside its cell.
const DETAIL_ATTACHMENTS := [0.18, 0.40]
const DIR_NAMES := ["n", "e", "s", "w"]
const OFFSETS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
static var manifest: Dictionary = {}
var components: Dictionary = {}
var colonies: Dictionary = {}
var unions: Dictionary = {}

static func specification() -> Dictionary:
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "theme_manifest.json"))
	return manifest

static func key(kind: String, color: int, cell: Vector2i) -> String:
	return "%s/%d/%d/%d" % [kind, color, cell.y, cell.x]

static func arrival(event: Dictionary, u: float) -> float:
	return minf(event.start + u * event.stroke, event.reverse + (1 - u) * event.stroke) if event.two_fronts else event.start + u * event.stroke

static func end_time(start: float, reverse: float, stroke: float, two_fronts: bool) -> float:
	var peak: float = clampf((reverse + stroke - start) / (2 * stroke), 0, 1) if two_fronts else 1.0
	return (minf(start + peak * stroke, reverse + (1 - peak) * stroke) if two_fronts else start + stroke) + SOFT

func _add(id: String, color: int, cell: Vector2i, center: Vector2, old: bool, start: float, stroke: float, reverse: float = 0, two_fronts: bool = false, rotation: int = 0, identity: String = "") -> Dictionary:
	var meta: Dictionary = specification().components[id]
	var event := {"key": key(id, color, cell) if identity.is_empty() else identity, "id": id, "color": color, "center": center, "size": Vector2(meta.size_px[0], meta.size_px[1]), "old": old, "start": -100.0 if old else start, "stroke": stroke, "reverse": -100.0 if old else reverse, "two_fronts": two_fronts, "rotation": rotation, "end": -100.0 if old else end_time(start, reverse, stroke, two_fronts), "bucket": int(meta.layer)}
	components[event.key] = event
	if not old:
		duration = maxf(duration, event.end)
	return event

static func union_layout(delta: Vector2i) -> Dictionary:
	for layout: Dictionary in specification().reef_unions.canonical_layouts:
		var offset := Vector2i(int(layout.colony_origin_delta[0]), int(layout.colony_origin_delta[1]))
		for turns in range(4):
			if delta == offset or delta == -offset:
				return {"id": layout.id, "rotation": turns}
			offset = Vector2i(-offset.y, offset.x)
	return {}

func build(before: Array, after: Array) -> void:
	super.build(before, after)
	components.clear()
	colonies.clear()
	unions.clear()
	duration = 0
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
					arrivals[cell] = CELL_SECONDS
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
					if group.has(other) and float(arrivals[other]) > float(arrivals[cell]) + CELL_SECONDS:
						arrivals[other] = float(arrivals[cell]) + CELL_SECONDS
						wave.append(other)
	for cell: Vector2i in arrivals:
		var color: int = value(after, cell)
		var old: bool = value(before, cell) == color
		var center := Vector2(cell) + Vector2(0.5, 0.5)
		_add("core", color, cell, center, old, arrivals[cell], 0.18)
		for direction in range(4):
			var other: Vector2i = cell + OFFSETS[direction]
			if value(after, other) != color:
				continue
			var old_arm: bool = old and value(before, other) == color
			var start: float = 0.10 if independent.has(cell) else maxf(0, arrivals[cell])
			var reverse: float = 0.20 if independent.has(cell) else maxf(0, arrivals[other]) + HALF_SECONDS
			var name: String = DIR_NAMES[direction]
			var arm := _add("arm_" + name, color, cell, center, old_arm, start, HALF_SECONDS, reverse, true)
			for index in range(2):
				var u: float = DETAIL_ATTACHMENTS[index]
				_add("detail_%s_%d" % [name, index], color, cell, center, old_arm, arrival(arm, u) + 0.08, 0.16)
	# Iterate in canonical row/column order; later placements append their own
	# feature groups above surviving groups rather than sorting their layers apart.
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
			var fringe := _add("colony_fringe", color, origin, center, old, perimeter, 0.20)
			var lobes := _add("colony_lobes", color, origin, center, old, perimeter, 0.38)
			var finish := _add("colony_finish", color, origin, center, old, lobes.end, 0.12)
			colonies[origin] = {"origin": origin, "color": color, "old": old, "start": perimeter, "ready": maxf(fringe.end, lobes.end), "end": finish.end}
			flowers[corner].start = perimeter
			flowers[corner].old = old
	var origins: Array = colonies.keys()
	for i in range(origins.size()):
		var a: Vector2i = origins[i]
		for j in range(i + 1, origins.size()):
			var b: Vector2i = origins[j]
			if colonies[a].color != colonies[b].color:
				continue
			var layout := union_layout(b - a)
			if layout.is_empty():
				continue
			var identity := "union/%d/%d/%d/%d/%d" % [colonies[a].color, a.y, a.x, b.y, b.x]
			var center := (Vector2(a.min(b)) + Vector2(a.max(b) + Vector2i(2, 2))) / 2
			var event := _add(layout.id, colonies[a].color, a, center, colonies[a].old and colonies[b].old, maxf(colonies[a].ready, colonies[b].ready), 0.76, maxf(colonies[a].ready, colonies[b].ready), true, layout.rotation, identity)
			unions[identity] = event
			unions[identity].a = a
			unions[identity].b = b

func grid_visibility(a: Vector2i, b: Vector2i, time: float) -> float:
	if value(board, a) != 0 and value(board, b) == value(board, a):
		var direction: int = OFFSETS.find(b - a)
		if direction >= 0:
			var arm: Dictionary = components[key("arm_" + DIR_NAMES[direction], value(board, a), a)]
			var crossing: float = arrival(arm, 1)
			return 1.0 - smoothstep(crossing, crossing + GRID_FADE, time)
	return super.grid_visibility(a, b, time)
