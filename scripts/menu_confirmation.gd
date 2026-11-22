extends PanelContainer

# A regular in-game panel, so confirmation uses the same surface and controls
# as Settings rather than the operating system's dialog chrome.
signal confirmed
signal canceled

var dialog_text := "Start new game"
var ok_button_text := "OK"
var cancel_button_text := "Go back"
var content := VBoxContainer.new()
var prompt := Label.new()
var ok_button := Button.new()
var cancel_button := Button.new()

func _init() -> void:
	visible = false
	content.add_theme_constant_override("separation", 9)
	add_child(content)
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

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		canceled.emit()
		get_viewport().set_input_as_handled()
