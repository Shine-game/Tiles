extends Control

const Palette = preload("res://scripts/palette.gd")
var color := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.27
	draw_circle(size / 2, radius + 1, Color(Palette.text(), 0.25), true, -1, true)
	draw_circle(size / 2, radius, Palette.tile(color), true, -1, true)
