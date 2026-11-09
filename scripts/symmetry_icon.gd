extends Control

const Palette = preload("res://scripts/palette.gd")
var rotational := false
var available: Array = [true, true, true, true]
var complete: Array = [false, false, false, false]
var saved := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _ink(index: int) -> Color:
	return Palette.tile(1) if complete[index] else (Color(Palette.text(), 0.42) if available[index] else Color(Palette.muted(), 0.18))

func _draw() -> void:
	var center := size / 2
	var radius: float = minf(size.x, size.y) * 0.34
	if rotational:
		var lit: bool = complete.any(func(value): return value)
		var ink: Color = Palette.tile(1) if lit else (Color(Palette.text(), 0.42) if available.any(func(value): return value) else Color(Palette.muted(), 0.18))
		draw_arc(center, radius, -PI / 2, PI, 40, ink, 3 if lit else 2, true)
		var tip := center + Vector2(0, -radius)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-radius * 0.4, -radius * 0.25), tip + Vector2(-radius * 0.4, radius * 0.25)]), ink)
	else:
		var directions := [Vector2(0, 1), Vector2(1, 0), Vector2(1, -1).normalized(), Vector2(1, 1).normalized()]
		for enabled in [false, true]:
			for i in range(4):
				if bool(complete[i]) == enabled:
					var offset: Vector2 = directions[i] * radius * (1.414 if i >= 2 else 1.1)
					draw_line(center - offset, center + offset, _ink(i), 3 if enabled else 1.5, true)
	if saved:
		var point := size * Vector2(0.75, 0.8)
		draw_polyline(PackedVector2Array([point + Vector2(-5, 0), point + Vector2(-1, 4), point + Vector2(7, -5)]), Palette.text(), 2, true)
