extends Control

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Game = preload("res://scripts/game.gd")
const BoardView = preload("res://scripts/board_view.gd")
const PieceView = preload("res://scripts/piece_view.gd")
const FloatingPiece = preload("res://scripts/floating_piece.gd")
const SymmetryIcon = preload("res://scripts/symmetry_icon.gd")
var game = Game.new()
var cells: Array = []
var has_hover := false
var dragging := false
var pointer_id := -1
var grabbed_cell := Vector2i.ZERO
var last_pointer := Vector2.ZERO
var floating_piece: Control
var scroll: ScrollContainer
var selected := Vector2i(-1, -1)
var board_view: Control
var piece_view: Control
var status: Label
var move_label: Label
var piece_label: Label
var undo_button: Button
var place_button: Button
var rotate_button: Button
var flip_button: Button
var blue_button: Button
var coral_button: Button
var indicators: Array = []
var size_picker: OptionButton
var reset_dialog: ConfirmationDialog
var requested_size := 9

func _ready() -> void:
	_build_interface()
	cells = game.piece().cells
	_refresh()

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _label(text: String, font_size: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("334638"))
	parent.add_child(label)
	return label

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.add_theme_stylebox_override("normal", _style(Color("e5ebdf")))
	button.add_theme_stylebox_override("hover", _style(Color("d7e2d0")))
	button.add_theme_stylebox_override("pressed", _style(Color("c9d9c4")))
	button.add_theme_color_override("font_color", Color("334638"))
	button.add_theme_color_override("font_hover_color", Color("334638"))
	button.add_theme_color_override("font_pressed_color", Color("334638"))
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _build_interface() -> void:
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -80
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Retain vertical scrolling on short screens without taking width from the board.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("tiles  *", 38, header)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("How to play", header, _show_help)
	var subtitle := _label("Let a pattern unfold.", 30, column)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var caption := _label("A piece at a time. No timer, no hurry.", 17, column)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	column.add_child(top)
	var sym_column := VBoxContainer.new()
	sym_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sym_column)
	_label("PATHS TO SYMMETRY", 15, sym_column)
	var summaries := HBoxContainer.new()
	summaries.add_theme_constant_override("separation", 12)
	sym_column.add_child(summaries)
	for i in range(2):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(130, 110)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summaries.add_child(panel)
		var content := VBoxContainer.new()
		panel.add_child(content)
		var icon = SymmetryIcon.new()
		icon.rotational = i == 1
		icon.custom_minimum_size = Vector2(80, 72)
		content.add_child(icon)
		var label := _label("Reflections" if i == 0 else "Rotation", 14, content)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicators.append({"panel": panel, "icon": icon, "label": label})
	_label("Lit lines show remaining possibilities", 13, sym_column)
	var next_column := VBoxContainer.new()
	next_column.custom_minimum_size.x = 170
	top.add_child(next_column)
	_label("YOUR NEXT PIECE", 15, next_column)
	piece_view = PieceView.new()
	piece_view.custom_minimum_size = Vector2(145, 100)
	next_column.add_child(piece_view)
	piece_label = _label("", 16, next_column)
	piece_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	column.add_child(tools)
	rotate_button = _button("Rotate [R]", tools, _rotate)
	flip_button = _button("Flip [F]", tools, _flip)
	blue_button = _button("Blue", tools, func(): _choose_color(Rules.BLUE))
	coral_button = _button("Coral", tools, func(): _choose_color(Rules.CORAL))
	for button: Button in [rotate_button, flip_button, blue_button, coral_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Change the unplaced piece; you can change it again at any time."
	blue_button.toggle_mode = true
	coral_button.toggle_mode = true
	move_label = _label("", 15, column)
	board_view = BoardView.new()
	board_view.custom_minimum_size.y = 600
	column.add_child(board_view)
	column.resized.connect(func(): board_view.custom_minimum_size.y = column.size.x)
	status = _label("", 17, column)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 48
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var dock := PanelContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -80
	dock.z_index = 50
	dock.add_theme_stylebox_override("panel", _style(Color("f6f5ef")))
	add_child(dock)
	dock.add_child(actions)
	place_button = _button("Place piece", actions, _place)
	place_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button = _button("Back", actions, _undo)
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 14)
	column.add_child(settings)
	_label("Garden size", 16, settings)
	size_picker = OptionButton.new()
	size_picker.add_item("9 x 9", 9)
	size_picker.add_item("11 x 11", 11)
	size_picker.custom_minimum_size = Vector2(100, 50)
	settings.add_child(size_picker)
	size_picker.item_selected.connect(func(index: int): _ask_reset(size_picker.get_item_id(index)))
	_button("New pattern", settings, func(): _ask_reset(game.board.size()))
	var legend := _label("11 shapes · Choose either color · Gray warns of invalid placement", 15, column)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "A new garden?"
	reset_dialog.dialog_text = "This will replace your current pattern."
	reset_dialog.confirmed.connect(_reset)
	reset_dialog.canceled.connect(func(): size_picker.select(0 if game.board.size() == 9 else 1))
	add_child(reset_dialog)
	floating_piece = FloatingPiece.new()
	floating_piece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floating_piece)
	# Inset the surrounding controls, while the square board spans the viewport.
	for child: Control in column.get_children():
		if child == board_view:
			continue
		var position_in_column := child.get_index()
		column.remove_child(child)
		var inset := MarginContainer.new()
		inset.add_theme_constant_override("margin_left", 24)
		inset.add_theme_constant_override("margin_right", 24)
		inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(inset)
		column.move_child(inset, position_in_column)
		inset.add_child(child)


func _refresh() -> void:
	board_view.board = game.board
	piece_view.cells = [] if game.over else cells
	piece_view.color = game.piece().color
	piece_view.queue_redraw()
	piece_label.text = "Pattern ended" if game.lost else "Garden complete" if game.no_space else "%s · %s" % [game.queue[game.index], "Blue" if game.piece().color == Rules.BLUE else "Coral"]
	undo_button.text = "Back  (%d / 3)" % game.history.size()
	undo_button.disabled = game.history.is_empty()
	rotate_button.disabled = game.over
	flip_button.disabled = game.over
	blue_button.disabled = game.over
	coral_button.disabled = game.over
	for button: Button in [blue_button, coral_button]:
		var chosen: bool = (button == blue_button) == (game.current_color == Rules.BLUE)
		button.set_pressed_no_signal(chosen)
		var ink := Palette.BLUE if button == blue_button else Palette.CORAL
		var style := _style(ink)
		style.set_border_width_all(3 if chosen else 0)
		style.border_color = Color("243446")
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, Color.WHITE)
	move_label.text = "YOUR GARDEN  %d x %d     ·     %d pieces placed" % [game.board.size(), game.board.size(), game.moves]
	_preview()

func _update_summaries(board: Array) -> void:
	var states: Array = Rules.symmetry_states(board)
	for i in range(2):
		var available: Array = []
		var details: Array = []
		for symmetry in (range(4) if i == 0 else range(4, 7)):
			available.append(states[symmetry].possible)
			details.append(Rules.SYMMETRY_NAMES[symmetry] + (": possible" if states[symmetry].possible else ": unavailable"))
		var lit: bool = available.any(func(value): return value)
		var indicator: Dictionary = indicators[i]
		indicator.icon.available = available
		indicator.icon.queue_redraw()
		indicator.panel.add_theme_stylebox_override("panel", _style(Color("e2edda") if lit else Color("e5e4dc")))
		indicator.panel.tooltip_text = "\n".join(details)

func _preview() -> void:
	board_view.queue_redraw()
	floating_piece.cells = cells if has_hover and not game.over else []
	floating_piece.color = game.current_color
	var physical := false
	var legal := false
	var proposed: Array = game.board
	if has_hover and not game.over:
		physical = Rules.physical_placement(game.board, cells, selected).ok
		legal = Rules.placement(game.board, cells, game.current_color, selected).ok
		if physical:
			proposed = game.board.duplicate(true)
			for cell: Vector2i in cells:
				proposed[selected.y + cell.y][selected.x + cell.x] = game.current_color
	floating_piece.valid = legal
	place_button.disabled = not physical or game.over
	_update_summaries(proposed)
	if game.lost:
		status.text = "The last path to symmetry is closed. Go back, or begin again."
	elif game.no_space:
		status.text = "Your garden is full. Enjoy your completed pattern, or go back."
	elif has_hover:
		status.text = ("Ready. Press Place to set this piece." if legal else "This placement ends symmetry. Place to finish, or keep exploring.") if physical else "This position cannot be placed. Drag the piece to another spot."
	else:
		status.text = "Drag any square of the piece onto the field, then release to inspect."
	_update_floating_position()

func _update_floating_position() -> void:
	floating_piece.pitch = board_view.pitch
	floating_piece.origin = board_view.get_global_transform_with_canvas() * (board_view.field.position + Vector2(8, 8) + Vector2(selected) * board_view.pitch)
	floating_piece.queue_redraw()

func _drag_to(point: Vector2) -> void:
	last_pointer = point
	var local: Vector2 = board_view.get_global_transform_with_canvas().affine_inverse() * point
	var relative: Vector2 = (local - board_view.field.position - Vector2(8, 8)) / board_view.pitch
	selected = Vector2i(floori(relative.x), floori(relative.y)) - grabbed_cell
	has_hover = true
	_preview()

func _start_drag(point: Vector2, id: int) -> bool:
	if game.over or dragging or reset_dialog.visible or point.y >= get_viewport_rect().size.y - 80:
		return false
	var hit := Vector2i(-1, -1)
	if has_hover:
		hit = floating_piece.cell_at(point)
	if hit.x < 0:
		hit = piece_view.cell_at(piece_view.get_global_transform_with_canvas().affine_inverse() * point)
	if hit.x < 0:
		return false
	grabbed_cell = hit
	pointer_id = id
	dragging = true
	_drag_to(point)
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _start_drag(event.position, event.index):
				get_viewport().set_input_as_handled()
		elif dragging and event.index == pointer_id:
			_drag_to(event.position)
			dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and dragging and event.index == pointer_id:
		_drag_to(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _start_drag(event.position, -1):
				get_viewport().set_input_as_handled()
		elif dragging and pointer_id == -1:
			_drag_to(event.position)
			dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging and pointer_id == -1:
		_drag_to(event.position)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if dragging:
		var height: float = get_viewport_rect().size.y - 80
		var direction := -1.0 if last_pointer.y < 64 else (1.0 if last_pointer.y > height - 64 else 0.0)
		if direction != 0:
			scroll.scroll_vertical += roundi(direction * 500 * delta)
			_drag_to(last_pointer)
	if has_hover:
		_update_floating_position()

func _place() -> void:
	if not has_hover:
		return
	var result: Dictionary = game.place(cells, selected)
	if not result.ok:
		status.text = result.reason
		return
	cells = [] if game.over else game.piece().cells
	_clear_selection()
	_refresh()

func _clear_selection() -> void:
	has_hover = false
	dragging = false
	selected = Vector2i(-1, -1)

func _rotate() -> void:
	if not game.over:
		cells = Rules.rotate(cells)
		_refresh()

func _flip() -> void:
	if not game.over:
		cells = Rules.flip(cells)
		_refresh()

func _choose_color(color: int) -> void:
	if not game.over:
		game.current_color = color
		_refresh()

func _undo() -> void:
	if game.undo():
		cells = game.restored_cells
		_clear_selection()
		_refresh()

func _ask_reset(n: int) -> void:
	requested_size = n
	reset_dialog.popup_centered(Vector2i(420, 180))

func _reset() -> void:
	game = Game.new(requested_size)
	cells = game.piece().cells
	size_picker.select(0 if requested_size == 9 else 1)
	_clear_selection()
	_refresh()

func _show_help() -> void:
	var help := AcceptDialog.new()
	help.title = "A little space for balance"
	help.dialog_text = "Drag any square of the piece from the upper right onto the field.\nRelease to leave it hovering; drag any of its squares again to adjust.\nPlace at bottom left commits it when it physically fits and touches the pattern.\nA gray piece warns of an invalid position; placing a symmetry conflict ends play.\nRotate with R, or mirror horizontally with F.\nChoose Blue or Coral freely before placing any piece.\nGray previews indicate invalid positions.\nGo back up to three placements, including color and orientation.\n\nA lit symmetry is still possible, even when it is not complete.\nEmpty partners can be filled later; different colors cannot match.\nAll reflections and rotations use the board's center.\n\nAll four sizes are equally likely while they fit.\nPieces with no physical fit are excluded from the draw.\nPlay ends after you place a piece that breaks the last symmetry, or fill the garden.\nThere is no timer. Enjoy finding your pattern."
	add_child(help)
	help.confirmed.connect(help.queue_free)
	help.canceled.connect(help.queue_free)
	help.popup_centered()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: _rotate()
			KEY_F: _flip()
			KEY_C: _choose_color(Rules.CORAL if game.current_color == Rules.BLUE else Rules.BLUE)
			_: return
		get_viewport().set_input_as_handled()
