extends SceneTree
const Sets = preload("res://scripts/clockwork_sets.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const Visuals = preload("res://scripts/clockwork_visuals.gd")
const Rules = preload("res://scripts/rules.gd")
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
	check(Sets.tier0.ok and Sets.tier1.ok, "Both production sets use the shared validated format")
	check(Sets.tier0.definition.tier == 0 and Sets.tier1.definition.tier == 1, "One set describes each ordinary tier")
	check(Sets.role("straight_run_decoration").is_empty() and Sets.role("wheel_collar").is_empty(), "Unapproved long-run decoration and omitted collars remain unused")
	check(Sets.vine().animation.duration_seconds == Clock.HALF_TRAVEL and Sets.vine().animation.tail_seconds == Clock.REVEAL_TAIL and Sets.vine().animation.center_emit_delay_seconds == Clock.CORE_EMIT_DELAY, "Public compatibility timing values still match the authoritative sets")
	var model := Clock.new()
	var visuals := Visuals.new()
	root.add_child(visuals)
	visuals.set_process(false)
	for color in [1, 2]:
		for mask in range(16):
			var grid := Rules.empty_board(9)
			var center := Vector2i(4, 4)
			grid[4][4] = color
			for d in range(4):
				if mask & (1 << d):
					var cell: Vector2i = center + [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][d]
					grid[cell.y][cell.x] = color
			model.build(Rules.empty_board(9), grid)
			visuals.reconcile(model, true, false)
			var wheel := mask not in [5, 10]
			check(Sets.centers(mask).size() == (3 if wheel else 0), "Role selection chooses a complete centerpiece only on non-straights")
			for id: String in ["C01", "C02", "C03"]:
				var key := Clock.key(id, color, center)
				check(model.components.has(key) == wheel and visuals.ordinary_components.nodes.has(key) == wheel, "Selected centerparts are drawn by the common persistent renderer")
				if not wheel: continue
				var entry: Dictionary = visuals.registry[key]
				var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/clockwork_source_catalog.json")).components[id]
				var treatment := "copper" if color == 1 else "gunmetal"
				check(entry.node.texture == Assets.texture(source.assets[treatment], Clock.ROOT), "Treatment selection preserves the actual original metal artwork")
				check(entry.node.position == Vector2(4.5, 4.5) * 256 and entry.node.offset == Vector2.ZERO, "Set pivots/anchors preserve the centered assembly")
				check(entry.event.seconds == Sets.part(id).animation.duration_seconds and entry.event.layer == source.layer, "Set animation and event bands preserve legacy timing/layers")
			for d in range(4):
				if not mask & (1 << d): continue
				var key := Clock.key("T01_" + Clock.NAMES[d], color, center)
				var node: Sprite2D = visuals.ordinary_components.nodes[key]
				check(node.flip_v == (not wheel and d in [2, 3]), "Declared straight-port flips preserve the existing shading workaround")
				check(node.texture == Assets.texture("artwork/%s/clockwork_tier1_pipe_color%d_1.png" % [("copper" if color == 1 else "gunmetal"),color], Clock.ROOT), "Directional vines still share the original canonical image")
	# Prove the shared shape selector reads configuration rather than a wheel-specific branch.
	var alternate: Dictionary = Sets.tier1.duplicate(true)
	alternate.definition.roles.straight = "centerpiece"
	check(Cells.center_parts(5, Sets.tier0, alternate).size() == 3 and Sets.centers(5).is_empty(), "Shared selection follows the supplied role table without changing the real set")
	var parent := Node2D.new()
	root.add_child(parent)
	var renderer := Renderer.new()
	for treatment in ["copper", "gunmetal"]:
		check(renderer.compose(Sets.tier0, "isolated", parent, null, "probe", treatment), "Generic composition supports a selected treatment")
		check(renderer.nodes["probe/C02"].texture == Assets.texture("artwork/%s/clockwork_tier0_core_color%d_2.png" % [treatment,1 if treatment=="copper" else 2], Clock.ROOT), "The generic renderer binds the requested variant")
	var old_ids: Array = renderer.nodes.values().map(func(node): return node.get_instance_id())
	check(not renderer.compose(Sets.tier0, "isolated", parent, null, "probe", "unknown"), "Missing treatments fail explicitly instead of substituting metal artwork")
	check(old_ids == renderer.nodes.values().map(func(node): return node.get_instance_id()), "Failed treatment selection keeps the current assembly intact")
	var endpoint := Rules.empty_board(9)
	endpoint[4][3] = 1
	endpoint[4][4] = 1
	var straight := endpoint.duplicate(true)
	straight[4][5] = 1
	model.build(endpoint, endpoint)
	visuals.reconcile(model, true, false)
	var survivor := Clock.key("T01_E", 1, Vector2i(3, 4))
	var survivor_id: int = visuals.registry[survivor].node.get_instance_id()
	model.build(endpoint, straight)
	visuals.reconcile(model, false, true)
	check(not visuals.ordinary_components.nodes.has(Clock.key("C02", 1, Vector2i(4, 4))), "Extending an endpoint releases its centerpiece from the common owner")
	check(visuals.registry[survivor].node.get_instance_id() == survivor_id, "Existing vines retain their render nodes through topology changes")
	visuals.advance(100)
	model.build(straight, endpoint)
	visuals.reconcile(model, true, true, true)
	check(visuals.ordinary_components.nodes.has(Clock.key("C02", 1, Vector2i(4, 4))), "Helper restoration rebuilds the endpoint centerpiece through the same set")
	for id: String in ["L01", "H00_plain_hatch"]: check(Sets.owns(id), "Tier 2 parts also use live sets")
	for id: String in ["CH01_link", "H03_exhaust"]: check(not Sets.owns(id), "Tier 3 artwork remains outside this migration")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("art/themes/clockwork_workshop/sets/*.json"), "Production set definitions are included in the Android export filter")
	renderer.clear()
	parent.queue_free()
	visuals.queue_free()
	await process_frame
	print("Clockwork sets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
