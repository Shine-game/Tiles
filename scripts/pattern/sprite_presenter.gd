class_name PatternSpritePresenter
extends RefCounted

# Owns only presentation. ComponentState remains the sole clock/lifecycle owner.
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Metadata = preload("res://scripts/pattern/sprite_metadata.gd")
const Growth = preload("res://scripts/pattern/sprite_growth.gd")
const Timing = preload("res://scripts/pattern/growth_schedule.gd")
const Reveal = preload("res://shaders/sprite_reveal.gdshader")
const ROOT := "sprite-presentation"
var renderer := Renderer.new()
var diagnostics: Array = []
var _fields: Dictionary = {}

func clear() -> void:
	renderer.clear()
	_fields.clear()
	diagnostics.clear()

func _fail(message: String) -> bool:
	diagnostics.append(message)
	return false

func _valid_transform(value: Variant) -> bool:
	return value is Transform2D and value.is_finite() and value.determinant() != 0.0

func _base_field(base: Dictionary, field: Dictionary, override: Variant) -> Dictionary:
	var metadata := Metadata.load_sprite(base.metadata_path)
	if not metadata.ok: return {"ok": false, "errors": metadata.errors}
	var scalar: Texture2D
	if override != null:
		scalar = Assets.resolve(override, "res://", diagnostics)
		if scalar == null: return {"ok": false}
		if scalar.get_size() != Vector2(base.canvas_px[0], base.canvas_px[1]): return {"ok": false, "errors": ["Base field must match source canvas"]}
	var fronts: Array = field.fronts.duplicate(true)
	var reference := INF
	for front: Dictionary in fronts: reference = minf(reference, front.start)
	for front: Dictionary in fronts: front.start -= reference
	var key := str([base.metadata_path, base.image_path, fronts, field.u_range, override])
	if not _fields.has(key):
		var width := int(base.canvas_px[0])
		var height := int(base.canvas_px[1])
		var origin := Renderer.vector(metadata.resolved.origin)
		var forward := Renderer.vector(metadata.resolved.forward)
		var occupancy := Metadata.occupancy(base.image_path)
		if not occupancy.ok: return occupancy
		var extent := 0.0
		for y in range(height):
			for x in range(width):
				if occupancy.mask.get_bit(x, y): extent = maxf(extent, (Vector2(x, y) - origin).dot(forward))
		var source: Image = scalar.get_image() if scalar != null else null
		if source != null and source.is_compressed() and source.decompress() != OK: return {"ok": false, "errors": ["Unreadable base field"]}
		var image := Image.create(width, height, false, Image.FORMAT_RF)
		for y in range(height):
			for x in range(width):
				var u := source.get_pixel(x, y).r if source != null else clampf((Vector2(x, y) - origin).dot(forward) / maxf(extent, 0.000001), 0.0, 1.0)
				u = lerpf(field.u_range[0], field.u_range[1], u)
				image.set_pixel(x, y, Color(Timing.field_arrival(fronts, u), 0, 0, 1))
		if _fields.size() >= 64: _fields.erase(_fields.keys()[0])
		_fields[key] = ImageTexture.create_from_image(image)
	return {"ok": true, "texture": _fields[key], "start": reference, "soft_seconds": maxf(0.0, field.source_end - Timing.field_end(field.fronts))}

# Reconcile only on layout/source changes. View scaling may change independently.
# All resources and timing revisions are checked before touching the live tree.
func reconcile(plans: Dictionary, timeline: Dictionary, state, parent: Node2D, cells_to_pixels: Transform2D = Transform2D(0.0, Vector2(256, 256), 0.0, Vector2.ZERO), base_fields: Dictionary = {}) -> bool:
	diagnostics.clear()
	if not is_instance_valid(parent) or not _valid_transform(cells_to_pixels): return _fail("Invalid presentation parent or view transform")
	if timeline.get("version") != Growth.VERSION: return _fail("Unsupported sprite timeline")
	var prepared: Array = []
	var ids: Array = plans.keys()
	ids.sort()
	for id: String in ids:
		var plan: Dictionary = plans[id]
		if not plan.get("ok", false) or plan.get("component_id") != id: return _fail("Invalid component plan: " + id)
		var component: Dictionary = timeline.get("components", {}).get(id, {})
		if component.get("base_path") != plan.base.metadata_path: return _fail("Missing or stale base source: " + id)
		if not _valid_transform(plan.base.transform): return _fail("Invalid base transform: " + id)
		var base_texture := Assets.resolve(plan.base.image_path, "res://", diagnostics)
		if base_texture == null or base_texture.get_size() != Renderer.vector(plan.base.canvas_px): return _fail("Base texture does not match canvas: " + id)
		var field: Dictionary = component.field
		var base_material: ShaderMaterial
		if not field.old and state.schedule.clock < field.source_end:
			var built := _base_field(plan.base, field, base_fields.get(id))
			if not built.ok: return _fail("Invalid base reveal: " + id + str(built.get("errors", [])))
			base_material = Renderer.material(Reveal, {"time_field": true, "reveal_field": built.texture, "field_start": built.start, "soft_seconds": built.soft_seconds, "visual_clock": state.schedule.clock})
		var decorations: Array = []
		for placement: Dictionary in plan.decorations:
			var event_id := Growth.event_id(placement.id)
			var event: Dictionary = timeline.get("events", {}).get(event_id, {})
			var record: Dictionary = state.records.get(event_id, {})
			var revision := Growth.placement_revision(plan, placement)
			if event.get("revision") != revision or record.get("revision") != revision: return _fail("Missing or stale decoration timing: " + event_id)
			if not _valid_transform(placement.local_transform): return _fail("Invalid decoration transform: " + event_id)
			var texture := Assets.resolve(placement.image_path, "res://", diagnostics)
			if texture == null: return _fail("Missing decoration texture: " + event_id)
			var ink: ShaderMaterial
			if event.mode == "progressive" and record.phase != "settled":
				if not placement.has("reveal"): return _fail("Progressive decoration has no reveal: " + event_id)
				var mask := Assets.resolve(placement.reveal, "res://", diagnostics)
				if mask == null or mask.get_size() != texture.get_size(): return _fail("Invalid decoration reveal: " + event_id)
				ink = Renderer.material(Reveal, {"reveal_field": mask, "reveal_progress": record.progress})
			decorations.append({"id": event_id, "asset": texture, "source_transform": placement.local_transform, "material": ink, "growth_at": placement.growth_at})
		decorations.sort_custom(func(a, b): return a.growth_at < b.growth_at if a.growth_at != b.growth_at else a.id < b.id)
		prepared.append({"id": id, "base": plan.base, "asset": base_texture, "material": base_material, "field": field, "decorations": decorations})
	var keep: Array = [ROOT]
	var root := renderer.ensure(ROOT, {"provider": "group", "source_transform": cells_to_pixels, "lifecycle": "external"}, parent)
	for part: Dictionary in prepared:
		var group_id: String = ROOT + "/" + part.id
		var group := renderer.ensure(group_id, {"provider": "group", "source_transform": part.base.transform, "lifecycle": "external"}, root)
		root.move_child(group, -1)
		keep.append(group_id)
		var base_id := group_id + "/base"
		renderer.ensure(base_id, {"asset": part.asset, "source_transform": Transform2D.IDENTITY, "material": part.material, "lifecycle": "external"}, group)
		renderer.stop_reveal(base_id)
		if part.material != null: renderer.reveal(base_id, {"end": part.field.source_end}, "visual_clock")
		keep.append(base_id)
		for deco: Dictionary in part.decorations:
			var node := renderer.ensure(deco.id, {"asset": deco.asset, "source_transform": deco.source_transform, "material": deco.material, "lifecycle": "reveal", "z_index": 1}, group)
			group.move_child(node, -1)
			keep.append(deco.id)
	renderer.remove_missing(keep)
	advance(state)
	return true

func advance(state) -> void:
	renderer.advance(state.schedule.clock, state)

func set_view_transform(value: Transform2D) -> bool:
	if not _valid_transform(value): return _fail("Invalid view transform")
	if renderer.nodes.has(ROOT) and is_instance_valid(renderer.nodes[ROOT]): renderer.nodes[ROOT].transform = value
	return true

func cache_sizes() -> Dictionary:
	return {"arrival_fields": _fields.size(), "nodes": renderer.nodes.size()}
