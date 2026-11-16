class_name PatternCellSets
extends RefCounted
const Topology = preload("res://scripts/pattern/topology.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")

static func parts_for_role(loaded: Dictionary, role: String) -> Dictionary:
	if not loaded.get("ok", false): return {}
	var composition: Variant = loaded.definition.get("roles", {}).get(role, role)
	if composition == null or not loaded.definition.compositions.has(composition): return {}
	return loaded.definition.compositions[composition].parts

static func center_parts(mask: int, tier0: Dictionary, tier1: Dictionary) -> Dictionary:
	var shape := Topology.shape(mask)
	return parts_for_role(tier0 if shape == "isolated" else tier1, shape)

static func anchor(cell: Vector2i, role: String = "cell_center", direction: int = 1) -> Vector2:
	var position := Vector2(cell) + Vector2.ONE * 0.5
	if role == "shared_edge_midpoint": position += Vector2(Topology.DIRECTIONS[direction]) * 0.5
	return position

static func forward_port(direction: int) -> bool:
	return direction in [1, 2]
