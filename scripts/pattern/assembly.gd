class_name PatternAssembly
extends RefCounted
# Canonical artwork and its masks rotate together in local sprite coordinates.
# Shared-edge placement rotates around the cell center before applying the cell.
const Topology = preload("res://scripts/pattern/topology.gd")
const NAMES := ["N", "E", "S", "W"]

static func vector(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(float(value[0]), float(value[1]))

static func rotation(spec: Dictionary) -> float:
	return float(spec.quarter_turns) * PI / 2 if spec.has("quarter_turns") else float(spec.get("rotation_radians", 0))

static func point(value: Vector2, turns: int) -> Vector2:
	match posmod(turns, 4):
		1: return Vector2(-value.y, value.x)
		2: return -value
		3: return Vector2(value.y, -value.x)
	return value

static func port_turns(direction: int, canonical_port: int = 0) -> int:
	return direction - canonical_port

static func rotated(part: Dictionary, turns: int, pivot_cells: Vector2 = Vector2.ONE * 0.5) -> Dictionary:
	var spec := part.duplicate(true)
	spec.rotation_radians = rotation(part) + turns * PI / 2
	spec.erase("quarter_turns")
	if part.has("position_cells"):
		spec.position_cells = pivot_cells + point(vector(part.position_cells) - pivot_cells, turns)
	if part.has("position_px"):
		var pivot := pivot_cells * float(part.get("pixels_per_cell", 256))
		spec.position_px = pivot + point(vector(part.position_px) - pivot, turns)
	if part.has("requires_mask"): spec.requires_mask = Topology.rotate_mask(int(part.requires_mask), turns)
	# Pivots and offsets remain in source-image coordinates. Sprite2D rotates
	# them, the artwork and shader UVs together; rotating offsets twice breaks joins.
	return spec

static func on_port(part: Dictionary, cell: Vector2i, direction: int) -> Dictionary:
	var canonical: int = int(part.get("canonical_port", 0))
	var local := part.duplicate(true)
	var offset := Vector2(Topology.DIRECTIONS[canonical]) * 0.5 if part.get("anchor", "cell_center") == "shared_edge_midpoint" else Vector2.ZERO
	local.position_cells = Vector2.ONE * 0.5 + offset
	if not local.has("offset_px"): local.offset_px = -offset * float(part.get("pixels_per_cell", 256))
	var spec := rotated(local, port_turns(direction, canonical))
	spec.position_cells += Vector2(cell)
	if part.has("flip_h_ports"): spec.flip_h = NAMES[direction] in part.flip_h_ports
	if part.has("flip_v_ports"): spec.flip_v = NAMES[direction] in part.flip_v_ports
	return spec
