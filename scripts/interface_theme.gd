extends RefCounted
const Palette = preload("res://scripts/interface_palette.gd")
const RADIUS := 8
const BEVEL := 1
const TRAVEL := 2
const SHADOW := 2
static var cache: Dictionary = {}

static func button_style(state: String, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.controls()
	style.set_corner_radius_all(RADIUS)
	style.set_border_width_all(2 if selected else BEVEL)
	var pressed := state in ["pressed", "hover_pressed"]
	style.border_color = Palette.shade() if pressed else Palette.light()
	style.shadow_color = Color(Palette.shade(), 0.8)
	style.shadow_size = 1 if pressed else SHADOW
	style.shadow_offset = Vector2(0, 1) if pressed else Vector2(1, SHADOW)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4 + (TRAVEL if pressed else 0)
	style.content_margin_bottom = 4 - (TRAVEL if pressed else 0)
	if pressed:
		style.expand_margin_top = -TRAVEL
		style.expand_margin_bottom = TRAVEL
	if state == "disabled": style.shadow_color.a = 0.25
	return style

static func panel_style() -> StyleBoxFlat:
	var style := button_style("normal")
	style.bg_color = Palette.panel_background()
	style.set_content_margin_all(12)
	return style

static func build() -> Theme:
	var key: String = Palette.theme_id()
	if cache.has(key): return cache[key]
	var result := Theme.new()
	for type: String in ["Button", "CheckButton", "CheckBox", "OptionButton", "MenuButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			result.set_stylebox(state, type, button_style(state))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			result.set_color(state, type, Palette.text())
		result.set_color("font_disabled_color", type, Palette.muted())
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.set_corner_radius_all(RADIUS)
		focus.set_border_width_all(2)
		focus.border_color = Palette.text()
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
