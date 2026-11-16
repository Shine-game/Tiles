class_name ZenTrees
extends Node2D
const Components = preload("res://scripts/pattern/component_renderer.gd")
const Timing = preload("res://scripts/pattern/growth_schedule.gd")
const Connections = preload("res://scripts/pattern/connection_assembly.gd")
const Topology = preload("res://scripts/pattern/topology.gd")
const Art = preload("res://scripts/zen_tree_art.gd")
const Trunk = preload("res://scripts/zen_tree_trunk.gd")
const BRANCH_SHADER = preload("res://shaders/zen_tree_branch.gdshader")
const TRUNK_SHADER = preload("res://shaders/zen_tree_trunk.gdshader")
const GROW_SECONDS := 1.80
const TRUNK_SECONDS := 0.40
const BRANCH_SECONDS := 1.0
var season := "winter"
var groups: Array = []
var snapshots: Dictionary = {}
var signature := ""
var next_id := 0
var branches: Dictionary = {}
var trunks: Dictionary = {}
var trunk_layer := Node2D.new()
var branch_layer := Node2D.new()
var rake_mask: ImageTexture
var grid_size := 9
var screen_pixel := 1.0

static func season_for_month(month: int) -> String:
	if month in [3, 4, 5]: return "spring"
	if month in [6, 7, 8]: return "summer"
	if month in [9, 10, 11]: return "autumn"
	return "winter"

static func clusters(formations: Dictionary) -> Array:
	var result: Array = []
	for cluster: Dictionary in Connections.territories(formations, 1):
		# Preserve the legacy arithmetic in source-pixel coordinates exactly.
		result.append({"cells": cluster.cells, "center": Topology.centroid(cluster.cells, 256.0), "start": Connections.ready(cluster, formations), "old": cluster.old})
	return result

func _init() -> void:
	z_index = 5
	add_child(trunk_layer)
	add_child(branch_layer)
	reset()

func reset(month: int = 0) -> void:
	season = season_for_month(int(Time.get_datetime_dict_from_system().month) if month == 0 else month)
	groups.clear()
	snapshots.clear()
	signature = ""
	next_id = 0
	for layer: Node2D in [trunk_layer, branch_layer]:
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	branches.clear()
	trunks.clear()

func snapshot() -> Dictionary:
	return {"season": season, "groups": groups.duplicate(true), "next_id": next_id, "signature": signature}

func appearance_signature() -> String:
	return var_to_bytes([season, groups]).hex_encode().sha256_text()

func copy_from(other: ZenTrees) -> void:
	var state := other.snapshot()
	reset()
	season = state.season
	groups = state.groups
	next_id = state.next_id
	signature = state.signature
	_install(true, {})

func _new_branch(root: Vector2, toward: Vector2, big: bool, support: Vector2i, spread: float = 0.0) -> Dictionary:
	var id := next_id
	next_id += 1
	var vector := toward - root
	var length := clampf(vector.length(), 307.2 if big else 89.6, 384.0 if big else 294.4)
	var angle := vector.angle() + spread
	return {"id": id, "root": root, "angle": angle, "length": length, "choice": Art.BRANCHES[season].size() - 1 if big else id % Art.BRANCHES[season].size(), "support": support, "bridge": big}

func reconcile(model, settled: bool) -> void:
	grid_size = model.board.size()
	var image := Image.create(grid_size, grid_size, false, Image.FORMAT_L8)
	for y in range(grid_size):
		for x in range(grid_size): image.set_pixel(x, y, Color.WHITE if model.board[y][x] == 1 else Color.BLACK)
	rake_mask = ImageTexture.create_from_image(image)
	var cells_key: Array = []
	for cluster: Dictionary in model.groves: cells_key.append(cluster.cells)
	var key := var_to_bytes(cells_key).hex_encode()
	if key == signature:
		if settled: advance(100.0)
		configure_surface(null)
		return
	var starts: Dictionary = {}
	if snapshots.has(key):
		var restored: Dictionary = snapshots[key]
		groups = restored.groups.duplicate(true)
		next_id = maxi(next_id, restored.next_id)
	else:
		var previous: Array = groups
		groups = []
		for cluster: Dictionary in model.groves:
			var contributors: Array = []
			var retained: Array = []
			var prior_cells: Dictionary = {}
			var generation := 0
			var largest := 0.0
			for group: Dictionary in previous:
				if not group.cells.any(func(cell): return cluster.cells.has(cell)): continue
				contributors.append(group)
				generation = maxi(generation, group.generation + 1)
				largest = maxf(largest, group.thickness)
				for cell: Vector2i in group.cells: prior_cells[cell] = true
				for spec: Dictionary in group.branches:
					if cluster.cells.has(spec.support): retained.append(spec.duplicate(true))
			var added: Array = cluster.cells.filter(func(cell): return not prior_cells.has(cell))
			var specs: Array = retained
			var expanding := not added.is_empty()
			if expanding and not contributors.is_empty():
				for group: Dictionary in contributors:
					var direction: Vector2 = group.center - cluster.center
					if direction.length() < 1.0: direction = Vector2.RIGHT.rotated(float(generation) * 2.4) * 180.0
					var count := 2 + generation % 2
					for i in range(count):
						var spread := (float(i) - float(count - 1) * 0.5) * 0.28
						specs.append(_new_branch(cluster.center, cluster.center + direction.normalized() * maxf(220.0, direction.length() * 1.6), true, added[0], spread))
			if contributors.is_empty() or expanding:
				var targets: Array = cluster.cells if contributors.is_empty() else added
				var amount := mini(3 if contributors.is_empty() else 2, targets.size())
				for i in range(amount):
					var target: Vector2i = targets[int(float(i) * targets.size() / amount)]
					if contributors.is_empty():
						var aim := Vector2.RIGHT.rotated(float(i) * TAU / amount + 0.3)
						for candidate: Vector2i in targets:
							if (Vector2(candidate - target)).dot(aim) > 0: target = candidate
					specs.append(_new_branch(cluster.center, (Vector2(target) + Vector2.ONE * 0.5) * 256.0, false, target, (i - 1) * 0.11))
			var thickness := maxf(largest + (3.5 if expanding else 0.0), 17.0 + sqrt(float(cluster.cells.size())) * 2.0)
			var trunk_id := "%s/%d" % [str(cluster.center), next_id]
			# An unchanged independent grove retains its trunk as well as branches.
			if contributors.size() == 1 and not expanding and contributors[0].cells == cluster.cells:
				trunk_id = contributors[0].trunk_id
				generation = contributors[0].generation
				thickness = contributors[0].thickness
			groups.append({"cells": cluster.cells.duplicate(), "center": cluster.center, "generation": generation, "thickness": thickness, "trunk_id": trunk_id, "branches": specs})
			starts[trunk_id] = -100.0 if settled or cluster.old else cluster.start
		groups = groups.duplicate(true)
		if not groups.is_empty(): snapshots[key] = {"groups": groups.duplicate(true), "next_id": next_id}
	# Restoring cached geometry still animates newly re-created branches when
	# the player places the formation again after Undo.
	for group: Dictionary in groups:
		if starts.has(group.trunk_id): continue
		for cluster: Dictionary in model.groves:
			if group.cells == cluster.cells:
				starts[group.trunk_id] = -100.0 if settled or cluster.old else cluster.start
	signature = key
	_install(settled, starts)

func _ink(shader: Shader) -> ShaderMaterial:
	var ink := Components.material(shader)
	ink.set_shader_parameter("occupancy_mask", rake_mask)
	ink.set_shader_parameter("grid_size", grid_size)
	ink.set_shader_parameter("cell_pixels", 256.0)
	ink.set_shader_parameter("screen_pixel", screen_pixel)
	return ink

func _install(settled: bool, starts: Dictionary) -> void:
	var keep_branches: Dictionary = {}
	var keep_trunks: Dictionary = {}
	for group: Dictionary in groups:
		var start: float = starts.get(group.trunk_id, -100.0)
		keep_trunks[group.trunk_id] = true
		if not trunks.has(group.trunk_id):
			var node := Trunk.new()
			node.position = group.center
			node.thickness = group.thickness
			node.material = _ink(TRUNK_SHADER)
			node.material.set_shader_parameter("trunk_origin", group.center)
			trunk_layer.add_child(node)
			trunks[group.trunk_id] = {"node": node, "start": start}
		var stagger := 0
		for spec: Dictionary in group.branches:
			keep_branches[spec.id] = true
			if branches.has(spec.id):
				branches[spec.id].start = -100.0
				continue
			var art := Art.asset(season, spec.choice)
			var node := Components.sprite({})
			node.texture = art.texture
			node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			node.centered = false
			node.offset = -art.pivot
			node.position = spec.root
			node.scale = Vector2.ONE * spec.length / maxf(1.0, art.size.x - art.pivot.x)
			node.rotation = spec.angle
			node.material = _ink(BRANCH_SHADER)
			for uniform: String in ["uv_rect", "pivot"]: node.material.set_shader_parameter(uniform, art[uniform])
			node.material.set_shader_parameter("image_size", art.size)
			node.material.set_shader_parameter("branch_root", node.position)
			node.material.set_shader_parameter("branch_scale", node.scale.x)
			node.material.set_shader_parameter("branch_angle", node.rotation)
			branch_layer.add_child(node)
			branches[spec.id] = {"node": node, "start": -100.0 if settled or start < 0 else start + TRUNK_SECONDS + minf(stagger * 0.07, 0.35)}
			stagger += 1
	for id in branches.keys():
		if not keep_branches.has(id):
			branch_layer.remove_child(branches[id].node)
			branches[id].node.queue_free()
			branches.erase(id)
	for id in trunks.keys():
		if not keep_trunks.has(id):
			trunk_layer.remove_child(trunks[id].node)
			trunks[id].node.queue_free()
			trunks.erase(id)
	var order: Array = branches.keys()
	order.sort()
	for i in range(order.size()): branch_layer.move_child(branches[order[i]].node, i)
	visible = not groups.is_empty()
	configure_surface(null)
	advance(100.0 if settled else 0.0)

func advance(clock: float) -> void:
	for item: Dictionary in trunks.values():
		# The board clock starts at zero on every placement. A completed layer
		# belongs to the settled tree, never to a previous placement's clock.
		if item.start >= 0.0 and clock >= item.start + TRUNK_SECONDS: item.start = -100.0
		item.node.progress = Timing.smooth(item.start, TRUNK_SECONDS, clock)
		item.node.queue_redraw()
	for item: Dictionary in branches.values():
		if item.start >= 0.0 and clock >= item.start + BRANCH_SECONDS: item.start = -100.0
		item.node.material.set_shader_parameter("progress", Timing.smooth(item.start, BRANCH_SECONDS, clock))

func configure_surface(platform) -> void:
	if platform != null: screen_pixel = 256.0 / platform.cell_pixels
	for item: Dictionary in trunks.values() + branches.values():
		item.node.material.set_shader_parameter("occupancy_mask", rake_mask)
		item.node.material.set_shader_parameter("grid_size", grid_size)
		item.node.material.set_shader_parameter("screen_pixel", screen_pixel)
