extends SceneTree
const Sets = preload("res://scripts/coral_sets.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Model = preload("res://scripts/coral_growth.gd")
const Visuals = preload("res://scripts/coral_visuals.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	Sets.install()
	check(Sets.tier0.ok and Sets.tier1.ok and Sets.catalog.size() == 14, "Production sets own ordinary parts and the five colony parts")
	check(Cells.parts_for_role(Sets.tier1, "straight_run_decoration").is_empty(), "Unapproved tiny fingers remain omitted")
	check(Sets.propagation().cell_seconds == Model.CELL_SECONDS and Sets.part("arm_n").animation.duration_seconds == Model.HALF_SECONDS, "Public compatibility timings match live set values")
	var bad: Dictionary = Sets.tier1.definition.duplicate(true)
	bad.compositions.branching_center.parts.junction_ne.requires_mask = 16
	check(not Assets.load_set(bad, Sets.ROOT).ok, "Out-of-range required connections fail validation")
	bad.compositions.branching_center.parts.junction_ne.requires_mask = 1.5
	check(not Assets.load_set(bad, Sets.ROOT).ok, "Fractional required connections fail validation")
	var model := Model.new()
	var visuals := Visuals.new()
	root.add_child(visuals)
	var center := Vector2i(4, 4)
	for color in [1, 2]:
		var treatment := "salmon" if color == 1 else "turquoise"
		for mask in range(16):
			var board := Rules.empty_board(9)
			board[4][4] = color
			for d in range(4):
				if mask & (1 << d):
					var p: Vector2i = center + Model.OFFSETS[d]
					board[p.y][p.x] = color
			model.build(Rules.empty_board(9), board)
			visuals.reconcile(model, false, false)
			check(Sets.centers(mask).has("core") == (mask not in [5, 10]), "Only opposite two-port straights suppress their core")
			check(model.components.has(Model.key("core", color, center)) == (mask not in [5, 10]), "The model applies the shared shape role")
			for id: String in Sets.catalog:
				if id.begins_with("colony_"): continue
				var required: int = int(Sets.part(id).get("requires_mask", 0))
				var expected: bool = mask not in [5, 10] if id == "core" else (mask & required == required)
				var key := Model.key(id, color, center)
				check(model.components.has(key) == expected and visuals.registry.has(key) == expected, "Selected multipart centers and vines follow their declared connection requirements")
				if not expected: continue
				var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/coral_source_catalog.json")).components[id]
				var entry: Dictionary = model.components[key]
				var node: Sprite2D = visuals.registry[key]
				check(node.texture == Assets.texture(source.artwork[treatment], Model.ROOT), "Both treatments use the exact original canonical texture")
				check(node.position == Vector2(4.5, 4.5) * 256 and node.offset == Vector2.ZERO, "Set anchor and pivot preserve source placement")
				check(is_equal_approx(node.rotation, deg_to_rad(float(source.get("artwork_rotation_clockwise", 0)))), "Set orientation preserves every canonical arm/junction rotation")
				check(node.get_parent().z_index == int(Sets.part(id).group_z_index), "Ordinary painter groups use declared set layers")
				check(entry.stroke == source.animation.duration_seconds and entry.bucket == int(source.layer), "Animation timings and legacy event bands match the source")
				check(node.material.get_shader_parameter("growth_mask") == Visuals.texture(source.reveal_mask), "Directional junction fields are not replaced by canonical artwork paths")
				check(is_equal_approx(node.material.get_shader_parameter("growth_mask_rotation_radians"), deg_to_rad(float(source.get("growth_mask_rotation_clockwise", 0)))), "Junction mask UV rotation remains independent of sprite rotation")
				check(node.material.get_shader_parameter("front_one_enabled") == entry.two_fronts, "Existing two-front reveals remain attached to live event clocks")
	# A definition edit changes role selection through shared data alone.
	var alternate: Dictionary = Sets.tier1.duplicate(true)
	alternate.definition.roles.straight = "endpoint"
	check(Cells.center_parts(5, Sets.tier0, alternate).has("core") and not Sets.centers(5).has("core"), "The common role table controls suppression")
	var before := Rules.empty_board(9)
	before[4][3] = 1
	before[4][4] = 1
	model.build(before, before)
	visuals.reconcile(model, true, false)
	var arm_key := Model.key("arm_w", 1, center)
	var survivor: Sprite2D = visuals.registry[arm_key]
	var after := before.duplicate(true)
	after[4][5] = 1
	model.build(before, after)
	visuals.reconcile(model, false)
	check(not visuals.registry.has(Model.key("core", 1, center)) and visuals.registry[arm_key] == survivor, "Continuing an endpoint removes only its core and preserves the existing vine node")
	var branched := after.duplicate(true)
	branched[3][4] = 1
	model.build(after, branched)
	visuals.reconcile(model, false)
	var restored: Dictionary = model.components[Model.key("core", 1, center)]
	check(not restored.old and restored.start == 0 and restored.end > 0, "A former straight gets a newly scheduled centerpiece even though its cell is old")
	check(visuals.registry[Model.key("core", 1, center)].material != null, "Newly required cores use the existing growth shader")
	visuals.advance(100)
	check(visuals.active.is_empty(), "Completed shared ordinary reveals release the growth gate")
	model.build(after, before)
	visuals.reconcile(model, true)
	check(visuals.registry.has(Model.key("core", 1, center)) and visuals.registry[arm_key] == survivor, "Helper restoration recovers the endpoint without replacing surviving vine artwork")
	var mixed := before.duplicate(true)
	mixed[4][5] = 2
	model.build(mixed, mixed)
	check(model.components.has(Model.key("core", 1, center)), "A different-color neighbor does not turn an endpoint into a straight")
	var parent := Node2D.new()
	root.add_child(parent)
	var renderer := Renderer.new()
	check(renderer.compose(Sets.tier0, "isolated", parent, null, "probe", "salmon"), "The generic renderer can draw a static production composition")
	check(renderer.nodes["probe/core"].material == null, "Static composition displays the original artwork without an unbound event shader")
	renderer.clear()
	parent.queue_free()
	for id: String in ["colony_body", "colony_fold_ne"]: check(Sets.owns(id), "Tier 2 colony parts use live sets")
	for id: String in ["anemone_foot", "anemone_region_0", "ground_01"]: check(not Sets.owns(id), "Tier 3 and ground stay outside this migration")
	Palette.select_theme("coral_reef")
	check(Palette.theme_version() == "2.2", "New core suppression has a distinct saved appearance version")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("art/themes/coral_reef/sets/*.json"), "Production sets are included in Android exports")
	visuals.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await check_straight_joins()
	print("Coral sets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_straight_joins() -> void:
	for color in [1, 2]:
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var grid := Rules.empty_board(9)
			for i in range(-1, 2):
				var p: Vector2i = Vector2i(4, 4) + direction * i
				grid[p.y][p.x] = color
			var view := SubViewport.new()
			view.size = Vector2i(256, 256)
			view.transparent_bg = true
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(view)
			var model := Model.new()
			model.build(grid, grid)
			var layer := Visuals.new()
			view.add_child(layer)
			layer.position = Vector2(128, 128) - Vector2(4.5, 4.5) * 256
			layer.reconcile(model, true, false)
			for key: String in layer.registry: layer.registry[key].visible = model.components[key].id.begins_with("arm_")
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := view.get_texture().get_image()
			var continuous := true
			for i in range(4, 252):
				var p := Vector2i(i, 128) if direction.x else Vector2i(128, i)
				if picture.get_pixelv(p).a < 0.9: continuous = false
			check(continuous, "Opposing arms make a continuous straight without a replacement core")
			view.queue_free()
			await process_frame
