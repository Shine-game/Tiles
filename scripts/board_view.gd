class_name TileBoardView
extends Control

const Palette = preload("res://scripts/palette.gd")
var board: Array = []
var field := Rect2()
var pitch := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func update_geometry() -> void:
	if board.is_empty():
		return
	var side: float = minf(size.x, size.y)
	field = Rect2((size - Vector2.ONE * side) / 2, Vector2.ONE * side)
	pitch = (side - 16.0) / board.size()

func _draw() -> void:
	if board.is_empty():
		return
	update_geometry()
	draw_style_box(_box(Color("e6e7dc"), 12), field)
	for y in range(board.size()):
		for x in range(board.size()):
			var cell := Vector2i(x, y)
			var rect := Rect2(field.position + Vector2(8, 8) + Vector2(cell) * pitch, Vector2.ONE * (pitch - 4))
			var value: int = board[y][x]
			var color := Color("f8f8f1") if value == 0 else Palette.tile(value)
			draw_style_box(_box(color, 4), rect)
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
