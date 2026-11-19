extends Control

const Surface = preload("res://scripts/tile_surface.gd")
const Rules = preload("res://scripts/rules.gd")
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
	var extent := Vector2i.ZERO
	for cell: Vector2i in display_cells():
		extent = extent.max(cell + Vector2i.ONE)
	if extent == Vector2i.ZERO:
		return {"origin": size / 2, "unit": maxf(1, cell_pitch), "scale": 1.0}
	var unit: float = cell_pitch if cell_pitch > 0 else minf(51, minf(size.x / extent.x, size.y / extent.y))
	var scale: float = 1.0
	var drawn_size: Vector2 = Vector2(extent) * unit
	var origin := (size - drawn_size) / 2
	# Tall rotations extend downward over the board instead of off the screen.
	origin.y = maxf(0, origin.y)
	return {"origin": origin, "unit": unit, "scale": scale}

func cell_at(point: Vector2) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	var layout: Dictionary = geometry()
	var local: Vector2 = (point - layout.origin) / layout.unit
	var cell := Vector2i(floori(local.x), floori(local.y))
	var index: int = display_cells().find(cell)
	return cells[index] if index >= 0 else Vector2i(-1, -1)

func _draw() -> void:
	Surface.begin(self)
	if cells.is_empty():
		return
	var layout: Dictionary = geometry()
	Surface.draw_piece(self, display_cells(), layout.origin, layout.unit, Palette.tile(color))
