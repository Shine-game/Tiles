extends Control
signal interface_changed(restyled: bool)
signal design_save_finished(result: Dictionary)

const ThemeAssets = preload("res://scripts/pattern/asset_library.gd")
const PlayLayout = preload("res://scripts/play_layout.gd")
const Geometry = preload("res://scripts/piece_geometry.gd")
const Gesture = preload("res://scripts/piece_gesture.gd")
const Preview = preload("res://scripts/placement_preview.gd")
var piece_gesture = Gesture.new()
const Rules = preload("res://scripts/rules.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Palette = preload("res://scripts/palette.gd")
const Introduction = preload("res://scripts/introduction.gd")
const IntroModel = preload("res://scripts/tutorial_model.gd")
var introduction: Control
var intro_progress_path := IntroModel.PATH
const TouchSlider = preload("res://scripts/touch_slider.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")
const MenuConfirmation = preload("res://scripts/menu_confirmation.gd")
const InterfaceTheme = preload("res://scripts/interface_theme.gd")
const Interface = preload("res://scripts/interface_palette.gd")
const PlayerActions = preload("res://scripts/player_actions.gd")
var player_actions = PlayerActions.new()
const Game = preload("res://scripts/game.gd")
const Session = preload("res://scripts/game_session.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const BoardView = preload("res://scripts/board_view.gd")
const PieceView = preload("res://scripts/piece_view.gd")
const FloatingPiece = preload("res://scripts/floating_piece.gd")
const ThemeAudio = preload("res://scripts/theme_audio.gd")
const PaletteChoice = preload("res://scripts/palette_choice.gd")
const Gallery = preload("res://scripts/gallery.gd")
const GalleryPanel = preload("res://scripts/gallery_panel.gd")
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
var session_enabled := Session.autosave_enabled(OS.get_cmdline_args())
var session_store = Session.new()
var session_ready := false
var cells: Array = []
var has_hover := false
var dragging: bool:
	get: return piece_gesture.active and piece_gesture.tool == "piece"
	set(value):
		if not value: piece_gesture.cancel()
const TAP_LIMIT := Gesture.TAP_LIMIT
const GESTURE_SLOP := Gesture.SLOP
var gesture_age: float:
	get: return piece_gesture.age
	set(value): piece_gesture.age = value

var tray_moved := false
var erase_mode := false
var erase_target := Vector2i(-1, -1)
const ArtworkCapture = preload("res://scripts/artwork_capture.gd")
var artwork_capture = ArtworkCapture.new()
var save_error_dialog: AcceptDialog
var saving := false
var saved_fingerprint := ""
var gallery = Gallery.new()
var gallery_panel: GalleryPanel
var skip_button: Button
var erase_button: Button
var grabbed_cell: Vector2i:
	get: return piece_gesture.grabbed
	set(value): piece_gesture.grabbed = value
var last_pointer := Vector2.ZERO
var selected := Vector2i(-1, -1)
var floating_piece: Control
var board_view: Control
var sounds: ThemeAudio
var piece_view: Control
var undo_button: Button
var place_button: Button
var flip_button: Button
var blue_button: Button
var new_button: Button
var replay_button: Button
var palette_button: Button
var palette_menu: SettingsMenu
var palette_list: Control
var menu_frame: BoardFrame
var palette_options: Array = []
var indicators: Array = []
var size_picker: Button
var requested_size := 9

var menu_page: String:
	get: return palette_menu.page
var pending_theme := ""
var gameplay_options: Array = []
var size_options: Array = []
var preset_summary: Label
var change_presets_button: Button
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
var confirmation: MenuConfirmation
var confirmation_blocker: Control
var game_over_message: Label
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
	_refresh_theme()
	_layout()
	_refresh_and_save()
	if session_enabled: _maybe_introduction.call_deferred(not restored.is_empty())

func _maybe_introduction(returning_player: bool) -> void:
	var progress := IntroModel.progress(intro_progress_path)
	if progress.done: return
	if returning_player and not progress.started:
		var error := IntroModel.save_checkpoint("rotate",true,intro_progress_path)
		if error != OK: push_warning("Could not save tutorial progress: "+error_string(error))
		return
	_start_introduction(progress.lesson_id,progress.checkpoint)

func _start_introduction(lesson_id: String = "rotate", checkpoint: String = "") -> void:
	if introduction != null: return
	palette_menu.hide()
	dragging = false
	introduction = Introduction.new()
	introduction.host = self
	introduction.lesson_id = lesson_id
	introduction.initial_checkpoint = checkpoint
	introduction.progress_path = intro_progress_path
	var active_tutorial: Control = introduction
	introduction.finished.connect(func():
		if introduction == active_tutorial: introduction = null)
	add_child(introduction)
	introduction.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.clip_text = true
	add_child(button)
	themed_buttons.append(button)
	button.button_down.connect(InterfaceTheme.press_children.bind(button, true))
	button.button_up.connect(InterfaceTheme.press_children.bind(button, false))
	button.pressed.connect(callback)
	return button

func _build_interface() -> void:
	var panel := _button("", _save_design)
	panel.tooltip_text = "Show symmetries / save a symmetric design"
	var icon = SymmetryIcon.new()
	icon.name = "ControlIcon"
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
	sounds = ThemeAudio.new()
	add_child(sounds)
	sounds.attach_board(board_view)
	player_actions.completed.connect(sounds.action_completed)
	flip_button = _button("Flip", _flip)
	blue_button = _button("", func(): _choose_color(Rules.CORAL if game.current_color == Rules.BLUE else Rules.BLUE))
	for color_button: Button in [blue_button]:
		var mark := ColorMark.new()
		mark.name = "ControlIcon"
		mark.color = game.current_color
		color_button.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		color_button.tooltip_text = "Color %d" % mark.color
	blue_button.get_child(0).paired = true
	blue_button.tooltip_text = "Switch piece color"
	place_button = _button("Place", _place)
	undo_button = _button("↶ 3", _undo)
	skip_button = _button("⇥ 3", _skip)
	erase_button = _button("⌫ 3", _toggle_erase)
	erase_button.toggle_mode = true
	new_button = _button("Start", _start_new_game)
	size_picker = _button("Size", _cycle_size_preset)
	palette_button = _button("⚙", _toggle_palette_menu)
	replay_button = _button("", _replay_game)
	for pair: Array in [[erase_button,"erase"],[undo_button,"undo"],[skip_button,"skip"],[palette_button,"settings"],[replay_button,"replay"],[flip_button,"flip"],[place_button,"place"]]:
		var action = ActionIcon.new()
		action.name = "ControlIcon"
		action.kind = pair[1]
		pair[0].text = ""
		pair[0].tooltip_text = {"erase":"Erase a tile", "undo":"Undo", "skip":"Skip this piece", "settings":"Settings", "replay":"Start new game", "flip":"Flip the piece", "place":"Place the piece"}[pair[1]]
		pair[0].add_child(action)
		action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palette_menu = SettingsMenu.new()
	palette_menu.page_changed.connect(_settings_page_changed)
	palette_menu.closed.connect(func(): interface_changed.emit(false))
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
	game_over_message = Label.new()
	game_over_message.text = "No symmetries left."
	game_over_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_message.z_index = 40
	add_child(game_over_message)
	confirmation_blocker = Control.new()
	confirmation_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_blocker.z_index = 299
	confirmation_blocker.hide()
	add_child(confirmation_blocker)
	confirmation = MenuConfirmation.new()
	confirmation.z_index = 300
	confirmation.visibility_changed.connect(func(): confirmation_blocker.visible = confirmation.visible)
	confirmation.confirmed.connect(func():
		var action := pending_change
		pending_change = Callable()
		if action.is_valid(): action.call())
	confirmation.canceled.connect(func(): pending_change = Callable())
	add_child(confirmation)
	themed_buttons.append_array([confirmation.get_ok_button(), confirmation.get_cancel_button()])
	for button: Button in [confirmation.get_ok_button(), confirmation.get_cancel_button()]:
		button.button_down.connect(InterfaceTheme.press_children.bind(button, true))
		button.button_up.connect(InterfaceTheme.press_children.bind(button, false))
	gallery_panel = GalleryPanel.new()
	add_child(gallery_panel)
	gallery_panel.configure(gallery, _button)
	gallery_panel.back_requested.connect(_show_menu.bind("Settings"))
	floating_piece = FloatingPiece.new()
	floating_piece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floating_piece)
	for control: Control in _controls():
		control.z_index = 50

func button_icon(button: Button) -> Control:
	return button.get_node("ControlIcon")

func _refresh_after_tutorial() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or introduction != null: return
	_layout()
	_refresh_and_save()

func _controls() -> Array:
	return [place_button, undo_button, skip_button, erase_button, flip_button, blue_button, palette_button, replay_button, indicators[0].panel]

func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

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
	var gap := clampf(view.x * 0.015, 4, 10)
	if view.x > view.y: gap = 2.0
	var hardware := _layout_insets(view, false)
	var pixel_scale := maxf(0.001, get_viewport().get_stretch_transform().x.length())
	var edge := 10.0 / pixel_scale + maxf(hardware.x, hardware.z)
	var layout := PlayLayout.measure(view, safe, edge, gap, game.board.size())
	var side: float = layout.board_side
	var header_height: float = layout.header_height
	var control_side: float = layout.control_side
	var dock_side: float = layout.dock_side
	var dock_padding: float = layout.dock_padding
	var dock_vertical_padding: float = layout.dock_vertical_padding
	var controls_left := maxf(safe.x, safe.z) + gap
	var controls_right := view.x - controls_left - control_side
	var preview_left := controls_left + control_side + gap
	var preview_width := maxf(1, controls_right - gap - preview_left)
	var left := (view.x - side) / 2
	var top := safe.y
	for i in range(3):
		_set_rect([erase_button, undo_button, skip_button][i], Rect2(controls_left, top + i * (header_height - control_side) / 2, control_side, control_side))
	_set_rect(palette_button, Rect2(controls_right, top, control_side, control_side))
	_set_rect(replay_button, Rect2(controls_right, top + (header_height - control_side) / 2, control_side, control_side))
	_set_rect(flip_button, Rect2(controls_right, top + header_height - control_side, control_side, control_side))
	_set_rect(piece_view, Rect2(preview_left, top, preview_width, header_height))
	_set_rect(game_over_message, piece_view.get_rect())
	var board_top := top + header_height + gap
	_set_rect(board_view, Rect2(left, board_top, side, side))
	board_view.update_geometry()
	piece_view.cell_pitch = board_view.pitch
	var dock_y := board_top + side + dock_vertical_padding
	for i in range(3):
		_set_rect([blue_button, place_button, indicators[0].panel][i], Rect2(dock_padding + i * (dock_side + 2 * dock_padding), dock_y, dock_side, dock_side))
	for control: Control in _controls():
		control.add_theme_font_size_override("font_size", clampi(roundi(control_side * 0.34), 12, 26))
	_set_rect(reef_background, Rect2(Vector2.ZERO, view))
	_layout_palette_menu(gap)
	_layout_confirmation(gap)
	gallery_panel.layout(size, gap)
	board_view.queue_redraw()
	piece_view.queue_redraw()
	queue_redraw()
	if has_hover:
		_update_floating_position()

func _refresh() -> void:
	board_view.sync_board(game.board)
	game_over_message.visible = game.over and game.lost and introduction == null
	piece_view.cells = [] if game.over or tray_moved else cells
	piece_view.color = game.current_color
	piece_view.queue_redraw()
	undo_button.get_child(0).count = game.undo_left
	skip_button.get_child(0).count = game.skip_left
	erase_button.get_child(0).count = game.erase_left
	# Availability is enforced by the action policy, not by changing button faces.
	for button: Button in _controls():
		button.disabled = false
	erase_button.set_pressed_no_signal(erase_mode)
	blue_button.get_child(0).queue_redraw()
	blue_button.get_child(0).color = game.current_color
	_preview()
	interface_changed.emit(false)

func _refresh_and_save() -> void:
	_refresh()
	_autosave()

func _update_summaries(board: Array) -> void:
	var states: Array = Rules.symmetry_states(board)
	board_view.set_axis_states(states)
	var occupied: bool = board.any(func(row: Array): return row.any(func(value): return value != 0))
	var indicator: Dictionary = indicators[0]
	indicator.icon.available = states.map(func(state: Dictionary): return state.possible)
	indicator.icon.complete = states.map(func(state: Dictionary): return occupied and state.complete)
	indicator.icon.saved = board == game.board and saved_fingerprint == _design_fingerprint()
	indicator.icon.queue_redraw()
	indicator.panel.disabled = false
	_apply_button_style(indicator.panel)

func _surface_revision(theme: String) -> String:
	var revision: String = Platform.surface_revision(theme) + "/complete-background-v1/flush-frame-v2/hires2160-v1"
	if Themes.profile(theme).get("tier1_artwork", {}).get("status") == "active": revision += "/tier1-generative-v1"
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
	var legal := false
	if has_hover and not game.over:
		legal = game.placement(cells, selected).ok
	floating_piece.valid = legal
	place_button.disabled = false
	place_button.get_child(0).color = game.current_color
	place_button.get_child(0).queue_redraw()
	_update_summaries(_prediction_board())
	_update_floating_position()

# Preview symmetry on a copy; saving and game rules still use the committed board.
func _prediction_board() -> Array:
	return Preview.board(game.board,cells,selected,game.current_color,has_hover and not game.over and not erase_mode)

func _update_floating_position() -> void:
	floating_piece.pitch = board_view.pitch
	floating_piece.face_lift = board_view.surface_depth()
	floating_piece.origin = board_view.get_global_transform_with_canvas() * board_view._floor_point(Vector2(selected))
	floating_piece.queue_redraw()

func _drag_to(point: Vector2) -> void:
	last_pointer = point
	var local: Vector2 = board_view.get_global_transform_with_canvas().affine_inverse() * point
	local += Vector2(0, board_view.surface_depth())
	selected = Geometry.anchor(local,board_view._floor_point(Vector2.ZERO),board_view.pitch,grabbed_cell)
	has_hover = true
	_preview()

func _pick_piece(point: Vector2) -> Dictionary:
	if game.over or dragging or confirmation.visible or palette_menu.visible or gallery_panel.visible or erase_mode or saving: return {}
	for control: Control in _controls():
		if control.visible and control.get_global_rect().has_point(point): return {}
	var hit: Vector2i = floating_piece.cell_at(point) if has_hover else Vector2i(-1,-1)
	var from_tray := false
	if hit.x < 0:
		hit = piece_view.cell_at(piece_view.get_global_transform_with_canvas().affine_inverse()*point)
		from_tray = hit.x >= 0
	return {} if hit.x < 0 else {"cell":hit,"from_tray":from_tray}

func _pick_gesture_target(point: Vector2) -> Dictionary:
	if erase_mode and board_view.get_global_rect().has_point(point):
		erase_target = _erase_cell_at(point)
		return {"cell":erase_target,"tool":"erase"}
	return _pick_piece(point)

func _start_drag(point: Vector2, id: int) -> bool:
	return piece_gesture.begin(point,id,_pick_piece(point))

func _consume_gesture(result: Dictionary) -> void:
	if result.is_empty(): return
	if result.tool == "erase":
		if result.released:
			if not result.canceled and _erase_cell_at(result.point) == result.grabbed: _erase(result.grabbed)
			erase_target = Vector2i(-1,-1)
		return
	if result.moving:
		if result.started and result.from_tray:
			var grabbed_index: int = cells.find(grabbed_cell)
			cells = piece_view.display_cells()
			tray_moved = true
			grabbed_cell = cells[grabbed_index]
			_refresh()
		_drag_to(result.point)
	if result.tap:
		_rotate()
	elif result.released:
		_autosave()

func _move_gesture(point: Vector2) -> void:
	_consume_gesture(piece_gesture.move(point,piece_gesture.pointer_id))

func _finish_gesture(point: Vector2) -> void:
	_consume_gesture(piece_gesture.finish(point,piece_gesture.pointer_id))

func _erase_cell_at(point: Vector2) -> Vector2i:
	var local: Vector2 = board_view.get_global_transform_with_canvas().affine_inverse()*point
	local += Vector2(0,board_view.surface_depth())
	return Geometry.board_cell(local,board_view._floor_point(Vector2.ZERO),board_view.pitch)

func _input(event: InputEvent) -> void:
	if introduction != null: return
	if confirmation.visible:
		piece_gesture.cancel()
		return
	if saving:
		piece_gesture.cancel()
		get_viewport().set_input_as_handled()
		return
	if gallery_panel.visible: return
	var p := Gesture.pointer(event)
	if palette_menu.visible:
		if not p.is_empty() and p.kind == "press" and not palette_menu.get_global_rect().has_point(p.point) and not palette_button.get_global_rect().has_point(p.point):
			palette_menu.hide()
			get_viewport().set_input_as_handled()
		return
	var result := piece_gesture.handle(event,_pick_gesture_target)
	if not result.is_empty():
		_consume_gesture(result)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if introduction != null: return
	piece_gesture.tick(delta)
	if has_hover: _update_floating_position()

# Every button, keyboard shortcut, and tap uses this same command entry point.
func _request_player_action(action: String, parameters: Dictionary = {}) -> Dictionary:
	if introduction != null: return introduction.request_action(action,parameters)
	var request := {"cells":cells,"color":game.current_color}
	request.merge(parameters,true)
	return player_actions.execute(action,game,request,_action_available)

func _action_available(action: String, _request: Dictionary) -> bool:
	if saving: return false
	if action not in ["undo","erase"] and game.over: return false
	if action in ["rotate","flip","color"]: return not cells.is_empty()
	if action == "place":
		if not has_hover or cells.is_empty() or board_view.growing or erase_mode: return false
		return game.physical_placement(_request.get("cells",cells), _request.get("anchor",selected)).ok
	return true

func _place() -> void:
	var before: Array = game.board
	var result := _request_player_action("place",{"anchor":selected})
	if not result.ok or result.get("tutorial",false): return
	board_view.animate_growth(before, game.board)
	cells = _offered_cells()
	_clear_selection()
	_refresh_and_save()

func _clear_selection() -> void:
	tray_moved = false
	piece_view.cells = [] if game.over else cells
	piece_view.queue_redraw()
	has_hover = false
	dragging = false
	selected = Vector2i(-1, -1)

func _offered_cells() -> Array:
	return [] if game.over else Geometry.laying(game.piece().cells)

func _rotate() -> void:
	var result := _request_player_action("rotate")
	if not result.ok or result.get("tutorial",false): return
	cells = result.cells
	_refresh_and_save()

func _flip() -> void:
	var result := _request_player_action("flip")
	if not result.ok or result.get("tutorial",false): return
	cells = result.cells
	_refresh_and_save()

func _choose_color(color: int) -> void:
	var result := _request_player_action("color",{"choice":color})
	if not result.ok or result.get("tutorial",false): return
	game.current_color = result.color
	_refresh_and_save()

func _skip() -> void:
	var result := _request_player_action("skip")
	if not result.ok or result.get("tutorial",false): return
	cells = _offered_cells()
	_clear_selection()
	_refresh_and_save()

func _toggle_erase() -> void:
	if introduction != null:
		introduction.joker_action("erase")
		return
	if saving or game.erase_left <= 0 or not game.board.any(func(row: Array): return row.any(func(value): return value != 0)):
		return
	erase_mode = not erase_mode
	erase_target = Vector2i(-1, -1)
	dragging = false
	_refresh()

func _erase(cell: Vector2i) -> void:
	var result := _request_player_action("erase",{"cell":cell})
	if not result.ok or result.get("tutorial",false): return
	erase_mode = false
	board_view.show_settled(game.board, true)
	cells = _offered_cells()
	_clear_selection()
	_refresh_and_save()

func _undo() -> void:
	var result := _request_player_action("undo")
	if not result.ok or result.get("tutorial",false): return
	erase_mode = false
	board_view.show_settled(game.board, true)
	cells = game.restored_cells
	_clear_selection()
	_refresh_and_save()

func _ask_reset(n: int) -> void:
	_confirm_new_game("Start a new game on a %d × %d board?" % [n, n], func():
		requested_size = n
		_reset())

func _replay_game() -> void:
	if saving: return
	_confirm_new_game("Start new game", func():
		if introduction != null: introduction.finish(true)
		palette_menu.history.clear()
		_reset(game.board.size(), game.difficulty))

func _game_started() -> bool:
	return game.moves > 0 or game.index > 0 or game.undo_left < 3 or game.skip_left < 3 or game.erase_left < 3

func _request_configuration_change(action: Callable, page: String) -> void:
	var apply := func():
		action.call()
		_reset()
		_show_menu(page, false)
	if _game_started(): _confirm_new_game("Start new game", apply)
	else: apply.call()

func _reset(board_size: int = -1, level: int = -1) -> void:
	palette_menu.hide()
	erase_mode = false
	game = Game.new(requested_size if board_size < 0 else board_size, -1, difficulty if level < 0 else level)
	board_view.show_settled(game.board)
	cells = _offered_cells()
	size_picker.text = "%d × %d" % [requested_size, requested_size]
	_clear_selection()
	_refresh_theme()
	_layout()
	_refresh_and_save()

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
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	for page: String in ["Themes", "Gameplay", "Gallery", "Audio", "Tutorial"]:
		settings_options.append(_menu_button(page, _open_gallery if page == "Gallery" else (_start_introduction if page == "Tutorial" else _show_menu.bind(page))))
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
	gameplay_options = [_menu_button("Difficulty", _cycle_difficulty_preset), size_picker, axes_button]
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var slider := TouchSlider.new()
	slider.min_value=0
	slider.max_value=100
	slider.step=1
	slider.value=value*100
	slider.size_flags_vertical=Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y=44
	slider.tooltip_text=title+" volume"
	slider.value_changed.connect(func(amount):
		label.text="%s volume: %d%%" % [title,roundi(amount)]
		changed.call(amount))
	row.add_child(slider)
	palette_list.add_child(row)
	menu_buttons.append(row)
	return row

func _close_menu() -> void:
	palette_menu.close()

func _back_menu() -> void:
	palette_menu.go_back()

func _show_menu(page: String, remember: bool = true) -> void:
	if introduction != null and introduction.lesson_id == "reveal" and page not in ["Settings","Themes"]: return
	palette_menu.open_page(page, remember)

func _settings_page_changed() -> void:
	dragging = false
	_layout_palette_menu(clampf(minf(size.x, size.y) * 0.018, 4, 12))
	_update_summaries(_prediction_board())
	interface_changed.emit(false)

func _review_new_game(theme: String) -> void:
	if introduction != null and introduction.lesson_id == "reveal":
		introduction.choose_theme(theme)
		return
	_request_theme(theme)

func _cycle_difficulty_preset() -> void:
	var next_level := ((int(difficulty) + 1) % 3) as Game.Difficulty
	_request_configuration_change(func(): difficulty = next_level, "Gameplay")

func _cycle_size_preset() -> void:
	var n := 11 if requested_size == 9 else 9
	_request_configuration_change(func(): requested_size = n, "Gameplay")

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
	palette_menu.history.clear()
	_reset()

func _layout_palette_menu(pad: float) -> void:
	for option: Control in menu_buttons:
		option.hide()
	var options: Array = settings_options
	if menu_page == "Themes":
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
	menu_frame.hide()
	_refresh_menu_style()
	var inset := Vector4(12, 12, 12, 12)
	var row_units := options.size() + (1 if menu_page == "Game Presets" else 0)
	var desired_height: float = (38 + 70 * row_units + 12) * 1.5
	if menu_page == "Themes": desired_height = maxf(desired_height,420)
	if menu_page == "Audio": desired_height = maxf(desired_height,330)
	var width: float = size.x * 0.70
	var height: float = minf(desired_height, size.y - 2 * pad)
	var scale_factor: float = minf(1, minf(width / 540, height / desired_height))
	var content_width: float = width - inset.x - inset.z
	var content_height: float = height - inset.y - inset.w
	var title_height: float = maxf(57 * scale_factor, InterfaceTheme.FONT.get_height(InterfaceTheme.FONT_SIZE) + 16)
	var gap: float = 9 * scale_factor
	var bottom: float = 18 * scale_factor
	var row_height: float = (content_height - title_height - bottom - gap * (options.size() - 1)) / row_units
	var y: float = minf(palette_button.get_rect().end.y + pad, size.y - pad - height)
	_set_rect(palette_menu, Rect2((size.x - width) / 2, maxf(pad, y), width, height))
	_set_rect(palette_list, Rect2(Vector2(inset.x, inset.y), Vector2(content_width, content_height)))
	menu_title.text = ""
	menu_title.hide()
	menu_title.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
	var close_side: float = maxf(InterfaceTheme.FONT.get_height(InterfaceTheme.FONT_SIZE) + 8, 48 * scale_factor)
	menu_close.show()
	menu_close.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
	_set_rect(menu_close, Rect2(content_width - close_side, 0, close_side, close_side))
	_set_rect(menu_title, Rect2(close_side + gap, 0, maxf(1, content_width - 2 * (close_side + gap)), title_height - gap))
	back_button.show()
	back_button.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
	_set_rect(back_button, Rect2(0, 0, close_side, close_side))
	new_button.text = "Start"
	gameplay_options[0].text = "Difficulty: " + ["Easy", "Moderate", "Hard"][difficulty]
	size_picker.text = "Size: %d × %d" % [requested_size,requested_size]
	preset_summary.text = "%s\nDifficulty: %s\nSize: %d × %d\nAxes: %s" % [MENU_THEMES.get(pending_theme, MENU_THEMES.get(Palette.theme_id(), Palette.theme_name())), ["Easy", "Moderate", "Hard"][difficulty], requested_size,requested_size,"On" if board_view.show_axes else "Off"]
	for i in range(size_options.size()):
		var n := 9 if i == 0 else 11
		size_options[i].text = ("✓ " if requested_size == n else "") + "%d × %d" % [n,n]
	_update_axes_label()
	background_button.text = "Background noises: " + ("On" if sounds.background_enabled else "Off")
	effects_button.text = "Special effects: " + ("On" if sounds.effects_enabled else "Off")
	for i in range(theme_options.size()):
		var id: String = theme_options[i].get_meta("theme_id")
		theme_options[i].text = ("✓ " if id == Palette.theme_id() else "") + MENU_THEMES[id]
		var tile: Control = theme_options[i].get_child(0)
		var longest_word := 0.0
		for word: String in MENU_THEMES[id].split(" "):
			longest_word = maxf(longest_word, InterfaceTheme.FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,InterfaceTheme.FONT_SIZE).x)
		var tile_side: float = maxf(16, minf(minf(row_height - 16 * scale_factor, content_width * 0.23), content_width-longest_word-38))
		theme_options[i].set_meta("menu_right_inset", tile_side + 20)
		_set_rect(tile, Rect2(content_width - tile_side - 12, (row_height - tile_side) / 2, tile_side, tile_side))
	for i in range(difficulty_options.size()):
		difficulty_options[i].text = ("✓ " if i == difficulty else "") + ["Easy", "Moderate", "Hard"][i]
	var row_y := title_height
	for i in range(options.size()):
		if options[i] is Label:
			var label: Label = options[i]
			label.show()
			label.add_theme_font_size_override("font_size",InterfaceTheme.FONT_SIZE)
			label.add_theme_color_override("font_color",Interface.text())
			_set_rect(label,Rect2(0,row_y,content_width,row_height*2))
			row_y += row_height*2 + gap
			continue
		if options[i] is VBoxContainer:
			var row: VBoxContainer = options[i]
			row.show()
			var label: Label = row.get_child(0)
			label.add_theme_font_size_override("font_size",InterfaceTheme.FONT_SIZE)
			label.add_theme_color_override("font_color",Interface.text())
			label.size.x = content_width
			label.update_minimum_size()
			row.update_minimum_size()
			_set_rect(row,Rect2(0,row_y,content_width,row_height))
			row_y += row_height + gap
			continue
		var button: Button = options[i]
		button.show()
		if palette_options.has(button):
			button.set_meta("menu_right_inset", row_height + 12)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
		_apply_button_style(button)
		button.size.x = content_width
		button.update_minimum_size()
		_set_rect(button, Rect2(0, row_y, content_width, row_height))
		row_y += row_height + gap

func _refresh_menu_style() -> void:
	var menu_style := InterfaceTheme.panel_style()
	var inset := Vector4(12, 12, 12, 12)
	menu_style.content_margin_left = inset.x
	menu_style.content_margin_top = inset.y
	menu_style.content_margin_right = inset.z
	menu_style.content_margin_bottom = inset.w
	menu_style.set_border_width_all(1)
	menu_style.border_color = Color(Interface.shade(), 0.65)
	menu_style.shadow_size = 0
	palette_menu.add_theme_stylebox_override("panel", menu_style)
	confirmation.add_theme_stylebox_override("panel", menu_style)

func _layout_confirmation(pad: float) -> void:
	var width := size.x * 0.70
	var height := minf((38 + 70 * 3 + 12) * 1.5, size.y - 2 * pad)
	var y := minf(palette_button.get_rect().end.y + pad, size.y - pad - height)
	_set_rect(confirmation, Rect2((size.x - width) / 2, maxf(pad, y), width, height))

func _apply_button_style(button: Button) -> void:
	InterfaceTheme.sync_highlight(button)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := InterfaceTheme.button_style(state)
		if theme_options.has(button):
			style.content_margin_left = 18
			style.content_margin_right = float(button.get_meta("menu_right_inset", 70))
		elif palette_options.has(button):
			style.content_margin_right = float(button.get_meta("menu_right_inset", 70))
		button.add_theme_stylebox_override(state, style)

func _refresh_theme() -> void:
	theme = InterfaceTheme.build()
	confirmation.theme = theme
	game_over_message.add_theme_font_override("font", InterfaceTheme.FONT)
	game_over_message.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
	game_over_message.add_theme_color_override("font_color", Interface.text())
	if save_error_dialog != null: save_error_dialog.theme = theme
	gallery_panel.apply_theme(theme)
	reef_background.visible = Palette.coral_reef
	for button: Button in themed_buttons:
		_apply_button_style(button)
	for button: Button in [blue_button]:
		button.get_child(0).queue_redraw()
	for button: Button in [erase_button, undo_button, skip_button, palette_button, replay_button, flip_button, place_button]:
		button.get_child(0).queue_redraw()
	_refresh_menu_style()
	menu_title.add_theme_color_override("font_color", Interface.text())
	queue_redraw()
	interface_changed.emit(true)

func _toggle_palette_menu() -> void:
	if introduction != null:
		if introduction.lesson_id == "reveal":
			introduction.open_settings()
			return
		return
	dragging = false
	if palette_menu.visible:
		palette_menu.hide()
	else:
		_show_menu("Settings")

func _confirm_new_game(_message: String, action: Callable) -> void:
	dragging = false
	pending_change = action
	confirmation.dialog_text = "Start new game"
	_layout_confirmation(clampf(size.x * 0.025, 6, 14))
	confirmation.open()

func _request_theme(id: String) -> void:
	if id not in MENU_THEMES or id == Palette.theme_id(): return
	_request_configuration_change(func(): Palette.select_theme(id), "Themes")

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
	_update_axes_label()
	_autosave()

func _update_axes_label() -> void:
	axes_button.text = "Show axes on field: " + ("On" if board_view.show_axes else "Off")
	axes_button.set_pressed_no_signal(board_view.show_axes)

func _toggle_background() -> void:
	sounds.set_background_enabled(not sounds.background_enabled)
	_layout_palette_menu(8)

func _toggle_effects() -> void:
	sounds.set_effects_enabled(not sounds.effects_enabled)
	_layout_palette_menu(8)

func _choose_palette(index: int) -> void:
	if Palette.select(index):
		palette_menu.hide()
		_refresh_theme()
		_refresh_and_save()
		board_view.queue_redraw()
		for indicator: Dictionary in indicators:
			indicator.icon.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if saving or confirmation.visible:
			return
		if gallery_panel.visible:
			if event.keycode == KEY_ESCAPE:
				gallery_panel.go_back()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and erase_mode and introduction == null:
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

func _open_gallery() -> void:
	palette_menu.hide()
	dragging = false
	gallery_panel.open_gallery()

func _save_design() -> Dictionary:
	if introduction != null:
		introduction.show_hint()
		return {"ok":false,"status":"tutorial_redirect"}
	return await save_current_design()

# Shared capture entry point; the tutorial can save without routing its button again.
func save_current_design() -> Dictionary:
	if saving: return {"ok":false,"status":"busy"}
	var fingerprint := _design_fingerprint()
	var session_id: int = game.get_instance_id()
	if board_view.growing or not _can_save():
		return _complete_design_save({"ok":false,"status":"unavailable"},fingerprint,session_id)
	saving = true
	interface_changed.emit(false)
	var snapshot: Array = game.board.duplicate(true)
	var palette_index: int = Palette.selected_index
	var theme_id: String = Palette.theme_id()
	var theme_version: String = Palette.theme_version()
	var surface_revision := _surface_revision(theme_id)
	var image: Image = await artwork_capture.render(self,board_view,snapshot,theme_id)
	if not is_inside_tree() or is_queued_for_deletion():
		saving = false
		return {"ok":false,"status":"cancelled","fingerprint":fingerprint,"session_id":session_id}
	if game.get_instance_id() != session_id or _design_fingerprint() != fingerprint:
		return _complete_design_save({"ok":false,"status":"cancelled"},fingerprint,session_id)
	var result: Dictionary
	if image == null or image.is_empty(): result = {"ok":false,"status":"capture_failed"}
	else:
		result = gallery.save_design(snapshot,palette_index,image,theme_id,theme_version,surface_revision)
		result.status = "saved" if result.ok else "storage_failed"
	return _complete_design_save(result,fingerprint,session_id)

func _complete_design_save(result: Dictionary, fingerprint: String, session_id: int) -> Dictionary:
	saving = false
	result.fingerprint = fingerprint
	result.session_id = session_id
	if result.ok and game.get_instance_id() == session_id and _design_fingerprint() == fingerprint:
		saved_fingerprint = fingerprint
	_refresh()
	if not result.ok and result.status not in ["cancelled","unavailable"] and introduction == null:
		_show_design_save_failure()
	design_save_finished.emit(result.duplicate(true))
	return result

func _show_design_save_failure() -> void:
	if save_error_dialog == null:
		save_error_dialog = AcceptDialog.new()
		save_error_dialog.title = ""
		save_error_dialog.dialog_text = "Couldn't save the picture. Please try again."
		add_child(save_error_dialog)
	save_error_dialog.theme = theme
	save_error_dialog.popup_centered(Vector2i(mini(360,int(size.x*0.7)),120))
