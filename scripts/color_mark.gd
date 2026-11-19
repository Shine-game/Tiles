extends Control

const Palette = preload("res://scripts/palette.gd")
const Interface = preload("res://scripts/interface_palette.gd")
var color := 1
var paired := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.27
	if paired:
		var offset := Vector2(radius * 0.36, radius * 0.36)
		draw_circle(size / 2 + offset, radius, Palette.tile(2 if color == 1 else 1), true, -1, true)
		draw_circle(size / 2 - offset, radius + 1, Color(Interface.text(), 0.25), true, -1, true)
		draw_circle(size / 2 - offset, radius, Palette.tile(color), true, -1, true)
		return
	draw_circle(size / 2, radius + 1, Color(Interface.text(), 0.25), true, -1, true)
	draw_circle(size / 2, radius, Palette.tile(color), true, -1, true)
