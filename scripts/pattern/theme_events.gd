extends RefCounted

# Collect live theme events into the shared lifecycle. Geometry, clocks and
# persistent history stay owned by their theme; no nodes enter common state.
const Formations = preload("res://scripts/pattern/formation_assembly.gd")
const Growth = preload("res://scripts/growth.gd")
const Landmark = preload("res://scripts/zen_landmark.gd")
const Pond = preload("res://scripts/zen_pond.gd")
const Trees = preload("res://scripts/zen_trees.gd")
const Centerpiece = preload("res://scripts/zen_centerpiece.gd")
const Schedule = preload("res://scripts/pattern/growth_schedule.gd")

static func _put(events: Dictionary, id: String, start: float, end: float, old: bool, owner: Variant = null, retiring: bool = false) -> void:
	events[id] = {"start": start, "end": end, "old": old, "owner": owner, "retiring": retiring}

static func _part(events: Dictionary, prefix: String, key: String, event: Dictionary) -> void:
	var start: float = event.start
	if event.get("two_fronts", false): start = minf(start, event.reverse)
	if event.has("edge_start"): start = minf(start, event.edge_start)
	_put(events, prefix + key, start, event.end, event.old, event.get("cell", event.get("feature", key)))

static func collect(model, theme: String, zen = null, workshop = null) -> Dictionary:
	var events: Dictionary = {}
	var prefix := theme + "/"
	if theme == "clockwork":
		var parts: Dictionary = model.components.duplicate()
		if workshop != null:
			for key: String in workshop.registry: parts[key] = workshop.registry[key].event
		for key: String in parts: _part(events, prefix + "part/", key, parts[key])
		var chains: Dictionary = model.chains if workshop == null else workshop.chain_nodes
		for key: String in chains: _part(events, prefix + "chain/", key, chains[key] if workshop == null else chains[key].event)
		if workshop != null:
			for entry: Dictionary in workshop.retiring:
				var id: String = prefix + ("chain/" if entry.event.id == "chain" else "part/") + entry.event.key
				_put(events, id, entry.retire_at, entry.retire_end, false, entry.event.get("cell", entry.event.key), true)
	elif theme == "coral_reef":
		for key: String in model.components: _part(events, prefix + "part/", key, model.components[key])
	elif theme == "zen_garden" and zen != null:
		_zen(events, prefix, model, zen)
	else:
		for cell: Vector2i in model.arrivals:
			var at: float = model.arrivals[cell]
			_put(events, prefix + "cell/%d/%d/%d" % [model.board[cell.y][cell.x], cell.y, cell.x], at, at + Growth.CENTER_POP, at < 0, cell)
		for edge: Dictionary in model.edges:
			_put(events, prefix + "edge/%d/%s" % [edge.color, str(Growth.edge_key(edge.a, edge.b))], minf(edge.start_a, edge.start_b), edge.finish + maxf(maxf(Growth.RIPPLE, Growth.STAR_POP), Growth.LEAF_POP), edge.old, [edge.a, edge.b])
		for link: Dictionary in model.links:
			var seconds := Growth.LINK_GROW + Growth.STAR_POP
			_put(events, prefix + "connection/%d/%s" % [link.color, str(Growth.edge_key(link.a, link.b))], link.start, link.start + seconds, link.old, [link.a, link.b])
	events.merge(Formations.state_events(model.tier2_records(), theme, events))
	# Decoration events enter the existing lifecycle after structural formation
	# dependencies were collected. Their tail cannot move higher-tier starts.
	for id: String in model.sprite_growth_events:
		if events.has(id):
			push_error("Sprite timing identity collides with a structural event: " + id)
			continue
		events[id] = model.sprite_growth_events[id].duplicate(true)
	return events

static func _zen(events: Dictionary, prefix: String, model, zen) -> void:
	for cell: Vector2i in model.arrivals:
		var at: float = model.arrivals[cell]
		_put(events, prefix + "pattern/%d/%d/%d" % [model.board[cell.y][cell.x], cell.y, cell.x], at, at + Landmark.PATTERN_SECONDS, at < 0, cell)
	for cell: Vector2i in zen.centerpieces:
		var center = zen.centerpieces[cell]
		for stage in range(center.stage):
			var old: bool = not center.growing.has(stage)
			var start: float = center.growing.get(stage, Schedule.SETTLED_AT)
			_put(events, prefix + "center/%d/%d/%d" % [cell.y, cell.x, stage], start, start + Centerpiece.GROW_SECONDS, old, cell)
	if zen.pond != null:
		for key: String in zen.pond.regions:
			var start: float = zen.pond.regions[key].start
			_put(events, prefix + "water/" + key, start, start + Pond.FILL_SECONDS, start == Schedule.SETTLED_AT, key)
		for key: String in zen.pond.plants:
			var start: float = zen.pond.plants[key].start
			_put(events, prefix + "shrub/" + key, start + Pond.FILL_SECONDS, start + Pond.FILL_SECONDS + Pond.PLANT_SECONDS, start == Schedule.SETTLED_AT, key)
	if zen.trees != null:
		for key: String in zen.trees.trunks:
			var start: float = zen.trees.trunks[key].start
			_put(events, prefix + "trunk/" + key, start, start + Trees.TRUNK_SECONDS, start == Schedule.SETTLED_AT, key)
		for id: int in zen.trees.branches:
			var start: float = zen.trees.branches[id].start
			_put(events, prefix + "branch/%d" % id, start, start + Trees.BRANCH_SECONDS, start == Schedule.SETTLED_AT, id)
