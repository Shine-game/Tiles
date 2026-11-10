extends Button

const Palette = preload("res://scripts/palette.gd")
# -1 is the compact top-right button; options point to their fixed pair.
var pair_index := -1

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var index: int = Palette.selected_index if pair_index < 0 else pair_index
	var colors: Array = [Palette.tile(1), Palette.tile(2)] if pair_index < 0 and Palette.theme_id() != "vines" else Palette.PAIRS[index].colors
	var radius: float = minf(size.x, size.y) * (0.22 if pair_index < 0 else 0.17)
	var center := size / 2 if pair_index < 0 else Vector2(size.x - radius * 3.4, size.y / 2)
	for i in range(2):
		var point: Vector2 = center + Vector2((i - 0.5) * radius * 1.5, 0)
		draw_circle(point, radius + 0.8, Color(Palette.text(), 0.35), true, -1, true)
		draw_circle(point, radius, colors[i], true, -1, true)
