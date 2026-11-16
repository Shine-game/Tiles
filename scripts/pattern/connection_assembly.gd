class_name PatternConnectionAssembly
extends RefCounted

# Shared Tier 3 geometry and prerequisites. Theme models own the resulting
# artwork, animation clocks and historical growth; these records are disposable.
const Topology = preload("res://scripts/pattern/topology.gd")

static func _record(features: Dictionary, members: Array, key_offset: Vector2i) -> Dictionary:
	var occupied: Dictionary = {}
	var origins: Array = []
	var old := true
	for member: Vector2i in members:
		var origin := member - key_offset
		origins.append(origin)
		for cell: Vector2i in Topology.support_cells(origin): occupied[cell] = true
		old = old and bool(features[member].old)
	var cells := Topology.sorted_cells(occupied.keys())
	return {"members": members, "origins": origins, "cells": cells,
		"color": features[members[0]].color, "old": old, "center": Topology.centroid(cells)}

static func pair_identity(color: int, a: Vector2i, b: Vector2i) -> String:
	var edge := Topology.edge_key(a, b)
	return "tier3/pair/%d/%d/%d/%d/%d" % [color, edge.y, edge.x, edge.w, edge.z]

static func pairs(features: Dictionary, key_offset: Vector2i = Vector2i.ZERO) -> Array:
	var result: Array = []
	for pair: Dictionary in Topology.adjacent_pairs(features):
		var record := _record(features, [pair.a, pair.b], key_offset)
		record.merge(pair)
		record.id = pair_identity(record.color, record.origins[0], record.origins[1])
		result.append(record)
	return result

static func directed_sides(features: Dictionary, color: int = 0) -> Array:
	# Preserve feature insertion order and N/E/S/W side order. This also preserves
	# random-once vegetation selection in consumers, unlike expanding pair order.
	var result: Array = []
	for origin: Vector2i in features:
		if color != 0 and features[origin].color != color: continue
		for neighbor: Dictionary in Topology.formation_neighbors(features, origin):
			var record := _record(features, [origin, neighbor.origin], Vector2i.ZERO)
			record.origin = origin
			record.direction = neighbor.direction
			record.id = pair_identity(record.color, origin, neighbor.origin)
			record.side_id = "%s/side/%d/%d/%d" % [record.id, origin.y, origin.x, neighbor.direction]
			result.append(record)
	return result

static func territories(features: Dictionary, color: int = 0, minimum_count: int = 2) -> Array:
	var result: Array = []
	for cluster: Dictionary in Topology.connected_formations(features, color, minimum_count):
		var record := _record(features, cluster.origins, Vector2i.ZERO)
		# Structural membership is not a tree's persistent lineage/trunk identity.
		var signature: Array = []
		for origin: Vector2i in Topology.sorted_cells(record.origins): signature.append("%d/%d" % [origin.y, origin.x])
		record.id = "tier3/territory/%d/%s" % [record.color, ";".join(signature)]
		result.append(record)
	return result

static func ready(record: Dictionary, features: Dictionary, field: String = "ready", floor_time: float = -100.0) -> float:
	var latest := floor_time
	for member: Vector2i in record.members: latest = maxf(latest, float(features[member][field]))
	return latest

static func start(record: Dictionary, features: Dictionary, field: String = "ready", delay: float = 0.0, floor_time: float = -100.0) -> float:
	return -100.0 if record.old else ready(record, features, field, floor_time) + delay
