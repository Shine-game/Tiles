extends RefCounted
const UI = preload("res://scripts/interface_theme.gd")

# Own only the presentation overrides required by a tutorial. Restore is safe to
# call on normal completion, explicit exit, or unexpected removal, exactly once.
var host: Control
var controls: Array = []
var visibility := {}
var menu_controls: Array = []
var board_mode: int
var menu_mode: int
var menu_z: int
var menu_owned := false
var restored := false

func _init(owner: Control) -> void:
	host = owner
	board_mode = host.board_view.process_mode
	menu_mode = host.palette_menu.process_mode
	menu_z = host.palette_menu.z_index
	for button: Button in host._controls():
		var icon: Control = host.button_icon(button)
		controls.append({"node":button,"mode":button.process_mode,"disabled":button.disabled,"visible":button.visible,"text":button.text,"tooltip":button.tooltip_text,"icon":icon,"icon_visible":icon.visible,"kind":icon.get("kind"),"count":icon.get("count")})
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.show()
		button.disabled = true
	for view: Control in [host.piece_view,host.floating_piece]:
		visibility[view] = view.visible
		view.hide()
	# Freeze only the existing artwork, not the application or its menus/audio.
	host.board_view.process_mode = Node.PROCESS_MODE_DISABLED

func allow_theme_menu(z: int) -> void:
	if menu_owned: return
	menu_owned = true
	host.board_view.process_mode = board_mode
	host.palette_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	host.palette_menu.z_index = z
	for button: Control in host.menu_buttons:
		if button is BaseButton:
			menu_controls.append({"node":button,"disabled":button.disabled})
			button.disabled = button not in host.theme_options and button not in [host.settings_options[0],host.menu_close,host.back_button]

func restore() -> void:
	if restored: return
	restored = true
	for record: Dictionary in controls:
		if not is_instance_valid(record.node): continue
		UI.press_children(record.node,false)
		record.node.process_mode = record.mode
		record.node.disabled = record.disabled
		record.node.visible = record.visible
		record.node.text = record.text
		record.node.tooltip_text = record.tooltip
		if is_instance_valid(record.icon):
			record.icon.visible = record.icon_visible
			if record.kind != null: record.icon.kind = record.kind
			if record.count != null: record.icon.count = record.count
	for view: Control in visibility:
		if is_instance_valid(view): view.visible = visibility[view]
	for record: Dictionary in menu_controls:
		if is_instance_valid(record.node): record.node.disabled = record.disabled
	if not is_instance_valid(host): return
	if is_instance_valid(host.board_view): host.board_view.process_mode = board_mode
	if menu_owned and is_instance_valid(host.palette_menu):
		host.palette_menu.process_mode = menu_mode
		host.palette_menu.z_index = menu_z
		host.palette_menu.hide()
		host.menu_history.clear()
