extends Control

const Surface = preload("res://scripts/tile_surface.gd")
const Geometry = preload("res://scripts/piece_geometry.gd")
const Palette = preload("res://scripts/palette.gd")
var cells: Array = []
var color := 1
var cell_pitch := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

# The tray and floating piece keep the same orientation, including tap rotations.
func display_cells() -> Array:
	return cells

func display_cell(cell: Vector2i) -> Vector2i:
	var index: int = cells.find(cell)
	return display_cells()[index] if index >= 0 else Vector2i(-1, -1)

func geometry() -> Dictionary:
	return Geometry.tray(display_cells(),Rect2(Vector2.ZERO,size),cell_pitch)

func cell_at(point: Vector2) -> Vector2i:
	var layout := geometry()
	var cell := Geometry.hit(display_cells(),point,layout.origin,layout.unit)
	return cells[display_cells().find(cell)] if cell.x >= 0 else cell

func _draw() -> void:
	Surface.begin(self)
	if cells.is_empty():
		return
	var layout: Dictionary = geometry()
	Surface.draw_piece(self, display_cells(), layout.origin, layout.unit, Palette.tile(color))
