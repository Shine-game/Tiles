class_name PatternThemeRegistry
extends RefCounted

# One active theme/UI contract. Hook IDs select reviewed project code; data
# never names a script to execute. Pattern artwork stays in pattern-set files.
const PATH := "res://assets/themes/themes.json"
const SCHEMA := "tiles.themes.v1"
const HOOKS := ["zen_garden", "clockwork", "vines", "coral_reef"]
static var definition: Dictionary = {}

static func validate(data: Variant) -> Array:
	if not data is Dictionary: return ["Theme registry must be an object"]
	var errors: Array = []
	if data.get("schema") != SCHEMA: errors.append("Expected schema " + SCHEMA)
	var themes: Variant = data.get("themes")
	var order: Variant = data.get("order")
	if not themes is Dictionary or themes.is_empty(): return errors + ["Registry needs named themes"]
	if not order is Array or order.is_empty(): return errors + ["Registry needs ordered theme IDs"]
	var seen: Dictionary = {}
	for id: Variant in order:
		if not id is String or not themes.has(id) or seen.has(id): errors.append("Invalid or duplicate theme ID: " + str(id))
		else: seen[id] = true
	if seen.size() != themes.size(): errors.append("Every active theme must appear in order")
	if not seen.has(data.get("default", "")): errors.append("Default theme must be active")
	for id: String in themes:
		var profile: Variant = themes[id]
		if not profile is Dictionary:
			errors.append(id + ": profile must be an object")
			continue
		for field: String in ["name", "version"]:
			if not profile.get(field) is String or str(profile[field]).is_empty(): errors.append(id + ": missing " + field)
		var colors: Variant = profile.get("colors")
		if not colors is Array or colors.size() not in [0, 2]: errors.append(id + ": colors must be empty or a pair")
		elif not colors.all(func(c): return c is String and Color.html_is_valid(c)): errors.append(id + ": invalid tile color")
		for field: String in ["ui", "frame", "sets", "hooks", "preview", "environment"]:
			if not profile.get(field) is Dictionary: errors.append(id + ": missing " + field)
		if profile.get("ui") is Dictionary:
			for key: String in profile.ui:
				var value: Variant = profile.ui[key]
				if not value is String or not Color.html_is_valid(value): errors.append(id + ": invalid UI color " + key)
		if profile.get("frame") is Dictionary:
			if not profile.frame.get("enabled") is bool: errors.append(id + ": frame enabled must be boolean")
			if not profile.frame.get("appearance") is String: errors.append(id + ": frame needs an appearance ID")
			if profile.frame.get("enabled", false) == true and not texture_file(profile.frame.get("texture")): errors.append(id + ": missing frame artwork")
		if profile.get("preview") is Dictionary:
			var ground: Variant = profile.preview.get("ground")
			if not ground is String or not Color.html_is_valid(ground): errors.append(id + ": invalid preview ground")
			var core: Variant = profile.preview.get("core")
			if not core is String or (core != "" and not texture_file(core)): errors.append(id + ": invalid preview artwork")
		if profile.get("environment") is Dictionary and profile.environment.has("background"):
			if not texture_file(profile.environment.background): errors.append(id + ": invalid background artwork")
		if profile.get("hooks") is Dictionary:
			for kind: String in ["growth", "environment"]:
				if profile.hooks.get(kind) not in HOOKS: errors.append(id + ": unknown " + kind + " hook")
		if profile.get("sets") is Dictionary:
			if profile.sets.is_empty(): errors.append(id + ": no pattern families")
			for family: String in profile.sets:
				var tiers: Variant = profile.sets[family]
				if not tiers is Dictionary:
					errors.append(id + ": invalid tier family")
					continue
				for tier: String in ["0", "1", "2"]:
					if not tiers.has(tier): errors.append(id + ": missing tier " + tier)
				for tier: String in tiers:
					if tier not in ["0", "1", "2", "3"] or not project_file(tiers[tier], "json"): errors.append(id + ": invalid set path for tier " + tier)
		if profile.has("tier1_artwork"):
			var artwork: Variant = profile.tier1_artwork
			if not artwork is Dictionary or artwork.get("status") not in ["staged", "active"] or not project_file(artwork.get("catalog"), "json"):
				errors.append(id + ": invalid tier1_artwork catalog link")
			else:
				var layout: Variant = artwork.get("source_layout")
				if artwork.status == "active" and layout == null: errors.append(id + ": active tier1_artwork needs source_layout")
				if layout != null and layout not in ["components", "edge_halves", "shared_edges", "cell_centers"]: errors.append(id + ": unsupported source_layout")
				if layout == "components":
					var ports: Variant = artwork.get("component_ports")
					if not ports is Dictionary or ports.is_empty(): errors.append(id + ": components layout needs component_ports")
					else:
						for port: Variant in ports.values():
							if not (port is String and not port.is_empty()) and not ((port is int or port is float) and port == floorf(port) and port >= 0 and port <= 3): errors.append(id + ": invalid component port")
				if artwork.has("size_cells"):
					var size: Variant = artwork.size_cells
					if not size is Array or size.size() != 2 or not size.all(func(n): return (n is int or n is float) and is_finite(n) and n > 0): errors.append(id + ": invalid sprite size_cells")
				for field: String in ["stroke_seconds", "duration_sec"]:
					if artwork.has(field) and (not (artwork[field] is int or artwork[field] is float) or not is_finite(float(artwork[field])) or artwork[field] < 0): errors.append(id + ": invalid " + field)
				for field: String in ["layer_z_index", "decoration_z_index", "seed"]:
					if artwork.has(field) and (not (artwork[field] is int or artwork[field] is float) or not is_finite(float(artwork[field])) or artwork[field] != floorf(artwork[field])): errors.append(id + ": invalid " + field)
				if artwork.has("logical_color") and (not (artwork.logical_color is int or artwork.logical_color is float) or artwork.logical_color != floorf(artwork.logical_color) or artwork.logical_color < 1 or artwork.logical_color > 2): errors.append(id + ": invalid sprite logical_color")
				if artwork.has("family") and (not artwork.family is String or artwork.family.is_empty()): errors.append(id + ": invalid sprite family")
		if profile.get("environment") is Dictionary and profile.environment.has("catalog"):
			if not project_file(profile.environment.catalog, "json"): errors.append(id + ": invalid environment catalog")
	if not data.get("frame_geometry") is Dictionary: errors.append("Missing shared frame geometry")
	else:
		var geometry: Dictionary = data.frame_geometry
		if not geometry.get("source_size") is Array or geometry.source_size.size() != 2 or not geometry.source_size.all(func(n): return (n is int or n is float) and n > 0): errors.append("Frame needs source dimensions")
		for field: String in ["rim", "sidewall"]:
			var value: Variant = geometry.get(field)
			if not (value is int or value is float) or float(value) < 0: errors.append("Invalid frame " + field)
	var pairs: Variant = data.get("palette_pairs")
	if not pairs is Array or pairs.is_empty(): errors.append("Missing palette pairs")
	else:
		for pair: Variant in pairs:
			if not pair is Dictionary or not pair.get("colors") is Array or pair.colors.size() != 2:
				errors.append("Palette needs two colors")
				continue
			if not pair.get("name") is String: errors.append("Palette needs a name")
			for value: Variant in pair.colors + [pair.get("floor")]:
				if not value is String or not Color.html_is_valid(value): errors.append("Invalid palette color")
	return errors

static func project_file(path: Variant, extension: String) -> bool:
	return path is String and path.begins_with("res://") and path.get_extension() == extension and FileAccess.file_exists(path)

static func texture_file(path: Variant) -> bool:
	return path is String and path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D")

static func specification() -> Dictionary:
	if definition.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		var errors := validate(data)
		assert(errors.is_empty(), "Invalid theme registry: " + str(errors))
		if errors.is_empty(): definition = data
	return definition

static func ids() -> Array:
	return specification().order.duplicate()

static func profile(id: String) -> Dictionary:
	return specification().themes.get(id, {})

static func label(id: String) -> String:
	return profile(id).get("name", specification().get("archived_labels", {}).get(id, id))

static func pattern_set_path(id: String, tier: int, family: String = "default") -> String:
	return profile(id).get("sets", {}).get(family, {}).get(str(tier), "")

static func palette_pairs() -> Array:
	var pairs: Array = specification().palette_pairs.duplicate(true)
	for pair: Dictionary in pairs:
		pair.colors = [Color(pair.colors[0]), Color(pair.colors[1])]
		pair.floor = Color(pair.floor)
	return pairs

static func sprite_catalog_path(id: String) -> String:
	return profile(id).get("tier1_artwork", {}).get("catalog", "")
