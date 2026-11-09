extends Control

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Game = preload("res://scripts/game.gd")
const BoardView = preload("res://scripts/board_view.gd")
const PieceView = preload("res://scripts/piece_view.gd")
const FloatingPiece = preload("res://scripts/floating_piece.gd")
const GrowthSounds = preload("res://scripts/growth_audio.gd")
const PaletteChoice = preload("res://scripts/palette_choice.gd")
const SymmetryIcon = preload("res://scripts/symmetry_icon.gd")
var game = Game.new()
var cells: Array = []
var has_hover := false
var dragging := false
var pointer_id := -1
var grabbed_cell := Vector2i.ZERO
var last_pointer := Vector2.ZERO
var selected := Vector2i(-1, -1)
var floating_piece: Control
var board_view: Control
var sounds: GrowthAudio
var piece_view: Control
var undo_button: Button
var place_button: Button
var rotate_button: Button
var flip_button: Button
var blue_button: Button
var coral_button: Button
var new_button: Button
var palette_button: Button
var palette_menu: PanelContainer
var palette_list: Control
var palette_options: Array = []
var indicators: Array = []
var size_picker: Button
var requested_size := 9

func _ready() -> void:
	_build_interface()
	cells = game.piece().cells
	resized.connect(_layout)
	_layout()
	_refresh()

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_stylebox_override("normal", _style(Color("e5ebdf")))
	button.add_theme_stylebox_override("hover", _style(Color("d7e2d0")))
	button.add_theme_stylebox_override("pressed", _style(Color("c9d9c4")))
	button.add_theme_stylebox_override("disabled", _style(Color("e4e5df")))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("334638"))
	button.add_theme_color_override("font_disabled_color", Color("929b8e"))
	add_child(button)
	button.pressed.connect(callback)
	return button

func _build_interface() -> void:
	for i in range(2):
		var panel := PanelContainer.new()
		add_child(panel)
		var icon = SymmetryIcon.new()
		icon.rotational = i == 1
		panel.add_child(icon)
		indicators.append({"panel": panel, "icon": icon})
	piece_view = PieceView.new()
	add_child(piece_view)
	board_view = BoardView.new()
	add_child(board_view)
	board_view.growth_finished.connect(_preview)
	sounds = GrowthSounds.new()
	add_child(sounds)
	board_view.growth_started.connect(sounds.begin)
	board_view.flower_opened.connect(sounds.bloom)
	board_view.growth_finished.connect(sounds.finish)
	board_view.growth_canceled.connect(sounds.cancel)
	rotate_button = _button("↻", _rotate)
	flip_button = _button("Flip", _flip)
	blue_button = _button("", func(): _choose_color(Rules.BLUE))
	coral_button = _button("", func(): _choose_color(Rules.CORAL))
	blue_button.toggle_mode = true
	coral_button.toggle_mode = true
	place_button = _button("Place", _place)
	undo_button = _button("↶", _undo)
	new_button = _button("+", func(): _ask_reset(game.board.size()))
	size_picker = _button("9 × 9", func(): _ask_reset(11 if game.board.size() == 9 else 9))
	palette_button = PaletteChoice.new()
	add_child(palette_button)
	palette_button.pressed.connect(_toggle_palette_menu)
	palette_menu = PanelContainer.new()
	palette_menu.visible = false
	palette_menu.z_index = 80
	add_child(palette_menu)
	palette_list = Control.new()
	palette_menu.add_child(palette_list)
	for i in range(Palette.PAIRS.size()):
		var option = PaletteChoice.new()
		option.pair_index = i
		option.text = Palette.PAIRS[i].name
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.pressed.connect(_choose_palette.bind(i))
		palette_list.add_child(option)
		palette_options.append(option)

	floating_piece = FloatingPiece.new()
	floating_piece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floating_piece)
	for control: Control in _controls():
		control.z_index = 50

func _controls() -> Array:
	return [place_button, undo_button, rotate_button, flip_button, blue_button, coral_button, size_picker, new_button, palette_button]

func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _layout_row(controls: Array, rect: Rect2, gap: float) -> void:
	var width: float = (rect.size.x - gap * (controls.size() - 1)) / controls.size()
	for i in range(controls.size()):
		_set_rect(controls[i], Rect2(rect.position + Vector2(i * (width + gap), 0), Vector2(width, rect.size.y)))

func _layout() -> void:
	if not is_instance_valid(board_view):
		return
	var view: Vector2 = size
	var pad: float = clampf(minf(view.x, view.y) * 0.018, 4, 12)
	var button_height: float = clampf(minf(view.x, view.y) * 0.10, 32, 56)
	for control: Control in _controls():
		control.add_theme_font_size_override("font_size", clampi(roundi(button_height * 0.35), 11, 20))
	var landscape: bool = view.x > view.y * 1.15
	# Retain the old preview bounds only as a reference for exact 1.5x scaling.
	var legacy_height: float = minf(104, view.y * 0.28) if landscape else clampf(view.y * 0.10, 60, 104)
	var legacy_width: float = view.x - minf(view.y - 2 * pad, view.x * 0.58) - 3 * pad if landscape else view.x - 2 * pad
	piece_view.reference_size = Vector2(legacy_width * 0.38, legacy_height)
	var top_height: float = legacy_height * 1.5
	var top := Rect2(pad, pad, view.x - 2 * pad, top_height)
	var tools: Rect2
	var actions: Rect2
	if landscape:
		var side: float = minf(view.y - top.end.y - 2 * pad, view.x * 0.58)
		_set_rect(board_view, Rect2(Vector2(pad, top.end.y + pad), Vector2.ONE * side))
		var panel_x: float = side + 2 * pad
		var panel_width: float = view.x - panel_x - pad
		var y: float = top.end.y + pad + (side - 2 * button_height - pad) / 2
		tools = Rect2(panel_x, y, panel_width, button_height)
		actions = Rect2(panel_x, tools.end.y + pad, panel_width, button_height)
	else:
		actions = Rect2(pad, view.y - pad - button_height, view.x - 2 * pad, button_height)
		tools = Rect2(pad, actions.position.y - pad - button_height, view.x - 2 * pad, button_height)
		var space: float = tools.position.y - top.end.y - 2 * pad
		var side: float = maxf(1, minf(view.x, space))
		_set_rect(board_view, Rect2(Vector2((view.x - side) / 2, top.end.y + pad + (space - side) / 2), Vector2.ONE * side))
	var group_width: float
	if view.x >= 600:
		var icon_side: float = minf(64, top.size.y)
		for i in range(2):
			_set_rect(indicators[i].panel, Rect2(top.position + Vector2(i * (icon_side + pad), 0), Vector2.ONE * icon_side))
		group_width = icon_side * 2 + pad
	else:
		var icon_side: float = minf((top.size.y - pad) / 2, view.x * 0.15)
		for i in range(2):
			_set_rect(indicators[i].panel, Rect2(top.position + Vector2(0, i * (icon_side + pad)), Vector2.ONE * icon_side))
		group_width = icon_side
	var palette_size: float = maxf(32, button_height)
	_set_rect(palette_button, Rect2(view.x - pad - palette_size, pad, palette_size, palette_size))
	var reserve: float = maxf(group_width, palette_size) + 2 * pad
	_set_rect(piece_view, Rect2(reserve, top.position.y, view.x - 2 * reserve, top.size.y))
	_layout_palette_menu(pad)
	_layout_row([rotate_button, flip_button, blue_button, coral_button], tools, pad)
	_layout_row([place_button, undo_button, size_picker, new_button], actions, pad)
	# Update geometry immediately so an in-progress drag survives a resize.
	board_view.update_geometry()
	board_view.queue_redraw()
	piece_view.queue_redraw()
	queue_redraw()
	if has_hover:
		_update_floating_position()

func _refresh() -> void:
	_refresh_theme()
	board_view.sync_board(game.board)
	piece_view.cells = [] if game.over else cells
	piece_view.color = game.current_color
	piece_view.queue_redraw()
	undo_button.text = "↶ %d" % game.history.size()
	undo_button.disabled = game.history.is_empty()
	for button: Button in [rotate_button, flip_button, blue_button, coral_button]:
		button.disabled = game.over
	for button: Button in [blue_button, coral_button]:
		var chosen: bool = (button == blue_button) == (game.current_color == Rules.BLUE)
		button.set_pressed_no_signal(chosen)
		var ink: Color = Palette.tile(1 if button == blue_button else 2)
		var style := _style(ink)
		style.set_border_width_all(3 if chosen else 0)
		style.border_color = Color("101a30") if ink.get_luminance() > 0.7 else (Color.WHITE if Palette.dark() else Palette.text())
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, style)
	_preview()

func _update_summaries(board: Array) -> void:
	var states: Array = Rules.symmetry_states(board)
	for i in range(2):
		var available: Array = []
		for symmetry in (range(4) if i == 0 else range(4, 7)):
			available.append(states[symmetry].possible)
		var lit: bool = available.any(func(value): return value)
		var indicator: Dictionary = indicators[i]
		indicator.icon.available = available
		indicator.icon.queue_redraw()
		indicator.panel.add_theme_stylebox_override("panel", _style(Palette.controls().lerp(Palette.tile(1), 0.10) if lit else Palette.controls()))

func _preview() -> void:
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
	place_button.disabled = not physical or game.over or board_view.growing
	_update_summaries(proposed)
	_update_floating_position()

func _update_floating_position() -> void:
	floating_piece.pitch = board_view.pitch
	floating_piece.origin = board_view.get_global_transform_with_canvas() * (board_view.field.position + Vector2(8, 8) + Vector2(selected) * board_view.pitch)
	floating_piece.queue_redraw()

func _drag_to(point: Vector2) -> void:
	last_pointer = point
	var local: Vector2 = board_view.get_global_transform_with_canvas().affine_inverse() * point
	local += Vector2(0, board_view.surface_depth())
	var relative: Vector2 = (local - board_view.field.position - Vector2(8, 8)) / board_view.pitch
	selected = Vector2i(floori(relative.x), floori(relative.y)) - grabbed_cell
	has_hover = true
	_preview()

func _start_drag(point: Vector2, id: int) -> bool:
	if game.over or dragging or palette_menu.visible:
		return false
	for control: Control in _controls():
		if control.get_global_rect().has_point(point):
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
	var pointer_pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if palette_menu.visible and pointer_pressed:
		if not palette_menu.get_global_rect().has_point(event.position) and not palette_button.get_global_rect().has_point(event.position):
			palette_menu.hide()
			get_viewport().set_input_as_handled()
			return
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

func _process(_delta: float) -> void:
	if has_hover:
		_update_floating_position()

func _place() -> void:
	if not has_hover or board_view.growing:
		return
	var before: Array = game.board
	var result: Dictionary = game.place(cells, selected)
	if not result.ok:
		return
	board_view.animate_growth(before, game.board)
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
		board_view.show_settled(game.board, true)
		cells = game.restored_cells
		_clear_selection()
		_refresh()

func _ask_reset(n: int) -> void:
	requested_size = n
	_reset()

func _reset() -> void:
	palette_menu.hide()
	game = Game.new(requested_size)
	board_view.show_settled(game.board)
	cells = game.piece().cells
	size_picker.text = "%d × %d" % [requested_size, requested_size]
	_clear_selection()
	_refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.background())

func _layout_palette_menu(pad: float) -> void:
	var row_height: float = clampf(size.y * 0.09, 30, 44)
	var width: float = minf(260, size.x - 2 * pad)
	var height: float = row_height * Palette.PAIRS.size() + 4 * (Palette.PAIRS.size() - 1) + 12
	var y: float = minf(palette_button.get_rect().end.y + pad, size.y - pad - height)
	_set_rect(palette_menu, Rect2(size.x - pad - width, maxf(pad, y), width, height))
	for i in range(palette_options.size()):
		_set_rect(palette_options[i], Rect2(0, i * (row_height + 4), width - 12, row_height))
		palette_options[i].add_theme_font_size_override("font_size", clampi(roundi(row_height * 0.36), 11, 16))

func _refresh_theme() -> void:
	for button: Button in [rotate_button, flip_button, place_button, undo_button, size_picker, new_button, palette_button]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var ink: Color = Palette.controls().lightened(0.04 if state == "hover" or state == "pressed" else 0)
			button.add_theme_stylebox_override(state, _style(ink))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, Palette.text())
		button.add_theme_color_override("font_disabled_color", Palette.muted())
	var menu_style := _style(Palette.controls())
	menu_style.set_border_width_all(1)
	menu_style.border_color = Color(Palette.text(), 0.20)
	palette_menu.add_theme_stylebox_override("panel", menu_style)
	for i in range(palette_options.size()):
		var option: Button = palette_options[i]
		var style := _style(Palette.background())
		style.set_border_width_all(2 if i == Palette.selected_index else 0)
		style.border_color = Palette.tile(1)
		for state in ["normal", "hover", "pressed"]:
			option.add_theme_stylebox_override(state, style)
			option.add_theme_color_override("font_color", Palette.text())
			option.add_theme_color_override("font_hover_color", Palette.text())
			option.add_theme_color_override("font_pressed_color", Palette.text())
		option.queue_redraw()
	palette_button.queue_redraw()
	queue_redraw()

func _toggle_palette_menu() -> void:
	palette_menu.visible = not palette_menu.visible

func _choose_palette(index: int) -> void:
	if Palette.select(index):
		palette_menu.hide()
		_refresh()
		board_view.queue_redraw()
		for indicator: Dictionary in indicators:
			indicator.icon.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and palette_menu.visible:
			palette_menu.hide()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_R: _rotate()
			KEY_F: _flip()
			KEY_C: _choose_color(Rules.CORAL if game.current_color == Rules.BLUE else Rules.BLUE)
			_: return
		get_viewport().set_input_as_handled()
