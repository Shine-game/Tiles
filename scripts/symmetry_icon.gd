extends Control

var symmetry := 0
var active := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size / 2
	var ink := Color("45654b") if active else Color("96978c")
	var rect := Rect2(center - Vector2(12, 12), Vector2(24, 24))
	draw_rect(rect, Color(ink, 0.25), false, 1)
	match symmetry:
		0: draw_line(center - Vector2(0, 14), center + Vector2(0, 14), ink, 2)
		1: draw_line(center - Vector2(14, 0), center + Vector2(14, 0), ink, 2)
		2: draw_line(center + Vector2(-12, 12), center + Vector2(12, -12), ink, 2)
		3: draw_line(center - Vector2(12, 12), center + Vector2(12, 12), ink, 2)
		_:
			draw_arc(center, 10, -PI / 2, PI, 24, ink, 2, true)
			draw_line(center + Vector2(0, -10), center + Vector2(-5, -14), ink, 2)
			draw_line(center + Vector2(0, -10), center + Vector2(-5, -6), ink, 2)
