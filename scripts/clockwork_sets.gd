extends RefCounted
# Clockwork's ordinary sets use the shared loader/selector/renderer. Existing
# pressure, operation and retirement hooks keep their legacy component IDs.
const Assembly = preload("res://scripts/pattern/assembly.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const RISE = preload("res://shaders/clockwork_rise.gdshader")
const REVEAL = preload("res://shaders/clockwork_reveal.gdshader")
const ROOT := "res://art/themes/clockwork_workshop/sets/"
const NAMES := ["N", "E", "S", "W"]
static var tier0: Dictionary = {}
static var tier1: Dictionary = {}
static var catalog: Dictionary = {}

static func install() -> void:
	if not tier0.is_empty(): return
	Renderer.register_material_provider("clockwork.rise", _rise)
	Renderer.register_material_provider("clockwork.tube", _tube)
	tier0 = Assets.load_set(ROOT + "tier0.json")
	tier1 = Assets.load_set(ROOT + "tier1.json")
	assert(tier0.ok and tier1.ok, "Invalid Clockwork ordinary sets: " + str(tier0.errors + tier1.errors))
	for loaded: Dictionary in [tier0, tier1]:
		for composition: Dictionary in loaded.definition.compositions.values():
			for id: String in composition.parts:
				var spec: Dictionary = composition.parts[id].duplicate(true)
				spec.asset_root = loaded.root
				catalog[id] = spec

static func owns(id: String) -> bool:
	install()
	return catalog.has(id)

static func part(id: String) -> Dictionary:
	install()
	return catalog[id]

static func centers(mask: int) -> Dictionary:
	install()
	return Cells.center_parts(mask, tier0, tier1)

static func role(name: String) -> Dictionary:
	install()
	return Cells.parts_for_role(tier1, name)

static func vine() -> Dictionary:
	return role("vine").values()[0]

static func join() -> Dictionary:
	return role("boundary_join").values()[0]

static func render_spec(event: Dictionary, settled: bool, straight: bool) -> Dictionary:
	var spec: Dictionary = part(event.id).duplicate(true)
	var treatment: String = tier0.definition.treatments[str(event.color)]
	var bound := Assets.bind_part(spec, treatment)
	assert(bound.ok, str(bound.errors))
	spec = bound.part
	spec = Assembly.rotated(spec, roundi(event.rotation / (PI / 2)))
	spec.position_cells = event.center
	spec.lifecycle = "external"
	spec.flip_v = spec.has("straight_flip_ports") and straight and NAMES[int(event.direction)] in spec.straight_flip_ports
	if spec.get("material", {}).get("provider", "") == "clockwork.tube":
		if settled or event.old: spec.material = null
		else:
			spec.material.params.growth_field = spec.masks.reveal.asset
			spec.material.params.asset_root = spec.asset_root
			spec.material.params.start_core = event.start
			spec.material.params.start_edge = event.edge_start
			spec.material.params.travel_seconds = event.seconds
			spec.material.params.reveal_tail_seconds = spec.animation.tail_seconds
	elif not spec.has("material"): spec.material = null
	return spec

static func _rise(params: Dictionary) -> ShaderMaterial:
	return Renderer.material(RISE, {"height_source": float(params.height_source)})

static func _tube(params: Dictionary) -> ShaderMaterial:
	return Renderer.material(REVEAL, {"growth_field": Assets.resolve(params.growth_field, params.asset_root), "start_core": params.start_core, "start_edge": params.start_edge, "edge_enabled": params.edge_enabled, "travel_seconds": params.travel_seconds, "reveal_tail_seconds": params.reveal_tail_seconds})
