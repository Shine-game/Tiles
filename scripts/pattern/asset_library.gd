class_name PatternAssetLibrary
extends RefCounted

const SET_SCHEMA := "tiles.pattern-set.v1"
static var textures: Dictionary = {}
static var atlases: Dictionary = {}
static var generated: Dictionary = {}
static var providers: Dictionary = {}
static var provider_validators: Dictionary = {}
static var node_kinds: Dictionary = {"sprite": true, "group": true}
static var material_kinds: Dictionary = {}

static func register_provider(id: String, factory: Callable, validator: Callable = Callable()) -> void:
	providers[id] = factory
	if validator.is_valid(): provider_validators[id] = validator

static func path_for(path: String, root: String) -> String:
	return (path if path.begins_with("res://") else root.path_join(path)).simplify_path()

static func region(value: Variant) -> Rect2:
	if value is Rect2: return value
	if value is Array and value.size() == 4 and value.all(func(n): return n is int or n is float): return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Rect2()

static func validate(asset: Variant, root: String = "res://") -> Array:
	if asset is Texture2D: return []
	if asset is String: asset = {"provider": "texture", "path": asset}
	if not asset is Dictionary: return ["Asset must be a texture, path or descriptor"]
	var status: String = str(asset.get("status", "available"))
	if status not in ["available", "missing", "unused"]: return ["Unknown asset status: " + status]
	if status != "available": return ["Required asset is " + status] if asset.get("required", false) else []
	var provider: String = str(asset.get("provider", "texture"))
	if provider == "variants":
		var choices: Variant = asset.get("variants")
		if not choices is Dictionary or choices.is_empty(): return ["Variant asset needs named treatments"]
		var errors: Array = []
		for name: String in choices:
			for issue: String in validate(choices[name], root): errors.append(name + ": " + issue)
		if asset.has("variant") and not choices.has(str(asset.variant)): errors.append("Unknown artwork treatment: " + str(asset.variant))
		return errors
	if provider not in ["texture", "atlas"]:
		if not providers.has(provider): return ["Unknown registered texture provider: " + provider]
		if not asset.get("params", {}) is Dictionary: return ["Provider parameters must be an object: " + provider]
		return provider_validators[provider].call(asset.get("params", {})) if provider_validators.has(provider) else []
	var path := path_for(str(asset.get("path", "")), root)
	if not path.begins_with("res://") or path.get_extension().to_lower() not in ["png", "webp", "jpg", "jpeg", "svg", "ctex"]: return ["Expected a project texture path: " + path]
	if not ResourceLoader.exists(path, "Texture2D"): return ["Texture does not exist: " + path]
	if provider == "atlas":
		var rect := region(asset.get("region_px"))
		if rect.position.x < 0 or rect.position.y < 0 or rect.size.x <= 0 or rect.size.y <= 0: return ["Invalid atlas region for " + path]
		var master := texture(path)
		if master == null: return ["Unable to load atlas source: " + path]
		if rect.end.x > master.get_width() or rect.end.y > master.get_height(): return ["Atlas region exceeds source texture: " + path]
	return []

static func select_variant(asset: Variant, treatment: String, errors: Array = []) -> Variant:
	if not asset is Dictionary or asset.get("provider", "texture") != "variants": return asset
	var choices: Dictionary = asset.get("variants", {})
	if not choices.has(treatment):
		errors.append("No artwork treatment selected: " + treatment)
		return null
	return select_variant(choices[treatment], treatment, errors)

static func bind_part(part: Dictionary, treatment: String) -> Dictionary:
	var result: Dictionary = part.duplicate(true)
	var errors: Array = []
	if part.has("asset"): result.asset = select_variant(part.asset, treatment, errors)
	if part.get("masks") is Dictionary:
		for id: String in part.masks:
			result.masks[id].asset = select_variant(part.masks[id].asset, treatment, errors)
	return {"ok": errors.is_empty(), "part": result, "errors": errors}

static func texture(path: String, root: String = "res://") -> Texture2D:
	return resolve({"provider": "texture", "path": path}, root)

static func resolve(asset: Variant, root: String = "res://", errors: Array = []) -> Texture2D:
	if asset is Texture2D: return asset
	if asset is String: asset = {"provider": "texture", "path": asset}
	var issues := validate(asset, root)
	if not issues.is_empty():
		errors.append_array(issues)
		return null
	if asset.get("status", "available") != "available": return null
	var provider: String = str(asset.get("provider", "texture"))
	if provider == "variants":
		var chosen: Variant = select_variant(asset, str(asset.get("variant", "")), errors)
		return resolve(chosen, root, errors) if chosen != null else null
	if provider not in ["texture", "atlas"]:
		var params: Dictionary = asset.get("params", {})
		var key := provider + "/" + var_to_bytes(params).hex_encode()
		if not generated.has(key):
			var result: Variant = providers[provider].call(params)
			if not result is Texture2D:
				errors.append("Texture provider did not return Texture2D: " + provider)
				return null
			generated[key] = result
		return generated[key]
	var path := path_for(asset.path, root)
	if not textures.has(path): textures[path] = load(path) as Texture2D
	if provider == "texture": return textures[path]
	var rect := region(asset.region_px)
	var key := path + "/" + str(rect) + "/" + str(asset.get("filter_clip", true))
	if not atlases.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = textures[path]
		atlas.region = rect
		atlas.filter_clip = asset.get("filter_clip", true)
		atlases[key] = atlas
	return atlases[key]

static func validate_placement(spec: Dictionary) -> Array:
	var errors: Array = []
	for field: String in ["position_cells", "position_px", "pivot_px", "offset_px", "scale", "size_cells"]:
		if not spec.has(field): continue
		var v: Variant = spec[field]
		if not v is Vector2 and not (v is Array and v.size() == 2 and v.all(func(n): return n is int or n is float)): errors.append("Expected a vector for " + field)
	for field: String in ["pixels_per_cell", "rotation_radians", "quarter_turns", "z_index", "texture_filter"]:
		if spec.has(field) and not (spec[field] is int or spec[field] is float): errors.append("Expected a number for " + field)
	if spec.has("pixels_per_cell") and (spec.pixels_per_cell is float or spec.pixels_per_cell is int) and spec.pixels_per_cell <= 0: errors.append("pixels_per_cell must be positive")
	return errors

static func validate_masks(part: Dictionary, root: String = "res://") -> Array:
	var errors: Array = []
	if not part.has("masks"): return errors
	if not part.masks is Dictionary: return ["Masks must be a named dictionary"]
	for id: String in part.masks:
		var mask: Variant = part.masks[id]
		if not mask is Dictionary:
			errors.append("Mask must be a descriptor: " + id)
			continue
		if mask.get("purpose", "") not in ["reveal", "protection", "coverage", "placement"]: errors.append("Unknown mask purpose: " + id)
		if mask.get("channel", "") not in ["r", "g", "b", "a"]: errors.append("Missing/unknown mask channel: " + id)
		if mask.get("encoding", "") != "linear": errors.append("Masks must declare linear encoding: " + id)
		if not mask.has("zero") or not mask.has("one"): errors.append("Mask needs explicit zero/one meanings: " + id)
		errors.append_array(validate(mask.get("asset"), root))
	return errors

static func load_set(source: Variant, root: String = "res://") -> Dictionary:
	var errors: Array = []
	var definition: Variant = source
	if source is String:
		var path := path_for(source, root)
		if not path.begins_with("res://") or path.get_extension() != "json" or not FileAccess.file_exists(path):
			return {"ok": false, "errors": ["Expected a project JSON set: " + path]}
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {"ok": false, "errors": ["Invalid set JSON: " + parser.get_error_message()]}
		definition = parser.data
		root = path.get_base_dir()
	if not definition is Dictionary: return {"ok": false, "errors": ["Set must be an object"]}
	if definition.get("schema", "") != SET_SCHEMA: errors.append("Expected schema " + SET_SCHEMA)
	if not definition.get("id") is String or str(definition.get("id", "")).is_empty(): errors.append("Set needs a stable string id")
	var tier: Variant = definition.get("tier", -1)
	if not (tier is int or tier is float) or float(tier) != floorf(float(tier)) or int(tier) < 0 or int(tier) > 3: errors.append("Set tier must be 0, 1, 2 or 3")
	if not definition.get("compositions") is Dictionary: return {"ok": false, "errors": errors + ["Set needs compositions"]}
	for name: String in definition.compositions:
		var composition: Variant = definition.compositions[name]
		if not composition is Dictionary or not composition.get("parts") is Dictionary:
			errors.append("Composition needs named parts: " + name)
			continue
		for id: String in composition.parts:
			var part: Variant = composition.parts[id]
			if not part is Dictionary:
				errors.append("Part must be an object: " + name + "/" + id)
				continue
			for issue: String in validate_placement(part) + validate_masks(part, root): errors.append(name + "/" + id + ": " + issue)
			var kind: String = str(part.get("provider", "sprite"))
			if not node_kinds.has(kind): errors.append(name + "/" + id + ": Unknown node provider: " + kind)
			if part.get("material") is Dictionary and not material_kinds.has(part.material.get("provider", "")):
				errors.append(name + "/" + id + ": Unknown material provider")
			if kind == "sprite":
				for issue: String in validate(part.get("asset"), root): errors.append(name + "/" + id + ": " + issue)
	if definition.has("roles"):
		if not definition.roles is Dictionary: errors.append("Roles must be named composition references")
		else:
			for role: String in definition.roles:
				var target: Variant = definition.roles[role]
				if target != null and (not target is String or not definition.compositions.has(target)): errors.append("Unknown composition for role " + role)
	return {"ok": errors.is_empty(), "errors": errors, "definition": definition.duplicate(true), "root": root}
