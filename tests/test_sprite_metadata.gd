extends SceneTree
const Sprites = preload("res://scripts/pattern/sprite_metadata.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const BASE := "res://art/themes/vines/artwork/tier1/vines_tier1_vine_color1_basic.json"
const LEAF := "res://art/themes/vines/artwork/tier1/vines_tier1_deco_color1_1.json"
const PEBBLE := "res://art/themes/zen_garden/artwork/tier1/zen_tier1_deco_color1_1.json"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func reject(result: Dictionary, message: String) -> void:
	check(not result.ok and not result.get("errors", []).is_empty(), message)
func raw(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func leaf(data: Dictionary) -> Dictionary:
	return Sprites.load_sprite(data, LEAF.get_base_dir())
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Sprites.clear_cache()
	var geometries := 0
	for theme: String in Themes.ids():
		var catalog := Assets.load_sprite_catalog(Themes.sprite_catalog_path(theme), "res://", theme)
		check(catalog.ok, "Actual staged catalog loads: " + theme + str(catalog.get("errors", [])))
		if not catalog.ok: continue
		for family_id: String in catalog.families:
			var family: Dictionary = catalog.families[family_id]
			geometries += family.bases.size() + family.decorations.size()
			for color: String in family.logical_colors:
				var loaded := Assets.load_sprite_set(catalog, family_id, int(color))
				check(loaded.ok, "Actual catalog adapts to the existing set format: " + theme + str(loaded.get("errors", [])))
				if not loaded.ok: continue
				for composition: Dictionary in loaded.definition.compositions.values():
					for spec: Dictionary in composition.parts.values():
						check(Renderer.validate_spec(spec).is_empty(), "Adapter emits an existing renderer-compatible part")
						check(Assets.resolve(spec.asset) != null, "Adapter artwork uses the shared texture resolver")
						if spec.has("masks"):
							var mask: Texture2D = Assets.resolve(spec.masks.growth.asset)
							check(mask != null and mask.get_size() == Vector2(spec.source_canvas_px[0], spec.source_canvas_px[1]), "Progressive reveal integrates with the existing cached mask provider")
	check(geometries == 52, "Every production geometry loads")
	var before := Sprites.cache_sizes()
	var cached := Assets.load_sprite_catalog(Themes.sprite_catalog_path("vines"))
	check(cached.ok and Sprites.cache_sizes() == before, "Repeated catalog loads reuse JSON, records, masks and texture caches")
	cached.families.default.bases[0].definition.images.clear()
	check(not Assets.load_sprite_catalog(Themes.sprite_catalog_path("vines")).families.default.bases[0].definition.images.is_empty(), "Caller mutation cannot corrupt cached dictionaries")
	var record := Sprites.load_sprite(BASE)
	check(record.ok and record.canvas_px == [255.0, 255.0] and record.resolved.origin == [127.0, 127.0], "Source pixel frame is retained without a 256px assumption")
	check(record.anchors[0].forward == [0.0, -1.0] and record.anchors[10].forward == [0.0, 1.0], "Anchor marker points become local direction vectors")
	var image_path: String = record.images.color1
	var occupancy := Sprites.occupancy(image_path)
	check(occupancy.ok and occupancy.mask == Sprites.occupancy(image_path).mask and occupancy.mask.get_true_bit_count() > 0, "Alpha occupancy is computed once per texture")
	var seed := raw(LEAF)
	var minimal := {"schema_version": 1, "kind": "decoration", "status": "ready", "images": seed.images, "canvas_px": [128, 128], "attachment": seed.attachment}
	var normalized := leaf(minimal)
	check(normalized.ok and normalized.resolved.forward == [0.0, -1.0] and normalized.resolved.spawn.mode == "direct", "Omitted decoration direction and animation use documented defaults")
	check(normalized.resolved.variation.scale == [1.0, 1.0] and not normalized.resolved.transforms.allow_flip_x, "Variation and reflection defaults are explicit")
	var minimal_base := {"schema_version": 1, "kind": "base", "status": "ready", "images": seed.images, "canvas_px": [128, 128], "anchors": [{"id": "one", "position": [30, 90]}]}
	var normalized_base := leaf(minimal_base)
	check(normalized_base.ok and normalized_base.resolved.origin == [64.0, 64.0] and normalized_base.anchors[0].forward == [0.0, -1.0] and normalized_base.anchors[0].growth_at == 0, "Omitted base frame, anchor forward and growth threshold normalize")
	var bad: Dictionary
	for field: String in ["schema_version", "kind", "status", "images", "attachment", "canvas_px"]:
		bad = seed.duplicate(true); bad.erase(field)
		reject(leaf(bad), "Missing required field diagnosed: " + field)
	for replacement: Dictionary in [{"schema_version": 2}, {"images": []}, {"attachment": ["x", 1]}, {"spawn": {"mode": "progressiv"}}, {"variation": {"scale": [2, 1]}}, {"variation": {"weight": 0}}, {"direction": seed.attachment}, {"attachment": [-1, 0]}, {"canvas_px": [256, 256]}, {"transforms": {"allow_flip_x": "yes"}}, {"unknown": true}, {"spawn": {"mode": "direct", "count": [1, 2]}}, {"orientation": {"mode": "random"}}, {"status": "draft"}, {"authoring": {"pending": ["Not finished"]}}]:
		bad = seed.duplicate(true); bad.merge(replacement, true)
		reject(leaf(bad), "Malformed/scope-invalid metadata rejected: " + str(replacement))
	bad = seed.duplicate(true); bad.erase("direction")
	reject(leaf(bad), "Progressive growth requires an explicit direction")
	bad = seed.duplicate(true); bad.images = {"color1": "res://missing-leaf.png"}
	reject(leaf(bad), "Missing PNG is diagnosed")
	bad = seed.duplicate(true); bad.images = {"color1": "user://leaf.png"}
	reject(leaf(bad), "External image path is rejected")
	bad = seed.duplicate(true); bad.spawn.reveal_mask = PEBBLE.get_basename() + ".png"
	reject(leaf(bad), "Reveal mask must match dimensions")
	bad = minimal_base.duplicate(true); bad.anchors.append(bad.anchors[0].duplicate(true))
	reject(leaf(bad), "Duplicate anchor IDs are rejected")
	bad = minimal_base.duplicate(true); bad.anchors[0].forward = bad.anchors[0].position
	reject(leaf(bad), "Zero local direction is rejected")
	bad = minimal_base.duplicate(true); bad.anchors[0].spawn = {"count": [1, 2]}
	reject(leaf(bad), "Anchor cannot override layout-wide count")
	bad = minimal_base.duplicate(true); bad.lighting = {"toward": [64, 64]}
	reject(leaf(bad), "Zero light direction is rejected")
	bad = minimal_base.duplicate(true); bad.orientation = {"mode": "random", "range_deg": [180, 0]}
	reject(leaf(bad), "Reversed rotation ranges are rejected")
	bad = seed.duplicate(true); bad.attachment = [NAN, 1]
	reject(leaf(bad), "Non-finite inline coordinates are rejected")
	check(Sprites.path_for("../artwork/tier1/leaf.json", "res://art/themes/example/sets") == "res://art/themes/example/artwork/tier1/leaf.json", "Catalog-relative project paths resolve")
	for path: String in ["/tmp/example.json", "user://example.json", "https://example.com/a.json", "res://../../example.json", "res://example.png", "res://a\\b.json"]:
		reject(Sprites.load_sprite(path), "Unsupported/escaping paths rejected: " + path)
	var settings := raw(Sprites.SETTINGS_PATH)
	bad = seed.duplicate(true); bad.status = "review"
	check(Sprites.load_sprite(bad, LEAF.get_base_dir(), settings).ok, "Review artwork follows settings")
	settings.loading.allow_review_assets = false
	reject(Sprites.load_sprite(bad, LEAF.get_base_dir(), settings), "Changing load policy cannot reuse permissive cache results")
	settings = raw(Sprites.SETTINGS_PATH); settings.defaults.variation.scale = [2, 1]
	reject(Sprites.load_sprite(seed, LEAF.get_base_dir(), settings), "Invalid settings ranges are diagnosed")
	settings = raw(Sprites.SETTINGS_PATH); settings.defaults.spawn.erase("mode")
	reject(Sprites.load_sprite(seed, LEAF.get_base_dir(), settings), "Incomplete settings are diagnosed before normalization")
	reject(Assets.load_sprite_catalog(Themes.sprite_catalog_path("vines"), "res://", "a_different_theme"), "Registry/catalog identity mismatch is diagnosed")
	var masked := {"schema_version": 1, "kind": "decoration", "status": "ready", "images": {"color1": "res://art/themes/coral_reef/artwork/tier1/coral_tier1_vine_color1_basic.png"}, "canvas_px": [256, 256], "attachment": [128, 128], "direction": [128, 0], "spawn": {"mode": "progressive", "reveal_mask": "res://art/themes/coral_reef/masks/arm_n.png"}}
	var explicit := Sprites.load_sprite(masked)
	check(explicit.ok and explicit.reveals.color1.provider == "texture" and Assets.resolve(explicit.reveals.color1) != null, "Explicit same-size grayscale reveal integrates with shared assets")
	masked.spawn.reveal_mask = masked.images.color1
	reject(Sprites.load_sprite(masked), "Colored artwork cannot silently serve as a grayscale reveal mask")
	var catalog_path := Themes.sprite_catalog_path("vines")
	var definition := raw(catalog_path)
	var synthetic: Dictionary = definition.duplicate(true)
	synthetic.id = "future-theme-tier1"; synthetic.theme_id = "a_new_theme"; synthetic.artwork_theme = "new_theme"
	check(Sprites.load_catalog(synthetic, catalog_path.get_base_dir()).ok, "New theme identity needs only data, without a loader branch")
	bad = definition.duplicate(true); bad.families.default.logical_colors["1"].image_variant = "not_a_color"
	reject(Sprites.load_catalog(bad, catalog_path.get_base_dir()), "Catalog binding must exist on every referenced sprite")
	bad = definition.duplicate(true); bad.families.default.decorations.append(bad.families.default.decorations[0])
	reject(Sprites.load_catalog(bad, catalog_path.get_base_dir()), "Duplicate catalog references are rejected")
	bad = definition.duplicate(true); bad.families.default.bases = [bad.families.default.decorations[0]]
	reject(Sprites.load_catalog(bad, catalog_path.get_base_dir()), "Catalog kind mismatches are rejected")
	bad = definition.duplicate(true); bad.families.default.logical_colors = []
	reject(Sprites.load_catalog(bad, catalog_path.get_base_dir()), "Malformed catalog is diagnosed before iteration")
	reject(Assets.load_sprite_set(Assets.load_sprite_catalog(catalog_path), "missing", 1), "Unknown family diagnosed")
	reject(Assets.load_sprite_set(Assets.load_sprite_catalog(Themes.sprite_catalog_path("zen_garden")), "stones", 1), "Zen has no accidental logical-color-1 stone binding")
	settings = raw(Sprites.SETTINGS_PATH)
	var base := {"spawn": {"count": [2, 4], "minimum_spacing_px": 20}, "orientation": {"mode": "relative", "angle_deg": 30}, "variation": {"scale": [0.8, 1]}, "constraints": {"base_overlap": "avoid", "base_gap_px": 3, "inside_canvas": true}}
	var deco := seed.duplicate(true)
	deco.spawn.duration_sec = 0.6; deco.variation.scale = [0.5, 0.7]; deco.constraints = {"base_gap_px": 1, "inside_canvas": false, "max_radius_px": 9}
	var anchor := {"orientation": {"jitter_deg": 5}, "spawn": {"duration_sec": 0.8}, "constraints": {"max_radius_px": 8}}
	var rules := Sprites.rules(base, deco, anchor, settings)
	check(rules.ok and rules.animation.mode == "progressive" and rules.animation.duration_sec == 0.8, "Animation overrides merge per field, with anchor duration winning")
	check(not rules.animation.has("count") and rules.variation.scale == [0.5, 0.7], "Animation excludes layout count; decoration scale overrides base scale")
	check(rules.orientation.angle_deg == 30 and rules.orientation.jitter_deg == 5, "Anchor orientation inherits base angle")
	check(rules.constraints.inside_canvas and rules.constraints.base_gap_px == 3 and rules.constraints.max_radius_px == 8, "Decoration constraints cannot relax base or anchor restrictions")
	deco.constraints.base_overlap = "require_attachment"
	rules = Sprites.rules(base, deco, anchor, settings)
	check(rules.constraints.base_overlap_checks == ["avoid", "require_attachment"], "Conflicting overlap requirements are preserved for candidate rejection")
	reject(Sprites.rules({"spawn": {"mode": "progressive"}}, raw(PEBBLE), {}, settings), "Progressive override cannot invent a pebble growth direction")
	var changed_registry := Themes.specification().duplicate(true)
	changed_registry.themes.vines.tier1_artwork = {"status": "staged", "catalog": "user://catalog.json"}
	check(not Themes.validate(changed_registry).is_empty(), "Registry validates optional catalog links")
	Sprites.clear_cache()
	check(Sprites.cache_sizes().values().all(func(n): return n == 0), "Explicit cache invalidation releases metadata and image analysis")
	print("Sprite metadata: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
