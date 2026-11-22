extends Control

const Axes = preload("res://scripts/field_axes.gd")
const Palette = preload("res://scripts/interface_palette.gd")
var rotational := false
var combined := false
var available: Array = [true, true, true, true]
var complete: Array = [false, false, false, false]
var saved := false
var camera_size := 16

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _disabled_authored_ink() -> bool:
	return Palette.directional_bevel() and get_parent() is Button and get_parent().disabled

func _ink(index: int) -> Color:
	return Axes.appearance(available[index],complete[index]).color

func _draw() -> void:
	var center := size/2
	var radius := minf(size.x,size.y)*0.34
	if not rotational:
		var directions := [Vector2.DOWN,Vector2.RIGHT,Vector2(1,-1).normalized(),Vector2(1,1).normalized()]
		for i in range(4):
			var style := Axes.appearance(available[i],complete[i])
			if not style.visible: continue
			var offset: Vector2 = directions[i]*radius*(1.0 if combined else (1.414 if i >= 2 else 1.1))
			draw_line(center-offset,center+offset,style.color,style.width,true)
	if combined or rotational:
		var indices: Array = [4,5,6] if combined else range(available.size())
		var possible := false
		var present := false
		for i: int in indices:
			possible = possible or available[i]
			present = present or complete[i]
		var style := Axes.appearance(possible,present)
		if style.visible:
			var arc_radius := radius*0.72 if combined else radius
			draw_arc(center,arc_radius,-PI/2,TAU-PI/2-0.3,48,style.color,style.width,true)
			var tip := center+Vector2(0,-arc_radius)
			draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-radius*0.25,-radius*0.16),tip+Vector2(-radius*0.25,radius*0.16)]),style.color)
	if saved:
		var ink := Palette.muted() if _disabled_authored_ink() else Palette.text()
		draw_set_transform(size * Vector2(0.75, 0.8), 0.0, Vector2.ONE * camera_size)
		draw_polyline(PackedVector2Array([
			Vector2(-0.44, -0.23), Vector2(-0.20, -0.23), Vector2(-0.12, -0.36),
			Vector2(0.15, -0.36), Vector2(0.23, -0.23), Vector2(0.44, -0.23),
			Vector2(0.44, 0.32), Vector2(-0.44, 0.32), Vector2(-0.44, -0.23),
		]), ink, 0.08, true)
		draw_arc(Vector2(0, 0.045), 0.16, 0, TAU, 20, ink, 0.08, true)
		draw_set_transform(Vector2.ZERO)
