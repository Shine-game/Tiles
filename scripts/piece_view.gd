extends Control

const Surface = preload("res://scripts/tile_surface.gd")
const Palette = preload("res://scripts/palette.gd")
var cells: Array = []
var color := 1
var cell_pitch := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func geometry() -> Dictionary:
	var extent := Vector2i.ZERO
	for cell: Vector2i in cells:
		extent = extent.max(cell + Vector2i.ONE)
	if extent == Vector2i.ZERO:
		return {"origin": size / 2, "unit": maxf(1, cell_pitch), "scale": 1.0}
	var unit: float = cell_pitch if cell_pitch > 0 else minf(51, minf(size.x / extent.x, size.y / extent.y))
	var scale: float = 1.0
	var drawn_size: Vector2 = Vector2(extent) * unit - Vector2.ONE * 4 * scale
	var origin := (size - drawn_size) / 2
	return {"origin": origin, "unit": unit, "scale": scale}

func cell_at(point: Vector2) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	var layout: Dictionary = geometry()
	var local: Vector2 = (point - layout.origin) / layout.unit
	var cell := Vector2i(floori(local.x), floori(local.y))
	return cell if cells.has(cell) else Vector2i(-1, -1)

func _draw() -> void:
	Surface.begin(self)
	if cells.is_empty():
		return
	var layout: Dictionary = geometry()
	for cell: Vector2i in cells:
		var face := Rect2(layout.origin + Vector2(cell) * layout.unit, Vector2.ONE * (layout.unit - 4 * layout.scale))
		Surface.draw(self, face, Palette.tile(color), Surface.depth(layout.unit))
