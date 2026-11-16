extends RefCounted
# Ordinary Coral metadata is live set data; higher tiers retain their adapter.
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const REVEAL = preload("res://art/themes/coral_reef/shaders/growth_reveal.gdshader")
const ROOT := "res://art/themes/coral_reef/sets/"
static var tier0: Dictionary = {}
static var tier1: Dictionary = {}
static var catalog: Dictionary = {}

static func install() -> void:
	if not tier0.is_empty(): return
	Renderer.register_material_provider("coral.reveal", _reveal)
	tier0 = Assets.load_set(ROOT + "tier0.json")
	tier1 = Assets.load_set(ROOT + "tier1.json")
	assert(tier0.ok and tier1.ok, str(tier0.errors + tier1.errors))
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

static func vines(mask: int) -> Dictionary:
	install()
	return Cells.connected_parts(Cells.parts_for_role(tier1, "vine"), mask)

static func propagation() -> Dictionary:
	install()
	return tier1.definition.propagation

static func render_spec(event: Dictionary, settled: bool) -> Dictionary:
	var spec: Dictionary = part(event.id).duplicate(true)
	var bound := Assets.bind_part(spec, tier0.definition.treatments[str(event.color)])
	assert(bound.ok, str(bound.errors))
	spec = bound.part
	spec.position_cells = event.center
	spec.rotation_radians = (event.rotation + float(spec.quarter_turns)) * PI / 2
	spec.erase("quarter_turns")
	if settled or event.old: spec.material = null
	else:
		var params: Dictionary = spec.material.params
		params.artwork = spec.asset
		params.growth_mask = spec.masks.reveal.asset
		params.asset_root = spec.asset_root
		params.growth_mask_rotation_radians = deg_to_rad(float(spec.masks.reveal.rotation_degrees))
		params.start_at_zero = event.start
		params.start_at_one = event.reverse
		params.stroke_seconds = event.stroke
		params.front_one_enabled = event.two_fronts
	return spec

static func _reveal(params: Dictionary) -> ShaderMaterial:
	# Static composition has no event clock/fronts; display the original artwork.
	if not params.has("artwork"): return null
	var uniforms: Dictionary = params.duplicate()
	uniforms.artwork = Assets.resolve(params.artwork, params.asset_root)
	uniforms.growth_mask = Assets.resolve(params.growth_mask, params.asset_root)
	uniforms.erase("asset_root")
	return Renderer.material(REVEAL, uniforms)
