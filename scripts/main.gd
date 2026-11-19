extends Control

const ThemeAssets = preload("res://scripts/pattern/asset_library.gd")
const Rules = preload("res://scripts/rules.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Palette = preload("res://scripts/palette.gd")
const Interface = preload("res://scripts/interface_palette.gd")
const Game = preload("res://scripts/game.gd")
const Session = preload("res://scripts/game_session.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const BoardView = preload("res://scripts/board_view.gd")
const PieceView = preload("res://scripts/piece_view.gd")
const FloatingPiece = preload("res://scripts/floating_piece.gd")
const GrowthSounds = preload("res://scripts/growth_audio.gd")
const PaletteChoice = preload("res://scripts/palette_choice.gd")
const Gallery = preload("res://scripts/gallery.gd")
const GalleryExport = preload("res://scripts/gallery_export.gd")
const Frame = preload("res://scripts/board_frame.gd")
const ThemeTile = preload("res://scripts/theme_tile.gd")
const MENU_THEMES = {
	"vines": "Porcelain Vines",
	"coral_reef": "Coral Reef",
	"clockwork": "Mechanical Workshop",
}
const ColorMark = preload("res://scripts/color_mark.gd")
const ActionIcon = preload("res://scripts/action_icon.gd")
const SymmetryIcon = preload("res://scripts/symmetry_icon.gd")
var game = Game.new()
# Script-driven tests/render tools opt in explicitly with a temporary session path.
var session_enabled := not OS.get_cmdline_args().has("--script")
var session_store = Session.new()
var session_ready := false
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
var gallery_save: Button
var gallery_share: Button
var gallery_status: Label
var gallery_file_dialog: FileDialog
var gallery_exporter: Node
var gallery_export_busy := false
var gallery_export_source := ""
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
var replay_button: Button
var palette_button: Button
var palette_menu: PanelContainer
var palette_list: Control
var menu_frame: BoardFrame
var palette_options: Array = []
var indicators: Array = []
var size_picker: Button
var requested_size := 9

var menu_page := "Settings"
var menu_history: Array[String] = []
var pending_theme := ""
var gameplay_options: Array = []
var size_options: Array = []
var preset_summary: Label
var change_presets_button: Button
var gallery_back: Button
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
	var restored: Dictionary = session_store.load_state() if session_enabled else {}
	if not restored.is_empty() and restored.theme in MENU_THEMES:
		Palette.select_theme(restored.theme)
		Palette.select(int(restored.palette))
		game = Session.unpack(restored.game)
		requested_size = int(restored.preset_size)
		difficulty = int(restored.preset_difficulty) as Game.Difficulty
	else:
		restored = {}
	_build_interface()
	if restored.is_empty():
		cells = _offered_cells()
	else:
		cells = Session.decode_cells(restored.offered)
		has_hover = restored.hover and not game.over
		tray_moved = restored.tray_moved
		selected = Vector2i(int(restored.selected[0]),int(restored.selected[1]))
		board_view.show_axes = restored.axes
		board_view.restore_session_art(game.board,restored.get("art",{}))
	resized.connect(_layout)
	session_ready = true
	_layout()
	_refresh()

func _autosave() -> void:
	if not session_enabled or not session_ready: return
	var data := {"schema":"tiles.session.v1","theme":Palette.theme_id(),"palette":Palette.selected_index,
		"game":Session.pack(game),"preset_size":requested_size,"preset_difficulty":difficulty,"axes":board_view.show_axes,
		"art":board_view.session_art_state(),"offered":Session.encode_cells(cells),"hover":has_hover,"tray_moved":tray_moved,"selected":[selected.x,selected.y]}
	if not session_store.save_state(data): push_warning("Could not save the current game.")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST,NOTIFICATION_WM_GO_BACK_REQUEST]:
		_autosave()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and session_ready:
		get_tree().quit()

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
	piece_view = PieceView.new()
	piece_view.z_index = 30
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
	new_button = _button("Start", _start_new_game)
	size_picker = _button("Size", _show_menu.bind("Size"))
	palette_button = _button("⚙", _toggle_palette_menu)
	replay_button = _button("", _replay_game)
	for pair: Array in [[erase_button,"erase"],[undo_button,"undo"],[skip_button,"skip"],[palette_button,"settings"],[replay_button,"replay"],[flip_button,"flip"],[place_button,"place"]]:
		var action = ActionIcon.new()
		action.kind = pair[1]
		pair[0].text = ""
		pair[0].tooltip_text = {"erase":"Erase a tile", "undo":"Undo", "skip":"Skip this piece", "settings":"Settings", "replay":"Replay this game", "flip":"Flip the piece", "place":"Place the piece"}[pair[1]]
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
	return [place_button, undo_button, skip_button, erase_button, flip_button, blue_button, palette_button, replay_button, indicators[0].panel]

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
	var hardware := _layout_insets(view, false)
	var edge := 5.0 + maxf(hardware.x, hardware.z)
	var available_height := view.y - safe.y - safe.w
	var short_side := minf(view.x, view.y)
	var minimum_control := clampf(short_side * 0.05, 16, 36)
	var minimum_header := 3 * minimum_control + 2 * gap
	var minimum_dock := clampf(short_side * 0.1, 24, 64)
	# Keep the previous dock as the reference for the requested 20% increase.
	var old_caption := clampf(view.x * 0.04, 14, 22)
	var old_side := maxf(1, minf(view.x - 2 * maxf(hardware.x,hardware.z), available_height - 3 * gap - old_caption - minimum_header - minimum_dock))
	var old_spare := available_height - old_side - 3 * gap
	var old_dock := clampf(minf(old_side * 0.22, old_spare * 0.31), minimum_dock, old_spare - old_caption - minimum_header)
	var dock_side := old_dock * 1.2
	var old_header := old_spare - old_dock - old_caption
	var control_side := minf(old_side * 0.16, (old_header - 2 * gap) / 3)
	var button_inset := maxf(safe.x, safe.z) + gap
	var controls_left := button_inset
	var controls_right := view.x - button_inset - control_side
	var preview_left := controls_left + control_side + gap
	var preview_width := maxf(1, controls_right - gap - preview_left)
	var extent := Vector2i.ONE
	for definition: Dictionary in Rules.PIECES.values():
		var bounds := Vector2i.ONE
		for cell: Vector2i in definition.cells:
			bounds = bounds.max(cell + Vector2i.ONE)
		extent = extent.max(Vector2i(maxi(bounds.x,bounds.y),mini(bounds.x,bounds.y)))
	# New offers lie horizontally. Rotation may extend over the board without
	# changing the board geometry or the tile scale.
	var low := 28.0
	var high := maxf(low, view.x - 2 * edge)
	for iteration in range(18):
		var candidate := (low + high) / 2
		var unit := maxf(1, (candidate - 28) / maxi(1, game.board.size()))
		var preview_height := extent.y * unit + 2 * gap
		var header := maxf(3 * control_side + 2 * gap, preview_height)
		if candidate + header + dock_side + 2 * gap <= available_height and extent.x * unit <= preview_width:
			low = candidate
		else:
			high = candidate
	var side := maxf(1, view.x - 2 * edge) if view.y >= view.x else low
	var header_height := available_height - side - dock_side - 2 * gap
	var left := (view.x - side) / 2
	var top := safe.y
	for i in range(3):
		_set_rect([erase_button, undo_button, skip_button][i], Rect2(controls_left, top + i * (header_height - control_side) / 2, control_side, control_side))
	_set_rect(palette_button, Rect2(controls_right, top, control_side, control_side))
	_set_rect(replay_button, Rect2(controls_right, top + (header_height - control_side) / 2, control_side, control_side))
	_set_rect(flip_button, Rect2(controls_right, top + header_height - control_side, control_side, control_side))
	_set_rect(piece_view, Rect2(preview_left, top, preview_width, header_height))
	var board_top := top + header_height + gap
	_set_rect(board_view, Rect2(left, board_top, side, side))
	board_view.update_geometry()
	piece_view.cell_pitch = board_view.pitch
	var dock_y := board_top + side + gap
	var dock_width := view.x - 2 * button_inset
	for i in range(3):
		_set_rect([blue_button, place_button, indicators[0].panel][i], Rect2(button_inset + i * (dock_width - dock_side) / 2, dock_y, dock_side, dock_side))
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
	_autosave()

func _update_summaries(board: Array) -> void:
	var states: Array = Rules.symmetry_states(board)
	var occupied: bool = board.any(func(row: Array): return row.any(func(value): return value != 0))
	var indicator: Dictionary = indicators[0]
	indicator.icon.available = states.map(func(state: Dictionary): return state.possible)
	indicator.icon.complete = states.map(func(state: Dictionary): return occupied and state.complete)
	indicator.icon.saved = board == game.board and saved_fingerprint == _design_fingerprint()
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
	place_button.get_child(0).color = game.current_color
	place_button.get_child(0).queue_redraw()
	_update_summaries(_prediction_board())
	_update_floating_position()

# Preview symmetry on a copy; saving and game rules still use the committed board.
func _prediction_board() -> Array:
	if not has_hover or game.over or erase_mode or cells.is_empty() or not game.physical_placement(cells, selected).ok:
		return game.board
	var predicted: Array = game.board.duplicate(true)
	for cell: Vector2i in cells:
		predicted[selected.y + cell.y][selected.x + cell.x] = game.current_color
	return predicted

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
	_autosave()

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
	cells = _offered_cells()
	_clear_selection()
	_refresh()

func _clear_selection() -> void:
	tray_moved = false
	piece_view.cells = [] if game.over else cells
	piece_view.queue_redraw()
	has_hover = false
	dragging = false
	selected = Vector2i(-1, -1)

func _offered_cells() -> Array:
	if game.over: return []
	var offered: Array = game.piece().cells
	var bounds := Vector2i.ONE
	for cell: Vector2i in offered:
		bounds = bounds.max(cell + Vector2i.ONE)
	return Rules.rotate(offered) if bounds.y > bounds.x else offered

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
		cells = _offered_cells()
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
		cells = _offered_cells()
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

func _replay_game() -> void:
	if saving: return
	menu_history.clear()
	_reset(game.board.size(), game.difficulty)

func _reset(board_size: int = -1, level: int = -1) -> void:
	palette_menu.hide()
	erase_mode = false
	game = Game.new(requested_size if board_size < 0 else board_size, -1, difficulty if level < 0 else level)
	if board_view.zen_visuals != null and board_view.zen_visuals.pond != null:
		board_view.zen_visuals.pond.reset_choices()
	if board_view.zen_visuals != null and board_view.zen_visuals.trees != null:
		board_view.zen_visuals.trees.reset()
	board_view.show_settled(game.board)
	cells = _offered_cells()
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
	menu_close = _menu_button("×", _close_menu)
	back_button = _menu_button("‹", _back_menu)
	back_button.tooltip_text = "Back"
	menu_close.tooltip_text = "Close"
	for page: String in ["New Game", "Gameplay", "Gallery", "Audio"]:
		settings_options.append(_menu_button(page, _open_gallery if page == "Gallery" else _show_menu.bind(page)))
	for id: String in MENU_THEMES:
		var option := _menu_button(MENU_THEMES[id], _review_new_game.bind(id))
		option.set_meta("theme_id", id)
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.add_theme_constant_override("outline_size", 0)
		var tile := ThemeTile.new()
		tile.theme_id = id
		option.add_child(tile)
		theme_options.append(option)
	for level in range(3):
		difficulty_options.append(_menu_button(["Easy", "Moderate", "Hard"][level], _set_difficulty_preset.bind(level)))
	axes_button = _menu_button("Show axes on field: Off", _toggle_axes)
	axes_button.toggle_mode = true
	gameplay_options = [_menu_button("Difficulty", _show_menu.bind("Difficulty")), size_picker, axes_button]
	for n in [9,11]:
		size_options.append(_menu_button("%d × %d" % [n,n], _set_size_preset.bind(n)))
	preset_summary = Label.new()
	preset_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preset_summary.max_lines_visible = 5
	preset_summary.clip_text = true
	preset_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preset_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	palette_list.add_child(preset_summary)
	menu_buttons.append(preset_summary)
	change_presets_button = _menu_button("Change", _show_menu.bind("Gameplay"))
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

func _close_menu() -> void:
	palette_menu.hide()
	menu_history.clear()

func _back_menu() -> void:
	if menu_history.is_empty():
		_close_menu()
	else:
		_show_menu(menu_history.pop_back(), false)

func _show_menu(page: String, remember: bool = true) -> void:
	if page == "Settings":
		menu_history.clear()
	elif remember and palette_menu.visible and page != menu_page:
		menu_history.append(menu_page)
	menu_page = page
	palette_menu.show()
	dragging = false
	_layout_palette_menu(clampf(minf(size.x, size.y) * 0.018, 4, 12))
	_refresh_theme()
	_update_summaries(_prediction_board())

func _review_new_game(theme: String) -> void:
	if theme not in MENU_THEMES: return
	pending_theme = theme
	_show_menu("Game Presets")

func _set_difficulty_preset(level: int) -> void:
	difficulty = level as Game.Difficulty
	_back_menu()
	_autosave()

func _set_size_preset(n: int) -> void:
	requested_size = n
	_back_menu()
	_autosave()

func _start_new_game() -> void:
	if pending_theme not in MENU_THEMES: return
	Palette.select_theme(pending_theme)
	menu_history.clear()
	_reset()

func _layout_palette_menu(pad: float) -> void:
	for option: Control in menu_buttons:
		option.hide()
	var options: Array = settings_options
	if menu_page == "New Game":
		options = theme_options
	elif menu_page == "Game Presets":
		options = [preset_summary, change_presets_button, new_button]
	elif menu_page == "Gameplay":
		options = gameplay_options
	elif menu_page == "Difficulty":
		options = difficulty_options
	elif menu_page == "Size":
		options = size_options
	elif menu_page == "Audio":
		options = [ambience_volume_row, effects_volume_row]
	elif menu_page == "Vine colors":
		options = palette_options
	menu_frame.apply_theme(Palette.theme_id())
	_refresh_menu_style()
	var inset: Vector4 = Frame.margins() if menu_frame.is_present() else Vector4(12, 12, 12, 12)
	var row_units := options.size() + (1 if menu_page == "Game Presets" else 0)
	var desired_height: float = (38 + 70 * row_units + 12) * 1.5
	var width: float = minf(540, size.x - 2 * pad)
	var height: float = minf(desired_height, size.y - 2 * pad)
	var scale_factor: float = minf(1, minf(width / 540, height / desired_height))
	var content_width: float = width - inset.x - inset.z
	var content_height: float = height - inset.y - inset.w
	var title_height: float = 57 * scale_factor
	var gap: float = 9 * scale_factor
	var bottom: float = 18 * scale_factor
	var row_height: float = (content_height - title_height - bottom - gap * (options.size() - 1)) / row_units
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
	back_button.show()
	back_button.add_theme_font_size_override("font_size", maxi(11, roundi(28 * scale_factor)))
	_set_rect(back_button, Rect2(0, 0, close_side, close_side))
	new_button.text = "Start"
	gameplay_options[0].text = "Difficulty: " + ["Easy", "Moderate", "Hard"][difficulty]
	size_picker.text = "Size: %d × %d" % [requested_size,requested_size]
	preset_summary.text = "%s\nDifficulty: %s\nSize: %d × %d\nAxes: %s" % [MENU_THEMES.get(pending_theme, MENU_THEMES.get(Palette.theme_id(), Palette.theme_name())), ["Easy", "Moderate", "Hard"][difficulty], requested_size,requested_size,"On" if board_view.show_axes else "Off"]
	for i in range(size_options.size()):
		var n := 9 if i == 0 else 11
		size_options[i].text = ("✓ " if requested_size == n else "") + "%d × %d" % [n,n]
	axes_button.text = "Show axes on field: " + ("On" if board_view.show_axes else "Off")
	axes_button.set_pressed_no_signal(board_view.show_axes)
	background_button.text = "Background noises: " + ("On" if sounds.background_enabled else "Off")
	effects_button.text = "Special effects: " + ("On" if sounds.effects_enabled else "Off")
	for i in range(theme_options.size()):
		var id: String = theme_options[i].get_meta("theme_id")
		theme_options[i].text = ("✓ " if id == Palette.theme_id() else "") + MENU_THEMES[id]
		var tile: Control = theme_options[i].get_child(0)
		var tile_side: float = maxf(16, row_height - 16 * scale_factor)
		theme_options[i].set_meta("menu_right_inset", tile_side + 20)
		_set_rect(tile, Rect2(content_width - tile_side - 12, (row_height - tile_side) / 2, tile_side, tile_side))
	for i in range(difficulty_options.size()):
		difficulty_options[i].text = ("✓ " if i == difficulty else "") + ["Easy", "Moderate", "Hard"][i]
	var row_y := title_height
	for i in range(options.size()):
		if options[i] is Label:
			var label: Label = options[i]
			label.show()
			label.add_theme_font_size_override("font_size",maxi(12,roundi(26*scale_factor)))
			label.add_theme_color_override("font_color",Interface.text())
			_set_rect(label,Rect2(0,row_y,content_width,row_height*2))
			row_y += row_height*2 + gap
			continue
		if options[i] is VBoxContainer:
			var row: VBoxContainer = options[i]
			row.show()
			var label: Label = row.get_child(0)
			label.add_theme_font_size_override("font_size",maxi(12,roundi(28*scale_factor)))
			label.add_theme_color_override("font_color",Interface.text())
			_set_rect(row,Rect2(0,row_y,content_width,row_height))
			row_y += row_height + gap
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
		_set_rect(button, Rect2(0, row_y, content_width, row_height))
		row_y += row_height + gap

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
	reef_background.visible = Palette.coral_reef
	for button: Button in themed_buttons:
		var active := false
		var color := 1
		if button in [blue_button, place_button]:
			color = game.current_color
			active = button == blue_button
		elif theme_options.has(button):
			active = button.get_meta("theme_id") == Palette.theme_id()
		elif difficulty_options.has(button):
			active = difficulty_options.find(button) == difficulty
		elif size_options.has(button):
			active = requested_size == (9 if size_options.find(button) == 0 else 11)
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
	for button: Button in [erase_button, undo_button, skip_button, palette_button, replay_button, flip_button, place_button]:
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
	_update_summaries(_prediction_board())
	_autosave()

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
				_gallery_back()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and erase_mode:
			erase_mode = false
			_refresh()
			get_viewport().set_input_as_handled()
			return
		if palette_menu.visible:
			if event.keycode == KEY_ESCAPE:
				_back_menu()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_R: _rotate()
			KEY_F: _flip()
			KEY_C: _choose_color(Rules.CORAL if game.current_color == Rules.BLUE else Rules.BLUE)
			_: return
		get_viewport().set_input_as_handled()

func _build_gallery() -> void:
	gallery_exporter = GalleryExport.new()
	gallery_exporter.completed.connect(_gallery_export_completed)
	add_child(gallery_exporter)
	gallery_file_dialog = FileDialog.new()
	gallery_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	gallery_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	gallery_file_dialog.filters = PackedStringArray(["*.png ; PNG image"])
	gallery_file_dialog.title = "Save Image"
	gallery_file_dialog.file_selected.connect(_save_gallery_file)
	gallery_file_dialog.canceled.connect(func(): _gallery_export_completed("save", false, ""))
	add_child(gallery_file_dialog)
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
	gallery_back = _button("‹", _gallery_back)
	gallery_back.tooltip_text = "Back"
	gallery_close.tooltip_text = "Close"
	gallery_page = _button("0 / 0", func(): pass)
	gallery_save = _button("Save to Photos" if OS.has_feature("android") else "Save Image", _export_gallery_image.bind(false))
	gallery_share = _button("Share", _export_gallery_image.bind(true))
	gallery_share.tooltip_text = "Open the phone's sharing menu" if gallery_exporter.can_share() else gallery_exporter.unavailable_message()
	gallery_status = Label.new()
	gallery_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gallery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gallery_status.max_lines_visible = 2
	gallery_status.clip_text = true
	gallery_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gallery_panel.add_child(gallery_status)
	for control: Control in [gallery_previous, gallery_next, gallery_back, gallery_close, gallery_page, gallery_save, gallery_share]:
		control.reparent(gallery_panel)

func _layout_gallery(pad: float) -> void:
	_set_rect(gallery_panel, Rect2(Vector2.ZERO, size))
	var height: float = clampf(size.y * 0.08, 32, 56)
	_set_rect(gallery_close, Rect2(size.x - pad - height, pad, height, height))
	_set_rect(gallery_back, Rect2(pad,pad,height,height))
	var status_height := clampf(size.y * 0.045, 24, 44)
	var navigation_y := size.y - pad - height
	var status_y := navigation_y - pad - status_height
	var actions_y := status_y - pad - height
	_set_rect(gallery_image, Rect2(pad, height+2*pad, size.x-2*pad, maxf(1,actions_y-height-3*pad)))
	_layout_row([gallery_save,gallery_share],Rect2(pad,actions_y,size.x-2*pad,height),pad)
	_set_rect(gallery_status,Rect2(pad,status_y,size.x-2*pad,status_height))
	gallery_status.add_theme_font_size_override("font_size",clampi(roundi(size.x*0.025),11,18))
	_layout_row([gallery_previous, gallery_page, gallery_next], Rect2(pad,navigation_y,size.x-2*pad,height),pad)

func _open_gallery() -> void:
	palette_menu.hide()
	dragging = false
	gallery_entries = gallery.entries()
	gallery_index = 0
	_show_gallery_page()
	gallery_panel.show()

func _gallery_back() -> void:
	gallery_panel.hide()
	_show_menu("Settings")

func _turn_gallery(direction: int) -> void:
	gallery_index = clampi(gallery_index + direction, 0, maxi(0, gallery_entries.size() - 1))
	_show_gallery_page()

func _show_gallery_page() -> void:
	gallery_image.texture = null if gallery_entries.is_empty() else gallery.picture(gallery_entries[gallery_index])
	gallery_page.text = "%d / %d" % [0 if gallery_entries.is_empty() else gallery_index + 1, gallery_entries.size()]
	if not gallery_export_busy:
		gallery_status.text = "Your saved designs will appear here." if gallery_entries.is_empty() else (gallery_exporter.unavailable_message() if OS.has_feature("android") and not gallery_exporter.can_share() else "")
	_refresh_gallery_actions()

func _refresh_gallery_actions() -> void:
	var empty := gallery_entries.is_empty()
	gallery_save.disabled = empty or gallery_export_busy or (OS.has_feature("android") and not gallery_exporter.can_share())
	gallery_share.disabled = empty or gallery_export_busy or not gallery_exporter.can_share()
	gallery_previous.disabled = gallery_export_busy or gallery_index <= 0
	gallery_next.disabled = gallery_export_busy or gallery_index >= gallery_entries.size()-1

func _export_gallery_image(share: bool) -> void:
	if gallery_entries.is_empty() or gallery_export_busy: return
	var record: Dictionary = gallery_entries[gallery_index]
	var path: String = gallery.image_path(record)
	if path.is_empty():
		gallery_status.text = "This image is no longer available."
		return
	gallery_export_busy = true
	_refresh_gallery_actions()
	if share:
		gallery_status.text = "Opening sharing menu…"
		gallery_exporter.share_image(path,str(record.id))
	elif OS.has_feature("android"):
		gallery_status.text = "Saving image…"
		gallery_exporter.save_image(path,str(record.id))
	else:
		gallery_export_source = path
		gallery_file_dialog.current_file = "Tiles_"+str(record.id)+".png"
		var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if DirAccess.dir_exists_absolute(pictures): gallery_file_dialog.current_dir = pictures
		gallery_file_dialog.popup_centered(Vector2i(mini(700,int(size.x-24)),mini(500,int(size.y-24))))

func _save_gallery_file(destination: String) -> void:
	var result := GalleryExport.export_copy(gallery_export_source,destination)
	_gallery_export_completed("save",result.ok,result.message)

func _gallery_export_completed(_operation: String, _success: bool, message: String) -> void:
	gallery_export_busy = false
	gallery_export_source = ""
	gallery_status.text = message
	_refresh_gallery_actions()

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
