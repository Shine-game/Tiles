extends PanelContainer

# A regular in-game panel, so confirmation uses the same surface and controls
# as Settings rather than the operating system's dialog chrome.
signal confirmed
signal canceled

const BoardFrame = preload("res://scripts/board_frame.gd")
const InterfaceTheme = preload("res://scripts/interface_theme.gd")
const Interface = preload("res://scripts/interface_palette.gd")
const Palette = preload("res://scripts/palette.gd")

var dialog_text := "Start new game"
var ok_button_text := "OK"
var cancel_button_text := "Go back"
var content := VBoxContainer.new()
var prompt := Label.new()
var ok_button := Button.new()
var cancel_button := Button.new()
var frame := BoardFrame.new()

func _init() -> void:
	visible = false
	content.add_theme_constant_override("separation", 9)
	add_child(content)
	var frame_layer := Node2D.new()
	add_child(frame_layer)
	frame.thin_rim = 14.0
	frame_layer.add_child(frame)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for control: Control in [prompt, ok_button, cancel_button]:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(control)
	ok_button.pressed.connect(func():
		hide()
		confirmed.emit())
	cancel_button.pressed.connect(func():
		hide()
		canceled.emit())

func get_ok_button() -> Button:
	return ok_button

func get_cancel_button() -> Button:
	return cancel_button

func open() -> void:
	prompt.text = dialog_text
	ok_button.text = ok_button_text
	cancel_button.text = cancel_button_text
	show()
	# Touch/mouse openings should not arbitrarily highlight one choice.
	# Keyboard users can still focus either option with Tab.

func layout(view: Vector2, pad: float, requested_clearance: float, anchor_bottom: float = -1.0) -> void:
	var width := minf(view.x - 2 * pad, maxf(view.x * 0.70, 360.0))
	var rim := frame.thin_rim if frame.apply_theme(Palette.theme_id()) else 0.0
	var available := view.y - 2 * pad
	var actions := 2 if cancel_button.visible else 1
	var clearance := requested_clearance
	var inner_width := maxf(1.0, width - 2 * (rim + clearance))
	var text_height := InterfaceTheme.FONT.get_multiline_string_size(
		dialog_text, HORIZONTAL_ALIGNMENT_CENTER, inner_width, InterfaceTheme.FONT_SIZE).y
	clearance = clampf((available - 2 * rim - text_height - 46 * actions) / (actions + 2), 0.0, clearance)
	content.add_theme_constant_override("separation", roundi(clearance))
	var panel := InterfaceTheme.panel_style()
	panel.set_border_width_all(1)
	panel.border_color = Color(Interface.shade(), 0.65)
	panel.set_content_margin_all(rim + clearance)
	add_theme_stylebox_override("panel", panel)
	var height := minf(available, 2 * rim + text_height + 56 * actions + clearance * (actions + 2))
	position = Vector2((view.x - width) / 2, (view.y - height) / 2)
	if anchor_bottom >= 0.0:
		position.y = clampf(anchor_bottom + pad, pad, view.y - pad - height)
	size = Vector2(width, height)
	if frame.is_present():
		frame.surround(Rect2(Vector2.ONE * rim, size - 2 * Vector2.ONE * rim))

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		canceled.emit()
		get_viewport().set_input_as_handled()
