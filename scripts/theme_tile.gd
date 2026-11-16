extends Control

const Brush = preload("res://scripts/botanical_brush.gd")
const Maze = preload("res://scripts/labyrinth_renderer.gd")
var theme_id := "vines"
var pitch := 1.0
var core: Texture2D
var core_region := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var path: String = {
		"clockwork": "res://art/themes/clockwork_workshop/artwork/copper/C01.png",
		"coral_reef": "res://art/themes/coral_reef/artwork/salmon/core.png",
	}.get(theme_id, "")
	if not path.is_empty():
		core = load(path)
		core_region = Rect2(core.get_image().get_used_rect())

func _draw() -> void:
	pitch = minf(size.x, size.y)
	var rect := Rect2((size - Vector2.ONE * pitch) / 2, Vector2.ONE * pitch)
	draw_style_box(_ground(), rect)
	if theme_id == "zen_garden":
		draw_texture_rect(ZenVisuals.SAND, rect, false)
		# The centered decoration is unfinished: show the theme's sand tile.
	elif core != null:
		draw_texture_rect_region(core, rect.grow(-pitch * 0.12), core_region)
	elif theme_id == "labyrinth":
		Maze._pyramid(self, size / 2 + Vector2(0, pitch * 0.1), 1, 1.7)
	else:
		var ink: Color = preload("res://scripts/palette.gd").PAIRS[0].colors[0]
		for i in range(4):
			draw_set_transform(size / 2, i * PI / 2)
			draw_texture_rect(Brush.leaf(), Rect2(0, -pitch * 0.12, pitch * 0.44, pitch * 0.24), false, ink)
		draw_set_transform(Vector2.ZERO)

func _ground() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = {"zen_garden": Color("f0ece3"), "clockwork": Color("a3a29a"), "coral_reef": Color("edd7ad"), "labyrinth": Color("efe1c3")}.get(theme_id, Color("fff5fb"))
	style.set_corner_radius_all(4)
	return style
