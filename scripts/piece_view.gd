extends Control

const Palette = preload("res://scripts/palette.gd")
var cells: Array = []
var color := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func geometry() -> Dictionary:
	var extent := Vector2i.ZERO
	for cell: Vector2i in cells:
		extent = extent.max(cell + Vector2i.ONE)
	var unit: float = minf(34, minf(size.x / extent.x, size.y / extent.y))
	var origin := (size - Vector2(extent) * unit) / 2
	return {"origin": origin, "unit": unit}

func cell_at(point: Vector2) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	var layout: Dictionary = geometry()
	var local: Vector2 = (point - layout.origin) / layout.unit
	var cell := Vector2i(floori(local.x), floori(local.y))
	return cell if cells.has(cell) else Vector2i(-1, -1)

func _draw() -> void:
	if cells.is_empty():
		return
	var layout: Dictionary = geometry()
	for cell: Vector2i in cells:
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.tile(color)
		style.set_corner_radius_all(4)
		draw_style_box(style, Rect2(layout.origin + Vector2(cell) * layout.unit, Vector2.ONE * (layout.unit - 4)))
