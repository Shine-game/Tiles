class_name BoardFrame
extends NinePatchRect

const SETTINGS := "res://assets/frames/frames.json"
static var settings: Dictionary = {}
var theme_id := ""
var appearance := ""

static func specification() -> Dictionary:
	if settings.is_empty():
		settings = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	return settings

static func profile(theme: String) -> Dictionary:
	return specification().themes.get(theme, {"enabled": false, "texture": "", "appearance": ""})

static func margins() -> Vector4:
	var geometry: Dictionary = specification().geometry
	var rim: float = geometry.rim
	return Vector4(rim, rim, rim, rim + float(geometry.sidewall))

static func fit(available: Rect2) -> Rect2:
	var m := margins()
	var side: float = maxf(1.0, minf(available.size.x - m.x - m.z, available.size.y - m.y - m.w))
	var total := Vector2(side + m.x + m.z, side + m.y + m.w)
	var origin: Vector2 = available.position + (available.size - total) * 0.5
	return Rect2(origin + Vector2(m.x, m.y), Vector2.ONE * side)

func _init() -> void:
	name = "BoardFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	draw_center = false
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	var m := margins()
	patch_margin_left = int(m.x)
	patch_margin_top = int(m.y)
	patch_margin_right = int(m.z)
	patch_margin_bottom = int(m.w)
	z_index = 10
	visible = false

# An explicit texture also permits isolated renderer/layout checks without
# requiring production artwork or changing the shared theme profiles.
func apply_theme(theme: String, artwork: Texture2D = null) -> bool:
	if theme_id == theme and artwork == null:
		return is_present()
	theme_id = theme
	texture = null
	appearance = ""
	var style := profile(theme)
	if not style.enabled:
		hide()
		return false
	var path: String = style.texture
	if artwork != null:
		texture = artwork
	elif not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		texture = load(path)
	if texture != null and texture.get_size() != Vector2(specification().geometry.source_size[0], specification().geometry.source_size[1]):
		texture = null
	visible = texture != null
	if visible:
		appearance = style.appearance
	return is_present()

func is_present() -> bool:
	return visible and texture != null

func surround(board_rect: Rect2) -> void:
	var m := margins()
	position = board_rect.position - Vector2(m.x, m.y)
	size = board_rect.size + Vector2(m.x + m.z, m.y + m.w)
