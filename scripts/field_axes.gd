extends Control

const Palette = preload("res://scripts/palette.gd")
var pitch := 64.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	resized.connect(queue_redraw)

func configure(bounds: Rect2, cell_pitch: float) -> void:
	position = bounds.position
	size = bounds.size
	pitch = cell_pitch
	queue_redraw()

func axes() -> Array:
	var center := size / 2
	return [
		[Vector2(center.x, 0), Vector2(center.x, size.y)],
		[Vector2(0, center.y), Vector2(size.x, center.y)],
		[Vector2.ZERO, size],
		[Vector2(0, size.y), Vector2(size.x, 0)],
	]

func _draw() -> void:
	var dash: float = clampf(pitch * 0.16, 6, 14)
	# The light casing and dark center remain readable over every tile material.
	for axis: Array in axes():
		var start: Vector2 = axis[0]
		var finish: Vector2 = axis[1]
		var direction := (finish - start).normalized()
		var distance := start.distance_to(finish)
		var offset := 0.0
		while offset < distance:
			var a := start + direction * offset
			var b := start + direction * minf(distance, offset + dash)
			draw_line(a, b, Color(1, 1, 1, 0.82), 4, true)
			draw_line(a, b, Color(Palette.text(), 0.85), 1.5, true)
			offset += dash * 1.6
