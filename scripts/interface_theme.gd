extends RefCounted
const Palette = preload("res://scripts/interface_palette.gd")
const FONT = preload("res://assets/shared/fonts/lora_regular.ttf")
const FONT_SIZE := 28
const RADIUS := 8
const BEVEL := 1
const TRAVEL := 2
const SHADOW := 2
static var cache: Dictionary = {}

static func button_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.controls()
	style.set_corner_radius_all(RADIUS)
	style.set_border_width_all(BEVEL)
	var pressed := state in ["pressed", "hover_pressed"]
	style.border_color = Palette.shade() if pressed else Palette.light()
	style.shadow_color = Color(Palette.shadow(), 0.65)
	style.shadow_size = 1 if pressed else SHADOW
	style.shadow_offset = Vector2(0, 1) if pressed else Vector2(0 if Palette.directional_bevel() else 1, SHADOW)
	if Palette.directional_bevel():
		style.border_color = Palette.shade()
		style.border_width_bottom = 1 if pressed else 2
		style.border_width_right = 1 if pressed else 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4 + (TRAVEL if pressed else 0)
	style.content_margin_bottom = 4 - (TRAVEL if pressed else 0)
	if pressed:
		style.expand_margin_top = -TRAVEL
		style.expand_margin_bottom = TRAVEL
	return style

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.controls()
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(12)
	return style

static func build() -> Theme:
	var key: String = Palette.theme_id()
	if cache.has(key): return cache[key]
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = FONT_SIZE
	for type: String in ["Button", "CheckButton", "CheckBox", "OptionButton", "MenuButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			result.set_stylebox(state, type, button_style(state))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			result.set_color(state, type, Palette.text())
		result.set_color("font_disabled_color", type, Palette.muted())
		var focus := StyleBoxFlat.new()
		# Focus must not draw a second outline over the shared bevel.
		# Keep keyboard focus visible as a subtle inset face highlight instead.
		focus.bg_color = Color(Palette.light(), 0.20)
		focus.set_corner_radius_all(RADIUS - 3)
		focus.set_expand_margin_all(-4)
		result.set_stylebox("focus", type, focus)
	for type: String in ["Panel", "PanelContainer", "PopupPanel", "AcceptDialog", "Window"]:
		result.set_stylebox("panel", type, panel_style())
	for type: String in ["Label", "RichTextLabel", "Window", "PopupMenu", "LineEdit"]:
		result.set_color("font_color", type, Palette.text())
	result.set_color("title_color", "Window", Palette.text())
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.shade()
	track.set_corner_radius_all(2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := track.duplicate()
	fill.bg_color = Palette.text()
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(16):
		for x in range(16):
			var distance := Vector2(x - 7.5, y - 7.5).length()
			if distance < 7: image.set_pixel(x, y, Palette.light() if distance > 5.5 else Palette.controls())
	var knob := ImageTexture.create_from_image(image)
	for type: String in ["HSlider", "VSlider"]:
		result.set_stylebox("slider", type, track)
		result.set_stylebox("grabber_area", type, fill)
		result.set_stylebox("grabber_area_highlight", type, fill)
		for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]: result.set_icon(state, type, knob)
	cache[key] = result
	return result

static func press_children(button: Button, down: bool) -> void:
	var offset := TRAVEL if down else 0
	var previous: int = button.get_meta("press_travel", 0)
	for child: Node in button.get_children():
		if child is Control: child.position.y += offset - previous
	button.set_meta("press_travel", offset)

# StyleBoxFlat supplies the lower bevel; this thin overlay lights only top/left.
class BevelHighlight extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		get_parent().button_down.connect(queue_redraw)
		get_parent().button_up.connect(queue_redraw)
	func _draw() -> void:
		if not Palette.directional_bevel(): return
		if get_parent().is_pressed() and get_parent().get_meta("press_travel", 0) == 0:
			draw_set_transform(Vector2(0, TRAVEL))
		var r: float = minf(RADIUS, minf(size.x, size.y) / 2)
		var ink := Palette.light()
		draw_line(Vector2(r, 0.5), Vector2(size.x-r, 0.5), ink, 1, true)
		draw_line(Vector2(0.5, r), Vector2(0.5, size.y-r), ink, 1, true)
		draw_arc(Vector2(r,r), r-0.5, PI, 1.5*PI, 12, ink, 1, true)
		draw_arc(Vector2(size.x-r,r), r-0.5, 1.5*PI, 1.75*PI, 6, ink, 1, true)
		draw_arc(Vector2(r,size.y-r), r-0.5, 0.75*PI, PI, 6, ink, 1, true)

static func sync_highlight(button: Button) -> void:
	var overlay := button.get_node_or_null("BevelHighlight")
	if overlay == null:
		overlay = BevelHighlight.new()
		overlay.name = "BevelHighlight"
		button.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = Palette.directional_bevel()
	overlay.queue_redraw()
