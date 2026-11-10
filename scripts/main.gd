extends Control

const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Game = preload("res://scripts/game.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const BoardView = preload("res://scripts/board_view.gd")
const PieceView = preload("res://scripts/piece_view.gd")
const FloatingPiece = preload("res://scripts/floating_piece.gd")
const GrowthSounds = preload("res://scripts/growth_audio.gd")
const PaletteChoice = preload("res://scripts/palette_choice.gd")
const Gallery = preload("res://scripts/gallery.gd")
const SymmetryIcon = preload("res://scripts/symmetry_icon.gd")
var game = Game.new()
var cells: Array = []
var has_hover := false
var dragging := false
const TAP_LIMIT := 0.25
const GESTURE_SLOP := 10.0
var gesture_age := 0.0
var gesture_mode := "pending"
var gesture_start := Vector2.ZERO
var erase_mode := false
var erase_target := Vector2i(-1, -1)
var saving := false
var saved_fingerprint := ""
var gallery = Gallery.new()
var gallery_panel: Panel
var gallery_image: TextureRect
var gallery_previous: Button
var gallery_next: Button
var gallery_close: Button
var gallery_page: Button
var gallery_entries: Array = []
var gallery_index := 0
var theme_button: Button
var gallery_button: Button
var skip_button: Button
var erase_button: Button
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
		var panel := _button("", _save_design)
		var icon = SymmetryIcon.new()
		icon.rotational = i == 1
		panel.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	sounds.attach_board(board_view)
	flip_button = _button("Flip", _flip)
	blue_button = _button("", func(): _choose_color(Rules.BLUE))
	coral_button = _button("", func(): _choose_color(Rules.CORAL))
	blue_button.toggle_mode = true
	coral_button.toggle_mode = true
	place_button = _button("Place", _place)
	undo_button = _button("↶ 3", _undo)
	skip_button = _button("⇥ 3", _skip)
	erase_button = _button("⌫ 3", _toggle_erase)
	new_button = _button("+", func(): _ask_reset(game.board.size()))
	size_picker = _button("9 × 9", func(): _ask_reset(11 if game.board.size() == 9 else 9))
	palette_button = _button("⚙", _toggle_palette_menu)
	gallery_button = _button("Gallery", _open_gallery)
	theme_button = _button("Garden: Vines", _toggle_theme)
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

	for control: Control in [theme_button, size_picker, new_button, gallery_button]:
		control.reparent(palette_list)
	_build_gallery()
	floating_piece = FloatingPiece.new()
	floating_piece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floating_piece)
	for control: Control in _controls():
		control.z_index = 50

func _controls() -> Array:
	return [place_button, undo_button, skip_button, erase_button, flip_button, blue_button, coral_button, palette_button, indicators[0].panel, indicators[1].panel]

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
	var row_height: float = clampf(minf(view.x, view.y) * 0.085, 26, 44)
	var dock_height: float = 3 * row_height + 2 * pad
	var dock: Rect2
	if landscape:
		var side: float = minf(view.y - top.end.y - 2 * pad, view.x * 0.58)
		_set_rect(board_view, Rect2(Vector2(pad, top.end.y + pad), Vector2.ONE * side))
		dock = Rect2(side + 2 * pad, maxf(top.end.y + pad, view.y - pad - dock_height), view.x - side - 3 * pad, dock_height)
	else:
		dock = Rect2(pad, view.y - pad - dock_height, view.x - 2 * pad, dock_height)
		var side: float = maxf(1, minf(view.x, dock.position.y - top.end.y - 2 * pad))
		_set_rect(board_view, Rect2(Vector2((view.x - side) / 2, top.end.y + pad), Vector2.ONE * side))
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
	var left_width: float = dock.size.x * 0.20
	var right_width: float = dock.size.x * 0.27
	for i in range(3):
		_set_rect([blue_button, coral_button, flip_button][i], Rect2(dock.position + Vector2(0, i * (row_height + pad)), Vector2(left_width, row_height)))
	var middle := Rect2(dock.position + Vector2(left_width + pad, row_height + pad), Vector2(dock.size.x - left_width - right_width - 2 * pad, row_height))
	_layout_row([undo_button, skip_button, erase_button], middle, pad * 0.5)
	_set_rect(place_button, Rect2(dock.end.x - right_width, dock.position.y + (dock_height - 2 * row_height) / 2, right_width, 2 * row_height))
	_layout_gallery(pad)
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
	undo_button.text = "↶ %d" % game.undo_left
	skip_button.text = "⇥ %d" % game.skip_left
	erase_button.text = ("× %d" if erase_mode else "⌫ %d") % game.erase_left
	undo_button.disabled = game.history.is_empty() or game.undo_left <= 0 or saving
	skip_button.disabled = game.over or game.skip_left <= 0 or saving
	erase_button.disabled = game.erase_left <= 0 or not game.board.any(func(row: Array): return row.any(func(value): return value != 0)) or saving
	for button: Button in [flip_button, blue_button, coral_button]:
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
	var occupied: bool = board.any(func(row: Array): return row.any(func(value): return value != 0))
	for i in range(2):
		var available: Array = []
		var complete: Array = []
		for symmetry in (range(4) if i == 0 else range(4, 7)):
			available.append(states[symmetry].possible)
			complete.append(occupied and states[symmetry].complete)
		var lit: bool = complete.any(func(value): return value)
		var indicator: Dictionary = indicators[i]
		indicator.icon.available = available
		indicator.icon.complete = complete
		indicator.icon.saved = saved_fingerprint == _design_fingerprint()
		indicator.icon.queue_redraw()
		var style := _style(Palette.controls().lerp(Palette.tile(1), 0.20) if lit else Palette.controls())
		style.set_border_width_all(2 if lit else 0)
		style.border_color = Color(Palette.tile(1), 0.6)
		indicator.panel.add_theme_stylebox_override("normal", style)

func _surface_revision(theme: String) -> String:
	var revision: String = Platform.surface_revision(theme)
	if board_view.board_frame != null and board_view.board_frame.is_present():
		revision += "/frame-" + board_view.board_frame.appearance
	return revision

func _design_fingerprint() -> String:
	return Gallery.fingerprint(game.board, Palette.selected_index, Palette.theme_id(), Palette.theme_version(), _surface_revision(Palette.theme_id()))

func _can_save() -> bool:
	return game.board.any(func(row: Array): return row.any(func(value): return value != 0)) and Rules.symmetry_states(game.board).any(func(state: Dictionary): return state.complete)

func _preview() -> void:
	floating_piece.cells = cells if has_hover and not game.over and not erase_mode else []
	floating_piece.color = game.current_color
	var physical := false
	var legal := false
	if has_hover and not game.over:
		physical = Rules.physical_placement(game.board, cells, selected).ok
		legal = Rules.placement(game.board, cells, game.current_color, selected).ok
	floating_piece.valid = legal
	place_button.disabled = not physical or game.over or board_view.growing or erase_mode or saving
	_update_summaries(game.board)
	_update_floating_position()

func _update_floating_position() -> void:
	floating_piece.pitch = board_view.pitch
	floating_piece.face_lift = board_view.surface_depth()
	floating_piece.origin = board_view.get_global_transform_with_canvas() * board_view._floor_point(Vector2(selected))
	floating_piece.queue_redraw()

func _drag_to(point: Vector2) -> void:
	last_pointer = point
	var local: Vector2 = board_view.get_global_transform_with_canvas().affine_inverse() * point
	local += Vector2(0, board_view.surface_depth())
	var relative: Vector2 = (local - board_view._floor_point(Vector2.ZERO)) / board_view.pitch
	selected = Vector2i(floori(relative.x), floori(relative.y)) - grabbed_cell
	has_hover = true
	_preview()

func _start_drag(point: Vector2, id: int) -> bool:
	if game.over or dragging or palette_menu.visible or gallery_panel.visible or erase_mode or saving:
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
	gesture_age = 0
	gesture_mode = "pending"
	gesture_start = point
	last_pointer = point
	return true

func _move_gesture(point: Vector2) -> void:
	if gesture_mode == "pending":
		if point.distance_to(gesture_start) < GESTURE_SLOP:
			return
		gesture_mode = "move"
	_drag_to(point)

func _finish_gesture(point: Vector2) -> void:
	_move_gesture(point)
	if gesture_mode == "pending" and gesture_age <= TAP_LIMIT:
		_rotate()
	dragging = false

func _erase_cell_at(point: Vector2) -> Vector2i:
	var local: Vector2 = board_view.get_global_transform_with_canvas().affine_inverse() * point
	local += Vector2(0, board_view.surface_depth())
	var relative: Vector2 = (local - board_view._floor_point(Vector2.ZERO)) / board_view.pitch
	return Vector2i(floori(relative.x), floori(relative.y))

func _input(event: InputEvent) -> void:
	if saving:
		get_viewport().set_input_as_handled()
		return
	if gallery_panel.visible:
		return
	var pointer_event: bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if palette_menu.visible:
		if pointer_event and event.pressed and not palette_menu.get_global_rect().has_point(event.position) and not palette_button.get_global_rect().has_point(event.position):
			palette_menu.hide()
			get_viewport().set_input_as_handled()
		return
	if erase_mode and pointer_event and board_view.get_global_rect().has_point(event.position):
		if event.pressed:
			erase_target = _erase_cell_at(event.position)
			pointer_id = event.index if event is InputEventScreenTouch else -1
		elif (event.index if event is InputEventScreenTouch else -1) == pointer_id:
			if not (event is InputEventScreenTouch and event.canceled) and _erase_cell_at(event.position) == erase_target:
				_erase(erase_target)
			erase_target = Vector2i(-1, -1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _start_drag(event.position, event.index):
				get_viewport().set_input_as_handled()
		elif dragging and event.index == pointer_id:
			if event.canceled:
				dragging = false
			else:
				_finish_gesture(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and dragging and event.index == pointer_id:
		_move_gesture(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _start_drag(event.position, -1):
				get_viewport().set_input_as_handled()
		elif dragging and pointer_id == -1:
			_finish_gesture(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging and pointer_id == -1:
		_move_gesture(event.position)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if dragging:
		gesture_age += delta
	if has_hover:
		_update_floating_position()

func _place() -> void:
	if not has_hover or board_view.growing or erase_mode or saving:
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

func _skip() -> void:
	if game.skip():
		cells = game.piece().cells
		_clear_selection()
		_refresh()

func _toggle_erase() -> void:
	if game.erase_left <= 0:
		return
	erase_mode = not erase_mode
	erase_target = Vector2i(-1, -1)
	dragging = false
	_refresh()

func _erase(cell: Vector2i) -> void:
	if game.erase(cell):
		erase_mode = false
		board_view.show_settled(game.board, true)
		cells = game.piece().cells
		_clear_selection()
		_refresh()

func _undo() -> void:
	if game.undo():
		erase_mode = false
		board_view.show_settled(game.board, true)
		cells = game.restored_cells
		_clear_selection()
		_refresh()

func _ask_reset(n: int) -> void:
	requested_size = n
	_reset()

func _reset() -> void:
	palette_menu.hide()
	erase_mode = false
	game = Game.new(requested_size)
	board_view.show_settled(game.board)
	cells = game.piece().cells
	size_picker.text = "%d × %d" % [requested_size, requested_size]
	_clear_selection()
	_refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.background())

func _layout_palette_menu(pad: float) -> void:
	var options: Array = [theme_button] + (palette_options if Palette.theme_id() == "vines" else []) + [size_picker, new_button, gallery_button]
	for option: Control in palette_options:
		option.visible = Palette.theme_id() == "vines"
	theme_button.text = "Garden: " + Palette.theme_name()
	var row_height: float = clampf((size.y - 2 * pad - 12) / options.size() - 4, 22, 44)
	var width: float = minf(260, size.x - 2 * pad)
	var height: float = (row_height + 4) * options.size() + 8
	var y: float = minf(palette_button.get_rect().end.y + pad, size.y - pad - height)
	_set_rect(palette_menu, Rect2(size.x - pad - width, maxf(pad, y), width, height))
	new_button.text = "Restart"
	for i in range(options.size()):
		_set_rect(options[i], Rect2(0, i * (row_height + 4), width - 12, row_height))
		options[i].add_theme_font_size_override("font_size", clampi(roundi(row_height * 0.36), 11, 16))

func _refresh_theme() -> void:
	for button: Button in [flip_button, place_button, undo_button, skip_button, erase_button, size_picker, new_button, gallery_button, theme_button, palette_button]:
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
	dragging = false
	palette_menu.visible = not palette_menu.visible

func _toggle_theme() -> void:
	_select_theme(Palette.THEMES[(Palette.THEMES.find(Palette.theme_id()) + 1) % Palette.THEMES.size()])

func _select_theme(id: String) -> void:
	if not Palette.select_theme(id):
		return
	palette_menu.hide()
	dragging = false
	_layout()
	_refresh()
	board_view.queue_redraw()

func _choose_palette(index: int) -> void:
	if Palette.select(index):
		palette_menu.hide()
		_refresh()
		board_view.queue_redraw()
		for indicator: Dictionary in indicators:
			indicator.icon.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if saving:
			return
		if gallery_panel.visible:
			if event.keycode == KEY_ESCAPE:
				gallery_panel.hide()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and erase_mode:
			erase_mode = false
			_refresh()
			get_viewport().set_input_as_handled()
			return
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

func _build_gallery() -> void:
	gallery_panel = Panel.new()
	gallery_panel.z_index = 100
	gallery_panel.visible = false
	gallery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	gallery_panel.add_theme_stylebox_override("panel", _style(Color.WHITE))
	add_child(gallery_panel)
	gallery_image = TextureRect.new()
	gallery_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gallery_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gallery_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gallery_panel.add_child(gallery_image)
	gallery_previous = _button("‹", func(): _turn_gallery(-1))
	gallery_next = _button("›", func(): _turn_gallery(1))
	gallery_close = _button("×", func(): gallery_panel.hide())
	gallery_page = _button("0 / 0", func(): pass)
	for control: Control in [gallery_previous, gallery_next, gallery_close, gallery_page]:
		control.reparent(gallery_panel)

func _layout_gallery(pad: float) -> void:
	_set_rect(gallery_panel, Rect2(Vector2.ZERO, size))
	var height: float = clampf(size.y * 0.08, 32, 56)
	_set_rect(gallery_close, Rect2(size.x - pad - height, pad, height, height))
	var side: float = maxf(1, minf(size.x - 2 * pad, size.y - 2 * height - 4 * pad))
	_set_rect(gallery_image, Rect2(Vector2((size.x - side) / 2, height + 2 * pad), Vector2.ONE * side))
	_layout_row([gallery_previous, gallery_page, gallery_next], Rect2(pad, size.y - pad - height, size.x - 2 * pad, height), pad)

func _open_gallery() -> void:
	palette_menu.hide()
	dragging = false
	gallery_entries = gallery.entries()
	gallery_index = 0
	_show_gallery_page()
	gallery_panel.show()

func _turn_gallery(direction: int) -> void:
	gallery_index = clampi(gallery_index + direction, 0, maxi(0, gallery_entries.size() - 1))
	_show_gallery_page()

func _show_gallery_page() -> void:
	gallery_image.texture = null if gallery_entries.is_empty() else gallery.picture(gallery_entries[gallery_index])
	gallery_page.text = "%d / %d" % [0 if gallery_entries.is_empty() else gallery_index + 1, gallery_entries.size()]
	gallery_previous.disabled = gallery_index <= 0
	gallery_next.disabled = gallery_index >= gallery_entries.size() - 1

func _save_design() -> void:
	if saving or board_view.growing or not _can_save():
		return
	saving = true
	var snapshot: Array = game.board.duplicate(true)
	var palette_index: int = Palette.selected_index
	var theme: String = Palette.theme_id()
	var theme_version: String = Palette.theme_version()
	var fingerprint := _design_fingerprint()
	var surface_revision := _surface_revision(theme)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 900)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var artwork = BoardView.new()
	artwork.size = Vector2(900, 900)
	artwork.show_guides = false
	viewport.add_child(artwork)
	artwork.show_settled(snapshot)
	if board_view.board_frame != null and board_view.board_frame.is_present():
		artwork.board_frame.apply_theme(theme, board_view.board_frame.texture)
		artwork.update_geometry()
	# Preserve established leaf direction in the clean artwork capture.
	artwork.direction_by_edge = board_view.direction_by_edge.duplicate(true)
	artwork._adopt_directions(true)
	if board_view.coral_visuals != null and artwork.coral_visuals != null:
		artwork.coral_visuals.copy_order(board_view.coral_visuals)
	await RenderingServer.frame_post_draw
	var result: Dictionary = gallery.save_design(snapshot, palette_index, viewport.get_texture().get_image(), theme, theme_version, surface_revision)
	viewport.queue_free()
	saving = false
	if result.ok:
		saved_fingerprint = fingerprint
	else:
		push_error("Could not save the garden to the local gallery.")
	_refresh()
