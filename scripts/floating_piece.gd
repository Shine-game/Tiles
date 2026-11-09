extends Control

const Surface = preload("res://scripts/tile_surface.gd")
const Palette = preload("res://scripts/palette.gd")
var cells: Array = []
var origin := Vector2.ZERO
var pitch := 1.0
var color := 1
var valid := false
var face_lift := -1.0

func lift() -> float:
	return Surface.depth(pitch) if face_lift < 0 else face_lift

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30

func cell_at(point: Vector2) -> Vector2i:
	var face_origin: Vector2 = origin - Vector2(0, lift())
	var cell := Vector2i(floori((point.x - face_origin.x) / pitch), floori((point.y - face_origin.y) / pitch))
	return cell if cells.has(cell) else Vector2i(-1, -1)

func _draw() -> void:
	for cell: Vector2i in cells:
		var face := Rect2(origin + Vector2(cell) * pitch - Vector2(0, lift()), Vector2.ONE * (pitch - 4))
		var ink: Color = Palette.tile(color) if valid else Palette.INVALID
		Surface.draw(self, face, ink, Surface.depth(pitch))
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color.TRANSPARENT
		outline.border_color = Palette.tile(color).darkened(0.3) if valid else Palette.INVALID_BORDER
		outline.set_border_width_all(1)
		outline.set_corner_radius_all(roundi(face.size.x * 0.16))
		draw_style_box(outline, face.grow(-0.5))
