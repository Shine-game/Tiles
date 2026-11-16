class_name PatternTopology
extends RefCounted

# Pure geometry: no artwork, animation clocks, palettes, or theme dependencies.
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SUPPORT_OFFSETS := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]
const CANONICAL_MASKS := [0, 1, 5, 3, 11, 15]

static func value(grid: Array, cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].size(): return 0
	return int(grid[cell.y][cell.x])

static func neighbor_mask(grid: Array, cell: Vector2i) -> int:
	var color := value(grid, cell)
	if color == 0: return 0
	var mask := 0
	for direction in range(4):
		if value(grid, cell + DIRECTIONS[direction]) == color: mask |= 1 << direction
	return mask

static func rotate_mask(mask: int, turns: int) -> int:
	var turn := posmod(turns, 4)
	return ((mask << turn) | (mask >> (4 - turn))) & 15

static func canonical(mask: int) -> Dictionary:
	for source: int in CANONICAL_MASKS:
		for turns in range(4):
			if rotate_mask(source, turns) == mask: return {"mask": source, "turns": turns}
	return {}

static func shape(mask: int) -> String:
	var spec := canonical(mask)
	if spec.is_empty(): return "invalid"
	return {0: "isolated", 1: "endpoint", 5: "straight", 3: "bend", 11: "t", 15: "cross"}[spec.mask]

static func is_straight(mask: int) -> bool:
	return mask in [5, 10]

static func sorted_cells(cells: Array) -> Array:
	var result: Array = cells.duplicate()
	result.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result

static func edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.y > b.y or (a.y == b.y and a.x > b.x): return Vector4i(b.x, b.y, a.x, a.y)
	return Vector4i(a.x, a.y, b.x, b.y)

static func is_cardinal_offset(delta: Vector2i) -> bool:
	return absi(delta.x) + absi(delta.y) == 1

static func is_formation(grid: Array, origin: Vector2i, color: int) -> bool:
	if color == 0: return false
	for offset: Vector2i in SUPPORT_OFFSETS:
		if value(grid, origin + offset) != color: return false
	return true

static func support_cells(origin: Vector2i) -> Array:
	var cells: Array = []
	for offset: Vector2i in SUPPORT_OFFSETS: cells.append(origin + offset)
	return cells

static func formations(grid: Array) -> Dictionary:
	var result: Dictionary = {}
	for y in range(grid.size() - 1):
		for x in range(mini(grid[y].size(), grid[y + 1].size()) - 1):
			var origin := Vector2i(x, y)
			var color := value(grid, origin)
			if is_formation(grid, origin, color):
				result[origin] = {"origin": origin, "color": color, "cells": support_cells(origin), "center": Vector2(origin) + Vector2.ONE}
	return result

static func formation_neighbors(features: Dictionary, origin: Vector2i) -> Array:
	var result: Array = []
	if not features.has(origin): return result
	var color: int = features[origin].color
	if color == 0: return result
	for direction in range(4):
		var other: Vector2i = origin + DIRECTIONS[direction]
		if features.has(other) and features[other].color == color:
			result.append({"origin": other, "direction": direction})
	return result

static func adjacent_pairs(features: Dictionary) -> Array:
	# Legacy flower keys are centers/corners; newer keys are top-left origins.
	# Adjacency is invariant under that translation. Never reinterpret the keys.
	var result: Array = []
	for origin: Vector2i in sorted_cells(features.keys()):
		for direction in [1, 2]:
			var other: Vector2i = origin + DIRECTIONS[direction]
			if features[origin].color != 0 and features.has(other) and features[origin].color == features[other].color:
				result.append({"a": origin, "b": other, "direction": direction})
	return result

static func centroid(cells: Array, units_per_cell: float = 1.0) -> Vector2:
	var center := Vector2.ZERO
	if cells.is_empty(): return center
	for cell: Vector2i in cells: center += Vector2(cell) + Vector2.ONE * 0.5
	return center * (units_per_cell / cells.size())

static func connected_formations(features: Dictionary, color: int = 0, minimum_count: int = 1) -> Array:
	var remaining: Dictionary = {}
	for origin: Vector2i in sorted_cells(features.keys()):
		if features[origin].color != 0 and (color == 0 or features[origin].color == color): remaining[origin] = true
	var result: Array = []
	while not remaining.is_empty():
		var queue: Array = [remaining.keys()[0]]
		remaining.erase(queue[0])
		var origins: Array = []
		var occupied: Dictionary = {}
		var cursor := 0
		while cursor < queue.size():
			var origin: Vector2i = queue[cursor]
			cursor += 1
			origins.append(origin)
			for cell: Vector2i in support_cells(origin): occupied[cell] = true
			for neighbor: Dictionary in formation_neighbors(features, origin):
				if remaining.has(neighbor.origin):
					remaining.erase(neighbor.origin)
					queue.append(neighbor.origin)
		if origins.size() < minimum_count: continue
		var cells := sorted_cells(occupied.keys())
		result.append({"origins": origins, "color": features[origins[0]].color, "cells": cells, "center": centroid(cells)})
	return result
