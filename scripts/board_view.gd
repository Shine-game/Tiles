class_name TileBoardView
extends Control

signal anchor_selected(anchor: Vector2i)
signal anchor_hovered(anchor: Vector2i)
signal hover_exited

const Palette = preload("res://scripts/palette.gd")
var board: Array = []
var preview_cells: Array = []
var preview_anchor := Vector2i(-100, -100)
var preview_color := 1
var preview_valid := false
var field := Rect2()
var pitch := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hover_exited.emit())
	resized.connect(queue_redraw)

func _draw() -> void:
	if board.is_empty():
		return
	var side: float = minf(size.x, size.y)
	field = Rect2((size - Vector2.ONE * side) / 2, Vector2.ONE * side)
	pitch = (side - 16.0) / board.size()
	draw_style_box(_box(Color("e6e7dc"), 12), field)
	for y in range(board.size()):
		for x in range(board.size()):
			var cell := Vector2i(x, y)
			var rect := Rect2(field.position + Vector2(8, 8) + Vector2(cell) * pitch, Vector2.ONE * (pitch - 4))
			var value: int = board[y][x]
			var color := Color("f8f8f1") if value == 0 else Palette.tile(value)
			var is_preview: bool = preview_cells.has(cell - preview_anchor)
			if is_preview:
				color = Palette.tile(preview_color) if preview_valid else Palette.INVALID
			draw_style_box(_box(color, 4), rect)
			if is_preview:
				draw_rect(rect.grow(-1), Palette.tile(preview_color).darkened(0.25) if preview_valid else Palette.INVALID_BORDER, false, 2)
			if cell == Vector2i(board.size() / 2, board.size() / 2):
				draw_circle(rect.get_center(), 3, Color("f8f8f1"))

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func cell_at(position_in_board: Vector2) -> Vector2i:
	var local := position_in_board - field.position - Vector2(8, 8)
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var cell := Vector2i(floori(local.x / pitch), floori(local.y / pitch))
	if cell.x >= board.size() or cell.y >= board.size():
		return Vector2i(-1, -1)
	return cell

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		anchor_selected.emit(cell_at(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		anchor_selected.emit(cell_at(event.position))
		accept_event()
	elif event is InputEventMouseMotion:
		anchor_hovered.emit(cell_at(event.position))
