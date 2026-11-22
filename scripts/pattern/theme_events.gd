extends RefCounted

# Collect live theme events into the shared lifecycle. Geometry, clocks and
# persistent history stay owned by their theme; no nodes enter common state.
const Formations = preload("res://scripts/pattern/formation_assembly.gd")
const Growth = preload("res://scripts/growth.gd")

static func _put(events: Dictionary, id: String, start: float, end: float, old: bool, owner: Variant = null, retiring: bool = false) -> void:
	events[id] = {"start": start, "end": end, "old": old, "owner": owner, "retiring": retiring}

static func _part(events: Dictionary, prefix: String, key: String, event: Dictionary) -> void:
	var start: float = event.start
	if event.get("two_fronts", false): start = minf(start, event.reverse)
	if event.has("edge_start"): start = minf(start, event.edge_start)
	_put(events, prefix + key, start, event.end, event.old, event.get("cell", event.get("feature", key)))

static func collect(model, theme: String, workshop = null) -> Dictionary:
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
