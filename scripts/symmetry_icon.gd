extends Control

const Palette = preload("res://scripts/interface_palette.gd")
var rotational := false
var combined := false
var available: Array = [true, true, true, true]
var complete: Array = [false, false, false, false]
var saved := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _disabled_authored_ink() -> bool:
	return Palette.directional_bevel() and get_parent() is Button and get_parent().disabled

func _ink(index: int) -> Color:
	if _disabled_authored_ink(): return Palette.muted()
	return Palette.accent(1) if complete[index] else (Color(Palette.text(), 0.42) if available[index] else Color(Palette.muted(), 0.18))

func _draw() -> void:
	var center := size / 2
	var radius: float = minf(size.x, size.y) * 0.34
	if combined:
		var directions := [Vector2.DOWN, Vector2.RIGHT, Vector2(1, -1).normalized(), Vector2(1, 1).normalized()]
		for i in range(4):
			var offset: Vector2 = directions[i] * radius
			draw_line(center - offset, center + offset, _ink(i), 3 if complete[i] else 1.5, true)
		var lit := false
		var possible := false
		for i in range(4, 7):
			lit = lit or complete[i]
			possible = possible or available[i]
		var ink := Palette.accent(1) if lit else Color(Palette.text(), 0.42 if possible else 0.18)
		if _disabled_authored_ink(): ink = Palette.muted()
		draw_arc(center, radius * 0.72, -PI / 2, TAU - PI / 2 - 0.3, 48, ink, 3 if lit else 1.5, true)
		var tip := center + Vector2(0, -radius * 0.72)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-radius * 0.25, -radius * 0.16), tip + Vector2(-radius * 0.25, radius * 0.16)]), ink)
	elif rotational:
		var lit: bool = complete.any(func(value): return value)
		var ink: Color = Palette.accent(1) if lit else (Color(Palette.text(), 0.42) if available.any(func(value): return value) else Color(Palette.muted(), 0.18))
		if _disabled_authored_ink(): ink = Palette.muted()
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
		draw_polyline(PackedVector2Array([point + Vector2(-5, 0), point + Vector2(-1, 4), point + Vector2(7, -5)]), (Palette.muted() if _disabled_authored_ink() else Palette.text()), 2, true)
