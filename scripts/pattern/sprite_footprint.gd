class_name PatternSpriteFootprint
extends RefCounted

const Metadata = preload("res://scripts/pattern/sprite_metadata.gd")
const EPSILON := 0.00001
const MAX_FOOTPRINTS := 128
var _pixels: Dictionary = {}
var _bounds: Dictionary = {}
var _footprints: Dictionary = {}
var _radii: Dictionary = {}

func clear() -> void:
	_pixels.clear()
	_bounds.clear()
	_footprints.clear()
	_radii.clear()

func cache_sizes() -> Dictionary:
	return {"images": _pixels.size(), "footprints": _footprints.size()}

func _source(path: String) -> Dictionary:
	if not _pixels.has(path):
		var loaded := Metadata.occupancy(path)
		if not loaded.ok: return loaded
		var pixels: Array[Vector2i] = []
		var low: Vector2i = loaded.mask.get_size()
		var high := Vector2i.ZERO
		for y in range(loaded.mask.get_size().y):
			for x in range(loaded.mask.get_size().x):
				if loaded.mask.get_bit(x, y):
					var point := Vector2i(x, y)
					pixels.append(point)
					low = low.min(point)
					high = high.max(point + Vector2i.ONE)
		_pixels[path] = pixels
		_bounds[path] = Rect2i(low, high - low)
	return {"ok": true, "pixels": _pixels[path], "bounds": _bounds[path]}

func summary(path: String, transform: Transform2D, attachment: Vector2) -> Dictionary:
	# A uniform rotation/reflection preserves radius. Reuse the source radius
	# when no rule (and no caller) needs the actual occupied-cell raster.
	if not transform.is_finite(): return {"ok": false, "reason": "invalid_transform"}
	if not is_equal_approx(transform.x.length(), transform.y.length()) or not is_zero_approx(transform.x.dot(transform.y)): return raster(path, transform, attachment)
	var source := _source(path)
	if not source.ok: return source
	var region := transform * Rect2(Vector2(source.bounds.position) - Vector2.ONE * 0.5, Vector2(source.bounds.size))
	if (ceilf(region.size.x) + 1) * (ceilf(region.size.y) + 1) > 1048576: return {"ok": false, "reason": "footprint_budget"}
	var key := var_to_bytes([path, attachment]).hex_encode()
	if not _radii.has(key):
		var squared := 0.0
		for pixel: Vector2i in source.pixels:
			# The farthest corner of each source pixel square is opposite the
			# attachment on both axes; no four-corner loop is necessary.
			var delta := (Vector2(pixel) - attachment).abs() + Vector2.ONE * 0.5
			squared = maxf(squared, delta.length_squared())
		if _radii.size() >= MAX_FOOTPRINTS: _radii.erase(_radii.keys()[0])
		_radii[key] = sqrt(squared)
	return {"ok": true, "cells": {}, "radius": _radii[key] * transform.x.length()}

func raster(path: String, transform: Transform2D, attachment: Vector2) -> Dictionary:
	var key := var_to_bytes([path, transform, attachment]).hex_encode()
	if _footprints.has(key): return _footprints[key]
	var source := _source(path)
	if not source.ok: return source
	if not transform.is_finite(): return {"ok": false, "reason": "invalid_transform"}
	var region := transform * Rect2(Vector2(source.bounds.position) - Vector2.ONE * 0.5, Vector2(source.bounds.size))
	if (ceilf(region.size.x) + 1) * (ceilf(region.size.y) + 1) > 1048576: return {"ok": false, "reason": "footprint_budget"}
	var cells: Dictionary = {}
	var radius := 0.0
	var half_x := (absf(transform.x.x) + absf(transform.y.x)) * 0.5
	var half_y := (absf(transform.x.y) + absf(transform.y.y)) * 0.5
	var anchor := transform * attachment
	for pixel: Vector2i in source.pixels:
		var center := transform * Vector2(pixel)
		# Cover each transformed occupied pixel conservatively, rather than
		# rotating only its center or including the texture's transparent pad.
		for y in range(floori(center.y - half_y + 0.5 + EPSILON), ceili(center.y + half_y + 0.5 - EPSILON)):
			for x in range(floori(center.x - half_x + 0.5 + EPSILON), ceili(center.x + half_x + 0.5 - EPSILON)):
				cells[Vector2i(x, y)] = true
		for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			radius = maxf(radius, (transform * (Vector2(pixel) + corner)).distance_to(anchor))
	var result := {"ok": true, "cells": cells, "radius": radius}
	if _footprints.size() >= MAX_FOOTPRINTS: _footprints.erase(_footprints.keys()[0])
	_footprints[key] = result
	return result

func _near_base(cell: Vector2i, mask: BitMap, bounds: Rect2i, gap: float) -> bool:
	if not Rect2(bounds).grow(gap + 1).has_point(Vector2(cell)): return false
	if gap <= EPSILON: return Rect2i(Vector2i.ZERO, mask.get_size()).has_point(cell) and mask.get_bitv(cell)
	var reach := ceili(minf(gap, float(maxi(mask.get_size().x, mask.get_size().y)))) + 1
	for y in range(maxi(0, cell.y - reach), mini(mask.get_size().y, cell.y + reach + 1)):
		for x in range(maxi(0, cell.x - reach), mini(mask.get_size().x, cell.x + reach + 1)):
			if not mask.get_bit(x, y): continue
			var delta := (cell - Vector2i(x, y)).abs()
			if delta == Vector2i.ZERO: return true
			# Euclidean separation between the occupied source pixel squares.
			var distance := Vector2(maxi(0, delta.x - 1), maxi(0, delta.y - 1)).length()
			if distance < gap - EPSILON: return true
	return false

func rejection(footprint: Dictionary, base_path: String, canvas: Vector2i, anchor: Vector2, constraints: Dictionary, occupied: Dictionary) -> String:
	if not footprint.get("ok", false): return footprint.get("reason", "unreadable_texture")
	if footprint.radius > float(constraints.get("max_radius_px", INF)) + EPSILON: return "radius"
	var base := Metadata.occupancy(base_path)
	if not base.ok: return "unreadable_base"
	var overlap: Array = constraints.get("base_overlap_checks", [])
	if "require_attachment" in overlap:
		var point := Vector2i(floori(anchor.x + 0.5), floori(anchor.y + 0.5))
		if not Rect2i(Vector2i.ZERO, base.mask.get_size()).has_point(point) or not base.mask.get_bitv(point): return "attachment_off_base"
	var bounds := Rect2i()
	if "avoid" in overlap:
		var source := _source(base_path)
		if not source.ok: return "unreadable_base"
		bounds = source.bounds
	for cell: Vector2i in footprint.cells:
		if constraints.get("inside_canvas", false):
			var margin: float = constraints.get("edge_margin_px", 0.0)
			if cell.x < margin or cell.y < margin or cell.x > canvas.x - 1 - margin or cell.y > canvas.y - 1 - margin: return "canvas_boundary"
		if occupied.has(cell) and (constraints.get("avoid_deco_overlap", false) or occupied[cell]): return "decoration_overlap"
		if "avoid" in overlap and _near_base(cell, base.mask, bounds, float(constraints.get("base_gap_px", 0.0))): return "base_overlap"
	return ""
