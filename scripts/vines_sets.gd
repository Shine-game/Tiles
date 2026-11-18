extends RefCounted
const Junctions = preload("res://scripts/pattern/junction_layer.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Formations = preload("res://scripts/pattern/formation_assembly.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Components = preload("res://scripts/pattern/component_renderer.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const Topology = preload("res://scripts/pattern/topology.gd")
const Art = preload("res://scripts/vines_renderer.gd")
const ROOT := "res://art/themes/vines/sets/"
static var tier0: Dictionary = {}
static var tier1: Dictionary = {}
static var tier2: Dictionary = {}
static var renderer := Components.new()

static func install() -> void:
	if not tier0.is_empty(): return
	Components.register_draw_part_provider("vines.holding", Art.holding)
	Components.register_draw_part_provider("vines.connection", Art.connection)
	Components.register_draw_part_provider("vines.wash", Art.wash)
	Components.register_draw_part_provider("vines.flower", Art.flower)
	Components.register_draw_part_provider("vines.layered_post", Art.layered_post)
	tier0 = Assets.load_set(Themes.pattern_set_path("vines", 0))
	tier1 = Assets.load_set(Themes.pattern_set_path("vines", 1))
	tier2 = Assets.load_set(Themes.pattern_set_path("vines", 2))
	assert(tier0.ok and tier1.ok and tier2.ok, str(tier0.errors + tier1.errors + tier2.errors))
	assert(Formations.validate_schedule(Formations.parts(tier2)).is_empty(), "Invalid flower schedule")

static func centers(mask: int) -> Dictionary:
	install()
	return Cells.center_parts(mask, tier0, tier1)

static func identity(color: int, cell: Vector2i) -> String:
	return "vines/center/%d/%d/%d" % [color, cell.y, cell.x]

static func center_events(model, before: Array, settled: bool) -> Dictionary:
	var events: Dictionary = {}
	for cell: Vector2i in model.arrivals:
		if Junctions.handles("vines", Topology.shape(Topology.neighbor_mask(model.board, cell))): continue
		var parts := centers(Topology.neighbor_mask(model.board, cell))
		if parts.is_empty(): continue
		var color: int = model.board[cell.y][cell.x]
		var old: bool = settled or (Topology.value(before, cell) == color and not centers(Topology.neighbor_mask(before, cell)).is_empty())
		var start: float = -100.0 if old else maxf(0, model.arrivals[cell])
		var seconds: float = parts.values()[0].animation.duration_seconds
		events[identity(color, cell)] = {"start": start, "end": start + seconds, "old": old, "owner": cell}
	return events

static func center_scale(view, cell: Vector2i, spec: Dictionary) -> float:
	var record: Dictionary = view.construction_state.records.get(identity(view.board[cell.y][cell.x], cell), {})
	if record.get("phase") == "settled": return 1.0
	var start: float = record.get("start", view.pattern.arrivals[cell])
	return minf(1, view.pop((view.clock - start) / float(spec.animation.duration_seconds)))

static func draw(view) -> void:
	install()
	for cell: Vector2i in view.pattern.arrivals:
		var loaded: Dictionary = tier0 if Topology.neighbor_mask(view.board, cell) == 0 else tier1
		renderer.draw_parts(Cells.parts_for_role(loaded, "surface"), view, {"cell": cell})
	for edge: Dictionary in ([] if view.generative_tier1 else view.pattern.edges):
		renderer.draw_parts(Cells.parts_for_role(tier1, "vine"), view, {"edge": edge})
	# Higher-tier art stays in its existing providers and painter order.
	for link: Dictionary in view.pattern.links: view._draw_link(link)
	for cell: Vector2i in view.pattern.arrivals:
		if Junctions.handles("vines", Topology.shape(Topology.neighbor_mask(view.board, cell))): continue
		var selected := centers(Topology.neighbor_mask(view.board, cell))
		for id: String in selected:
			renderer.draw_parts({id: selected[id]}, view, {"cell": cell, "scale": center_scale(view, cell, selected[id])})
	for corner: Vector2i in view.pattern.flowers:
		renderer.draw_parts(Formations.parts(tier2), view, {"corner": corner, "event": view.pattern.flowers[corner]})

static func flower() -> Dictionary:
	install()
	return Formations.parts(tier2).flower
