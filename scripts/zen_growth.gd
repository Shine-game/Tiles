extends "res://scripts/coral_growth.gd"

# Reuse Coral's same-color waves and formation detection. Zen supplies its own
# landmark timing and artwork; no Coral bloom artwork is rendered.
var ponds: Dictionary = {}
var groves: Array = []
func build(before: Array, after: Array) -> void:
	super.build(before, after)
	components.clear()
	flowers.clear()
	links.clear()
	duration = 0.0
	for cell: Vector2i in arrivals:
		if float(arrivals[cell]) >= 0:
			duration = maxf(duration, float(arrivals[cell]) + 0.30)
	for origin: Vector2i in colonies:
		var formation: Dictionary = colonies[origin]
		var latest := -100.0
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			latest = maxf(latest, float(arrivals[origin + offset]))
		formation.pattern_end = latest + preload("res://scripts/zen_landmark.gd").PATTERN_SECONDS
		formation.start = -100.0 if formation.old else formation.pattern_end + preload("res://scripts/zen_landmark.gd").PATTERN_HOLD_SECONDS
		formation.end = formation.start + preload("res://scripts/zen_landmark.gd").GROW_SECONDS
		formation.ready = formation.end
		if not formation.old: duration = maxf(duration, formation.end)

	# Use the same adjacent-formation rule as Coral. Each new connection
	# activates the facing watershed on both formations, never diagonal ones.
	ponds.clear()
	for origin: Vector2i in colonies:
		var formation: Dictionary = colonies[origin]
		if formation.color != 2: continue
		for neighbor_info: Dictionary in Topology.formation_neighbors(colonies, origin):
			var direction: int = neighbor_info.direction
			var neighbor: Vector2i = neighbor_info.origin
			var old: bool = formation.old and colonies[neighbor].old
			var start := maxf(formation.ready, colonies[neighbor].ready)
			ponds["%d/%d/%d" % [origin.y, origin.x, direction]] = {"origin": origin, "direction": direction, "old": old, "start": -100.0 if old else start}
			if not old:
				duration = maxf(duration, start + preload("res://scripts/zen_pond.gd").FILL_SECONDS + preload("res://scripts/zen_pond.gd").PLANT_SECONDS)

	groves = preload("res://scripts/zen_trees.gd").clusters(colonies)
	for grove: Dictionary in groves:
		if not grove.old: duration = maxf(duration, grove.start + preload("res://scripts/zen_trees.gd").GROW_SECONDS)
