extends Control

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Game = preload("res://scripts/game.gd")
const BoardView = preload("res://scripts/board_view.gd")
const PieceView = preload("res://scripts/piece_view.gd")
const SymmetryIcon = preload("res://scripts/symmetry_icon.gd")
var game = Game.new()
var cells: Array = []
var anchor := Vector2i(-1, -1)
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
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sym_column.add_child(grid)
	for i in range(7):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(72, 72)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(panel)
		var content := VBoxContainer.new()
		panel.add_child(content)
		var icon = SymmetryIcon.new()
		icon.symmetry = i
		icon.custom_minimum_size = Vector2(32, 32)
		content.add_child(icon)
		var names := ["Vertical", "Horizontal", "Diag. /", "Diag. \\", "90°", "180°", "270°"]
		var label := _label(names[i], 12, content)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.tooltip_text = Rules.SYMMETRY_NAMES[i]
		indicators.append({"panel": panel, "icon": icon, "label": label})
	_label("Lit: possible   *: complete", 13, sym_column)
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
	board_view.anchor_selected.connect(_select_anchor)
	board_view.anchor_hovered.connect(_hover_anchor)
	board_view.hover_exited.connect(func():
		anchor = selected
		_preview())
	column.resized.connect(func(): board_view.custom_minimum_size.y = column.size.x)
	status = _label("", 17, column)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 48
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	undo_button = _button("Back", actions, _undo)
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_button = _button("Place piece", actions, _place)
	place_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var legend := _label("11 shapes · Choose either color · Gray means unavailable", 15, column)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "A new garden?"
	reset_dialog.dialog_text = "This will replace your current pattern."
	reset_dialog.confirmed.connect(_reset)
	reset_dialog.canceled.connect(func(): size_picker.select(0 if game.board.size() == 9 else 1))
	add_child(reset_dialog)
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
	piece_view.cells = cells
	piece_view.color = game.piece().color
	piece_view.queue_redraw()
	piece_label.text = "Garden complete" if game.no_space else "%s · %s" % [game.queue[game.index], "Blue" if game.piece().color == Rules.BLUE else "Coral"]
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
	var states: Array = Rules.symmetry_states(game.board)
	var possible := 0
	var names := ["Vertical", "Horizontal", "Diag. /", "Diag. \\", "90°", "180°", "270°"]
	for i in range(7):
		var state: Dictionary = states[i]
		var indicator: Dictionary = indicators[i]
		indicator.panel.add_theme_stylebox_override("panel", _style(Color("e2edda") if state.possible else Color("e5e4dc")))
		indicator.icon.active = state.possible
		indicator.icon.queue_redraw()
		indicator.label.text = names[i] + (" *" if state.complete else "")
		indicator.panel.tooltip_text = Rules.SYMMETRY_NAMES[i] + (": complete" if state.complete else (": possible" if state.possible else ": color conflict"))
		if state.possible:
			possible += 1
	status.text = ("Your garden is full. Enjoy your completed pattern, or go back." if game.no_space else "This piece fits, but every placement closes the last path to symmetry. Go back, or begin again.") if game.over else "%d paths remain. Tap a square to explore; tap again or choose Place." % possible
	_preview()

func _preview() -> void:
	board_view.preview_cells = [] if anchor.x < 0 or game.over else cells
	board_view.preview_anchor = anchor
	board_view.preview_color = game.piece().color
	var valid := false
	if anchor.x >= 0 and not game.over:
		valid = Rules.placement(game.board, cells, game.piece().color, anchor).ok
	board_view.preview_valid = valid
	board_view.queue_redraw()
	place_button.disabled = selected.x < 0 or game.over or not Rules.placement(game.board, cells, game.piece().color, selected).ok

func _select_anchor(cell: Vector2i) -> void:
	if game.over or cell.x < 0:
		return
	if selected == cell:
		_place()
		return
	selected = cell
	anchor = cell
	var result: Dictionary = Rules.placement(game.board, cells, game.piece().color, cell)
	status.text = "Tap again, or choose Place to put down roots." if result.ok else result.reason
	_preview()

func _hover_anchor(cell: Vector2i) -> void:
	anchor = cell
	_preview()

func _place() -> void:
	if selected.x < 0:
		return
	var result: Dictionary = game.place(cells, selected)
	if not result.ok:
		status.text = result.reason
		return
	cells = game.piece().cells
	_clear_selection()
	_refresh()

func _clear_selection() -> void:
	anchor = Vector2i(-1, -1)
	selected = anchor

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
	help.dialog_text = "Place pieces against an edge or corner of the pattern.\nTap to preview, then tap again or choose Place.\nThe selected square is the top-left of the piece's bounding box.\nRotate with R, or mirror horizontally with F.\nChoose Blue or Coral freely before placing any piece.\nGray previews indicate invalid positions.\nGo back up to three placements, including color and orientation.\n\nA lit symmetry is still possible, even when it is not complete.\nEmpty partners can be filled later; different colors cannot match.\nAll reflections and rotations use the board's center.\n\nAll four sizes are equally likely while they fit.\nPieces with no physical fit are excluded from the draw.\nPlay ends when a fitting piece cannot preserve symmetry, or the garden is full.\nThere is no timer. Enjoy finding your pattern."
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
