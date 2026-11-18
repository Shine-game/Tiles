extends RefCounted
# Adapters from the existing structural models to a common placement/source list.
# Decoration selection, transforms and reveals stay in the universal pipeline.
const Topology = preload("res://scripts/pattern/topology.gd")
const CellVariation = preload("res://scripts/pattern/cell_variation.gd")
const Growth = preload("res://scripts/growth.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")

static func descriptors(model, theme: String, before: Array) -> Array:
	var result: Array = []
	var config: Dictionary = Themes.profile(theme).get("tier1_artwork", {})
	var layout: String = config.get("source_layout", "")
	if layout == "components":
		for key: String in model.components:
			var event: Dictionary = model.components[key]
			var mapping: Variant = config.get("component_ports", {}).get(event.id)
			if mapping == null: continue
			var direction := int(event.get(mapping, -1)) if mapping is String else int(mapping)
			if direction < 0 or direction > 3: continue
			result.append({"id": theme + "/" + key, "family": config.get("family", "default"), "color": event.color, "context": {"origin_cells": event.center, "size_cells": _size(config), "target_forward": Vector2(Topology.DIRECTIONS[direction])}, "binding": {"event": event}})
		if config.has("center_join_masks"):
			# A cell-center overlay is shared by its half-arms. Assign one
			# deterministic owner; every other arm remains bare.
			for item: Dictionary in result:
				if config.has("fixed_decoration_path"): item.context.decoration_path = config.fixed_decoration_path
				var event: Dictionary = item.binding.event
				var mask := Topology.neighbor_mask(model.board, event.cell)
				var owner := -1
				for port in range(4):
					if mask & (1 << port):
						owner = port
						break
				item.context.suppress_decorations = not config.center_join_masks.any(func(value): return int(value) == mask) or item.context.target_forward != Vector2(Topology.DIRECTIONS[owner])
	elif layout == "edge_halves":
		for edge: Dictionary in model.edges:
			# Two native half-arms meet at one edge midpoint. Both bind to the
			# same full-edge field; forward alignment cannot be sacrificed to light.
			for side in range(2):
				var cell: Vector2i = edge.a if side == 0 else edge.b
				var other: Vector2i = edge.b if side == 0 else edge.a
				var id := theme + "/%d/%d/%d/%d/%d" % [edge.color, cell.y, cell.x, other.y, other.x]
				result.append({"id": id, "family": config.get("family", "default"), "color": edge.color, "context": {"origin_cells": Vector2(cell) + Vector2.ONE * 0.5, "size_cells": _size(config), "target_forward": Vector2(other - cell), "growth_forward": Vector2(edge.b - edge.a) * (-1.0 if int(edge.flow) < 0 else 1.0)}, "binding": {"event": edge, "stroke_seconds": config.get("stroke_seconds", Growth.STEP), "u_range": [0.0, 0.5] if side == 0 else [1.0, 0.5]}})
	elif layout == "cell_centers":
		var color := int(config.get("logical_color", 2))
		var seconds := float(config.get("duration_sec", 0.24))
		for cell: Vector2i in model.arrivals:
			if Topology.value(model.board, cell) != color: continue
			var old := Topology.value(before, cell) == color
			var start := maxf(0.0, model.arrivals[cell])
			result.append({"id": theme + "/stone/%d/%d" % [cell.y, cell.x], "family": config.get("family", "default"), "color": color, "context": {"origin_cells": Vector2(cell) + Vector2.ONE * 0.5, "size_cells": _size(config)}, "binding": {"event": {"old": old, "start": start, "end": start + seconds}}})
	elif layout == "shared_edges":
		var color := int(config.get("logical_color", 2))
		var seconds := float(config.get("duration_sec", 0.24))
		for cell: Vector2i in model.arrivals:
			if Topology.value(model.board, cell) != color: continue
			for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other := cell + offset
				if Topology.value(model.board, other) != color: continue
				var old := Topology.value(before, cell) == color and Topology.value(before, other) == color
				var start := maxf(0.0, maxf(model.arrivals[cell], model.arrivals[other]))
				result.append({"id": theme + "/stone/%d/%d/%d/%d" % [cell.y, cell.x, other.y, other.x], "family": config.get("family", "default"), "color": color, "context": {"origin_cells": (Vector2(cell + other) + Vector2.ONE) * 0.5, "size_cells": _size(config)}, "binding": {"event": {"old": old, "start": start, "end": start + seconds}}})
	if layout == "cell_centers":
		for item: Dictionary in result:
			var cell := Vector2i(item.context.origin_cells)
			var variation := CellVariation.choice(theme, cell, item.color)
			if not variation.is_empty():
				item.context.base_path = variation.base_path
				item.context.allowed_rotations_deg = [variation.rotation_deg]
				item.context.base_flip_x = variation.flip_x
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

static func _size(config: Dictionary) -> Vector2:
	var size: Array = config.get("size_cells", [1.0, 1.0])
	return Vector2(size[0], size[1])

static func active(theme: String) -> bool:
	return Themes.profile(theme).get("tier1_artwork", {}).get("status") == "active"
