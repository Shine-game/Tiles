extends SceneTree
const Planner = preload("res://scripts/pattern/sprite_planner.gd")
const Metadata = preload("res://scripts/pattern/sprite_metadata.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const CORAL := "res://art/themes/coral_reef/artwork/tier1/coral_tier1_vine_color1_basic.json"
const LEAF := "res://art/themes/vines/artwork/tier1/vines_tier1_deco_color1_1.json"
const PEBBLE := "res://art/themes/zen_garden/artwork/tier1/zen_tier1_deco_color1_5.json"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func raw(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func reject(result: Dictionary, message: String) -> void:
	check(not result.ok and not result.get("errors", []).is_empty(), message)
func _initialize() -> void:
	_run.call_deferred()
func fixture(base: Dictionary, decorations: Array = []) -> Dictionary:
	var loaded := Metadata.load_sprite(base, CORAL.get_base_dir())
	check(loaded.ok, "Fixture uses the real validated sprite loader: " + str(loaded.get("errors", [])))
	loaded.path = "res://fixture/base.json"
	return {"ok": true, "settings": raw(Metadata.SETTINGS_PATH), "families": {"default": {"logical_colors": {"1": {"image_variant": "color1", "treatment": "fixture"}}, "bases": [loaded], "decorations": decorations}}}
func simple_base() -> Dictionary:
	var d := raw(CORAL)
	d.spawn = {"count": [0, 0], "minimum_spacing_px": 0}
	d.anchors = []
	d.lighting = {"toward": [80, 128]}
	d.constraints = {"base_overlap": "allow"}
	return d
func _run() -> void:
	var planner := Planner.new()
	for theme: String in Themes.ids():
		var catalog := Assets.load_sprite_catalog(Themes.sprite_catalog_path(theme))
		var family_id := "stones" if theme == "zen_garden" else "default"
		for color: String in catalog.families[family_id].logical_colors:
			for turns in range(4):
				var context := {}
				if theme != "zen_garden": context.target_forward = Vector2.RIGHT.rotated(turns * PI / 2)
				var plan := planner.plan(catalog, family_id, int(color), "actual/" + theme, 42, context)
				check(plan.ok, "Production base has a valid orientation: " + theme)
				if not plan.ok: continue
				var record: Dictionary
				for base: Dictionary in catalog.families[family_id].bases:
					if base.path == plan.base.metadata_path: record = base; break
				check((plan.base.transform * Vector2(record.resolved.origin[0], record.resolved.origin[1])).is_equal_approx(Vector2.ZERO), "Base pivot maps exactly to the component origin")
				if context.has("target_forward"):
					check(plan.base.transform.basis_xform(Vector2(record.resolved.forward[0], record.resolved.forward[1])).normalized().is_equal_approx(context.target_forward), "Lighting never breaks required native forward")
				var anchors := {}
				for a: Dictionary in record.anchors: anchors[a.id] = a
				var ids := {}
				var occupied := {}
				for deco: Dictionary in plan.decorations:
					check(not ids.has(deco.anchor_id), "One decoration per selected anchor")
					ids[deco.anchor_id] = true
					var attachment := Vector2(deco.attachment[0], deco.attachment[1])
					var anchor := Vector2(anchors[deco.anchor_id].position[0], anchors[deco.anchor_id].position[1])
					check((deco.transform * attachment).is_equal_approx(plan.base.transform * anchor), "Attachment follows the whole base rotation/reflection")
					check(deco.id == "actual/" + theme + "/anchor/" + deco.anchor_id, "Decoration identity is stable across redraws")
					if theme == "zen_garden":
						check(deco.visible_radius_px <= 8.0001, "Zen visible footprint obeys its radius limit")
						var inside := true
						var disjoint := true
						for cell: Vector2i in deco.footprint:
							inside = inside and cell.x >= 1 and cell.y >= 1 and cell.x <= 253 and cell.y <= 253
							disjoint = disjoint and not occupied.has(cell)
							occupied[cell] = true
						check(inside and disjoint, "Zen footprint respects tile bounds and other decorations")
				check(plan.decorations.size() <= plan.target_count and plan.decorations.size() > 0, "Production layout places a constrained subset")
				check(var_to_bytes(plan) == var_to_bytes(planner.plan(catalog, family_id, int(color), "actual/" + theme, 42, context)), "Same identity, settings and seed reproduce the entire plan")
	var base := simple_base()
	var no_deco := fixture(base)
	var plan := planner.plan(no_deco, "default", 1, "lighting", 7, {"target_forward": Vector2.DOWN, "world_light": Vector2.LEFT})
	check(plan.ok and plan.base.flip_x and is_equal_approx(plan.base.light_score, 1.0), "Base reflects to preserve forward while lighting its left side")
	base.connections = [{"id": "north", "position": [128, 0], "toward": [128, -1]}, {"id": "east", "position": [255, 128], "toward": [256, 128]}]
	base.lighting.toward = [176, 128]
	var joined := fixture(base)
	var connections := [{"offset_cells": [0, -0.5], "outward": [0, -1]}, {"offset_cells": [127.0 / 256, 0], "outward": [1, 0]}]
	plan = planner.plan(joined, "default", 1, "sockets", 7, {"target_forward": Vector2.UP, "world_light": Vector2.LEFT, "required_connections": connections})
	check(plan.ok and not plan.base.flip_x and plan.base.light_score < 0, "Socket geometry takes priority over better lighting")
	connections[1] = {"offset_cells": [-127.0 / 256, 0], "outward": [-1, 0]}
	plan = planner.plan(joined, "default", 1, "sockets", 7, {"target_forward": Vector2.UP, "world_light": Vector2.LEFT, "required_connections": connections})
	check(plan.ok and plan.base.flip_x and plan.base.light_score > 0, "Reflection is available when it preserves the requested socket layout")
	connections[1] = {"offset_cells": [0, 0.5], "outward": [0, 1]}
	reject(planner.plan(joined, "default", 1, "sockets", 7, {"required_connections": connections}), "Impossible connections are reported instead of broken")
	var coincident := simple_base()
	coincident.connections = [{"id": "a", "position": [128, 0], "toward": [128, -1]}, {"id": "b", "position": [128, 0], "toward": [128, -1]}]
	var overlapping_ports := [{"offset_cells": [0, -0.5], "outward": [0, -1]}, {"id": "a", "offset_cells": [0, -0.5], "outward": [0, -1]}]
	check(planner.plan(fixture(coincident), "default", 1, "socket-assignment", 1, {"required_connections": overlapping_ports}).ok, "Socket matching finds a complete assignment when a later port has an explicit identity")
	var leaf := Metadata.load_sprite(LEAF)
	base = simple_base(); base.lighting = {"toward": [80, 80]}; base.spawn.count = [1, 1]
	base.anchors = [{"id": "one", "position": [128, 96], "accepts": ["leaf"], "forward": [128, 60]}]
	var leaves := fixture(base, [leaf])
	var mirrors := {}
	var fingerprints := {}
	for seed in range(20):
		plan = planner.plan(leaves, "default", 1, "mirror", seed, {"target_forward": Vector2.UP})
		check(plan.ok and plan.decorations.size() == 1, "Leaf fixture places its decoration")
		if plan.decorations.is_empty(): continue
		var deco: Dictionary = plan.decorations[0]
		mirrors[deco.flip_x] = true; fingerprints[plan.fingerprint] = true
		var aligned: Vector2 = deco.local_transform.basis_xform(Vector2(leaf.resolved.forward[0], leaf.resolved.forward[1])).normalized()
		check(aligned.is_equal_approx(Vector2.UP), "Independent mirror compensates the native diagonal direction")
	check(mirrors.size() == 2 and fingerprints.size() > 1, "Seeded generation uses original and mirrored leaf forms")
	var fixed := planner.plan(leaves, "default", 1, "survivor", 91)
	planner.plan(leaves, "default", 1, "unrelated", 92)
	check(planner.plan(leaves, "default", 1, "survivor", 91).fingerprint == fixed.fingerprint, "Unrelated construction does not reroll a survivor")
	var moved := planner.plan(leaves, "default", 1, "survivor", 91, {"origin_cells": Vector2(5, 7)})
	check(moved.fingerprint == fixed.fingerprint and moved.base.transform.origin.is_equal_approx(fixed.base.transform.origin + Vector2(5, 7)), "Translation changes placement without rerolling artwork")
	var zoomed := planner.plan(leaves, "default", 1, "survivor", 91, {"size_cells": [2, 2]})
	check(zoomed.fingerprint == moved.fingerprint and zoomed.base.transform.x.is_equal_approx(moved.base.transform.x * 2), "Display scaling changes transforms without rerolling local choices")
	var reordered := leaves.duplicate(true)
	reordered.families.default.decorations.reverse(); reordered.families.default.bases.reverse()
	check(Planner.new().plan(reordered, "default", 1, "survivor", 91).fingerprint == fixed.fingerprint, "Catalog ordering does not change seeded choices")
	fixed.decorations.clear()
	check(planner.plan(leaves, "default", 1, "survivor", 91).decorations.size() == 1, "Caller mutation cannot corrupt a cached layout")
	planner.forget("survivor")
	check(planner.plan(leaves, "default", 1, "survivor", 91).decorations.size() == 1, "Evicted construction regenerates deterministically")
	var ranked_base := simple_base()
	ranked_base.erase("lighting")
	var ranked := fixture(ranked_base)
	ranked.settings.lighting.tie_break = ["flip_x", "no_flip", "flip_y", "flip_xy"]
	check(planner.plan(ranked, "default", 1, "tie-break", 1, {"target_forward": Vector2.UP}).base.flip_x, "Configured lighting tie preference is honored")
	ranked.settings.lighting.connection_alignment_has_priority = false
	reject(planner.plan(ranked, "default", 1, "tie-break", 1), "Unsupported lighting policy cannot relax geometry requirements")
	var lit_leaf_raw := raw(LEAF)
	lit_leaf_raw.lighting = {"toward": [lit_leaf_raw.attachment[0] - 10, lit_leaf_raw.attachment[1]]}
	var lit_leaf := Metadata.load_sprite(lit_leaf_raw, LEAF.get_base_dir())
	lit_leaf.path = LEAF
	var leaf_base := simple_base()
	leaf_base.spawn.count = [1, 1]
	leaf_base.anchors = [{"id": "one", "position": [128, 96], "accepts": ["leaf"]}]
	var lit_catalog := fixture(leaf_base, [lit_leaf])
	plan = planner.plan(lit_catalog, "default", 1, "lit-leaf", 10, {"target_forward": Vector2.UP, "world_light": Vector2.LEFT})
	check(plan.ok and not plan.decorations[0].flip_x and plan.decorations[0].light_score > 0, "Decoration lighting chooses among geometrically valid independent mirrors")
	for orientation: Dictionary in [{"mode": "fixed", "angle_deg": 25, "jitter_deg": 5}, {"mode": "perpendicular", "angle_deg": 0}, {"mode": "random", "range_deg": [10, 20]}]:
		leaf_base.orientation = orientation
		var oriented := fixture(leaf_base, [leaf])
		plan = planner.plan(oriented, "default", 1, "orientation", 17, {"target_forward": Vector2.UP})
		var chosen: Dictionary = plan.decorations[0]
		var native := Vector2(leaf.resolved.forward[0], leaf.resolved.forward[1])
		var axis := rad_to_deg(chosen.local_transform.basis_xform(native).angle())
		if orientation.mode == "fixed": check(axis >= 19.999 and axis <= 30.001, "Fixed angle and jitter align in the native base frame")
		elif orientation.mode == "perpendicular": check(absf(axis) < 0.001, "Ring-like orientation is perpendicular to anchor forward")
		else: check(chosen.rotation_deg >= 9.999 and chosen.rotation_deg <= 20.001, "Random mode respects the allowed sprite-rotation range")
	leaf_base.orientation = {"mode": "relative"}
	var heavy := Metadata.load_sprite(LEAF.replace("color1_1.json", "color1_2.json"))
	heavy.definition.variation.weight = 1000
	heavy.resolved.variation.weight = 1000
	var weighted := fixture(leaf_base, [leaf, heavy])
	var reordered_weighted := weighted.duplicate(true)
	reordered_weighted.families.default.decorations.reverse()
	check(Planner.new().plan(reordered_weighted, "default", 1, "weighted", 7).fingerprint == planner.plan(weighted, "default", 1, "weighted", 7).fingerprint, "Weighted selection is independent of catalog entry order")
	var zen := Assets.load_sprite_catalog(Themes.sprite_catalog_path("zen_garden"))
	var reversed_zen := zen.duplicate(true)
	reversed_zen.families.stones.bases.reverse()
	check(Planner.new().plan(reversed_zen, "stones", 2, "zen-order", 42).fingerprint == planner.plan(zen, "stones", 2, "zen-order", 42).fingerprint, "Base variant selection is independent of catalog entry order")
	var heavy_count := 0
	for seed in range(24):
		plan = planner.plan(weighted, "default", 1, "weighted", seed)
		if plan.decorations[0].metadata_path == heavy.path: heavy_count += 1
	check(heavy_count >= 20, "Catalog weights affect artwork selection before mirror selection")
	leaf_base.spawn = {"count": [3, 3], "minimum_spacing_px": 20}
	leaf_base.anchors = [{"id": "a", "position": [128, 90]}, {"id": "b", "position": [128, 92]}, {"id": "c", "position": [128, 94]}]
	plan = planner.plan(fixture(leaf_base, [leaf]), "default", 1, "spacing", 1)
	check(plan.decorations.size() == 1 and plan.rejections.spacing == 2, "Minimum spacing applies between accepted attachment points")
	var pebble := Metadata.load_sprite(PEBBLE)
	base = simple_base(); base.spawn.count = [6, 6]
	base.constraints = {"inside_canvas": true, "edge_margin_px": 1, "base_overlap": "avoid", "base_gap_px": 3, "avoid_deco_overlap": true, "max_radius_px": 64}
	base.orientation = {"mode": "random"}
	base.anchors = []
	var points := [[30, 200], [120, 200], [220, 200], [125, 80], [0, 240], [30, 200]]
	for i in range(points.size()): base.anchors.append({"id": "p%d" % i, "position": points[i], "accepts": ["pebble"]})
	var stones := fixture(base, [pebble])
	plan = planner.plan(stones, "default", 1, "collision", 32)
	check(plan.ok and plan.decorations.size() == 3 and plan.warnings.size() == 1, "Actual alpha, tile and overlap constraints reject invalid candidates and report a shortfall")
	check(plan.rejections.has("base_overlap") and plan.rejections.has("canvas_boundary") and plan.rejections.has("decoration_overlap"), "Constraint failures retain actionable reasons")
	base.constraints.max_radius_px = 1
	var too_large := fixture(base, [pebble])
	plan = planner.plan(too_large, "default", 1, "radius", 32)
	check(plan.ok and plan.decorations.is_empty() and plan.rejections.has("radius"), "Visible radius rejects oversized art without relaxing the rule")
	var dot := pebble.duplicate(true)
	dot.definition.variation.scale = [0.02, 0.02]
	base = simple_base(); base.spawn.count = [2, 2]; base.orientation = {"mode": "random"}
	base.constraints = {"base_overlap": "avoid", "base_gap_px": 3}
	base.anchors = [{"id": "too_close", "position": [128, 131]}, {"id": "exact_gap", "position": [128, 132]}]
	plan = planner.plan(fixture(base, [dot]), "default", 1, "gap", 0)
	check(plan.ok and plan.decorations.size() == 1 and plan.decorations[0].anchor_id == "exact_gap", "Three-pixel base gap uses pixel-square separation, including the exact allowed boundary")
	base = simple_base(); base.spawn.count = [1, 1]; base.anchors = [{"id": "none", "position": [128, 96], "accepts": []}]
	plan = planner.plan(fixture(base, [leaf]), "default", 1, "tags", 1)
	check(plan.ok and plan.decorations.is_empty() and plan.rejections.has("incompatible_tags"), "An empty accepts list accepts no decoration")
	for context: Dictionary in [{"target_forward": Vector2.ZERO}, {"world_light": [0, 0]}, {"size_cells": [-1, 1]}, {"allowed_rotations_deg": []}, {"required_connections": [{}]}, {"base_path": 42}, {"unknown": true}]: reject(planner.plan(leaves, "default", 1, "invalid", 1, context), "Malformed placement context is diagnosed")
	reject(planner.plan(leaves, "default", 1, "invalid", 1, {"base_path": "res://no-such-base.json"}), "Unknown pinned base is diagnosed")
	reject(planner.plan(leaves, "missing", 1, "invalid", 1), "Unknown family is diagnosed")
	reject(planner.plan(leaves, "default", 2, "invalid", 1), "Missing logical binding is diagnosed")
	reject(planner.plan(leaves, "default", 1, "", 1), "Construction requires a stable identity")
	var overflow := raw(LEAF)
	overflow.direction = [1e100, 0]
	reject(Metadata.load_sprite(overflow, LEAF.get_base_dir()), "Finite doubles that overflow source Vector2 precision are diagnosed")
	var impossible_count := simple_base()
	impossible_count.spawn.count = [0, 1e30]
	reject(Metadata.load_sprite(impossible_count, CORAL.get_base_dir()), "Counts exceeding the RNG range are diagnosed before integer conversion")
	var giant_leaf := leaf.duplicate(true)
	giant_leaf.definition.variation.scale = [10000, 10000]
	plan = planner.plan(fixture(leaf_base, [giant_leaf]), "default", 1, "bounded-raster", 1)
	check(plan.ok and plan.decorations.is_empty() and plan.rejections.has("footprint_budget"), "Extreme finite scale is rejected before unbounded footprint work")
	planner.clear()
	check(planner.cache_sizes().plans == 0 and planner.cache_sizes().geometry.footprints == 0, "Planner caches can be explicitly released")
	print("Sprite planner: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
