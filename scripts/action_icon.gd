extends Control

const Palette = preload("res://scripts/interface_palette.gd")
const BUTTON_ART := {
	"erase": preload("res://assets/shared/ui/button_erase.png"),
	"flip": preload("res://assets/shared/ui/button_flip.png"),
	"place": preload("res://assets/shared/ui/button_place.png"),
	"replay": preload("res://assets/shared/ui/button_replay.png"),
	"settings": preload("res://assets/shared/ui/button_settings.png"),
	"skip": preload("res://assets/shared/ui/button_skip.png"),
	"undo": preload("res://assets/shared/ui/button_undo.png"),
}
var color := 1
var kind := ""
var count := -1:
	set(value):
		if count == value:
			return
		count = value
		queue_redraw()

static func badge_size(button_width: float) -> int:
	return clampi(roundi(button_width * 0.25), 12, 22) + 4

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var ink := Palette.text()
	if get_parent() is Button and get_parent().disabled:
		ink = Palette.muted()
	var artwork: Texture2D = BUTTON_ART.get(kind)
	if artwork != null:
		var side := minf(size.x, size.y) * 0.74
		draw_texture_rect(artwork, Rect2((size - Vector2.ONE * side) / 2.0, Vector2.ONE * side), false, ink)
	elif kind == "close":
		var center := size / 2.0
		var span := minf(size.x, size.y) * 0.208
		var stroke := minf(size.x, size.y) * 0.058
		draw_line(center - Vector2.ONE * span, center + Vector2.ONE * span, ink, stroke, true)
		draw_line(center - Vector2(span, -span), center + Vector2(span, -span), ink, stroke, true)
	if count >= 0:
		var font := get_theme_default_font()
		var font_size := badge_size(size.x)
		var center := Vector2(size.x * 0.82,size.y * 0.19)
		var text := str(count)
		var extent := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		draw_string(font,center+Vector2(-extent.x*0.5,font_size*0.35),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
