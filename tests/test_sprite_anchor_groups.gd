extends SceneTree
const Metadata = preload("res://scripts/pattern/sprite_metadata.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Planner = preload("res://scripts/pattern/sprite_planner.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const BASE := "res://assets/themes/coral_reef/sprites/tier1/coral_reef_tier1_vine_color1_01.json"
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func raw() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(BASE))
func load_base(data: Dictionary) -> Dictionary: return Metadata.load_sprite(data, BASE.get_base_dir())
func fixture(catalog: Dictionary, data: Dictionary) -> Dictionary:
	var result := catalog.duplicate(true)
	var base := load_base(data)
	check(base.ok, "Fixture base loads: " + str(base.get("errors", [])))
	base.path = "res://fixture/grouped-base.json"
	result.families.default.bases = [base]
	return result
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := Assets.load_sprite_catalog(Themes.sprite_catalog_path("coral_reef"))
	check(catalog.ok, "Production coral catalog loads")
	var other := BASE.replace("color1_basic.json", "color2_basic.json")
	check(FileAccess.get_file_as_string(BASE) == FileAccess.get_file_as_string(other), "Both color sidecars remain identical")
	var definition := raw()
	var anchors := {}
	var spine_count := 0
	for anchor: Dictionary in definition.anchors:
		anchors[anchor.id] = anchor
		if anchor.get("group") == "spine": spine_count += 1
	check(spine_count == 6 and definition.anchors.size() == 18, "Existing six spine and twelve side anchors retained")
	var selected_spine := {}
	var planner := Planner.new()
	for color in [1, 2]:
		for turn in range(4):
			for seed in range(16):
				var plan := planner.plan(catalog, "default", color, "coral-group/%d" % seed, seed, {"target_forward": Vector2.UP.rotated(turn * PI / 2), "include_footprints": false})
				check(plan.ok and plan.warnings.is_empty(), "Valid grouped layout for both colors/all rotations")
				check(plan.decorations.size() == plan.target_count and plan.target_count >= 4 and plan.target_count <= 6, "Spine decorations stay within the total 4–6")
				check(plan.group_counts.spine == 2, "Exactly two spine decorations are selected")
				var stem: Vector2 = plan.base.transform.basis_xform(Vector2.UP).normalized()
				for deco: Dictionary in plan.decorations:
					var metadata := Metadata.load_sprite(deco.metadata_path)
					var direction: Vector2 = deco.transform.basis_xform(Vector2(metadata.resolved.forward[0], metadata.resolved.forward[1])).normalized()
					if anchors[deco.anchor_id].get("group") == "spine":
						selected_spine[deco.anchor_id] = true
						check(direction.dot(stem) > 0.99999, "Spine growth remains parallel and forward after rotation/reflection")
					else: check(absf(direction.dot(stem)) <= sin(deg_to_rad(10.0)) + 0.00001, "Side growth stays perpendicular ±10 degrees")
	check(selected_spine.size() == 6, "Seeded selection varies across all six spine anchors")
	for quota: Variant in [-1, 1.5, 7]:
		var invalid := raw()
		invalid.spawn.group_counts.spine = quota
		check(not load_base(invalid).ok, "Negative, fractional or excessive group counts rejected")
	var invalid := raw()
	invalid.spawn.count = [1, 3]
	check(not load_base(invalid).ok, "Reservations cannot exceed the minimum total")
	invalid = raw()
	invalid.spawn.erase("count")
	check(not load_base(invalid).ok, "Defaults cannot silently underfund reserved anchors")
	invalid = raw()
	invalid.spawn.group_counts = {"": 0}
	check(not load_base(invalid).ok, "Empty group name rejected")
	var data := raw()
	data.spawn.group_counts.spine = 0
	var zero := planner.plan(fixture(catalog, data), "default", 1, "zero", 5, {"include_footprints": false})
	check(zero.ok and zero.group_counts.spine == 0 and zero.decorations.size() == zero.target_count and zero.decorations.all(func(d): return d.get("anchor_group") != "spine"), "Zero quota excludes that group")
	data = raw()
	data.spawn.group_counts = {"spine": 1, "side": 1}
	data.anchors[0].group = "side"
	var multi := planner.plan(fixture(catalog, data), "default", 2, "multiple", 9, {"include_footprints": false})
	check(multi.ok and multi.group_counts == {"spine": 1, "side": 1} and multi.decorations.size() == multi.target_count, "Multiple named groups reserve independently within the same total")
	data = raw()
	for anchor: Dictionary in data.anchors:
		if anchor.get("group") == "spine": anchor.accepts = ["unavailable"]
	var unmet := planner.plan(fixture(catalog, data), "default", 1, "unmet", 7, {"include_footprints": false})
	check(unmet.ok and unmet.group_counts.spine == 0 and not unmet.warnings.is_empty(), "Infeasible quota reports a shortfall without relaxing constraints")
	var rules := Metadata.rules(raw(), catalog.families.default.decorations[0].definition, {}, catalog.settings)
	check(rules.ok and not rules.animation.has("group_counts"), "Layout quotas do not leak into animation rules")
	var vine_path := "res://assets/themes/vines/sprites/tier1/vines_tier1_vine_color1_01.json"
	var vine: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(vine_path))
	for option: Array in [[], ["upper_02", "upper_02"], ["upper_02", "lower_07"], ["upper_02", "missing"], ["upper_02"]]:
		var malformed := vine.duplicate(true)
		malformed.spawn.group_anchor_sets.upper = [option]
		check(not Metadata.load_sprite(malformed, vine_path.get_base_dir()).ok, "Invalid authored anchor combination rejected")
	var unreserved := vine.duplicate(true)
	unreserved.spawn.group_counts.erase("upper")
	check(not Metadata.load_sprite(unreserved, vine_path.get_base_dir()).ok, "Authored combinations require matching fixed group quotas")
	print("Sprite anchor groups: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
