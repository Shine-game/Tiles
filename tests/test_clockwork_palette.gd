extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Model = preload("res://scripts/clockwork_growth.gd")
const Visuals = preload("res://scripts/clockwork_visuals.gd")
const Sets = preload("res://scripts/clockwork_sets.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Palette.select_theme("clockwork")
	for color in [1, 2]:
		var primary: String = "copper" if color == 1 else "gunmetal"
		var secondary: String = "gunmetal" if color == 1 else "copper"
		var board: Array = Rules.empty_board(9)
		for y in range(2, 6):
			for x in range(2, 6): board[y][x] = color
		var model = Model.new()
		model.build(board, board)
		var visuals = Visuals.new()
		root.add_child(visuals)
		visuals.reconcile(model, true, false)
		visuals.set_process(false)
		var examples: Dictionary = {}
		for entry: Dictionary in visuals.registry.values():
			examples[entry.event.id] = entry
		for id: String in ["C01", "C02", "C03", "T01", "T03", "L01", "H00_plain_hatch", "H02_rotating", "H03_exhaust", "J00_chain_junction"]:
			if not examples.has(id): continue
			var part: Dictionary = Sets.part(id) if Sets.owns(id) else Sets.special_part(id)
			var bound := Assets.bind_part(part,secondary if id=="L01" else primary)
			check(examples[id].node.texture == Assets.part_texture(bound.part), "Renamed sprite preserves artwork treatment for "+id)
		check(not examples.has("T02"), "tube-to-wheel collars are not rendered")
		check(not examples.has("L02") and not examples.has("L03"), "removed wheel layers stay unused")
		for id: String in ["H01_valve", "H00_left_shutter", "H00_right_shutter", "H03_opaque_underlay", "H03_shutters_left", "H03_shutters_right"]:
			check(Visuals.art_variant(id, color) == primary, "all finishing top/support variants keep their primary metal")
		var chain: Dictionary = visuals.chain_nodes.values()[0]
		for strip: ColorRect in chain.strips:
			var link: Texture2D = strip.material.get_shader_parameter("link_art")
			check(link.resource_path == Assets.part_texture(Assets.bind_part(Sets.special_part("CH01_link"),primary).part).resource_path, "both batched chain runs use the primary metal")
			check(strip.material.get_shader_parameter("link_scale") == 2.0 and strip.size.y == 128.0, "chain links are doubled in both dimensions")
		check(Visuals.CHAIN_PITCH == 58.0 and ceili(256.0 / Visuals.CHAIN_PITCH) == 5, "doubled pitch reduces each run from about nine links to five")
		check(examples.J00_chain_junction.node.scale == Vector2.ONE * 1.2, "return housing gives wider links clearance")
		check(model.components.values().all(func(event: Dictionary): return event.color == color) and model.chains.values().all(func(event: Dictionary): return event.color == color), "artwork alternation never changes logical color")
		check(model.mechanisms.size() == 9 and model.chains.size() == 12, "artwork split preserves the mechanism graph")
		check(examples.pin.node.texture.resource_path == Assets.part_texture(Assets.bind_part(Sets.ground_part("pin"),primary).part).resource_path, "plate rivets retain their supporting logical color")
		visuals.queue_free()
	check(Platform.surface_revision("clockwork") == "workshop4-straight-tubes-v5", "gallery distinguishes the revised wheel layout with alternating-metal designs")
	await process_frame
	print("Clockwork palette: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
