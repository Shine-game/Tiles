class_name BoardFrame
extends NinePatchRect

const Themes = preload("res://scripts/pattern/theme_registry.gd")
var full_frame: Texture2D
var full_frame_rect := Rect2()
var source_rect := Rect2()
var theme_id := ""
var appearance := ""

static func profile(theme: String) -> Dictionary:
	return Themes.profile(theme).get("frame", {"enabled": false, "texture": "", "appearance": ""})

static func margins() -> Vector4:
	var geometry: Dictionary = Themes.specification().frame_geometry
	var rim: float = geometry.rim
	return Vector4(rim, rim, rim, rim + float(geometry.sidewall))

static func fit(available: Rect2, theme: String = "") -> Rect2:
	var style := profile(theme) if not theme.is_empty() else {}
	if style.has("opening_rect"):
		var src: Array = style.source_rect
		var hole: Array = style.opening_rect
		var ratio := minf(available.size.x/float(src[2]),available.size.y/float(src[3]))
		var origin: Vector2 = available.position+(available.size-Vector2(src[2],src[3])*ratio)*0.5
		return Rect2(origin+Vector2(hole[0]-src[0],hole[1]-src[1])*ratio,Vector2(hole[2],hole[3])*ratio)
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
	full_frame = null
	queue_redraw()
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
	if texture != null and style.has("opening_rect"):
		full_frame = texture
		texture = null
		var src: Array = style.source_rect
		source_rect = Rect2(src[0],src[1],src[2],src[3])
	if texture != null and texture.get_size() != Vector2(Themes.specification().frame_geometry.source_size[0], Themes.specification().frame_geometry.source_size[1]):
		texture = null
	visible = texture != null or full_frame != null
	if visible:
		appearance = style.appearance
	return is_present()

func is_present() -> bool:
	return visible and (texture != null or full_frame != null)

func _draw() -> void:
	if full_frame != null: draw_texture_rect_region(full_frame,full_frame_rect,source_rect)

func surround(board_rect: Rect2) -> void:
	if full_frame != null:
		var hole: Array = profile(theme_id).opening_rect
		var ratio := board_rect.size/Vector2(hole[2],hole[3])
		position = board_rect.position
		size = board_rect.size
		full_frame_rect = Rect2((source_rect.position-Vector2(hole[0],hole[1]))*ratio,source_rect.size*ratio)
		queue_redraw()
		return
	var m := margins()
	position = board_rect.position - Vector2(m.x, m.y)
	size = board_rect.size + Vector2(m.x + m.z, m.y + m.w)
