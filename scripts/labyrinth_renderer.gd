class_name LabyrinthRenderer
extends RefCounted

const Growth = preload("res://scripts/growth.gd")
const Maze = preload("res://scripts/labyrinth_growth.gd")
const GREEN := Color("119d45")
const DEEP := Color("087b35")
const ROSE := Color("f43877")
const HEDGE_WIDTH := 0.24

static func draw(view) -> void:
	var pattern = view.pattern
	# Fuller hedge walls frame the sandy paths on both sides.
	for edge: Dictionary in pattern.edges:
		var opacity: float = pattern.wall_visibility(Growth.edge_key(edge.a, edge.b), view.clock)
		if opacity <= 0.001:
			continue
		var a: Vector2 = view._point(Vector2(edge.a) + Vector2(0.5, 0.5))
		var b: Vector2 = view._point(Vector2(edge.b) + Vector2(0.5, 0.5))
		var from_a: float = 1.0 if edge.old else clampf((view.clock - edge.start_a) / Growth.STEP, 0, 1)
		var from_b: float = 1.0 if edge.old else clampf((view.clock - edge.start_b) / Growth.STEP, 0, 1)
		if from_a + from_b >= 1:
			_wall(view, a, b, edge.color, opacity)
		else:
			if from_a > 0:
				_wall(view, a, a.lerp(b, from_a), edge.color, opacity)
			if from_b > 0:
				_wall(view, b.lerp(a, from_b), b, edge.color, opacity)
	for link: Dictionary in pattern.links:
		var scale: float = Maze.bench_progress(link, view.clock)
		if scale > 0:
			var center: Vector2 = view._point((Vector2(link.a) + Vector2(link.b)) / 2)
			_bench(view, center, Vector2(link.b - link.a).orthogonal(), scale)
	for cell: Vector2i in pattern.arrivals:
		var scale: float = view.pop((view.clock - float(pattern.arrivals[cell])) / Growth.CENTER_POP)
		if scale > 0:
			_pyramid(view, view._point(Vector2(cell) + Vector2(0.5, 0.5)), int(view.board[cell.y][cell.x]), scale)
	for corner: Vector2i in pattern.flowers:
		var tree: Dictionary = pattern.flowers[corner]
		var scale: float = view.pop((view.clock - float(tree.start)) / Growth.FLOWER_POP)
		if scale > 0:
			_tree(view, view._point(Vector2(corner)), tree.color, scale)

static func _wall(view, a: Vector2, b: Vector2, color: int, opacity: float) -> void:
	var pitch: float = view.pitch
	var width: float = pitch * HEDGE_WIDTH
	var rise := Vector2(0, -pitch * 0.08 * opacity)
	view.draw_line(a + Vector2(pitch * 0.025, pitch * 0.055), b + Vector2(pitch * 0.025, pitch * 0.055), Color("89754b", 0.16 * opacity), width * 1.6, true)
	view.draw_line(a, b, Color(DEEP.darkened(0.12), opacity), width, true)
	view.draw_line(a + rise, b + rise, Color(GREEN, opacity), width, true)
	var direction := (b - a).normalized()
	var normal := direction.orthogonal()
	var count: int = maxi(1, ceili(a.distance_to(b) / (pitch * 0.065)))
	for i in range(count + 1):
		var t: float = float(i) / count
		var point: Vector2 = a.lerp(b, t) + rise
		var leaf: Color = GREEN.lightened(0.13 if i % 3 == 0 else 0.03)
		view.draw_circle(point + normal * width * (0.10 if i % 2 == 0 else -0.10), width * 0.48, Color(leaf, opacity), true, -1, true)
		if color == 2:
			# Two staggered flower rows cover the broader shrub canopy.
			for side: int in [-1, 1]:
				var offset: Vector2 = normal * width * 0.23 * side + direction * pitch * (0.016 if side == 1 else -0.016)
				_rose(view, point + offset, pitch * 0.038, opacity)

static func _rose(view, point: Vector2, radius: float, opacity: float) -> void:
	for petal in range(5):
		var direction := Vector2.from_angle(float(petal) * TAU / 5)
		view.draw_circle(point + direction * radius * 0.55, radius * 0.56, Color(ROSE.lightened(0.15 if petal % 2 == 0 else 0), opacity), true, -1, true)
	view.draw_circle(point, radius * 0.29, Color("ffbdd4", opacity), true, -1, true)

static func _pyramid(view, center: Vector2, color: int, scale: float) -> void:
	var unit: float = view.pitch * scale
	var left := center + Vector2(-0.18, 0) * unit
	var right := center + Vector2(0.18, 0) * unit
	var front := center + Vector2(0, 0.17) * unit
	var back := center + Vector2(0, -0.13) * unit
	var peak := center + Vector2(0, -0.28) * unit
	view.draw_circle(center + Vector2(0.05, 0.055) * unit, unit * 0.19, Color("817246", 0.13), true, -1, true)
	view.draw_colored_polygon(PackedVector2Array([back, left, peak]), GREEN.lightened(0.13))
	view.draw_colored_polygon(PackedVector2Array([left, front, peak]), GREEN)
	view.draw_colored_polygon(PackedVector2Array([front, right, peak]), DEEP)
	view.draw_line(left, peak, Color("72e894", 0.45), maxf(0.5, unit * 0.012), true)
	if color == 2:
		for offset: Vector2 in [Vector2(-0.07, -0.09), Vector2(0.025, -0.20), Vector2(0.075, -0.025), Vector2(-0.025, 0.045)]:
			_rose(view, center + offset * unit, unit * 0.038, 1)

static func _tree(view, center: Vector2, color: int, scale: float) -> void:
	var unit: float = view.pitch * scale
	view.draw_circle(center + Vector2(0.07, 0.10) * unit, unit * 0.23, Color("796641", 0.15), true, -1, true)
	view.draw_line(center + Vector2(0, 0.07) * unit, center + Vector2(0, -0.20) * unit, Color("856043"), unit * 0.055, true)
	var crown := center + Vector2(0, -0.16) * unit
	view.draw_circle(crown + Vector2(0, 0.025) * unit, unit * 0.23, DEEP.darkened(0.08), true, -1, true)
	for lobe in range(7):
		var direction := Vector2.from_angle(float(lobe) * TAU / 7)
		var point: Vector2 = crown + direction * unit * 0.12
		view.draw_circle(point, unit * 0.115, GREEN.lightened(0.06 + 0.09 * (1 - direction.y)), true, -1, true)
		if color == 2:
			_rose(view, point, unit * 0.037, 1)
	view.draw_circle(crown - Vector2(0.025, 0.025) * unit, unit * 0.15, GREEN.lightened(0.19), true, -1, true)
	if color == 2:
		_rose(view, crown - Vector2(0.025, 0.025) * unit, unit * 0.045, 1)

static func _bench(view, center: Vector2, direction: Vector2, scale: float) -> void:
	var unit: float = view.pitch * scale
	var along := direction.normalized() * unit
	var across := direction.orthogonal().normalized() * unit
	view.draw_line(center - along * 0.18 + Vector2(0, 0.045) * unit, center + along * 0.18 + Vector2(0, 0.045) * unit, Color("7f6c4a", 0.20), unit * 0.15, true)
	for side: int in [-1, 1]:
		view.draw_line(center + along * 0.12 * side - across * 0.05, center + along * 0.12 * side + across * 0.055, Color("49544a"), unit * 0.035, true)
	for slat in range(3):
		var offset: Vector2 = across * (float(slat) - 1) * 0.035
		view.draw_line(center - along * 0.17 + offset, center + along * 0.17 + offset, Color("b98b5b") if slat == 2 else Color("d8b583"), unit * 0.027, true)
	view.draw_line(center - along * 0.20 - across * 0.085, center + along * 0.20 - across * 0.085, Color("977047"), unit * 0.036, true)
