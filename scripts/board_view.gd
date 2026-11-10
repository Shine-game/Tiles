class_name TileBoardView
extends Control

signal growth_finished
signal growth_started
signal growth_canceled
signal flower_opened(corner: Vector2i, color: int)
const Palette = preload("res://scripts/palette.gd")
const Brush = preload("res://scripts/botanical_brush.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const CoralLayer = preload("res://scripts/coral_visuals.gd")
const MazeGrowth = preload("res://scripts/labyrinth_growth.gd")
const MazeRenderer = preload("res://scripts/labyrinth_renderer.gd")
const Growth = preload("res://scripts/growth.gd")
var board: Array = []
var pattern = Growth.new()
var clock := 0.0
var growing := false
var field := Rect2()
var pitch := 1.0
var grid_inset := 8.0
var direction_by_edge: Dictionary = {}
var leaf_texture: Texture2D = Brush.leaf()
var announced_flowers: Dictionary = {}
var show_guides := true
var growth_before: Array = []
var labyrinth := false
var coral_reef := false
var coral_visuals: CoralVisuals
var occupied_platform: OccupiedPlatform

func _ready() -> void:
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)

func show_settled(grid: Array, preserve_direction: bool = false) -> void:
	growth_canceled.emit()
	announced_flowers.clear()
	board = grid
	_build_pattern(grid, grid)
	_adopt_directions(preserve_direction)
	_sync_coral(true, preserve_direction)
	clock = 0
	growing = false
	set_process(false)
	queue_redraw()

func sync_board(grid: Array) -> void:
	if pattern.board != grid:
		show_settled(grid)
	elif labyrinth != Palette.labyrinth or coral_reef != Palette.coral_reef:
		_restyle()

func _build_pattern(before: Array, after: Array) -> void:
	labyrinth = Palette.labyrinth
	coral_reef = Palette.coral_reef
	pattern = Coral.new() if coral_reef else (MazeGrowth.new() if labyrinth else Growth.new())
	pattern.build(before, after)
	if occupied_platform == null:
		occupied_platform = Platform.new()
		add_child(occupied_platform)
	occupied_platform.sync(after)
	update_geometry()

func _restyle() -> void:
	if not growing:
		show_settled(board, true)
		return
	_build_pattern(growth_before, board)
	_adopt_directions(true)
	_sync_coral(false, true)
	clock = minf(clock, pattern.duration)
	if coral_reef:
		coral_visuals.advance(clock)
	growing = clock < pattern.duration
	set_process(growing)
	if not growing:
		growth_finished.emit()
	queue_redraw()

func _sync_coral(settled: bool, preserve: bool) -> void:
	if coral_visuals != null and not preserve:
		coral_visuals.clear()
	if coral_reef:
		if coral_visuals == null:
			coral_visuals = CoralLayer.new()
			coral_visuals.z_index = 1
			add_child(coral_visuals)
		coral_visuals.show()
		coral_visuals.reconcile(pattern, settled, true)
		coral_visuals.advance(0 if settled else clock)
		update_geometry()
	elif coral_visuals != null:
		coral_visuals.hide()

func animate_growth(before: Array, after: Array) -> void:
	board = after
	growth_before = before.duplicate(true)
	_build_pattern(before, after)
	_adopt_directions(true)
	clock = 0
	_sync_coral(false, true)
	announced_flowers.clear()
	growing = pattern.duration > 0
	set_process(growing)
	if growing:
		growth_started.emit()
	queue_redraw()

func advance_growth(delta: float) -> void:
	if not growing:
		return
	clock = minf(pattern.duration, clock + maxf(0, delta))
	if coral_reef:
		coral_visuals.advance(clock)
	for corner: Vector2i in pattern.flowers:
		var flower: Dictionary = pattern.flowers[corner]
		if not flower.old and not announced_flowers.has(corner) and clock >= flower.start + Growth.FLOWER_POP * 0.12:
			announced_flowers[corner] = true
			flower_opened.emit(corner, flower.color)
	if clock >= pattern.duration:
		growing = false
		set_process(false)
		growth_finished.emit()
	queue_redraw()

func _process(delta: float) -> void:
	advance_growth(delta)

func update_geometry() -> void:
	if board.is_empty():
		return
	var side: float = minf(size.x, size.y)
	field = Rect2((size - Vector2.ONE * side) / 2, Vector2.ONE * side)
	# Keep the raised north edge and its shadow inside the field, including
	# high-resolution gallery captures. The logical board remains square.
	var edge_allowance: float = Platform.SOURCE_DEPTH / Platform.SOURCE_CELL + 0.035
	pitch = maxf(1, minf((side - 16.0) / board.size(), (side - 2.0) / (board.size() + 2 * edge_allowance)))
	grid_inset = maxf(8, (side - board.size() * pitch) / 2)
	if occupied_platform != null:
		occupied_platform.configure(_point(Vector2.ZERO), pitch, Palette.platform_color())
	if coral_visuals != null:
		coral_visuals.position = _point(Vector2.ZERO)
		coral_visuals.scale = Vector2.ONE * pitch / 256.0

func surface_depth() -> float:
	return Platform.depth(pitch)

func _floor_point(position_in_grid: Vector2) -> Vector2:
	return field.position + Vector2.ONE * grid_inset + position_in_grid * pitch

func _point(position_in_grid: Vector2) -> Vector2:
	return _floor_point(position_in_grid) - Vector2(0, surface_depth())

static func pop(progress: float) -> float:
	var t: float = clampf(progress, 0, 1)
	return smoothstep(0, 1, t) + sin(t * PI) * 0.15

func _adopt_directions(preserve: bool) -> void:
	var retained: Dictionary = {}
	for edge: Dictionary in pattern.edges:
		var key: Vector4i = Growth.edge_key(edge.a, edge.b)
		if preserve and edge.old and direction_by_edge.has(key) and direction_by_edge[key].color == edge.color:
			edge.flow = direction_by_edge[key].flow
		retained[key] = {"color": edge.color, "flow": edge.flow}
	direction_by_edge = retained

func _draw() -> void:
	if board.is_empty():
		return
	update_geometry()
	if show_guides:
		_draw_guides()
	if not coral_reef:
		_draw_occupied_faces()
	if coral_reef:
		return
	if labyrinth:
		MazeRenderer.draw(self)
		return
	for cell: Vector2i in pattern.arrivals:
		var scale: float = pop((clock - float(pattern.arrivals[cell])) / Growth.CENTER_POP)
		if scale > 0:
			var center := _point(Vector2(cell) + Vector2(0.5, 0.5))
			var pigment: Color = Palette.pigment(board[cell.y][cell.x])
			for layer in range(3):
				draw_circle(center, pitch * (0.34 + layer * 0.08), Color(pigment, 0.012 * scale), true, -1, true)
	for edge: Dictionary in pattern.edges:
		_draw_edge(edge)
	for link: Dictionary in pattern.links:
		_draw_link(link)
	for cell: Vector2i in pattern.arrivals:
		_draw_holding_motif(cell)
	for corner: Vector2i in pattern.flowers:
		_draw_flower(corner, pattern.flowers[corner])

func _draw_occupied_faces() -> void:
	# One color-independent surface; the board-wide shader owns its outline.
	for cell: Vector2i in pattern.arrivals:
		draw_rect(Rect2(_point(Vector2(cell)), Vector2.ONE * pitch), Palette.garden())

func _draw_guides() -> void:
	var n: int = board.size()
	var ink := Color("9b95a3", 0.20)
	var width: float = maxf(0.75, pitch * 0.012)
	for y in range(n):
		for x in range(n + 1):
			if Growth.value(board, Vector2i(x - 1, y)) == 0 and Growth.value(board, Vector2i(x, y)) == 0:
				draw_line(_floor_point(Vector2(x, y)), _floor_point(Vector2(x, y + 1)), ink, width, true)
	for y in range(n + 1):
		for x in range(n):
			if Growth.value(board, Vector2i(x, y - 1)) == 0 and Growth.value(board, Vector2i(x, y)) == 0:
				draw_line(_floor_point(Vector2(x, y)), _floor_point(Vector2(x + 1, y)), ink, width, true)

func _port_tangent(cell: Vector2i, neighbor: Vector2i) -> Vector2:
	var direction := Vector2(neighbor - cell)
	var connected: Array = []
	for offset: Vector2i in Growth.DIRECTIONS:
		if Growth.value(board, cell + offset) == Growth.value(board, cell):
			connected.append(Vector2(offset))
	if connected.size() == 2 and is_zero_approx(connected[0].dot(connected[1])):
		var other: Vector2 = connected[1] if connected[0] == direction else connected[0]
		return (direction - other).normalized()
	return direction

func _curve(a: Vector2, b: Vector2, tangent_a: Vector2 = Vector2.ZERO, tangent_b: Vector2 = Vector2.ZERO) -> Dictionary:
	var length: float = a.distance_to(b)
	var direction: Vector2 = (b - a).normalized()
	return {"a": a, "b": b, "ca": a + (direction if tangent_a == Vector2.ZERO else tangent_a) * length * 0.34, "cb": b + (-direction if tangent_b == Vector2.ZERO else tangent_b) * length * 0.34}

func _curve_point(curve: Dictionary, t: float, wave: float = 0) -> Vector2:
	var one: float = 1 - t
	var base: Vector2 = one * one * one * curve.a + 3 * one * one * t * curve.ca + 3 * one * t * t * curve.cb + t * t * t * curve.b
	var delta: Vector2 = curve.b - curve.a
	var normal := Vector2(-delta.y, delta.x).normalized()
	var curl: float = sin(t * TAU) * sin(t * PI) * pitch * 0.018
	var ripple: float = sin(t * TAU + clock * 11) * sin(t * PI) * pitch * 0.025 * wave
	return base + normal * (curl + ripple)

func _curve_tangent(curve: Dictionary, t: float) -> Vector2:
	return (_curve_point(curve, minf(1, t + 0.005)) - _curve_point(curve, maxf(0, t - 0.005))).normalized()

func _vine(curve: Dictionary, start: float, end: float, ink: Color, wave: float) -> void:
	if end <= start:
		return
	var points := PackedVector2Array()
	for i in range(21):
		points.append(_curve_point(curve, lerpf(start, end, i / 20.0), wave))
	draw_polyline(points, Color(ink, ink.a * 0.10), maxf(2.5, pitch * 0.115), true)
	draw_polyline(points, Color(ink, ink.a * 0.36), maxf(1.6, pitch * 0.060), true)
	draw_polyline(points, Color(ink, ink.a * 0.92), maxf(0.9, pitch * 0.029), true)

func _paint_leaf(root: Vector2, direction: Vector2, length: float, width: float, ink: Color, scale: float = 1) -> void:
	if length * scale < 0.6 or width * scale < 0.4:
		return
	# The watercolor texture's veins run root-to-tip, not in screen coordinates.
	draw_set_transform(root, direction.angle(), Vector2.ONE)
	draw_texture_rect(leaf_texture, Rect2(0, -width * scale / 2, length * scale, width * scale), false, ink)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_edge(edge: Dictionary) -> void:
	var a := _point(Vector2(edge.a) + Vector2(0.5, 0.5))
	var b := _point(Vector2(edge.b) + Vector2(0.5, 0.5))
	var curve: Dictionary = _curve(a, b, _port_tangent(edge.a, edge.b), _port_tangent(edge.b, edge.a))
	var ink: Color = Palette.pigment(edge.color)
	var left: float = 1 if edge.old else clampf((clock - edge.start_a) / Growth.STEP, 0, 1)
	var right: float = 1 if edge.old else clampf((clock - edge.start_b) / Growth.STEP, 0, 1)
	var wave: float = 0 if edge.old else 1 - smoothstep(edge.finish, edge.finish + Growth.RIPPLE, clock)
	if left + right >= 1:
		_vine(curve, 0, 1, ink, wave)
	else:
		_vine(curve, 0, left, ink, wave)
		_vine(curve, 1 - right, 1, ink, wave)
	for sprout: Dictionary in Growth.leaf_sprouts(edge):
		var scale: float = pop((clock - sprout.start) / Growth.LEAF_POP)
		if scale <= 0:
			continue
		var tangent: Vector2 = _curve_tangent(curve, sprout.fraction) * sprout.direction
		var normal: Vector2 = Vector2(-tangent.y, tangent.x) * float(sprout.side)
		var direction: Vector2 = (tangent * 0.75 + normal * 0.93).normalized()
		_paint_leaf(_curve_point(curve, sprout.fraction), direction, pitch * 0.44, pitch * 0.21, Color(ink.lightened(0.08), 0.92), scale)
	if not edge.old:
		var t: float = (clock - edge.finish) / Growth.STAR_POP
		if t > 0 and t < 1:
			_star(_curve_point(curve, 0.5) + Vector2(0, -pitch * 0.09 * t), pitch * 0.065 * sin(PI * t), Color(Palette.blossom(edge.color), 1 - t))

func _draw_holding_motif(cell: Vector2i) -> void:
	var scale: float = minf(1, pop((clock - float(pattern.arrivals[cell])) / Growth.CENTER_POP))
	if scale <= 0:
		return
	var center := _point(Vector2(cell) + Vector2(0.5, 0.5))
	var ink: Color = Palette.pigment(board[cell.y][cell.x])
	var accent: Color = Palette.blossom(board[cell.y][cell.x])
	# Disconnected directions grow full, nonconnecting fronds toward the cell's
	# boundary. Opposite colors nearly meet in foliage, never in logical stems.
	for vector: Vector2i in Growth.DIRECTIONS:
		var direction := Vector2(vector)
		var normal := Vector2(-direction.y, direction.x)
		var open: bool = Growth.value(board, cell + vector) != board[cell.y][cell.x]
		var reach: float = 0.415 if open else 0.205
		var tip: Vector2 = center + direction * pitch * reach * scale
		var curve: Dictionary = _curve(center, tip, direction + normal * 0.3, -direction)
		_vine(curve, 0, 1, Color(ink, 0.76 if open else 0.60), 0)
		for side: float in [-1.0, 1.0]:
			if open:
				_paint_leaf(center + direction * pitch * 0.10 * scale, (direction + normal * side * 0.70).normalized(), pitch * 0.30, pitch * 0.16, Color(ink, 0.90), scale)
				_paint_leaf(center + direction * pitch * 0.23 * scale, (direction + normal * side * 0.70).normalized(), pitch * 0.26, pitch * 0.14, Color(ink.lightened(0.10), 0.84), scale)
			else:
				var root: Vector2 = center + direction * pitch * 0.09 * scale
				_paint_leaf(root, (direction + normal * side * 0.75).normalized(), pitch * 0.14, pitch * 0.075, Color(ink, 0.78), scale)
		_star(tip, pitch * (0.037 if open else 0.031) * scale, Color(accent, 0.9))
	draw_circle(center, maxf(0.5, pitch * 0.014 * scale), Color(ink, 0.75), true, -1, true)

func _draw_link(link: Dictionary) -> void:
	var a := _point(Vector2(link.a))
	var b := _point(Vector2(link.b))
	var curve: Dictionary = _curve(a, b)
	var t: float = 1 if link.old else clampf((clock - link.start) / Growth.LINK_GROW, 0, 1)
	_vine(curve, 0, t, Palette.pigment(link.color), 0 if link.old else 1 - t)
	for fraction: float in [0.25, 0.5, 0.75]:
		var scale: float = 1 if link.old else pop((clock - link.start - fraction * Growth.LINK_GROW) / Growth.STAR_POP)
		if scale > 0:
			_star(_curve_point(curve, fraction), pitch * 0.045 * scale, Palette.blossom(link.color))

func _star(center: Vector2, radius: float, ink: Color) -> void:
	if radius < 0.35 or ink.a <= 0.01:
		return
	var points := PackedVector2Array()
	for i in range(8):
		points.append(center + Vector2.from_angle(i * TAU / 8) * radius * (1.0 if i % 2 == 0 else 0.23))
	draw_colored_polygon(points, ink)
	draw_polyline(PackedVector2Array([points[0], points[2], points[4], points[6], points[0]]), Color(ink, 0.18), 0.6, true)

func _draw_flower(corner: Vector2i, flower: Dictionary) -> void:
	var progress: float = clampf((clock - flower.start) / Growth.FLOWER_POP, 0, 1)
	if progress <= 0:
		return
	var center := _point(Vector2(corner))
	var stem: Color = Palette.pigment(flower.color)
	var ink: Color = Palette.blossom(flower.color)
	var support_scale: float = minf(1, pop(progress / 0.60))
	var base: Vector2 = center + Vector2(0, pitch * 0.455)
	var curve: Dictionary = _curve(base, center, Vector2(-0.18, -1).normalized(), Vector2(0, 1))
	_vine(curve, 0, support_scale, stem, 0)
	# Red-marked reference: leaf stems rise from underneath and cradle the bloom.
	for side: float in [-1.0, 1.0]:
		_paint_leaf(base + Vector2(0, -pitch * 0.025), Vector2(side * 0.72, -0.88).normalized(), pitch * 0.31, pitch * 0.12, Color(stem, 0.88), support_scale)
		_paint_leaf(base + Vector2(0, -pitch * 0.10), Vector2(side * 0.55, -1).normalized(), pitch * 0.19, pitch * 0.08, Color(stem.lightened(0.15), 0.76), support_scale)
	var scale: float = minf(1, pop((progress - 0.12) / 0.88))
	var radius: float = pitch * Growth.FLOWER_RADIUS * scale
	if radius < 0.6:
		return
	for layer in range(3):
		draw_circle(center, radius * (0.72 + layer * 0.12), Color(ink, 0.025), true, -1, true)
	for petal in range(8):
		var direction := Vector2.from_angle(petal * TAU / 8)
		_paint_leaf(center + direction * radius * 0.04, direction, radius * 0.96, radius * 0.55, Color(ink, 0.96))
		_paint_leaf(center + direction * radius * 0.03, direction, radius * 0.72, radius * 0.25, Color(ink.lightened(0.25), 0.62))
	draw_circle(center, radius * 0.11, Palette.tile(flower.color), true, -1, true)
	for i in range(8):
		var offset := Vector2.from_angle(i * TAU / 8) * radius * 0.14
		draw_circle(center + offset, maxf(0.35, radius * 0.022), Color(stem, 0.62), true, -1, true)
