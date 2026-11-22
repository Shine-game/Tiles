class_name PatternSpriteMetadata
extends RefCounted

const Schema = preload("res://scripts/pattern/sprite_schema.gd")
const SCHEMA_PATH := "res://assets/shared/schemas/sprite-metadata-v1.schema.json"
const SETTINGS_PATH := "res://assets/shared/assembly/tier1-generation.json"
const CATALOG_SCHEMA := "tiles.sprite-catalog.v1"
const ALPHA_THRESHOLD := 0.01
static var _json: Dictionary = {}
static var _records: Dictionary = {}
static var _catalogs: Dictionary = {}
static var _textures: Dictionary = {}
static var _alpha: Dictionary = {}
static var _reveals: Dictionary = {}
static var _mask_images: Dictionary = {}

static func clear_cache() -> void:
	_json.clear()
	_records.clear()
	_catalogs.clear()
	_textures.clear()
	_alpha.clear()
	_reveals.clear()
	_mask_images.clear()

static func cache_sizes() -> Dictionary:
	return {"json": _json.size(), "records": _records.size(), "catalogs": _catalogs.size(), "textures": _textures.size(), "alpha": _alpha.size(), "reveals": _reveals.size(), "reveal_images": _mask_images.size()}

static func _failure(path: String, issues: Array) -> Dictionary:
	return {"ok": false, "errors": issues.map(func(issue): return path + ": " + str(issue))}

static func path_for(value: Variant, root: String, extension: String = "json") -> String:
	if not value is String or value.is_empty() or not root.begins_with("res://"): return ""
	if value.contains("\\") or (value.contains(":") and not value.begins_with("res://")) or value.begins_with("/"): return ""
	var combined: String = value if value.begins_with("res://") else root.path_join(value)
	var segments: Array[String] = []
	for segment: String in combined.trim_prefix("res://").split("/", false):
		if segment == ".": continue
		if segment == "..":
			if segments.is_empty(): return ""
			segments.pop_back()
		else: segments.append(segment)
	var path := "res://" + "/".join(segments)
	return path if path.get_extension() == extension else ""

static func _document(source: Variant, root: String) -> Dictionary:
	if source is Dictionary: return {"ok": true, "definition": source.duplicate(true), "root": root, "path": "<inline>"}
	var path := path_for(source, root)
	if path.is_empty() or not FileAccess.file_exists(path): return _failure(str(source), ["Expected an existing project JSON file"])
	if not _json.has(path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK: return _failure(path, ["Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]])
		if not parser.data is Dictionary: return _failure(path, ["Expected a JSON object"])
		_json[path] = parser.data
	return {"ok": true, "definition": _json[path].duplicate(true), "root": path.get_base_dir(), "path": path}

static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var result := a.duplicate(true)
	result.merge(b, true)
	return result

static func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func _pair(value: Vector2) -> Array:
	return [value.x, value.y]

static func _inside(point: Array, canvas: Array) -> bool:
	return point[0] >= 0 and point[1] >= 0 and point[0] < canvas[0] and point[1] < canvas[1]

static func _settings(source: Variant) -> Dictionary:
	var loaded := _document(source, "res://")
	if not loaded.ok: return loaded
	var data: Dictionary = loaded.definition
	var schema := _document(SCHEMA_PATH, "res://")
	if not schema.ok: return schema
	var errors: Array = []
	if not (data.get("schema_version") is int or data.get("schema_version") is float) or data.schema_version != 1: errors.append("Unsupported settings schema_version")
	if not data.get("defaults") is Dictionary: errors.append("Missing settings defaults")
	else:
		for field: String in ["spawn", "orientation", "variation", "constraints"]:
			if not data.defaults.get(field) is Dictionary: errors.append("Missing defaults." + field)
			else:
				errors.append_array(Schema.validate(data.defaults[field], schema.definition.properties[field], "defaults." + field))
				if errors.is_empty(): _ordered_ranges(data.defaults[field], "defaults." + field, errors)
		for field: String in ["allow_flip_x", "allow_flip_y"]:
			if not data.defaults.get(field) is bool: errors.append("Expected boolean defaults." + field)
		if data.defaults.get("frame_origin") != "canvas_center" or data.defaults.get("frame_up") != "one_pixel_above_origin": errors.append("Unsupported default frame convention")
		var required := {"spawn": ["mode", "count", "minimum_spacing_px", "duration_sec"], "orientation": ["mode", "angle_deg", "jitter_deg"], "variation": ["weight", "scale"], "constraints": ["inside_canvas", "edge_margin_px", "base_overlap", "base_gap_px", "avoid_deco_overlap"]}
		for block: String in required:
			for field: String in required[block]:
				if not data.defaults.get(block, {}) is Dictionary or not data.defaults[block].has(field): errors.append("Missing default " + block + "." + field)
	if not data.get("loading") is Dictionary or not data.loading.get("allow_review_assets") is bool: errors.append("Expected loading.allow_review_assets boolean")
	if not data.get("lighting") is Dictionary or Schema.validate(data.lighting.get("world_direction"), schema.definition.properties.direction).size() > 0: errors.append("Expected lighting.world_direction vector")
	elif not _vector(data.lighting.world_direction).is_finite() or _vector(data.lighting.world_direction).is_zero_approx(): errors.append("World lighting direction must be nonzero")
	if not errors.is_empty(): return _failure(loaded.path, errors)
	return loaded

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var texture := load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
		if texture != null: _textures[path] = texture
	return _textures.get(path)

static func occupancy(path: String) -> Dictionary:
	var canonical := path_for(path, "res://", "png")
	if canonical.is_empty(): return _failure(path, ["Expected a project PNG"])
	if not _alpha.has(canonical):
		var texture := _texture(canonical)
		if texture == null: return _failure(canonical, ["Texture does not exist"])
		var image := texture.get_image()
		if image == null: return _failure(canonical, ["Texture has no readable image"])
		if image.is_compressed() and image.decompress() != OK: return _failure(canonical, ["Cannot decompress texture"])
		var mask := BitMap.new()
		mask.create_from_image_alpha(image, ALPHA_THRESHOLD)
		if mask.get_true_bit_count() == 0: return _failure(canonical, ["Texture is entirely transparent"])
		_alpha[canonical] = mask
	return {"ok": true, "mask": _alpha[canonical]}

static func _ordered_ranges(data: Dictionary, path: String, errors: Array) -> void:
	for key: String in ["count", "scale", "range_deg"]:
		if data.has(key) and data[key][0] > data[key][1]: errors.append(path + "." + key + ": range must be ascending")
		if key == "count" and data.has(key) and data[key][1] > 2147483647: errors.append(path + ".count: exceeds the RNG integer range")

static func _semantic(data: Dictionary) -> Array:
	var errors: Array = []
	for field: String in ["spawn", "variation", "orientation"]: _ordered_ranges(data.get(field, {}), field, errors)
	if data.kind == "decoration":
		for field: String in ["frame", "anchors", "connections", "orientation"]:
			if data.has(field): errors.append(field + ": belongs on a base or anchor, not a decoration")
		for field: String in ["count", "minimum_spacing_px", "group_counts", "group_count_ranges", "group_anchor_sets", "max_per_group"]:
			if data.get("spawn", {}).has(field): errors.append("spawn." + field + ": belongs on a base")
		if data.get("spawn", {}).get("mode") == "progressive" and not data.has("direction"): errors.append("Progressive decoration requires an explicit direction marker")
	else:
		if data.get("spawn", {}).has("reveal_mask"): errors.append("spawn.reveal_mask belongs on a decoration")
		var quotas: Dictionary = data.get("spawn", {}).get("group_counts", {})
		quotas = quotas.duplicate()
		for group: String in data.get("spawn", {}).get("group_count_ranges", {}):
			var limits: Array = data.spawn.group_count_ranges[group]
			if limits[0] > limits[1]: errors.append("Group count range must be ascending")
			if quotas.has(group): errors.append("Group cannot have both fixed and ranged counts")
			quotas[group] = limits[1]
		for group: String in quotas:
			if group.is_empty(): errors.append("spawn.group_counts: group name cannot be empty")
			var capacity := 0
			for anchor: Dictionary in data.get("anchors", []):
				if anchor.get("group", "") == group: capacity += 1
			if quotas[group] > capacity: errors.append("spawn.group_counts." + group + ": exceeds available anchors")
		for group: String in data.get("spawn", {}).get("group_anchor_sets", {}):
			if not data.spawn.get("group_counts", {}).has(group): errors.append("Anchor sets need a fixed group count: " + group)
			for option: Array in data.spawn.group_anchor_sets[group]:
				if option.size() != int(data.spawn.get("group_counts", {}).get(group, -1)): errors.append("Anchor set size differs from group count: " + group)
				var seen: Dictionary = {}
				for id: String in option:
					if seen.has(id): errors.append("Duplicate anchor in set: " + id)
					seen[id] = true
					if not data.get("anchors", []).any(func(a): return a.id == id and a.get("group", "") == group): errors.append("Anchor set references wrong or missing group anchor: " + id)
		for field: String in ["attachment", "direction", "tags"]:
			if data.has(field): errors.append(field + ": belongs on a decoration")
		if data.get("variation", {}).has("weight"): errors.append("variation.weight belongs on a decoration")
		for collection: String in ["anchors", "connections"]:
			var ids: Dictionary = {}
			for item: Dictionary in data.get(collection, []):
				if item.id.is_empty(): errors.append(collection + ": id cannot be empty")
				if item.get("spawn", {}).has("reveal_mask"): errors.append(collection + "/" + item.id + ": reveal_mask belongs on a decoration")
				if ids.has(item.id): errors.append(collection + ": duplicate id " + item.id)
				ids[item.id] = true
				if item.has("forward") and _vector(item.forward).is_equal_approx(_vector(item.position)): errors.append(collection + "/" + item.id + ": zero forward vector")
				if item.has("toward") and _vector(item.toward).is_equal_approx(_vector(item.position)): errors.append(collection + "/" + item.id + ": zero connection vector")
				for field: String in ["spawn", "orientation"]: _ordered_ranges(item.get(field, {}), collection + "/" + item.id + "." + field, errors)
				for field: String in ["count", "minimum_spacing_px", "group_counts", "group_count_ranges", "group_anchor_sets", "max_per_group"]:
					if item.get("spawn", {}).has(field): errors.append(collection + "/" + item.id + ": " + field + " belongs on the base")
	if data.status == "ready" and not data.get("authoring", {}).get("pending", []).is_empty(): errors.append("Ready artwork has unresolved authoring.pending entries")
	return errors

static func _reveal(image_path: String, attachment: Vector2, direction: Vector2, explicit: String, size: Vector2) -> Dictionary:
	var key := image_path + "/" + str(attachment) + "/" + str(direction) + "/" + explicit
	if not _reveals.has(key):
		if not explicit.is_empty():
			var mask := _texture(explicit)
			if mask == null or mask.get_size() != size: return _failure(explicit, ["Reveal mask must match sprite dimensions"])
			if not _mask_images.has(explicit):
				var image := mask.get_image()
				if image == null: return _failure(explicit, ["Reveal mask has no readable image"])
				if image.is_compressed() and image.decompress() != OK: return _failure(explicit, ["Cannot decompress reveal mask"])
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						var pixel := image.get_pixel(x, y)
						if pixel.a > ALPHA_THRESHOLD and (absf(pixel.r - pixel.g) > 0.005 or absf(pixel.g - pixel.b) > 0.005): return _failure(explicit, ["Reveal mask must be grayscale"])
				_mask_images[explicit] = true
			_reveals[key] = {"provider": "texture", "path": explicit}
		else:
			var occupied := occupancy(image_path)
			if not occupied.ok: return occupied
			var low := 0.0
			var high := -INF
			for y in range(int(size.y)):
				for x in range(int(size.x)):
					if occupied.mask.get_bit(x, y):
						var projection := (Vector2(x, y) - attachment).dot(direction)
						low = minf(low, projection)
						high = maxf(high, projection)
			if high <= 0: return _failure(image_path, ["Progressive direction has no positive visible extent"])
			_reveals[key] = {"provider": "linear_reveal", "params": {"size_px": _pair(size), "zero_px": _pair(attachment + direction * low + Vector2.ONE * 0.5), "one_px": _pair(attachment + direction * high + Vector2.ONE * 0.5)}}
	return {"ok": true, "asset": _reveals[key].duplicate(true)}

static func load_sprite(source: Variant, root: String = "res://", settings_source: Variant = SETTINGS_PATH) -> Dictionary:
	var loaded := _document(source, root)
	if not loaded.ok: return loaded
	var settings := _settings(settings_source)
	if not settings.ok: return settings
	var cache_key: String = loaded.path + "/" + JSON.stringify(settings.definition).sha256_text()
	if source is String and _records.has(cache_key): return _records[cache_key].duplicate(true)
	var schema := _document(SCHEMA_PATH, "res://")
	if not schema.ok: return schema
	var data: Dictionary = loaded.definition
	var errors := Schema.validate(data, schema.definition)
	if not errors.is_empty(): return _failure(loaded.path, errors)
	errors = _semantic(data)
	if data.status == "draft": errors.append("Draft artwork is not renderable")
	if data.status == "review" and not settings.definition.loading.allow_review_assets: errors.append("Review artwork is disabled by settings")
	if not errors.is_empty(): return _failure(loaded.path, errors)
	var image_paths: Dictionary = {}
	var canvas: Array = data.get("canvas_px", [])
	for variant: String in data.images:
		var path := path_for(data.images[variant], loaded.root, "png")
		if variant.is_empty() or path.is_empty():
			errors.append("images." + variant + ": expected a project PNG")
			continue
		var texture := _texture(path)
		if texture == null:
			errors.append("images." + variant + ": missing texture " + path)
			continue
		if canvas.is_empty(): canvas = _pair(texture.get_size())
		if texture.get_size() != _vector(canvas): errors.append("images." + variant + ": texture dimensions differ from canvas_px")
		var occupied := occupancy(path)
		if not occupied.ok: errors.append_array(occupied.errors)
		image_paths[variant] = path
	if not errors.is_empty(): return _failure(loaded.path, errors)
	var defaults: Dictionary = settings.definition.defaults
	var origin: Array = data.get("frame", {}).get("origin", [float(canvas[0]) / 2, float(canvas[1]) / 2]) if data.kind == "base" else data.attachment
	var marker: Array = data.get("frame", {}).get("up", [origin[0], origin[1] - 1]) if data.kind == "base" else data.get("direction", [origin[0], origin[1] - 1])
	var forward := _vector(marker) - _vector(origin)
	if not forward.is_finite() or forward.is_zero_approx(): errors.append("Native direction must be finite and nonzero")
	if not _inside(origin, canvas): errors.append("Placement origin must be inside canvas")
	var light := _vector(data.lighting.toward) - _vector(origin) if data.has("lighting") else Vector2.ZERO
	if data.has("lighting") and (not light.is_finite() or light.is_zero_approx()): errors.append("Lighting direction must be finite and nonzero")
	var resolved := {"origin": origin, "forward": _pair(forward.normalized()), "lighting": _pair(light.normalized()), "has_lighting": data.has("lighting"), "spawn": _merge(defaults.spawn, data.get("spawn", {})), "orientation": _merge(defaults.orientation, data.get("orientation", {})), "variation": _merge(defaults.variation, data.get("variation", {})), "constraints": _merge(defaults.constraints, data.get("constraints", {})), "transforms": _merge({"allow_flip_x": defaults.allow_flip_x, "allow_flip_y": defaults.allow_flip_y}, data.get("transforms", {}))}
	var reserved := 0
	for amount: Variant in resolved.spawn.get("group_counts", {}).values(): reserved += int(amount)
	var reserved_max := reserved
	for limits: Array in resolved.spawn.get("group_count_ranges", {}).values():
		reserved += int(limits[0])
		reserved_max += int(limits[1])
	if reserved_max > resolved.spawn.count[1]: errors.append("Group maximum counts exceed maximum total")
	if reserved > resolved.spawn.count[0]: errors.append("spawn.group_counts: reserved counts exceed minimum total count")
	var anchors: Array = []
	for anchor: Dictionary in data.get("anchors", []):
		var position := _vector(anchor.position)
		if not _inside(anchor.position, canvas): errors.append("anchors/" + anchor.id + ": position outside canvas")
		var native := _vector(anchor.forward) - position if anchor.has("forward") else forward
		if not native.is_finite(): errors.append("anchors/" + anchor.id + ": direction exceeds source-coordinate precision")
		var normalized := anchor.duplicate(true)
		normalized.forward = _pair(native.normalized())
		normalized.growth_at = anchor.get("growth_at", 0.0)
		normalized.orientation = _merge(resolved.orientation, anchor.get("orientation", {}))
		anchors.append(normalized)
	for connection: Dictionary in data.get("connections", []):
		if not _vector(connection.toward).is_finite(): errors.append("connections/" + connection.id + ": direction exceeds source-coordinate precision")
		if not _inside(connection.position, canvas): errors.append("connections/" + connection.id + ": position outside canvas")
	if not errors.is_empty(): return _failure(loaded.path, errors)
	var reveals: Dictionary = {}
	# A base/anchor can override direct -> progressive later, so precompute a
	# directional field for every decoration having positive visible extent.
	if data.kind == "decoration":
		var explicit := ""
		if data.get("spawn", {}).has("reveal_mask"):
			explicit = path_for(data.spawn.reveal_mask, loaded.root, "png")
			if explicit.is_empty(): return _failure(loaded.path, ["Invalid reveal_mask path"])
		for variant: String in image_paths:
			var reveal := _reveal(image_paths[variant], _vector(origin), forward.normalized(), explicit, _vector(canvas))
			if not reveal.ok and (resolved.spawn.mode == "progressive" or not explicit.is_empty()): return _failure(loaded.path, reveal.errors)
			if reveal.ok: reveals[variant] = reveal.asset
	var result := {"ok": true, "errors": [], "path": loaded.path, "root": loaded.root, "definition": data, "canvas_px": canvas, "images": image_paths, "resolved": resolved, "anchors": anchors, "reveals": reveals}
	if source is String: _records[cache_key] = result.duplicate(true)
	return result

static func load_catalog(source: Variant, root: String = "res://", settings_source: Variant = SETTINGS_PATH) -> Dictionary:
	var loaded := _document(source, root)
	if not loaded.ok: return loaded
	var settings := _settings(settings_source)
	if not settings.ok: return settings
	var key: String = loaded.path + "/" + JSON.stringify(settings.definition).sha256_text()
	if source is String and _catalogs.has(key): return _catalogs[key].duplicate(true)
	var schema := _document("res://assets/shared/schemas/sprite-catalog-v1.schema.json", "res://")
	if not schema.ok: return schema
	var errors := Schema.validate(loaded.definition, schema.definition)
	if not errors.is_empty(): return _failure(loaded.path, errors)
	var families: Dictionary = {}
	for name: String in loaded.definition.families:
		if name.is_empty(): errors.append("Family name cannot be empty")
		if name in loaded.definition.get("legacy_families", []): errors.append("Family cannot be both staged and legacy: " + name)
		var raw: Dictionary = loaded.definition.families[name]
		var family := {"logical_colors": raw.logical_colors.duplicate(true), "bases": [], "decorations": []}
		var seen: Dictionary = {}
		var ids: Dictionary = {}
		for collection: String in ["bases", "decorations"]:
			for reference: String in raw[collection]:
				var path := path_for(reference, loaded.root)
				if path.is_empty() or seen.has(path):
					errors.append(name + "/" + collection + ": invalid or duplicate metadata reference " + reference)
					continue
				seen[path] = true
				var record := load_sprite(path, "res://", settings_source)
				if not record.ok:
					errors.append_array(record.errors)
					continue
				if record.definition.kind != ("base" if collection == "bases" else "decoration"): errors.append(path + ": wrong sprite kind for " + collection)
				var id := path.get_file().get_basename()
				if ids.has(id): errors.append(name + ": duplicate part basename " + id)
				ids[id] = true
				for color: String in raw.logical_colors:
					if not record.images.has(raw.logical_colors[color].image_variant): errors.append(path + ": missing image variant for logical color " + color)
				family[collection].append(record)
		families[name] = family
	if not errors.is_empty(): return _failure(loaded.path, errors)
	var result := {"ok": true, "errors": [], "path": loaded.path, "root": loaded.root, "definition": loaded.definition, "families": families, "settings": settings.definition}
	if source is String: _catalogs[key] = result.duplicate(true)
	return result

static func rules(base: Dictionary, decoration: Dictionary, anchor: Dictionary, settings: Dictionary) -> Dictionary:
	# Raw authored values are essential here: an inherited base default must
	# not erase an explicitly authored decoration's animation or scale.
	var defaults: Dictionary = settings.defaults
	var animation: Dictionary = defaults.spawn.duplicate(true)
	for item: Dictionary in [decoration, base, anchor]: animation.merge(item.get("spawn", {}), true)
	for field: String in ["count", "minimum_spacing_px", "group_counts", "group_count_ranges", "group_anchor_sets", "max_per_group"]: animation.erase(field)
	if animation.mode == "progressive" and not decoration.has("direction"): return _failure("spawn", ["Progressive override requires an explicit decoration direction"])
	var orientation := _merge(_merge(defaults.orientation, base.get("orientation", {})), anchor.get("orientation", {}))
	var variation := _merge(_merge(defaults.variation, base.get("variation", {})), decoration.get("variation", {}))
	var constraints: Dictionary = defaults.constraints.duplicate(true)
	var overlaps: Array = []
	for item: Dictionary in [defaults, base, anchor, decoration]:
		var extra: Dictionary = item.get("constraints", {})
		for field: String in extra:
			match field:
				"inside_canvas", "avoid_deco_overlap": constraints[field] = constraints.get(field, false) or extra[field]
				"edge_margin_px", "base_gap_px": constraints[field] = maxf(constraints.get(field, 0), extra[field])
				"max_radius_px": constraints[field] = minf(constraints.get(field, INF), extra[field])
				"base_overlap":
					if extra[field] != "allow" and extra[field] not in overlaps: overlaps.append(extra[field])
	constraints.base_overlap_checks = overlaps
	# Keep the simple field for consumers of one restriction; checks retains
	# every requirement when different scopes impose both restrictions.
	constraints.base_overlap = overlaps[0] if not overlaps.is_empty() else "allow"
	return {"ok": true, "animation": animation, "orientation": orientation, "variation": variation, "constraints": constraints}

static func pattern_definition(catalog: Dictionary, family_id: String, logical_color: int) -> Dictionary:
	if not catalog.get("ok", false): return _failure("catalog", catalog.get("errors", ["Catalog failed to load"]))
	if not catalog.families.has(family_id): return _failure(catalog.path, ["Unknown artwork family " + family_id])
	var family: Dictionary = catalog.families[family_id]
	var color := str(logical_color)
	if not family.logical_colors.has(color): return _failure(catalog.path, ["No artwork binding for logical color " + color])
	var variant: String = family.logical_colors[color].image_variant
	var compositions: Dictionary = {}
	for collection: String in ["bases", "decorations"]:
		var parts: Dictionary = {}
		for record: Dictionary in family[collection]:
			var spec := {"asset": {"provider": "texture", "path": record.images[variant]}, "pivot_px": record.resolved.origin.duplicate(), "sprite_metadata_path": record.path, "source_canvas_px": record.canvas_px.duplicate(), "sprite_rules": record.resolved.duplicate(true)}
			if record.resolved.spawn.mode == "progressive" and record.definition.kind == "decoration":
				spec.masks = {"growth": {"purpose": "reveal", "channel": "r", "encoding": "linear", "zero": "first_visible", "one": "last_visible", "asset": record.reveals[variant].duplicate(true)}}
			parts[record.path.get_file().get_basename()] = spec
		compositions[collection] = {"parts": parts}
	return {"ok": true, "definition": {"schema": "tiles.pattern-set.v1", "id": catalog.definition.id + "/" + family_id + "/" + color, "tier": 1, "roles": {"vine": "bases", "decoration": "decorations"}, "compositions": compositions}, "root": "res://"}
