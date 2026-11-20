extends Control

const Palette = preload("res://scripts/interface_palette.gd")
var color := 1
var kind := ""
var count := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var ink := Palette.text()
	if get_parent() is Button and get_parent().disabled:
		ink = Palette.muted()
	var unit := minf(size.x, size.y) * 0.32
	draw_set_transform(size * 0.5, 0, Vector2.ONE * unit)
	match kind:
		"erase":
			draw_polyline(PackedVector2Array([Vector2(-0.58,-0.4),Vector2(-0.46,0.8),Vector2(0.46,0.8),Vector2(0.58,-0.4)]), ink, 0.13, true)
			draw_line(Vector2(-0.78,-0.55),Vector2(0.78,-0.55),ink,0.13,true)
			draw_arc(Vector2(0,-0.62),0.3,PI,TAU,16,ink,0.13,true)
			for x in [-0.22,0.22]: draw_line(Vector2(x,-0.25),Vector2(x,0.55),ink,0.1,true)
		"undo":
			draw_polyline(PackedVector2Array([Vector2(-0.7,-0.4),Vector2(0.25,-0.4),Vector2(0.65,-0.1),Vector2(0.65,0.35),Vector2(0.3,0.6),Vector2(-0.2,0.6)]),ink,0.18,true)
			draw_polyline(PackedVector2Array([Vector2(-0.2,-0.85),Vector2(-0.75,-0.4),Vector2(-0.2,0.05)]),ink,0.18,true)
		"close":
			draw_line(Vector2(-0.65,-0.65),Vector2(0.65,0.65),ink,0.18,true)
			draw_line(Vector2(0.65,-0.65),Vector2(-0.65,0.65),ink,0.18,true)
		"replay":
			draw_arc(Vector2.ZERO,0.78,-PI*0.6,PI*1.1,36,ink,0.16,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-0.74,-0.32),Vector2(-0.96,0.12),Vector2(-0.42,-0.02)]),ink)
		"skip":
			draw_line(Vector2(-0.8,0),Vector2(0.65,0),ink,0.2,true)
			draw_polyline(PackedVector2Array([Vector2(0.1,-0.6),Vector2(0.7,0),Vector2(0.1,0.6)]),ink,0.2,true)
		"settings":
			for i in range(3):
				var y := (i-1)*0.6
				draw_line(Vector2(-0.85,y),Vector2(0.85,y),ink,0.13,true)
				draw_circle(Vector2(-0.4 if i%2==0 else 0.4,y),0.22,ink,true,-1,true)
		"flip":
			draw_polyline(PackedVector2Array([Vector2(-0.22,-0.8),Vector2(-0.85,0.65),Vector2(-0.22,0.65),Vector2(-0.22,-0.8)]),ink,0.15,true)
			draw_colored_polygon(PackedVector2Array([Vector2(0.22,-0.8),Vector2(0.85,0.65),Vector2(0.22,0.65)]),ink)
		"place":
			# A pointing hand, matching the placement action in the mockup.
			draw_colored_polygon(PackedVector2Array([Vector2(-0.45,0.8),Vector2(-0.85,0.1),Vector2(-0.67,-0.08),Vector2(-0.3,0.2),Vector2(-0.3,-0.8),Vector2(-0.05,-0.9),Vector2(0.13,-0.8),Vector2(0.13,-0.12),Vector2(0.7,0.02),Vector2(0.8,0.35),Vector2(0.5,0.8)]),ink)
	draw_set_transform(Vector2.ZERO)
	if count >= 0:
		var font := get_theme_default_font()
		var font_size := clampi(roundi(size.x * 0.25),12,22)
		var center := Vector2(size.x * 0.82,size.y * 0.19)
		var text := str(count)
		var extent := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		draw_string(font,center+Vector2(-extent.x*0.5,font_size*0.35),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
