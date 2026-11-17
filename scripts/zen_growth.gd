extends "res://scripts/coral_growth.gd"

# Reuse Coral's same-color waves and formation detection. Zen supplies its own
# landmark timing and artwork; no Coral bloom artwork is rendered.
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Sets = preload("res://scripts/zen_sets.gd")
var ponds: Dictionary = {}
var groves: Array = []
func build(before: Array, after: Array) -> void:
	super.build(before, after)
	components.clear()
	flowers.clear()
	links.clear()
	var stone_timing: Dictionary = Themes.profile("zen_garden").get("tier1_artwork", {})
	var stone_scale: float = stone_timing.get("progression_scale", 1.0)
	var stone_seconds: float = stone_timing.get("duration_sec", 0.30)
	for cell: Vector2i in arrivals:
		if value(after, cell) == 2 and float(arrivals[cell]) >= 0: arrivals[cell] *= stone_scale
	duration = 0.0
	for cell: Vector2i in arrivals:
		if float(arrivals[cell]) >= 0:
			duration = maxf(duration, float(arrivals[cell]) + (stone_seconds if value(after, cell) == 2 else 0.30))
	var formations := Formations.collect(before, after)
	for origin: Vector2i in colonies:
		var formation: Dictionary = colonies[origin]
		var animation: Dictionary = Sets.formation_part(formation.color).animation
		var latest := -100.0
		for cell: Vector2i in formations[origin].cells:
			latest = maxf(latest, float(arrivals[cell]))
		formation.pattern_end = latest + (maxf(float(animation.pattern_seconds), stone_seconds) if formation.color == 2 else float(animation.pattern_seconds))
		formation.start = -100.0 if formation.old else formation.pattern_end + float(animation.hold_seconds)
		formation.end = formation.start + float(animation.duration_seconds)
		formation.ready = formation.end
		if not formation.old: duration = maxf(duration, formation.end)

	# Use the same adjacent-formation rule as Coral. Each new connection
	# activates the facing watershed on both formations, never diagonal ones.
	ponds.clear()
	for side: Dictionary in Connections.directed_sides(colonies, 2):
		var origin: Vector2i = side.origin
		var direction: int = side.direction
		var old: bool = side.old
		var start := Connections.start(side, colonies)
		ponds["%d/%d/%d" % [origin.y, origin.x, direction]] = {"origin": origin, "direction": direction, "old": old, "start": start}
		if not old:
			duration = maxf(duration, start + preload("res://scripts/zen_pond.gd").FILL_SECONDS + preload("res://scripts/zen_pond.gd").PLANT_SECONDS)

	groves = preload("res://scripts/zen_trees.gd").clusters(colonies)
	for grove: Dictionary in groves:
		if not grove.old: duration = maxf(duration, grove.start + preload("res://scripts/zen_trees.gd").GROW_SECONDS)
