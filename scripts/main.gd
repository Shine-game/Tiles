extends Control

const ThemeAssets = preload("res://scripts/pattern/asset_library.gd")
const Rules = preload("res://scripts/rules.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Palette = preload("res://scripts/palette.gd")
const Interface = preload("res://scripts/interface_palette.gd")
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
const ActionIcon = preload("res://scripts/action_icon.gd")
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
var tray_moved := false
var rotate_hint: Label
var theme_caption: Label
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
var ambience_volume_row: VBoxContainer
var effects_volume_row: VBoxContainer
var ambience_volume_slider: HSlider
var effects_volume_slider: HSlider
var background_button: Button
var effects_button: Button
var axes_button: Button
var menu_title: Label
var confirmation: ConfirmationDialog
var pending_change: Callable
var themed_buttons: Array = []
var reef_background: ColorRect
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
	var panel := _button("", _save_design)
	panel.tooltip_text = "Show symmetries / save a symmetric design"
	var icon = SymmetryIcon.new()
	icon.combined = true
	panel.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	indicators.append({"panel": panel, "icon": icon})
	rotate_hint = Label.new()
	rotate_hint.text = "Tap the piece to rotate it."
	rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rotate_hint)
	theme_caption = Label.new()
	theme_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(theme_caption)
	piece_view = PieceView.new()
	piece_view.z_index = 2
	add_child(piece_view)
	board_view = BoardView.new()
	board_view.flush_frame = true
	add_child(board_view)
	board_view.z_index = 3
	board_view.growth_finished.connect(_preview)
	sounds = GrowthSounds.new()
	add_child(sounds)
	board_view.growth_started.connect(sounds.begin)
	board_view.flower_opened.connect(sounds.bloom)
	board_view.growth_finished.connect(sounds.finish)
	board_view.growth_canceled.connect(sounds.cancel)
	sounds.attach_board(board_view)
	flip_button = _button("Flip", _flip)
	blue_button = _button("", func(): _choose_color(Rules.CORAL if game.current_color == Rules.BLUE else Rules.BLUE))
	for color_button: Button in [blue_button]:
		var mark := ColorMark.new()
		mark.color = game.current_color
		color_button.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		color_button.tooltip_text = "Color %d" % mark.color
	blue_button.toggle_mode = true
	blue_button.get_child(0).paired = true
	blue_button.tooltip_text = "Switch piece color"
	place_button = _button("Place", _place)
	undo_button = _button("↶ 3", _undo)
	skip_button = _button("⇥ 3", _skip)
	erase_button = _button("⌫ 3", _toggle_erase)
	new_button = _button("+", func(): _ask_reset(game.board.size()))
	size_picker = _button("9 × 9", func(): _ask_reset(11 if game.board.size() == 9 else 9))
	palette_button = _button("⚙", _toggle_palette_menu)
	for pair: Array in [[erase_button,"erase"],[undo_button,"undo"],[skip_button,"skip"],[palette_button,"settings"],[flip_button,"flip"],[place_button,"place"]]:
		var action = ActionIcon.new()
		action.kind = pair[1]
		pair[0].text = ""
		pair[0].tooltip_text = {"erase":"Erase a tile", "undo":"Undo", "skip":"Skip this piece", "settings":"Settings", "flip":"Flip the piece", "place":"Place the piece"}[pair[1]]
		pair[0].add_child(action)
		action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	return [place_button, undo_button, skip_button, erase_button, flip_button, blue_button, palette_button, indicators[0].panel]

func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _layout_row(controls: Array, rect: Rect2, gap: float) -> void:
	var width: float = (rect.size.x - gap * (controls.size() - 1)) / controls.size()
	for i in range(controls.size()):
		_set_rect(controls[i], Rect2(rect.position + Vector2(i * (width + gap), 0), Vector2(width, rect.size.y)))

func _layout_insets(view: Vector2, controls: bool = true) -> Vector4:
	var short_side := minf(view.x, view.y)
	var side := clampf(short_side * 0.04, 12, 32) if controls else 0.0
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
				var clearance := clampf(short_side * 0.015, 6, 12) if controls else 0.0
				inset.x = maxf(inset.x, safe.position.x * factor.x + clearance)
				inset.y = maxf(inset.y, safe.position.y * factor.y + clearance)
				inset.z = maxf(inset.z, (window.x - safe.end.x) * factor.x + clearance)
				inset.w = maxf(inset.w, (window.y - safe.end.y) * factor.y + clearance)
	return inset

func _layout() -> void:
	if not is_instance_valid(board_view) or size.x <= 0 or size.y <= 0:
		return
	var view := size
	var safe := _layout_insets(view)
	var gap := clampf(view.x * 0.025, 6, 14)
	# Fill portrait width; compact windows reserve enough room for usable controls.
	var hardware := _layout_insets(view, false)
	var edge := maxf(hardware.x, hardware.z)
	var available_height := view.y - safe.y - safe.w
	var short_side := minf(view.x, view.y)
	var minimum_control := clampf(short_side * 0.05, 16, 36)
	var minimum_header := 3 * minimum_control + 2 * gap
	var minimum_dock := clampf(short_side * 0.1, 24, 64)
	var caption_height := clampf(view.x * 0.04, 14, 22)
	var side := maxf(1, minf(view.x - 2 * edge, available_height - 3 * gap - caption_height - minimum_header - minimum_dock))
	var spare := available_height - side - 3 * gap
	var dock_side := clampf(minf(side * 0.22, spare * 0.31), minimum_dock, spare - caption_height - minimum_header)
	var header_height := spare - dock_side - caption_height
	var control_side := minf(side * 0.16, (header_height - 2 * gap) / 3)
	var left := (view.x - side) * 0.5
	var top := safe.y
	var controls_left := left + gap
	var controls_right := left + side - gap - control_side
	for i in range(3):
		_set_rect([erase_button, undo_button, skip_button][i], Rect2(controls_left, top + i * (header_height - control_side) / 2, control_side, control_side))
	_set_rect(palette_button, Rect2(controls_right, top, control_side, control_side))
	_set_rect(flip_button, Rect2(controls_right, top + header_height - control_side, control_side, control_side))
	var preview_left := controls_left + control_side + gap
	var preview_width := controls_right - gap - preview_left
	var hint_height := clampf(view.x * 0.05, 16, 26)
	_set_rect(rotate_hint, Rect2(preview_left, top, preview_width, hint_height))
	rotate_hint.add_theme_font_size_override("font_size", clampi(roundi(preview_width / 16), 10, 18))
	_set_rect(piece_view, Rect2(preview_left, top + hint_height + gap, preview_width, maxf(1, header_height - hint_height - gap)))
	var board_top := top + header_height + gap
	_set_rect(board_view, Rect2(left, board_top, side, side))
	board_view.update_geometry()
	piece_view.cell_pitch = minf(board_view.pitch, minf(preview_width / 4, piece_view.size.y / 4))
	_set_rect(theme_caption, Rect2(left + gap, board_top + side, side - 2 * gap, caption_height))
	theme_caption.text = "Theme: " + Palette.theme_label(Palette.theme_id())
	theme_caption.add_theme_font_size_override("font_size", clampi(roundi(caption_height * 0.65), 10, 16))
	var dock_y := board_top + side + caption_height + gap
	var dock_width := maxf(side, 3 * dock_side + 4 * gap)
	var dock_left := (view.x - dock_width) / 2
	for i in range(3):
		_set_rect([blue_button, place_button, indicators[0].panel][i], Rect2(dock_left + gap + i * (dock_width - 2 * gap - dock_side) / 2, dock_y, dock_side, dock_side))
	for control: Control in _controls():
		control.add_theme_font_size_override("font_size", clampi(roundi(control_side * 0.34), 12, 26))
	_set_rect(reef_background, Rect2(Vector2.ZERO, view))
	_layout_palette_menu(gap)
	_layout_gallery(gap)
	board_view.queue_redraw()
	piece_view.queue_redraw()
	queue_redraw()
	if has_hover:
		_update_floating_position()

func _refresh() -> void:
	_refresh_theme()
	board_view.sync_board(game.board)
	_layout()
	piece_view.cells = [] if game.over or tray_moved else cells
	rotate_hint.visible = not game.over and not tray_moved
	piece_view.color = game.current_color
	piece_view.queue_redraw()
	undo_button.get_child(0).count = game.undo_left
	skip_button.get_child(0).count = game.skip_left
	erase_button.get_child(0).count = game.erase_left
	undo_button.disabled = game.history.is_empty() or game.undo_left <= 0 or saving
	skip_button.disabled = game.over or game.skip_left <= 0 or saving
	erase_button.disabled = game.erase_left <= 0 or not game.board.any(func(row: Array): return row.any(func(value): return value != 0)) or saving
	for button: Button in [flip_button, blue_button]:
		button.disabled = game.over
	for button: Button in [blue_button]:
		var chosen := true
		button.set_pressed_no_signal(chosen)
		_apply_button_style(button, chosen, game.current_color)
		button.get_child(0).queue_redraw()
	blue_button.get_child(0).color = game.current_color
	_preview()

func _update_summaries(board: Array) -> void:
	var states: Array = Rules.symmetry_states(board)
	var occupied: bool = board.any(func(row: Array): return row.any(func(value): return value != 0))
	var indicator: Dictionary = indicators[0]
	indicator.icon.available = states.map(func(state: Dictionary): return state.possible)
	indicator.icon.complete = states.map(func(state: Dictionary): return occupied and state.complete)
	indicator.icon.saved = saved_fingerprint == _design_fingerprint()
	indicator.icon.queue_redraw()
	indicator.panel.disabled = not _can_save() or saving
	_apply_button_style(indicator.panel, indicator.icon.complete.any(func(value): return value))

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
			tray_moved = true
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
	tray_moved = false
	piece_view.cells = [] if game.over else cells
	piece_view.queue_redraw()
	rotate_hint.visible = not game.over
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
	draw_rect(Rect2(Vector2.ZERO, size), Interface.background())
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
	ambience_volume_row = _volume_control("Ambience", sounds.background_volume, func(value): sounds.set_background_volume(value/100.0))
	effects_volume_row = _volume_control("Effects", sounds.effects_volume, func(value): sounds.set_effects_volume(value/100.0))
	ambience_volume_slider = ambience_volume_row.get_child(1)
	effects_volume_slider = effects_volume_row.get_child(1)
	for control: Button in [size_picker, new_button]:
		control.reparent(palette_list)
		menu_buttons.append(control)

func _volume_control(title: String, value: float, changed: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s volume: %d%%" % [title,roundi(value*100)]
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value=0
	slider.max_value=100
	slider.step=1
	slider.value=value*100
	slider.size_flags_vertical=Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y=32
	slider.tooltip_text=title+" volume"
	slider.value_changed.connect(func(amount):
		label.text="%s volume: %d%%" % [title,roundi(amount)]
		changed.call(amount))
	row.add_child(slider)
	palette_list.add_child(row)
	menu_buttons.append(row)
	return row

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
		options = [back_button, background_button, ambience_volume_row, effects_button, effects_volume_row]
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
		if options[i] is VBoxContainer:
			var row: VBoxContainer = options[i]
			row.show()
			_set_rect(row,Rect2(0,title_height+i*(row_height+gap),content_width,row_height))
			var label: Label = row.get_child(0)
			label.add_theme_font_size_override("font_size",maxi(12,roundi(28*scale_factor)))
			label.add_theme_color_override("font_color",Interface.text())
			continue
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
	var menu_style := _style(Interface.controls())
	var inset: Vector4 = Frame.margins() if menu_frame.is_present() else Vector4(12, 12, 12, 12)
	menu_style.content_margin_left = inset.x
	menu_style.content_margin_top = inset.y
	menu_style.content_margin_right = inset.z
	menu_style.content_margin_bottom = inset.w
	menu_style.set_border_width_all(0 if menu_frame.is_present() else 2)
	menu_style.border_color = Color(Interface.accent(), 0.6)
	palette_menu.add_theme_stylebox_override("panel", menu_style)

func _apply_button_style(button: Button, active: bool = false, color: int = 1) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var ink: Color = Interface.controls().lerp(Interface.accent(color), 0.30 if active else 0.20)
		if state == "hover": ink = ink.lightened(0.04)
		if state in ["pressed", "hover_pressed"]: ink = ink.darkened(0.025)
		var style := _style(ink)
		style.set_border_width_all(3 if active else 2)
		style.border_color = Color(Interface.accent(color), 0.6)
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
		button.add_theme_color_override(state, Interface.text())
	button.add_theme_color_override("font_disabled_color", Interface.muted())
	var focus := _style(Color.TRANSPARENT)
	focus.set_border_width_all(2)
	focus.border_color = Color(Interface.accent(color), 0.9)
	button.add_theme_stylebox_override("focus", focus)

func _refresh_theme() -> void:
	rotate_hint.add_theme_color_override("font_color", Interface.text())
	theme_caption.add_theme_color_override("font_color", Interface.text())
	reef_background.visible = Palette.coral_reef
	for button: Button in themed_buttons:
		var active := false
		var color := 1
		if button in [blue_button]:
			color = game.current_color
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
	for button: Button in [blue_button]:
		button.get_child(0).queue_redraw()
	for button: Button in [erase_button, undo_button, skip_button, palette_button, flip_button, place_button]:
		button.get_child(0).queue_redraw()
	_refresh_menu_style()
	menu_title.add_theme_color_override("font_color", Interface.text())
	queue_redraw()

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
