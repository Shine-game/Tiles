extends Control

const Palette = preload("res://scripts/palette.gd")
var cells: Array = []
var color := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if cells.is_empty():
		return
	var extent := Vector2i.ZERO
	for cell: Vector2i in cells:
		extent = extent.max(cell + Vector2i.ONE)
	var unit: float = minf(34, minf(size.x / extent.x, size.y / extent.y))
	var origin := (size - Vector2(extent) * unit) / 2
	for cell: Vector2i in cells:
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.tile(color)
		style.set_corner_radius_all(4)
		draw_style_box(style, Rect2(origin + Vector2(cell) * unit, Vector2.ONE * (unit - 4)))
