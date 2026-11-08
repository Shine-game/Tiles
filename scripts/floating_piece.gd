extends Control

const Palette = preload("res://scripts/palette.gd")
var cells: Array = []
var origin := Vector2.ZERO
var pitch := 1.0
var color := 1
var valid := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30

func cell_at(point: Vector2) -> Vector2i:
	var cell := Vector2i(floori((point.x - origin.x) / pitch), floori((point.y - origin.y) / pitch))
	return cell if cells.has(cell) else Vector2i(-1, -1)

func _draw() -> void:
	for cell: Vector2i in cells:
		var rect := Rect2(origin + Vector2(cell) * pitch, Vector2.ONE * (pitch - 4))
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.tile(color) if valid else Palette.INVALID
		style.set_corner_radius_all(4)
		style.set_border_width_all(2)
		style.border_color = Palette.tile(color).darkened(0.3) if valid else Palette.INVALID_BORDER
		draw_style_box(style, rect)
