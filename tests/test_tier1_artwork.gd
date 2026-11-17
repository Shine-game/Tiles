extends SceneTree

# Stage-1 contract: imported assets are addressable in the project and PCK,
# with explicit logical-color bindings and source dimensions. No generation.
const REGISTRY := "res://assets/themes/themes.json"
var checks := 0
var failures := 0
var metadata_paths: Dictionary = {}
var image_paths: Dictionary = {}
var kinds := {"base": 0, "decoration": 0}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func read_json(path: String) -> Dictionary:
	check(FileAccess.file_exists(path), "JSON exists: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary, "JSON object: " + path)
	return parsed if parsed is Dictionary else {}

func inspect_sprite(path: String, family: Dictionary, expected_kind: String) -> void:
	check(not metadata_paths.has(path), "Catalog enumerates each shared geometry once: " + path)
	metadata_paths[path] = true
	var record := read_json(path)
	check(record.get("schema_version") == 1 and record.get("status") == "ready", "Ready universal v1 record: " + path)
	check(record.get("kind") == expected_kind, "Expected sprite kind: " + path)
	kinds[expected_kind] += 1
	var size: Array = record.get("canvas_px", [])
	check(size.size() == 2, "Explicit source dimensions: " + path)
	for binding: Dictionary in family.logical_colors.values():
		check(record.images.has(binding.image_variant), "Logical color has an explicit image variant: " + path)
	for name: String in record.get("images", {}).values():
		var image_path := path.get_base_dir().path_join(name).simplify_path()
		image_paths[image_path] = true
		check(ResourceLoader.exists(image_path, "Texture2D"), "Imported texture resolves: " + image_path)
		var texture := load(image_path) as Texture2D
		check(texture != null, "Texture loads: " + image_path)
		if texture != null and size.size() == 2:
			check(texture.get_size() == Vector2(size[0], size[1]), "Actual texture dimensions match metadata: " + image_path)
		# All image-specific sidecars are also exported, including the color2 copies.
		var sidecar := image_path.get_basename() + ".json"
		check(FileAccess.file_exists(sidecar), "Image sidecar is available: " + sidecar)
		check(FileAccess.get_file_as_string(sidecar) == FileAccess.get_file_as_string(path), "Color sidecars share exactly the same record: " + sidecar)

func _initialize() -> void:
	var registry := read_json(REGISTRY)
	var expected := {"coral_reef": "coral", "clockwork": "clockwork", "vines": "vines", "zen_garden": "zen"}
	for theme_id: String in expected:
		var link: Dictionary = registry.themes[theme_id].get("tier1_artwork", {})
		check(link.get("status") == "staged", "Import is staged: " + theme_id)
		var path: String = link.get("catalog", "")
		var catalog := read_json(path)
		check(catalog.get("schema") == "tiles.sprite-catalog.v1" and catalog.get("tier") == 1, "Tier 1 catalog format: " + theme_id)
		check(catalog.get("theme_id") == theme_id and catalog.get("artwork_theme") == expected[theme_id], "Registry/artwork identity mapping: " + theme_id)
		for family: Dictionary in catalog.families.values():
			for kind: String in ["base", "decoration"]:
				for reference: String in family["bases" if kind == "base" else "decorations"]:
					inspect_sprite(path.get_base_dir().path_join(reference).simplify_path(), family, kind)
		if theme_id == "zen_garden":
			check(catalog.families.stones.logical_colors.keys() == ["2"], "Zen stones bind only logical color 2")
			check(catalog.families.stones.logical_colors["2"].image_variant == "color1", "Zen's single art variant is not its logical color")
			check(catalog.legacy_families == ["rakes"], "Existing rake family remains separate")
		if theme_id == "vines":
			var bindings: Dictionary = catalog.families.default.logical_colors
			check(bindings["1"].image_variant == "color2" and bindings["2"].image_variant == "color1", "Pink/violet variants match logical Rose/Violet order")
			check(catalog.families.default.decorations.size() == 4, "Only four retained leaf designs are cataloged")
	check(kinds.base == 15 and kinds.decoration == 38, "Catalog contains 53 distinct shared geometries")
	check(image_paths.size() == 74, "All 74 actual PNGs resolve")
	check(read_json("res://assets/themes/tier1-generation.json").schema_version == 1, "Shared defaults are exported")
	check(read_json("res://assets/schemas/sprite-metadata-v1.schema.json").has("$schema"), "Authoring schema is exported")
	print("Tier 1 artwork: %d checks, %d failures; %d geometries, %d PNGs" % [checks, failures, metadata_paths.size(), image_paths.size()])
	quit(1 if failures else 0)
