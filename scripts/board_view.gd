class_name TileBoardView
extends Control

signal growth_finished
const Palette = preload("res://scripts/palette.gd")
const Growth = preload("res://scripts/growth.gd")
var board: Array = []
var pattern = Growth.new()
var clock := 0.0
var growing := false
var field := Rect2()
var pitch := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)

func show_settled(grid: Array) -> void:
	board = grid
	pattern.build(grid, grid)
	clock = 0
	growing = false
	set_process(false)
	queue_redraw()

func sync_board(grid: Array) -> void:
	if pattern.board != grid:
		show_settled(grid)

func animate_growth(before: Array, after: Array) -> void:
	board = after
	pattern.build(before, after)
	clock = 0
	growing = pattern.duration > 0
	set_process(growing)
	queue_redraw()

func advance_growth(delta: float) -> void:
	if not growing:
		return
	clock = minf(pattern.duration, clock + maxf(0, delta))
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
	pitch = (side - 16.0) / board.size()

func _point(position_in_grid: Vector2) -> Vector2:
	return field.position + Vector2(8, 8) + position_in_grid * pitch

static func pop(progress: float) -> float:
	var t: float = clampf(progress, 0, 1)
	return smoothstep(0, 1, t) + sin(t * PI) * 0.15

func _draw() -> void:
	if board.is_empty():
		return
	update_geometry()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("eeeee5")
	frame.set_corner_radius_all(10)
	draw_style_box(frame, field)
	# Occupancy stays logical: positioned squares give way to open floor.
	for y in range(board.size()):
		for x in range(board.size()):
			var rect := Rect2(_point(Vector2(x, y)), Vector2.ONE * (pitch - 2))
			draw_rect(rect, Color("f8f7ef"))
	for edge: Dictionary in pattern.edges:
		_draw_edge(edge)
	for link: Dictionary in pattern.links:
		_draw_link(link)
	for cell: Vector2i in pattern.arrivals:
		var scale: float = pop((clock - float(pattern.arrivals[cell])) / Growth.CENTER_POP)
		if scale > 0:
			var center := _point(Vector2(cell) + Vector2(0.5, 0.5))
			var color: Color = Palette.tile(board[cell.y][cell.x])
			draw_arc(center, pitch * 0.065 * scale, 0, TAU, 24, color, maxf(1, pitch * 0.024), true)
			draw_circle(center, pitch * 0.023 * scale, color, true, -1, true)
	for corner: Vector2i in pattern.flowers:
		_draw_flower(corner, pattern.flowers[corner])

func _vine(a: Vector2, b: Vector2, start: float, end: float, ink: Color, wave: float) -> void:
	if end <= start:
		return
	var points := PackedVector2Array()
	var direction := b - a
	var normal := Vector2(-direction.y, direction.x).normalized()
	for i in range(17):
		var t: float = lerpf(start, end, i / 16.0)
		var displacement: float = sin(t * TAU + clock * 11) * sin(t * PI) * pitch * 0.035 * wave
		points.append(a.lerp(b, t) + normal * displacement)
	draw_polyline(points, ink, maxf(1.2, pitch * 0.035), true)

func _draw_edge(edge: Dictionary) -> void:
	var a := _point(Vector2(edge.a) + Vector2(0.5, 0.5))
	var b := _point(Vector2(edge.b) + Vector2(0.5, 0.5))
	var ink: Color = Palette.tile(edge.color)
	var left: float = 1 if edge.old else clampf((clock - edge.start_a) / Growth.STEP, 0, 1)
	var right: float = 1 if edge.old else clampf((clock - edge.start_b) / Growth.STEP, 0, 1)
	var wave: float = 0 if edge.old else 1 - smoothstep(edge.finish, edge.finish + Growth.RIPPLE, clock)
	if left + right >= 1:
		_vine(a, b, 0, 1, ink, wave)
	else:
		_vine(a, b, 0, left, ink, wave)
		_vine(a, b, 1 - right, 1, ink, wave)
	if not edge.old:
		var t: float = (clock - edge.finish) / Growth.STAR_POP
		if t > 0 and t < 1:
			_star(a.lerp(b, 0.5) + Vector2(0, -pitch * 0.09 * t), pitch * 0.07 * sin(PI * t), Color(Palette.accent(edge.color), 1 - t))

func _draw_link(link: Dictionary) -> void:
	var a := _point(Vector2(link.a))
	var b := _point(Vector2(link.b))
	var t: float = 1 if link.old else clampf((clock - link.start) / Growth.LINK_GROW, 0, 1)
	_vine(a, b, 0, t, Palette.tile(link.color), 0 if link.old else 1 - t)
	for fraction: float in [0.25, 0.5, 0.75]:
		var scale: float = 1 if link.old else pop((clock - link.start - fraction * Growth.LINK_GROW) / Growth.STAR_POP)
		if scale > 0:
			_star(a.lerp(b, fraction), pitch * 0.055 * scale, Palette.accent(link.color))

func _star(center: Vector2, radius: float, ink: Color) -> void:
	# Subpixel polygons collapse to duplicate float coordinates during early pops.
	if radius < 0.35 or ink.a <= 0.01:
		return
	var points := PackedVector2Array()
	for i in range(8):
		points.append(center + Vector2.from_angle(i * TAU / 8) * radius * (1.0 if i % 2 == 0 else 0.27))
	draw_colored_polygon(points, ink)

func _draw_flower(corner: Vector2i, flower: Dictionary) -> void:
	var scale: float = pop((clock - flower.start) / Growth.FLOWER_POP)
	if scale <= 0:
		return
	# Even the pop overshoot remains within radius 1/3 cell, inside its quarters.
	var radius: float = pitch * Growth.FLOWER_RADIUS * minf(1, scale)
	if radius < 0.5:
		return
	var center := _point(Vector2(corner))
	var ink: Color = Palette.accent(flower.color)
	for petal in range(8):
		var angle: float = petal * TAU / 8
		var outward := Vector2.from_angle(angle)
		var sideways := Vector2(-outward.y, outward.x)
		var points := PackedVector2Array()
		for i in range(20):
			var t: float = i * TAU / 20
			points.append(center + outward * radius * (0.58 + cos(t) * 0.42) + sideways * sin(t) * radius * 0.20)
		draw_colored_polygon(points, ink)
	draw_circle(center, radius * 0.21, Palette.tile(flower.color), true, -1, true)
