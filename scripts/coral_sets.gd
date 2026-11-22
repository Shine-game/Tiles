extends RefCounted
const RadialPetals = preload("res://scripts/pattern/radial_petals.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
# All Coral artwork catalogs use shared sets; specialized growth stays theme-owned.
const Assembly = preload("res://scripts/pattern/assembly.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Formations = preload("res://scripts/pattern/formation_assembly.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const REVEAL = preload("res://assets/themes/coral_reef/shaders/coral_reef_growth_reveal.gdshader")
const ROOT := "res://assets/themes/coral_reef/assembly/"
static var tier0: Dictionary = {}
static var tier1: Dictionary = {}
static var tier2: Dictionary = {}
static var catalog: Dictionary = {}
static var environment: Dictionary = {}
static var grounds: Dictionary = {}

static func install() -> void:
	if not tier0.is_empty(): return
	Renderer.register_material_provider("coral.reveal", _reveal)
	tier0 = Assets.load_set(Themes.pattern_set_path("coral_reef", 0))
	tier1 = Assets.load_set(Themes.pattern_set_path("coral_reef", 1))
	tier2 = Assets.load_set(Themes.pattern_set_path("coral_reef", 2))
	assert(tier0.ok and tier1.ok and tier2.ok, str(tier0.errors + tier1.errors + tier2.errors))
	assert(Formations.validate_schedule(Formations.parts(tier2)).is_empty(), "Invalid Tier 2 part schedule")
	environment = Assets.load_set(Themes.profile("coral_reef").environment.catalog)
	assert(environment.ok, str(environment.errors))
	catalog = Assets.catalog([tier0, tier1, tier2])
	grounds = Assets.catalog([environment])

static func ground_part(id: String) -> Dictionary:
	install()
	return grounds[id]

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
	if event.has("radial_petal"): return RadialPetals.render_spec(event, spec, settled)
	if event.id == "core":
		spec = Cells.parts_for_role(tier0, "isolated")[event.id].duplicate(true)
		spec.asset_root = tier0.root
	var bound := Assets.bind_part(spec, tier0.definition.treatments[str(event.color)])
	assert(bound.ok, str(bound.errors))
	spec = bound.part
	spec = Assembly.rotated(spec, int(event.rotation))
	spec.position_cells = event.center
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

static func formation_parts() -> Dictionary:
	install()
	return Formations.parts(tier2)

static func ground_render_spec(event: Dictionary) -> Dictionary:
	var spec: Dictionary = ground_part(event.id).duplicate(true)
	var bound := Assets.bind_part(spec, tier0.definition.treatments[str(event.color)])
	assert(bound.ok, str(bound.errors))
	spec = bound.part
	spec.position_cells = event.center
	spec.rotation_radians = event.rotation * PI / 2
	return spec
