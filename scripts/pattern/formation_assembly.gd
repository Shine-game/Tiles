class_name PatternFormationAssembly
extends RefCounted
const Topology = preload("res://scripts/pattern/topology.gd")
const Timing = preload("res://scripts/pattern/growth_schedule.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")

static func identity(origin: Vector2i, color: int) -> String:
	return "tier2/%d/%d/%d" % [color, origin.y, origin.x]

static func collect(before: Array, after: Array) -> Dictionary:
	var records := Topology.formations(after)
	for origin: Vector2i in records:
		var record: Dictionary = records[origin]
		record.id = identity(origin, record.color)
		record.old = Topology.is_formation(before, origin, record.color)
	return records

static func perimeter(record: Dictionary) -> Array:
	# Clockwise NW/NE/SE/SW preserves the existing edge traversal order.
	var cells: Array = record.cells
	return [cells[0], cells[1], cells[3], cells[2]]

static func internal_ready(record: Dictionary, parts: Dictionary, key: Callable, core_ids: Array, arm_prefix: String, names: Array, floor_time: float) -> float:
	var ready := floor_time
	for cell: Vector2i in record.cells:
		for id: String in core_ids:
			ready = maxf(ready, float(parts[key.call(id, record.color, cell)].end))
		for direction in range(4):
			if not record.cells.has(cell + Topology.DIRECTIONS[direction]): continue
			var id: String = key.call(arm_prefix + names[direction], record.color, cell)
			if parts.has(id): ready = maxf(ready, float(parts[id].end))
	return ready

static func prerequisite_ready(record: Dictionary, events: Dictionary, key: Callable, loaded: Dictionary) -> float:
	var policy: Dictionary = loaded.definition.schedule
	return internal_ready(record, events, key, policy.support_parts, policy.port_prefix, policy.port_names, float(policy.floor_time))

static func completion(loaded: Dictionary, start: float, events: Dictionary) -> float:
	var policy: Dictionary = loaded.definition.schedule
	return start + float(policy.completion_offset_seconds) if policy.has("completion_offset_seconds") else ready(events)

static func assemble(record: Dictionary, parts: Dictionary, start: float, emit: Callable) -> Dictionary:
	# Emit complete legacy-compatible events, so dependencies can consume the
	# same two-front arrival fields as the existing specialized scheduler.
	var events: Dictionary = {}
	for id: String in parts:
		var spec: Dictionary = parts[id]
		var at := start + float(spec.animation.get("offset_seconds", 0.0))
		if not spec.animation.get("dependencies", []).is_empty(): at = Timing.dependent_start(spec.animation.dependencies, events)
		events[id] = emit.call(id, spec, record, at, float(spec.animation.duration_seconds))
	return events

static func ready(events: Dictionary, floor_time: float = -100.0) -> float:
	var finish := floor_time
	for event: Dictionary in events.values(): finish = maxf(finish, float(event.end))
	return finish

static func parts(loaded: Dictionary) -> Dictionary:
	return Cells.parts_for_role(loaded, "formation")

static func bind_records(grid: Array, features: Dictionary, end_field: String = "", seconds: float = 0.0, key_offset: Vector2i = Vector2i.ZERO) -> Dictionary:
	var records := collect(grid, grid)
	for origin: Vector2i in records:
		var feature: Dictionary = features[origin + key_offset]
		var record: Dictionary = records[origin]
		record.start = float(feature.start)
		record.end = float(feature[end_field]) if not end_field.is_empty() else record.start + seconds
		record.old = feature.old
	return records

static func state_events(records: Dictionary, theme: String, sources: Dictionary = {}) -> Dictionary:
	var events: Dictionary = {}
	for record: Dictionary in records.values():
		var event := {"start": record.start, "end": record.end, "old": record.old, "owner": record.origin, "supports": record.cells, "color": record.color, "center": record.center}
		# A supported formation may still have surviving parts growing
		# after a helper. Their rebased clocks take precedence over board-old status.
		if record.old:
			var start := INF
			var finish := -INF
			for id: String in record.get("children", []):
				var child: Dictionary = sources.get(id, {})
				if child.is_empty() or child.old: continue
				start = minf(start, float(child.start))
				finish = maxf(finish, float(child.end))
			if finish > 0:
				event.start = start
				event.end = finish
				event.old = false
		events[theme + "/" + record.id] = event
	return events

static func validate_schedule(parts: Dictionary) -> Array:
	var issues: Array = []
	var seen: Dictionary = {}
	for id: String in parts:
		var animation: Variant = parts[id].get("animation")
		if not animation is Dictionary:
			issues.append(id + ": missing formation animation")
			continue
		for field: String in ["duration_seconds", "offset_seconds"]:
			var value: Variant = animation.get(field, 0.0 if field == "offset_seconds" else null)
			if not (value is int or value is float) or float(value) < 0: issues.append(id + ": invalid " + field)
		var dependencies: Variant = animation.get("dependencies", [])
		if not dependencies is Array: issues.append(id + ": dependencies must be an array")
		else:
			for dependency: Variant in dependencies:
				if not dependency is Dictionary or not seen.has(dependency.get("component", "")): issues.append(id + ": dependency must refer to an earlier part")
		seen[id] = true
	return issues
