extends Control

var rotational := false
var available: Array = [true, true, true, true]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size / 2
	var radius: float = minf(size.x, size.y) * 0.36
	var active := Color("168bff")
	var inactive := Color("b9bcb7")
	if rotational:
		var ink: Color = active if available.any(func(value): return value) else inactive
		draw_arc(center, radius, -PI / 2, PI, 40, ink, 4, true)
		var tip := center + Vector2(0, -radius)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -7), tip + Vector2(-12, 7)]), ink)
	else:
		draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), Color("d3d9ce"), false, 1)
		var directions := [Vector2(0, 1), Vector2(1, 0), Vector2(1, -1).normalized(), Vector2(1, 1).normalized()]
		# Paint inactive axes first, so remaining axes stay clear at intersections.
		for enabled in [false, true]:
			for i in range(4):
				if available[i] == enabled:
					var offset: Vector2 = directions[i] * radius * (1.414 if i >= 2 else 1.1)
					draw_line(center - offset, center + offset, active if enabled else inactive, 4 if enabled else 2, true)
