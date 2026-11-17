class_name PatternSpritePlanner
extends RefCounted

const Metadata = preload("res://scripts/pattern/sprite_metadata.gd")
const Footprint = preload("res://scripts/pattern/sprite_footprint.gd")
const VERSION := 1
const EPSILON := 0.00001
const MAX_PLANS := 512
var _plans: Dictionary = {}
var _footprint := Footprint.new()

func clear() -> void:
	_plans.clear()
	_footprint.clear()

func forget(component_id: String) -> void:
	for key: String in _plans.keys():
		if _plans[key].component_id == component_id: _plans.erase(key)

func cache_sizes() -> Dictionary:
	return {"plans": _plans.size(), "geometry": _footprint.cache_sizes()}

static func _vector(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(float(value[0]), float(value[1]))

static func _valid_vector(value: Variant, positive: bool = false, nonzero: bool = false) -> bool:
	if not value is Vector2 and not (value is Array and value.size() == 2 and value.all(func(n): return (n is int or n is float) and is_finite(float(n)))): return false
	var point := _vector(value)
	return point.is_finite() and (not positive or (point.x > 0 and point.y > 0)) and (not nonzero or not point.is_zero_approx())

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "errors": [message]}

static func _rng(seed: int, component: String, purpose: String) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = JSON.stringify([VERSION, seed, component, purpose]).sha256_text().substr(0, 15).hex_to_int()
	return result

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> Array:
	var result := items.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary: Variant = result[i]
		result[i] = result[j]
		result[j] = temporary
	return result

static func _forms(flags: Dictionary) -> Array:
	var result: Array = [Vector2.ONE]
	if flags.allow_flip_x: result.append(Vector2(-1, 1))
	if flags.allow_flip_y: result.append(Vector2(1, -1))
	if flags.allow_flip_x and flags.allow_flip_y: result.append(Vector2(-1, -1))
	return result

static func _matrix(angle: float, scale: Vector2, pivot: Vector2, target: Vector2) -> Transform2D:
	var rotation := Transform2D(angle, Vector2.ZERO)
	var linear := rotation * Transform2D(Vector2(scale.x, 0), Vector2(0, scale.y), Vector2.ZERO)
	linear.origin = target - linear.basis_xform(pivot)
	return linear

static func _context_errors(context: Dictionary) -> Array:
	var errors: Array = []
	if context.has("include_footprints") and not context.include_footprints is bool: errors.append("include_footprints must be boolean")
	for key: Variant in context:
		if key not in ["origin_cells", "size_cells", "target_forward", "world_light", "required_connections", "connection_tolerance_cells", "allowed_rotations_deg", "base_path", "include_footprints"]: errors.append("Unknown placement field: " + str(key))
	for key: String in ["origin_cells", "size_cells", "target_forward", "world_light"]:
		if context.has(key) and not _valid_vector(context[key], key == "size_cells", key in ["target_forward", "world_light"]): errors.append("Invalid placement vector: " + key)
	if context.has("base_path") and not context.base_path is String: errors.append("base_path must be a metadata path")
	var tolerance: Variant = context.get("connection_tolerance_cells", 0.01)
	if not (tolerance is int or tolerance is float) or not is_finite(float(tolerance)) or tolerance < 0: errors.append("Invalid connection tolerance")
	var rotations: Variant = context.get("allowed_rotations_deg", [0, 90, 180, 270])
	if not rotations is Array or rotations.is_empty() or not rotations.all(func(n): return (n is int or n is float) and is_finite(float(n))): errors.append("Expected finite allowed_rotations_deg")
	if context.has("required_connections"):
		if not context.required_connections is Array: errors.append("required_connections must be an array")
		else:
			for socket: Variant in context.required_connections:
				if not socket is Dictionary or not _valid_vector(socket.get("offset_cells")) or not _valid_vector(socket.get("outward"), false, true): errors.append("Connection requires offset_cells and nonzero outward vector")
				elif socket.has("id") and not socket.id is String: errors.append("Connection id must be a string")
	return errors

static func _assign_socket(target: int, choices: Array, ownership: Dictionary, seen: Dictionary) -> bool:
	for socket: int in choices[target]:
		if seen.has(socket): continue
		seen[socket] = true
		if not ownership.has(socket) or _assign_socket(int(ownership[socket]), choices, ownership, seen):
			ownership[socket] = target
			return true
	return false

static func _sockets_match(record: Dictionary, transform: Transform2D, context: Dictionary) -> bool:
	if not context.has("required_connections"): return true
	var sockets: Array = record.definition.get("connections", [])
	if sockets.size() != context.required_connections.size(): return false
	var choices: Array = []
	for required: Dictionary in context.required_connections:
		var matches: Array = []
		for i in range(sockets.size()):
			if required.has("id") and required.id != sockets[i].id: continue
			var position := transform.basis_xform(_vector(sockets[i].position) - _vector(record.resolved.origin))
			var direction := transform.basis_xform(_vector(sockets[i].toward) - _vector(sockets[i].position)).normalized()
			if position.distance_to(_vector(required.offset_cells)) <= float(context.get("connection_tolerance_cells", 0.01)) + EPSILON and direction.is_equal_approx(_vector(required.outward).normalized()): matches.append(i)
		if matches.is_empty(): return false
		choices.append(matches)
	var ownership: Dictionary = {}
	for i in range(choices.size()):
		if not _assign_socket(i, choices, ownership, {}): return false
	return true

static func _orientations(record: Dictionary, context: Dictionary, light: Vector2, tie_break: Array) -> Array:
	var candidates: Array = []
	var origin := _vector(context.get("origin_cells", Vector2.ZERO))
	var size := _vector(context.get("size_cells", Vector2.ONE))
	var canvas := _vector(record.canvas_px)
	var forms := _forms(record.resolved.transforms)
	var names := {Vector2.ONE: "no_flip", Vector2(-1, 1): "flip_x", Vector2(1, -1): "flip_y", Vector2(-1, -1): "flip_xy"}
	forms.sort_custom(func(a, b): return tie_break.find(names[a]) < tie_break.find(names[b]))
	for form: Vector2 in forms:
		for degrees: float in context.get("allowed_rotations_deg", [0, 90, 180, 270]):
			var transform := _matrix(deg_to_rad(degrees), size / canvas * form, _vector(record.resolved.origin), origin)
			if context.has("target_forward") and not transform.basis_xform(_vector(record.resolved.forward)).normalized().is_equal_approx(_vector(context.target_forward).normalized()): continue
			if not _sockets_match(record, transform, context): continue
			if candidates.any(func(other): return other.transform.is_equal_approx(transform)): continue
			var score := transform.basis_xform(_vector(record.resolved.lighting)).normalized().dot(light) if record.resolved.has_lighting else 0.0
			candidates.append({"transform": transform, "rotation_deg": degrees, "flip_x": form.x < 0, "flip_y": form.y < 0, "light_score": score})
	return candidates

static func _weighted(records: Array, rng: RandomNumberGenerator) -> Array:
	var scored: Array = []
	for record: Dictionary in records:
		scored.append({"record": record, "score": -log(maxf(rng.randf(), 0.000000001)) / float(record.resolved.variation.weight)})
	scored.sort_custom(func(a, b): return a.score < b.score if a.score != b.score else a.record.path < b.record.path)
	return scored.map(func(item): return item.record)

static func _accepted(anchor: Dictionary, decoration: Dictionary) -> bool:
	if not anchor.has("accepts"): return true
	for tag: String in decoration.definition.get("tags", []):
		if tag in anchor.accepts: return true
	return false

func _decoration(base: Dictionary, base_transform: Transform2D, variant: String, anchor: Dictionary, decoration: Dictionary, settings: Dictionary, seed: int, component: String, light: Vector2, occupied: Dictionary, include_footprints: bool) -> Dictionary:
	var rules := Metadata.rules(base.definition, decoration.definition, anchor, settings)
	if not rules.ok: return {"ok": false, "reason": "invalid_growth_override"}
	if rules.animation.mode == "progressive" and not decoration.reveals.has(variant): return {"ok": false, "reason": "missing_reveal"}
	var purpose: String = "anchor/" + anchor.id + "/" + decoration.path
	var rng := _rng(seed, component, purpose + "/appearance")
	var scale := rng.randf_range(rules.variation.scale[0], rules.variation.scale[1])
	var mode: String = rules.orientation.mode
	var desired := deg_to_rad(float(rules.orientation.angle_deg) + rng.randf_range(-float(rules.orientation.jitter_deg), float(rules.orientation.jitter_deg)))
	if mode in ["relative", "perpendicular"]: desired += _vector(anchor.forward).angle() + (PI / 2 if mode == "perpendicular" else 0.0)
	if mode == "random":
		var limits: Array = rules.orientation.get("range_deg", [0, 360])
		desired = deg_to_rad(rng.randf_range(limits[0], limits[1]))
	var forms := _shuffle(_forms(decoration.resolved.transforms), _rng(seed, component, purpose + "/mirror"))
	var chosen: Dictionary = {}
	var reason := "no_valid_form"
	for form: Vector2 in forms:
		var rotation := desired if mode == "random" else desired - (_vector(decoration.resolved.forward) * form).angle()
		var local := _matrix(rotation, form * scale, _vector(decoration.resolved.origin), _vector(anchor.position))
		if rules.variation.has("growth_scale"):
			var forward := _vector(decoration.resolved.forward)
			var across := Vector2(-forward.y, forward.x)
			var axes := Transform2D(across, forward, Vector2.ZERO)
			var factors := _vector(rules.variation.growth_scale)
			var stretch := axes * Transform2D(Vector2(factors.x, 0), Vector2(0, factors.y), Vector2.ZERO) * axes.affine_inverse()
			local = local * stretch
			local.origin = _vector(anchor.position) - local.basis_xform(_vector(decoration.resolved.origin))
		var needs_raster: bool = include_footprints or rules.constraints.get("inside_canvas", false) or "avoid" in rules.constraints.get("base_overlap_checks", [])
		var footprint := _footprint.raster(decoration.images[variant], local, _vector(decoration.resolved.origin)) if needs_raster else _footprint.summary(decoration.images[variant], local, _vector(decoration.resolved.origin))
		reason = _footprint.rejection(footprint, base.images[variant], Vector2i(_vector(base.canvas_px)), _vector(anchor.position), rules.constraints, occupied)
		if not reason.is_empty(): continue
		var transform := base_transform * local
		var score := transform.basis_xform(_vector(decoration.resolved.lighting)).normalized().dot(light) if decoration.resolved.has_lighting else 0.0
		if not chosen.is_empty() and score <= chosen.light_score + EPSILON: continue
		chosen = {"ok": true, "id": component + "/anchor/" + anchor.id, "anchor_id": anchor.id, "metadata_path": decoration.path, "image_path": decoration.images[variant], "variant": variant, "transform": transform, "local_transform": local, "attachment": decoration.resolved.origin.duplicate(), "flip_x": form.x < 0, "flip_y": form.y < 0, "rotation_deg": rad_to_deg(rotation), "scale": scale, "light_score": score, "growth_at": anchor.growth_at, "rules": rules, "footprint": footprint.cells.keys(), "footprint_computed": needs_raster, "visible_radius_px": footprint.radius}
		if rules.animation.mode == "progressive": chosen.reveal = decoration.reveals[variant].duplicate(true)
		if not decoration.resolved.has_lighting: break
	return chosen if not chosen.is_empty() else {"ok": false, "reason": reason}

func plan(catalog: Dictionary, family_id: String, logical_color: int, component_id: String, seed: int, context: Dictionary = {}) -> Dictionary:
	if not catalog.get("ok", false): return _fail("Expected a successfully loaded sprite catalog")
	if component_id.is_empty(): return _fail("A stable component_id is required")
	var errors := _context_errors(context)
	if not errors.is_empty(): return {"ok": false, "errors": errors}
	if not catalog.families.has(family_id): return _fail("Unknown artwork family: " + family_id)
	var family: Dictionary = catalog.families[family_id]
	if not family.logical_colors.has(str(logical_color)): return _fail("No artwork binding for logical color " + str(logical_color))
	var key := var_to_bytes([VERSION, family, catalog.settings, family_id, logical_color, component_id, seed, context]).hex_encode().sha256_text()
	if _plans.has(key): return _plans[key].duplicate(true)
	var tie_break: Array = catalog.settings.lighting.get("tie_break", ["no_flip", "flip_x", "flip_y", "flip_xy"])
	if tie_break.size() != 4 or not ["no_flip", "flip_x", "flip_y", "flip_xy"].all(func(name): return tie_break.count(name) == 1): return _fail("Unsupported lighting tie_break policy")
	if catalog.settings.lighting.get("selection", "maximize_dot_product") != "maximize_dot_product" or not catalog.settings.lighting.get("connection_alignment_has_priority", true): return _fail("Lighting policy must preserve connections and maximize the marked light direction")
	var variant: String = family.logical_colors[str(logical_color)].image_variant
	var light := _vector(context.get("world_light", catalog.settings.lighting.world_direction)).normalized()
	var viable: Array = []
	var bases: Array = family.bases.duplicate()
	bases.sort_custom(func(a, b): return a.path < b.path)
	for record: Dictionary in bases:
		if context.has("base_path") and context.base_path != record.path: continue
		var options := _orientations(record, context, light, tie_break)
		if options.is_empty(): continue
		var best: Dictionary = options[0]
		# Forms are ordered identity/X/Y/XY and turns use the host's order:
		# keep the first candidate on a lighting tie.
		for option: Dictionary in options:
			if option.light_score > best.light_score + EPSILON: best = option
		viable.append({"record": record, "orientation": best})
	if viable.is_empty(): return _fail("No base orientation satisfies the required forward/connections")
	var selection: Dictionary = viable[_rng(seed, component_id, "base").randi_range(0, viable.size() - 1)]
	var base: Dictionary = selection.record
	var placement: Dictionary = selection.orientation.duplicate(true)
	placement.merge({"metadata_path": base.path, "image_path": base.images[variant], "variant": variant, "canvas_px": base.canvas_px.duplicate(), "origin": base.resolved.origin.duplicate(), "id": component_id + "/base"})
	var count: Array = base.resolved.spawn.count
	var target := _rng(seed, component_id, "count").randi_range(int(count[0]), int(count[1]))
	var anchors: Array = base.anchors.duplicate()
	anchors.sort_custom(func(a, b): return a.id < b.id)
	anchors = _shuffle(anchors, _rng(seed, component_id, "anchors"))
	var catalog_decorations: Array = family.decorations.duplicate()
	catalog_decorations.sort_custom(func(a, b): return a.path < b.path)
	# Any protected decoration requires footprints for all participants, even
	# if an earlier participant permits overlap. Omission is presentation-only.
	var include_footprints: bool = context.get("include_footprints", true) or base.resolved.constraints.get("avoid_deco_overlap", false)
	for record: Dictionary in catalog_decorations:
		include_footprints = include_footprints or record.resolved.constraints.get("avoid_deco_overlap", false)
	for anchor: Dictionary in anchors:
		include_footprints = include_footprints or anchor.get("constraints", {}).get("avoid_deco_overlap", false)
	var decorations: Array = []
	var occupied: Dictionary = {}
	var positions: Array[Vector2] = []
	var rejections: Dictionary = {}
	var quotas: Dictionary = base.resolved.spawn.get("group_counts", {}).duplicate()
	for group: String in base.resolved.spawn.get("group_count_ranges", {}):
		var limits: Array = base.resolved.spawn.group_count_ranges[group]
		quotas[group] = _rng(seed, component_id, "group/" + group).randi_range(int(limits[0]), int(limits[1]))
	var reserved := 0
	for amount: Variant in quotas.values(): reserved += int(amount)
	target = maxi(target, reserved)
	if not base.resolved.spawn.get("group_count_ranges", {}).is_empty() and anchors.all(func(a): return quotas.has(a.get("group", ""))): target = reserved
	var requests: Array = []
	var group_names: Array = quotas.keys()
	group_names.sort()
	for group: String in group_names:
		requests.append({"group": group, "count": int(quotas[group]), "anchors": anchors.filter(func(anchor): return anchor.get("group", "") == group)})
	requests.append({"group": null, "count": target, "anchors": anchors.filter(func(anchor): return not quotas.has(anchor.get("group", "")))})
	var group_counts: Dictionary = {}
	for request: Dictionary in requests:
		var placed := 0
		for anchor: Dictionary in request.anchors:
			if decorations.size() >= target or placed >= request.count: break
			var position := _vector(anchor.position)
			if positions.any(func(previous): return position.distance_to(previous) < float(base.resolved.spawn.minimum_spacing_px) - EPSILON):
				rejections.spacing = int(rejections.get("spacing", 0)) + 1
				continue
			var compatible := catalog_decorations.filter(func(record): return _accepted(anchor, record))
			if compatible.is_empty(): rejections.incompatible_tags = int(rejections.get("incompatible_tags", 0)) + 1
			for record: Dictionary in _weighted(compatible, _rng(seed, component_id, "anchor/" + anchor.id + "/catalog")):
				var candidate := _decoration(base, placement.transform, variant, anchor, record, catalog.settings, seed, component_id, light, occupied, include_footprints)
				if not candidate.ok:
					rejections[candidate.reason] = int(rejections.get(candidate.reason, 0)) + 1
					continue
				decorations.append(candidate)
				placed += 1
				if anchor.has("group"): candidate.anchor_group = anchor.group
				positions.append(position)
				for cell: Vector2i in candidate.footprint: occupied[cell] = occupied.get(cell, false) or candidate.rules.constraints.avoid_deco_overlap
				break
		if request.group != null: group_counts[request.group] = placed
	decorations.sort_custom(func(a, b): return a.growth_at < b.growth_at if a.growth_at != b.growth_at else a.anchor_id < b.anchor_id)
	var choices: Array = [base.path, placement.rotation_deg, placement.flip_x, placement.flip_y]
	for item: Dictionary in decorations: choices.append([item.anchor_id, item.metadata_path, item.flip_x, item.flip_y, item.rotation_deg, item.scale])
	var warnings: Array = []
	if decorations.size() < target: warnings.append("Placed %d/%d decorations; constraints were retained" % [decorations.size(), target])
	for group: String in group_names:
		if group_counts[group] < int(quotas[group]): warnings.append("Group %s placed %d/%d decorations; constraints were retained" % [group, group_counts[group], int(quotas[group])])
	var result := {"ok": true, "errors": [], "warnings": warnings, "component_id": component_id, "seed": seed, "planner_version": VERSION, "base": placement, "decorations": decorations, "target_count": target, "rejections": rejections, "fingerprint": var_to_bytes(choices).hex_encode().sha256_text()}
	if not quotas.is_empty(): result.group_counts = group_counts
	if _plans.size() >= MAX_PLANS: _plans.erase(_plans.keys()[0])
	_plans[key] = result.duplicate(true)
	return result
