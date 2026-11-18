class_name PatternJunctionLayer
extends Node2D

const LeafCenters = preload("res://scripts/pattern/leaf_centers.gd")
const CellVariation = preload("res://scripts/pattern/cell_variation.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Topology = preload("res://scripts/pattern/topology.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Palette = preload("res://scripts/palette.gd")
const Reveal = preload("res://shaders/sprite_reveal.gdshader")
var renderer := Renderer.new()
var events: Dictionary = {}
var specs: Dictionary = {}
var diagnostics: Array = []
var _records: Dictionary = {}

static func configuration(theme: String) -> Dictionary:
	return Themes.profile(theme).get("junctions", {})

static func role(shape: String, config: Dictionary) -> String:
	return "core" if shape in ["isolated", "endpoint"] and config.get("shapes", {}).has("core") else shape

static func handles(theme: String, shape: String) -> bool:
	var config := configuration(theme)
	return config.get("enabled", false) and config.get("shapes", {}).has(role(shape, config))

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _fail(message: String) -> Dictionary:
	return {"ok": false, "errors": [message]}

func load_sprite(path: String) -> Dictionary:
	if _records.has(path): return _records[path].duplicate(true)
	if not path.begins_with("res://") or path.get_extension() != "json" or not FileAccess.file_exists(path): return _fail("Missing junction metadata: " + path)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema") != "tiles.junction-sprite.v1": return _fail("Invalid junction metadata: " + path)
	for key: String in data:
		if key not in ["schema", "image", "center", "scale", "rotation", "source_color", "color_role"]: return _fail("Unknown junction field: " + key)
	if not data.get("image") is String: return _fail("Junction needs an image")
	var image_path := Assets.path_for(data.image, path.get_base_dir())
	if not image_path.begins_with("res://"): return _fail("Junction artwork must be a project texture")
	var errors := Assets.validate(image_path)
	if not errors.is_empty(): return {"ok": false, "errors": errors}
	var texture := Assets.resolve(image_path)
	if texture == null: return _fail("Unable to load junction artwork")
	var size := texture.get_size()
	var center: Variant = data.get("center", [(size.x - 1) * 0.5, (size.y - 1) * 0.5])
	if not center is Array or center.size() != 2 or not center.all(func(n): return number(n)): return _fail("Junction center needs two finite source coordinates")
	var pivot := Vector2(center[0], center[1])
	if pivot.x < 0 or pivot.y < 0 or pivot.x > size.x - 1 or pivot.y > size.y - 1: return _fail("Junction center is outside artwork")
	var scale: Variant = data.get("scale", 1.0)
	if not number(scale) or scale <= 0: return _fail("Junction scale must be positive")
	var rotation: Variant = data.get("rotation", {})
	if not rotation is Dictionary: return _fail("Junction rotation must be an object")
	for key: String in rotation:
		if key not in ["allowed_deg", "range_deg"]: return _fail("Unknown rotation field: " + key)
	if rotation.has("allowed_deg") and rotation.has("range_deg"): return _fail("Choose allowed_deg or range_deg, not both")
	if rotation.has("allowed_deg"):
		if not rotation.allowed_deg is Array or rotation.allowed_deg.is_empty() or not rotation.allowed_deg.all(func(n): return number(n)): return _fail("Expected a nonempty list of permitted angles")
	if rotation.has("range_deg"):
		if not rotation.range_deg is Array or rotation.range_deg.size() != 2 or not rotation.range_deg.all(func(n): return number(n)) or rotation.range_deg[0] > rotation.range_deg[1]: return _fail("Expected an ascending angle range")
	if data.get("color_role", "original") not in ["original", "opposite", "same"]: return _fail("Unknown junction color role")
	if (data.has("source_color") or data.get("color_role", "original") != "original") and (not data.get("source_color") is String or not Color.html_is_valid(data.source_color)): return _fail("Palette treatment needs a valid source_color")
	var record := {"ok": true, "path": path, "texture": texture, "size": size, "center": pivot, "scale": float(scale), "rotation": rotation, "revision": JSON.stringify(data).sha256_text(), "color_role": data.get("color_role", "original"), "source_color": Color(data.get("source_color", "ffffff"))}
	_records[path] = record.duplicate(true)
	return record

func prepare(model, theme: String, before: Array, settled: bool, preserve: bool, at: float, restart: bool, elapsed: float) -> bool:
	diagnostics.clear()
	var next_events: Dictionary = {}
	var next_specs: Dictionary = {}
	var config := configuration(theme)
	if not config.get("enabled", false):
		events.clear()
		specs.clear()
		return true
	if not config.get("shapes") is Dictionary:
		diagnostics.append("Junction shapes must be an object")
		return false
	# Preflight every shape/color before replacing the live presentation.
	var loaded: Dictionary = {}
	var paths: Dictionary = {}
	for shape: String in (["bend", "t", "cross", "core"] if config.shapes.has("core") else ["bend", "t", "cross"]):
		if not config.get("shapes", {}).get(shape) is Dictionary:
			diagnostics.append("Junction configuration needs bend, t and cross bindings")
			return false
		loaded[shape] = {}
		for color: String in ["1", "2"]:
			var path: Variant = config.shapes[shape].get(color)
			if not path is String or paths.has(path):
				diagnostics.append("Each junction shape/color needs its own metadata file")
				return false
			paths[path] = true
			var record := load_sprite(path)
			if not record.ok:
				diagnostics.append_array(record.errors)
				return false
			loaded[shape][color] = record
	# Retain leaf cores along straight growth; junction flowers replace them.
	if config.get("leaf_centers", {}).get("retain_when_connected", false) and preserve:
		for previous_id: String in events:
			if not "/core/leaf_" in previous_id: continue
			var previous: Dictionary = events[previous_id]
			var cell: Vector2i = previous.owner
			var color := int(previous_id.get_slice("/", 2))
			if Topology.value(model.board, cell) != color or Topology.value(before, cell) != color: continue
			if Topology.shape(Topology.neighbor_mask(model.board, cell)) in ["bend", "t", "cross"]: continue
			next_events[previous_id] = previous.duplicate(true)
			next_events[previous_id].old = true
			next_specs[previous_id] = specs[previous_id]
	for cell: Vector2i in model.arrivals:
		var shape := role(Topology.shape(Topology.neighbor_mask(model.board, cell)), config)
		if not loaded.has(shape): continue
		var color := Topology.value(model.board, cell)
		if shape in config.get("disabled_shapes_by_color", {}).get(str(color), []): continue
		var artwork: Dictionary = Themes.profile(theme).get("tier1_artwork", {})
		# Cell-centered paths already provide the entire core stone plus its deco.
		if shape == "core" and artwork.get("status") == "active" and artwork.get("source_layout") == "cell_centers" and color == int(artwork.get("logical_color", 2)): continue
		var record: Dictionary = loaded[shape][str(color)].duplicate(true)
		var variation := CellVariation.choice(theme, cell, color) if shape == "core" else {}
		if not variation.is_empty():
			record.texture = variation.texture
			record.size = variation.texture.get_size()
			record.center = variation.center
			record.revision += "/" + variation.base_path
		var id := "junction/%s/%d/%d/%d/%s" % [theme, color, cell.y, cell.x, shape]
		var rng := RandomNumberGenerator.new()
		rng.seed = JSON.stringify([config.get("seed", 10973), id]).sha256_text().substr(0, 15).hex_to_int()
		var degrees := 0.0
		if record.rotation.has("allowed_deg"): degrees = record.rotation.allowed_deg[rng.randi_range(0, record.rotation.allowed_deg.size() - 1)]
		elif record.rotation.has("range_deg"): degrees = rng.randf_range(record.rotation.range_deg[0], record.rotation.range_deg[1])
		if not variation.is_empty(): degrees = variation.rotation_deg
		# 100% uses one square of source canvas. No raster or artwork resampling.
		var transform := Transform2D(deg_to_rad(degrees), Vector2(-1.0 if variation.get("flip_x", false) else 1.0, 1.0) * record.scale / maxf(record.size.x, record.size.y), 0.0, Vector2.ZERO)
		transform.origin = Vector2(cell) + Vector2.ONE * 0.5 - transform.basis_xform(record.center)
		var old := settled or (Topology.value(before, cell) == color and role(Topology.shape(Topology.neighbor_mask(before, cell)), config) == shape)
		var start := maxf(at, float(model.arrivals[cell]))
		var revision: String = record.revision + "/" + str(degrees)
		if preserve and not settled and events.has(id) and events[id].revision == revision:
			var previous: Dictionary = events[id]
			if not previous.old and previous.start > at + (elapsed if restart else 0.0):
				old = false
				start = previous.start - (elapsed if restart else 0.0)
		if shape == "core" and config.has("leaf_centers"):
			var leaves := LeafCenters.placements(config.leaf_centers, cell, color, Topology.neighbor_mask(model.board,cell))
			for i in range(leaves.size()):
				var leaf_id := id + "/leaf_%d" % i
				next_events[leaf_id] = {"start":start,"end":start,"old":old,"revision":JSON.stringify(config.leaf_centers),"owner":cell,"kind":"junction"}
				next_specs[leaf_id] = leaves[i]
			continue
		next_events[id] = {"start": start, "end": start, "old": old, "revision": revision, "owner": cell, "kind": "junction"}
		next_specs[id] = {"asset": record.texture, "source_transform": transform, "lifecycle": "external", "material": null}
		if record.color_role != "original":
			var target := Palette.accent(color) if record.color_role == "opposite" else Palette.pigment(color)
			next_specs[id].material = Renderer.material(Reveal, {"recolor": true, "palette_source": record.source_color, "palette_target": target, "reveal_progress": 1.0})
	if theme == "vines":
		var duration: float = Assets.load_set(Themes.pattern_set_path(theme,2)).definition.compositions.flower.parts.flower.animation.duration_seconds
		for id: String in next_events:
			if not id.get_slice("/",5) in ["bend","t","cross"]:continue
			var cell: Vector2i = next_events[id].owner
			var covers: Array = []
			for corner: Vector2i in model.flowers:
				if cell.x>=corner.x-1 and cell.x<=corner.x and cell.y>=corner.y-1 and cell.y<=corner.y:
					covers.append({"start":model.flowers[corner].start,"old":model.flowers[corner].old,"duration":duration})
			next_events[id].flower_covers=covers
	events = next_events
	specs = next_specs
	z_index = int(config.get("z_index", 1))
	return true

func present(state, view_transform: Transform2D) -> bool:
	transform = view_transform
	if not renderer.sync(specs, self):
		diagnostics.append_array(renderer.diagnostics)
		return false
	advance(state)
	return true

func advance(state) -> void:
	for id: String in renderer.nodes:
		var record: Dictionary = state.records.get(id, {})
		var alpha := 1.0
		for cover: Dictionary in events.get(id,{}).get("flower_covers",[]):
			alpha = minf(alpha,0.0 if cover.old else 1.0-clampf((state.schedule.clock-cover.start)/cover.duration,0.0,1.0))
		renderer.nodes[id].modulate.a=alpha
		renderer.nodes[id].visible = not record.is_empty() and record.phase != "waiting" and alpha>0.0
