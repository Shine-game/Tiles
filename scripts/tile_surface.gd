class_name TileSurface
extends RefCounted

static func depth(unit: float) -> float:
	return clampf(unit * 0.065, 1.5, 5.0)

# A shallow colored slab for the incoming/hovering piece. Its logical face
# keeps the original footprint; thickness and shadow never change placement.
static func draw(canvas: CanvasItem, face: Rect2, color: Color, thickness: float) -> void:
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.10)
	shadow.set_corner_radius_all(5)
	shadow.shadow_color = Color(0, 0, 0, 0.13)
	shadow.shadow_size = roundi(thickness)
	shadow.shadow_offset = Vector2(thickness * 0.25, thickness * 0.7)
	canvas.draw_style_box(shadow, Rect2(face.position + Vector2(0, thickness), face.size))
	var side := StyleBoxFlat.new()
	side.bg_color = color.darkened(0.25)
	side.set_corner_radius_all(4)
	canvas.draw_style_box(side, Rect2(face.position + Vector2(0, thickness), face.size))
	var top := StyleBoxFlat.new()
	top.bg_color = color
	top.set_corner_radius_all(4)
	canvas.draw_style_box(top, face)
	var highlight := Rect2(face.position + Vector2(2, 1), Vector2(maxf(0, face.size.x - 4), 0))
	canvas.draw_line(highlight.position, highlight.end, Color(1, 1, 1, 0.30), 1, true)
