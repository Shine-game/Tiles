extends Control

const ThemeAssets = preload("res://scripts/pattern/asset_library.gd")
const Rules = preload("res://scripts/rules.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Palette = preload("res://scripts/palette.gd")
const Game = preload("res://scripts/game.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const BoardView = preload("res://scripts/board_view.gd")
const PieceView = preload("res://scripts/piece_view.gd")
const FloatingPiece = preload("res://scripts/floating_piece.gd")
const GrowthSounds = preload("res://scripts/growth_audio.gd")
const PaletteChoice = preload("res://scripts/palette_choice.gd")
const Gallery = preload("res://scripts/gallery.gd")
const Frame = preload("res://scripts/board_frame.gd")
const ThemeTile = preload("res://scripts/theme_tile.gd")
const ColorMark = preload("res://scripts/color_mark.gd")
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
var gesture_from_tray := false
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
var menu_frame: BoardFrame
var palette_options: Array = []
var indicators: Array = []
var size_picker: Button
var requested_size := 9

var menu_page := "Settings"
var menu_buttons: Array = []
var theme_options: Array = []
var difficulty_options: Array = []
var settings_options: Array = []
var menu_close: Button
var back_button: Button
var vine_colors_button: Button
var themes_back_button: Button
var background_button: Button
var effects_button: Button
var axes_button: Button
var menu_title: Label
var confirmation: ConfirmationDialog
var pending_change: Callable
var themed_buttons: Array = []
var reef_background: ColorRect
var zen_background: ColorRect
var difficulty: Game.Difficulty = Game.Difficulty.DIFFICULT

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
	button.clip_text = true
	button.add_theme_stylebox_override("normal", _style(Color("e5ebdf")))
	button.add_theme_stylebox_override("hover", _style(Color("d7e2d0")))
	button.add_theme_stylebox_override("pressed", _style(Color("c9d9c4")))
	button.add_theme_stylebox_override("disabled", _style(Color("e4e5df")))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("334638"))
	button.add_theme_color_override("font_disabled_color", Color("929b8e"))
	add_child(button)
	themed_buttons.append(button)
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
	piece_view.z_index = 2
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
	for color_button: Button in [blue_button, coral_button]:
		var mark := ColorMark.new()
		mark.color = 1 if color_button == blue_button else 2
		color_button.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		color_button.tooltip_text = "Color %d" % mark.color
	blue_button.toggle_mode = true
	coral_button.toggle_mode = true
	place_button = _button("Place", _place)
	undo_button = _button("↶ 3", _undo)
	skip_button = _button("⇥ 3", _skip)
	erase_button = _button("⌫ 3", _toggle_erase)
	new_button = _button("+", func(): _ask_reset(game.board.size()))
	size_picker = _button("9 × 9", func(): _ask_reset(11 if game.board.size() == 9 else 9))
	palette_button = _button("⚙", _toggle_palette_menu)
	palette_menu = PanelContainer.new()
	palette_menu.visible = false
	palette_menu.z_index = 80
	add_child(palette_menu)
	palette_list = Control.new()
	palette_menu.add_child(palette_list)
	menu_frame = Frame.new()
	menu_frame.name = "SettingsFrame"
	palette_list.add_child(menu_frame)
	_build_settings()
	reef_background = ColorRect.new()
	reef_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reef_background.z_index = 0
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/reef_lagoon.gdshader")
	reef_background.material = water
	add_child(reef_background)
	zen_background = ColorRect.new()
	zen_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zen_background.material = ZenVisuals.sand_material()
	add_child(zen_background)
	move_child(zen_background, 0)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Start a new game?"
	confirmation.ok_button_text = "New game"
	confirmation.confirmed.connect(func():
		if pending_change.is_valid(): pending_change.call()
		pending_change = Callable())
	confirmation.canceled.connect(func(): pending_change = Callable())
	add_child(confirmation)
	themed_buttons.append_array([confirmation.get_ok_button(), confirmation.get_cancel_button()])
	for button: Button in [confirmation.get_ok_button(), confirmation.get_cancel_button()]:
		button.custom_minimum_size = Vector2(100, 36)
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

func _layout_insets(view: Vector2) -> Vector4:
	var short_side := minf(view.x, view.y)
	var side := clampf(short_side * 0.04, 12, 32)
	var vertical := clampf(short_side * 0.05, 24, 40)
	var inset := Vector4(side, vertical, side, vertical)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var window := Vector2(DisplayServer.window_get_size())
		if window.x > 0 and window.y > 0:
			var safe := Rect2(DisplayServer.get_display_safe_area())
			safe.position -= Vector2(DisplayServer.window_get_position())
			safe = safe.intersection(Rect2(Vector2.ZERO, window))
			if safe.has_area():
				var factor := view / window
				var clearance := clampf(short_side * 0.015, 6, 12)
				inset.x = maxf(inset.x, safe.position.x * factor.x + clearance)
				inset.y = maxf(inset.y, safe.position.y * factor.y + clearance)
				inset.z = maxf(inset.z, (window.x - safe.end.x) * factor.x + clearance)
				inset.w = maxf(inset.w, (window.y - safe.end.y) * factor.y + clearance)
	return inset

func _header_metrics(view: Vector2, inset: float, gap: float, icon_gap: float) -> Dictionary:
	var preview_height: float = 2 * board_view.pitch + 8.0
	var left_space: float = view.x / 2 - 2 * board_view.pitch - inset - gap
	var icon_limit := maxf(16, (left_space - icon_gap) / 2)
	var icon_side := minf(minf(64 * 1.3, view.y * 0.12), icon_limit)
	var helper_height := clampf(view.y * 0.08, 24, 44)
	var group_height := icon_side + gap + helper_height
	return {"icon": icon_side, "helper": helper_height, "group": group_height, "preview": preview_height, "height": maxf(preview_height, group_height)}

func _layout() -> void:
	if not is_instance_valid(board_view):
		return
	var view: Vector2 = size
	if view.x <= 0 or view.y <= 0: return
	var pad: float = clampf(minf(view.x, view.y) * 0.01, 4, 8)
	var gap: float = clampf(minf(view.x, view.y) * 0.015, 6, 12)
	var safe := _layout_insets(view)
	var side_inset := maxf(safe.x, safe.z)
	var button_side := maxf(1, minf((view.x - 2 * side_inset - 3 * gap) / 4, view.y * 0.20))
	for control: Control in _controls():
		control.add_theme_font_size_override("font_size", clampi(roundi(button_side * 0.2), 12, 28))
	var icon_gap: float = 2 * pad
	# The frame stays exactly on the phone's vertical midpoint. Find the largest
	# square with enough safe space for both control bands, rather than moving
	# the frame up to squeeze the buttons against the screen edges.
	var low := 1.0
	var high := maxf(1, minf(view.x - 2 * side_inset, view.y - 2 * (safe.w + button_side + gap)))
	for iteration in range(12):
		var candidate := (low + high) * 0.5
		board_view.size = Vector2.ONE * candidate
		board_view.update_geometry()
		var metrics := _header_metrics(view, side_inset, gap, icon_gap)
		if float(metrics.height) <= (view.y - candidate) * 0.5 - safe.y - gap:
			low = candidate
		else:
			high = candidate
	var side := low
	_set_rect(board_view, Rect2((view - Vector2.ONE * side) * 0.5, Vector2.ONE * side))
	board_view.update_geometry()
	var metrics := _header_metrics(view, side_inset, gap, icon_gap)
	var icon_side: float = metrics.icon
	var helper_height: float = metrics.helper
	var header_center: float = (safe.y + board_view.position.y - gap) * 0.5
	var icon_y: float = header_center - float(metrics.group) * 0.5
	var group_width: float = 2 * icon_side + icon_gap
	for i in range(2):
		_set_rect(indicators[i].panel, Rect2(side_inset + i * (icon_side + icon_gap), icon_y, icon_side, icon_side))
	_set_rect(palette_button, Rect2(view.x - side_inset - minf(64, icon_side), icon_y, minf(64, icon_side), minf(64, icon_side)))
	var preview_width: float = 4 * board_view.pitch
	_set_rect(piece_view, Rect2((view.x - preview_width) / 2, header_center - float(metrics.preview) * 0.5, preview_width, metrics.preview))
	piece_view.cell_pitch = board_view.pitch
	var helper_y := icon_y + icon_side + gap
	var helper_width := group_width
	var usable_helpers := 3 * 40.0 + 2 * gap
	if helper_width < usable_helpers:
		if side_inset + usable_helpers + gap <= piece_view.position.x:
			helper_width = usable_helpers
		elif maxf(helper_y, piece_view.get_rect().end.y + gap) + helper_height <= board_view.position.y - gap:
			# Tall narrow phones have room below the preview for wider hit areas.
			helper_y = maxf(helper_y, piece_view.get_rect().end.y + gap)
			helper_width = usable_helpers
		elif float(metrics.preview) <= icon_side:
			# Compact windows can share the first row with the preview instead.
			piece_view.position.y = icon_y
			helper_width = usable_helpers
	var helper_font := clampi(roundi(helper_height * 0.42), 10, 18)
	var font: Font = erase_button.get_theme_font("font")
	var text_width := (helper_width - 2 * gap) / 3 - 6
	while helper_font > 8:
		var widest := 0.0
		for label: String in ["↶ 3", "⇥ 3", "⌫ 3", "× 3"]:
			widest = maxf(widest, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, helper_font).x)
		if widest <= text_width: break
		helper_font -= 1
	for control: Button in [undo_button, skip_button, erase_button]:
		control.add_theme_font_size_override("font_size", helper_font)
	_layout_row([undo_button, skip_button, erase_button], Rect2(side_inset, helper_y, helper_width, helper_height), gap)
	var dock_width: float = 4 * button_side + 3 * gap
	var dock_y: float = (board_view.get_rect().end.y + gap + view.y - safe.w - button_side) * 0.5
	var dock := Rect2((view.x - dock_width) / 2, dock_y, dock_width, button_side)
	_layout_row([blue_button, coral_button, flip_button, place_button], dock, gap)
	_set_rect(reef_background, Rect2(Vector2.ZERO, view))
	_set_rect(zen_background, Rect2(Vector2.ZERO, view))
	_sync_zen_background()
	_layout_palette_menu(pad)
	_layout_gallery(pad)
	board_view.queue_redraw()
	piece_view.queue_redraw()
	queue_redraw()
	if has_hover:
		_update_floating_position()

func _refresh() -> void:
	_refresh_theme()
	board_view.sync_board(game.board)
	_layout()
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
		_apply_button_style(button, chosen, 1 if button == blue_button else 2)
		button.get_child(0).queue_redraw()
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
		_apply_button_style(indicator.panel, lit)

func _surface_revision(theme: String) -> String:
	var revision: String = Platform.surface_revision(theme) + "/complete-background-v1"
	if Themes.profile(theme).get("tier1_artwork", {}).get("status") == "active": revision += "/tier1-generative-v1"
	if board_view.board_frame != null and board_view.board_frame.is_present():
		revision += "/frame-" + board_view.board_frame.appearance
	if theme == "zen_garden" and board_view.zen_visuals != null and board_view.zen_visuals.pond != null:
		var pond = board_view.zen_visuals.pond
		if not pond.plants.is_empty(): revision += "/shrubs-" + pond.appearance_signature()
	if theme == "zen_garden" and board_view.zen_visuals != null and board_view.zen_visuals.trees != null:
		var trees = board_view.zen_visuals.trees
		if not trees.groups.is_empty(): revision += "/trees-" + trees.appearance_signature()
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
		physical = game.physical_placement(cells, selected).ok
		legal = game.placement(cells, selected).ok
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
	if game.over or dragging or confirmation.visible or palette_menu.visible or gallery_panel.visible or erase_mode or saving:
		return false
	for control: Control in _controls():
		if control.get_global_rect().has_point(point):
			return false
	var hit := Vector2i(-1, -1)
	gesture_from_tray = false
	if has_hover:
		hit = floating_piece.cell_at(point)
	if hit.x < 0:
		hit = piece_view.cell_at(piece_view.get_global_transform_with_canvas().affine_inverse() * point)
		gesture_from_tray = hit.x >= 0
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
		if gesture_from_tray:
			var grabbed_index: int = cells.find(grabbed_cell)
			cells = piece_view.display_cells()
			grabbed_cell = cells[grabbed_index]
			_refresh()
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
	if saving or confirmation.visible:
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
	_confirm_new_game("Start a new game on a %d × %d board?" % [n, n], func():
		requested_size = n
		_reset())

func _reset() -> void:
	palette_menu.hide()
	erase_mode = false
	game = Game.new(requested_size, -1, difficulty)
	if board_view.zen_visuals != null and board_view.zen_visuals.pond != null:
		board_view.zen_visuals.pond.reset_choices()
	if board_view.zen_visuals != null and board_view.zen_visuals.trees != null:
		board_view.zen_visuals.trees.reset()
	board_view.show_settled(game.board)
	cells = game.piece().cells
	size_picker.text = "%d × %d" % [requested_size, requested_size]
	_clear_selection()
	_layout()
	_refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.background())
	if Palette.clockwork:
		var paper := ClockworkVisuals.texture(Themes.profile(Palette.theme_id()).environment.background)
		var factor: float = maxf(size.x / paper.get_width(), size.y / paper.get_height())
		var extent: Vector2 = paper.get_size() * factor
		draw_texture_rect(paper, Rect2((size - extent) * 0.5, extent), false)
	elif Palette.theme_id() == "vines":
		var paper := ThemeAssets.texture(Themes.profile("vines").environment.background)
		var factor: float = maxf(size.x / paper.get_width(), size.y / paper.get_height())
		var extent: Vector2 = paper.get_size() * factor
		draw_texture_rect(paper, Rect2((size - extent) * 0.5, extent), false)

func _menu_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.reparent(palette_list)
	menu_buttons.append(button)
	return button

func _build_settings() -> void:
	menu_title = Label.new()
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	palette_list.add_child(menu_title)
	menu_close = _menu_button("×", func(): palette_menu.hide())
	back_button = _menu_button("‹ Settings", func(): _show_menu("Settings"))
	for page: String in ["Themes", "Difficulty", "Gallery", "Sound Settings"]:
		settings_options.append(_menu_button(page, _open_gallery if page == "Gallery" else _show_menu.bind(page)))
	for id: String in Palette.THEMES:
		var option := _menu_button(Palette.theme_label(id), _request_theme.bind(id))
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.add_theme_constant_override("outline_size", 0)
		var tile := ThemeTile.new()
		tile.theme_id = id
		option.add_child(tile)
		theme_options.append(option)
	for level in range(3):
		difficulty_options.append(_menu_button(["Easy", "Moderate", "Difficult"][level], _request_difficulty.bind(level)))
	axes_button = _menu_button("Show axes on field: Off", _toggle_axes)
	axes_button.toggle_mode = true
	vine_colors_button = _menu_button("Vine colors", _show_menu.bind("Vine colors"))
	themes_back_button = _menu_button("‹ Themes", _show_menu.bind("Themes"))
	for i in range(Palette.PAIRS.size()):
		var option = PaletteChoice.new()
		option.pair_index = i
		option.text = Palette.PAIRS[i].name
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.pressed.connect(_choose_palette.bind(i))
		palette_list.add_child(option)
		palette_options.append(option)
		menu_buttons.append(option)
		themed_buttons.append(option)
	background_button = _menu_button("", _toggle_background)
	effects_button = _menu_button("", _toggle_effects)
	for control: Button in [size_picker, new_button]:
		control.reparent(palette_list)
		menu_buttons.append(control)

func _show_menu(page: String) -> void:
	menu_page = page
	palette_menu.show()
	dragging = false
	_layout_palette_menu(clampf(minf(size.x, size.y) * 0.018, 4, 12))
	_refresh_theme()
	_update_summaries(game.board)

func _layout_palette_menu(pad: float) -> void:
	for option: Control in menu_buttons:
		option.hide()
	var options: Array = settings_options
	if menu_page == "Themes":
		options = [back_button] + theme_options + ([vine_colors_button] if Palette.theme_id() == "vines" else [])
	elif menu_page == "Vine colors":
		options = [themes_back_button] + palette_options
	elif menu_page == "Difficulty":
		options = [back_button] + difficulty_options + [axes_button, size_picker, new_button]
	elif menu_page == "Sound Settings":
		options = [back_button, background_button, effects_button]
	menu_frame.apply_theme(Palette.theme_id())
	_refresh_menu_style()
	var inset: Vector4 = Frame.margins() if menu_frame.is_present() else Vector4(12, 12, 12, 12)
	var desired_height: float = (38 + 70 * options.size() + 12) * 1.5
	var width: float = minf(540, size.x - 2 * pad)
	var height: float = minf(desired_height, size.y - 2 * pad)
	var scale_factor: float = minf(1, minf(width / 540, height / desired_height))
	var content_width: float = width - inset.x - inset.z
	var content_height: float = height - inset.y - inset.w
	var title_height: float = 57 * scale_factor
	var gap: float = 9 * scale_factor
	var bottom: float = 18 * scale_factor
	var row_height: float = (content_height - title_height - bottom - gap * (options.size() - 1)) / options.size()
	var y: float = minf(palette_button.get_rect().end.y + pad, size.y - pad - height)
	_set_rect(palette_menu, Rect2((size.x - width) / 2, maxf(pad, y), width, height))
	_set_rect(palette_list, Rect2(Vector2(inset.x, inset.y), Vector2(content_width, content_height)))
	menu_frame.surround(Rect2(Vector2.ZERO, Vector2(content_width, content_height)))
	menu_title.text = menu_page
	menu_title.add_theme_font_size_override("font_size", maxi(12, roundi(40 * scale_factor)))
	var close_side: float = maxf(22, 48 * scale_factor)
	menu_close.show()
	menu_close.add_theme_font_size_override("font_size", maxi(11, roundi(28 * scale_factor)))
	_set_rect(menu_close, Rect2(content_width - close_side, 0, close_side, close_side))
	_set_rect(menu_title, Rect2(close_side + gap, 0, maxf(1, content_width - 2 * (close_side + gap)), title_height - gap))
	new_button.text = "Restart"
	axes_button.text = "Show axes on field: " + ("On" if board_view.show_axes else "Off")
	axes_button.set_pressed_no_signal(board_view.show_axes)
	background_button.text = "Background noises: " + ("On" if sounds.background_enabled else "Off")
	effects_button.text = "Special effects: " + ("On" if sounds.effects_enabled else "Off")
	for i in range(theme_options.size()):
		var id: String = Palette.THEMES[i]
		theme_options[i].text = ("✓ " if id == Palette.theme_id() else "") + Palette.theme_label(id)
		var tile: Control = theme_options[i].get_child(0)
		var tile_side: float = maxf(16, row_height - 16 * scale_factor)
		theme_options[i].set_meta("menu_right_inset", tile_side + 20)
		_set_rect(tile, Rect2(content_width - tile_side - 12, (row_height - tile_side) / 2, tile_side, tile_side))
	for i in range(difficulty_options.size()):
		difficulty_options[i].text = ("✓ " if i == difficulty else "") + ["Easy", "Moderate", "Difficult"][i]
	for i in range(options.size()):
		var button: Button = options[i]
		button.show()
		if palette_options.has(button):
			button.set_meta("menu_right_inset", row_height + 12)
		var text_width: float = content_width - (18 if theme_options.has(button) else 6) - float(button.get_meta("menu_right_inset", 6))
		var font_size: int = maxi(11, roundi(36 * scale_factor))
		var font: Font = button.get_theme_font("font")
		while font_size > 10 and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > text_width:
			font_size -= 1
		button.add_theme_font_size_override("font_size", font_size)
		_set_rect(button, Rect2(0, title_height + i * (row_height + gap), content_width, row_height))

func _refresh_menu_style() -> void:
	var menu_style := _style(Palette.controls())
	var inset: Vector4 = Frame.margins() if menu_frame.is_present() else Vector4(12, 12, 12, 12)
	menu_style.content_margin_left = inset.x
	menu_style.content_margin_top = inset.y
	menu_style.content_margin_right = inset.z
	menu_style.content_margin_bottom = inset.w
	menu_style.set_border_width_all(0 if menu_frame.is_present() else 2)
	menu_style.border_color = Color(Palette.tile(1), 0.6)
	palette_menu.add_theme_stylebox_override("panel", menu_style)

func _apply_button_style(button: Button, active: bool = false, color: int = 1) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var ink: Color = Palette.controls().lerp(Palette.tile(color), 0.30 if active else 0.20)
		if state == "hover": ink = ink.lightened(0.04)
		if state in ["pressed", "hover_pressed"]: ink = ink.darkened(0.025)
		var style := _style(ink)
		style.set_border_width_all(3 if active else 2)
		style.border_color = Color(Palette.tile(color), 0.6)
		if button in [undo_button, skip_button, erase_button]:
			style.content_margin_top = 2
			style.content_margin_bottom = 2
			style.content_margin_left = 3
			style.content_margin_right = 3
		if theme_options.has(button):
			style.content_margin_left = 18
			style.content_margin_right = float(button.get_meta("menu_right_inset", 70))
		elif palette_options.has(button):
			style.content_margin_right = float(button.get_meta("menu_right_inset", 70))
		button.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Palette.text())
	button.add_theme_color_override("font_disabled_color", Palette.muted())
	var focus := _style(Color.TRANSPARENT)
	focus.set_border_width_all(2)
	focus.border_color = Color(Palette.tile(color), 0.9)
	button.add_theme_stylebox_override("focus", focus)

func _refresh_theme() -> void:
	reef_background.visible = Palette.coral_reef
	zen_background.visible = Palette.zen_garden
	_sync_zen_background()
	for button: Button in themed_buttons:
		var active := false
		var color := 1
		if button in [blue_button, coral_button]:
			color = 1 if button == blue_button else 2
			active = game.current_color == color
		elif theme_options.has(button):
			active = Palette.THEMES[theme_options.find(button)] == Palette.theme_id()
		elif difficulty_options.has(button):
			active = difficulty_options.find(button) == difficulty
		elif button == background_button:
			active = sounds.background_enabled
		elif button == effects_button:
			active = sounds.effects_enabled
		elif button == axes_button:
			active = board_view.show_axes
		elif button == erase_button:
			active = erase_mode
		_apply_button_style(button, active, color)
	for button: Button in [blue_button, coral_button]:
		button.get_child(0).queue_redraw()
	_refresh_menu_style()
	menu_title.add_theme_color_override("font_color", Palette.text())
	queue_redraw()

func _sync_zen_background() -> void:
	if zen_background == null or not Palette.zen_garden: return
	var pitch: float = maxf(1.0, board_view.pitch)
	zen_background.material.set_shader_parameter("cell_origin", -(board_view.position + board_view._point(Vector2.ZERO)) / pitch)
	zen_background.material.set_shader_parameter("area_cells", size / pitch)

func _toggle_palette_menu() -> void:
	dragging = false
	if palette_menu.visible:
		palette_menu.hide()
	else:
		_show_menu("Settings")

func _confirm_new_game(message: String, action: Callable) -> void:
	dragging = false
	pending_change = action
	confirmation.dialog_text = message + "\nYour current game will be replaced."
	confirmation.popup_centered(Vector2i(mini(360, int(size.x - 24)), 160))

func _request_theme(id: String) -> void:
	if id not in Palette.THEMES or id == Palette.theme_id():
		return
	_confirm_new_game("Switch to %s and start a new game?" % Palette.theme_label(id), _select_theme.bind(id))

func _select_theme(id: String) -> void:
	if Palette.select_theme(id):
		_reset()

func _request_difficulty(level: int) -> void:
	if level == difficulty:
		return
	_confirm_new_game("Switch to %s and start a new game?" % ["Easy", "Moderate", "Difficult"][level], func():
		difficulty = level as Game.Difficulty
		_reset())

func _toggle_axes() -> void:
	board_view.show_axes = not board_view.show_axes
	_layout_palette_menu(clampf(minf(size.x, size.y) * 0.018, 4, 12))
	_refresh_theme()
	_update_summaries(game.board)

func _toggle_background() -> void:
	sounds.set_background_enabled(not sounds.background_enabled)
	_layout_palette_menu(8)

func _toggle_effects() -> void:
	sounds.set_effects_enabled(not sounds.effects_enabled)
	_layout_palette_menu(8)

func _choose_palette(index: int) -> void:
	if Palette.select(index):
		palette_menu.hide()
		_refresh()
		board_view.queue_redraw()
		for indicator: Dictionary in indicators:
			indicator.icon.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if saving or confirmation.visible:
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
		if palette_menu.visible:
			if event.keycode == KEY_ESCAPE:
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
	artwork.show_axes = false
	artwork.complete_background = true
	artwork.paper_background = Palette.clockwork
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
	if board_view.clockwork_visuals != null and artwork.clockwork_visuals != null:
		artwork.clockwork_visuals.copy_motion(board_view.clockwork_visuals)
	if board_view.zen_visuals != null and artwork.zen_visuals != null:
		artwork.zen_visuals.copy_landmark_order(board_view.zen_visuals)
	artwork.construction_state.copy_from(board_view.construction_state)
	await RenderingServer.frame_post_draw
	var result: Dictionary = gallery.save_design(snapshot, palette_index, viewport.get_texture().get_image(), theme, theme_version, surface_revision)
	viewport.queue_free()
	saving = false
	if result.ok:
		saved_fingerprint = fingerprint
	else:
		push_error("Could not save the garden to the local gallery.")
	_refresh()
