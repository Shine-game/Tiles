class_name TileBoardView
extends Control

signal workshop_cue(kind: String)
signal growth_finished
signal growth_started
signal growth_canceled
signal flower_opened(corner: Vector2i, color: int)
signal visual_state_changed(pattern, animating: bool, preserve: bool, clock: float, placement_id: int)
signal visual_clock_advanced(clock: float)
const Vines = preload("res://scripts/vines_sets.gd")
const AssetProviders = preload("res://scripts/pattern/legacy_assets.gd")
const ComponentState = preload("res://scripts/pattern/component_state.gd")
const LegacyEvents = preload("res://scripts/pattern/legacy_events.gd")
const Palette = preload("res://scripts/palette.gd")
const Brush = preload("res://scripts/botanical_brush.gd")
const Frame = preload("res://scripts/board_frame.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const Workshop = preload("res://scripts/clockwork_visuals.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const Water = preload("res://scripts/reef_water.gd")
const CoralLayer = preload("res://scripts/coral_visuals.gd")
const Axes = preload("res://scripts/field_axes.gd")
const Growth = preload("res://scripts/growth.gd")
const Zen = preload("res://scripts/zen_growth.gd")
const ZenLayer = preload("res://scripts/zen_visuals.gd")
var zen_garden := false
var zen_visuals: ZenVisuals
var zen_floor: ColorRect
var board: Array = []
var pattern = Growth.new()
var construction_state := ComponentState.new()
var clock := 0.0
var growing := false
var field := Rect2()
var pitch := 1.0
var grid_inset := 8.0
var direction_by_edge: Dictionary = {}
var leaf_texture: Texture2D = Brush.leaf()
var announced_flowers: Dictionary = {}
var axes_overlay: Control
var show_axes := false:
	set(enabled):
		show_axes = enabled
		_sync_axes()
var show_guides := true
var growth_before: Array = []
var coral_reef := false
var coral_visuals: CoralVisuals
var occupied_platform: OccupiedPlatform
var placement_revision := 0
var reef_water: ReefWater
var board_frame: BoardFrame
var clockwork := false
var clockwork_visuals: ClockworkVisuals
var paper_background := false
# Capture-only completion changes the surface mask, never the growth board.
var complete_background := false
var blank_ground: Node2D
var blank_signature: Array = []

func _ready() -> void:
	AssetProviders.install()
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)

func show_settled(grid: Array, preserve_direction: bool = false) -> void:
	var reverse: bool = preserve_direction and clockwork and clockwork_visuals != null and board != grid
	growth_canceled.emit()
	announced_flowers.clear()
	board = grid
	_build_pattern(grid, grid)
	_adopt_directions(preserve_direction)
	_sync_coral(true, preserve_direction)
	_sync_workshop(true, preserve_direction, reverse)
	_sync_zen(true)
	clock = 0
	growing = clockwork and pattern.duration > 0
	_sync_construction(not growing, preserve_direction)
	set_process(growing)
	if not preserve_direction:
		placement_revision = 0
	visual_state_changed.emit(pattern, growing, preserve_direction, clock, placement_revision)
	queue_redraw()

func sync_board(grid: Array) -> void:
	if pattern.board != grid:
		show_settled(grid)
	elif Palette.clockwork and not clockwork:
		show_settled(grid, true)
	elif coral_reef != Palette.coral_reef or clockwork != Palette.clockwork or zen_garden != Palette.zen_garden:
		_restyle()

func _build_pattern(before: Array, after: Array) -> void:
	clockwork = Palette.clockwork
	coral_reef = Palette.coral_reef
	zen_garden = Palette.zen_garden
	pattern = Zen.new() if zen_garden else (Clock.new() if clockwork else (Coral.new() if coral_reef else Growth.new()))
	pattern.build(before, after)
	if board_frame == null:
		board_frame = Frame.new()
		add_child(board_frame)
	board_frame.apply_theme(Palette.theme_id())
	if reef_water == null and coral_reef:
		reef_water = Water.new()
		# Insert before the platform: both floor layers share z=-1.
		add_child(reef_water)
		move_child(reef_water, 0)
	if reef_water != null:
		reef_water.visible = coral_reef
	if occupied_platform == null:
		occupied_platform = Platform.new()
		add_child(occupied_platform)
	occupied_platform.sync(_surface_board(after))
	_sync_blank_ground()
	update_geometry()

func _surface_board(grid: Array) -> Array:
	if not complete_background:
		return grid
	var filled: Array = grid.duplicate(true)
	for row: Array in filled:
		for x in range(row.size()):
			if row[x] == 0: row[x] = 1
	return filled

func _sync_blank_ground() -> void:
	var signature: Array = [board, Palette.theme_id(), complete_background]
	if signature == blank_signature:
		return
	blank_signature = [board.duplicate(true), Palette.theme_id(), complete_background]
	if blank_ground == null:
		if not complete_background: return
		blank_ground = Node2D.new()
		blank_ground.name = "BlankBackgroundTiles"
		add_child(blank_ground)
	for child: Node in blank_ground.get_children():
		blank_ground.remove_child(child)
		child.queue_free()
	blank_ground.visible = complete_background
	if not complete_background or not (coral_reef or clockwork):
		return
	for y in range(board.size()):
		for x in range(board.size()):
			if board[y][x] != 0: continue
			var cell := Vector2i(x, y)
			var sprite := Sprite2D.new()
			var turn := 0
			if clockwork:
				var choice: Dictionary = Clock.ground_choice(cell)
				sprite.texture = Workshop.texture("artwork/ground/plate_%02d.png" % choice.variant)
				turn = choice.rotation
			else:
				var choice: Dictionary = Coral.ground_choice(cell)
				var meta: Dictionary = Coral.specification().components[choice.id]
				sprite.texture = CoralLayer.texture(meta.artwork.salmon)
				turn = choice.rotation
			sprite.position = (Vector2(cell) + Vector2.ONE * 0.5) * 256
			sprite.rotation = turn * PI / 2
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var ink := ShaderMaterial.new()
			ink.shader = preload("res://shaders/ground_surface.gdshader")
			ink.set_shader_parameter("cell_center", Vector2(cell) + Vector2.ONE * 0.5)
			ink.set_shader_parameter("quarter_turn", float(turn))
			ink.set_shader_parameter("cell_pixels", 256.0)
			ink.set_shader_parameter("submerged", coral_reef)
			ink.set_shader_parameter("metal_surface", clockwork)
			if clockwork:
				ink.set_shader_parameter("metal_lip", Workshop.texture("artwork/ground/edge_lip_2ui.png"))
			sprite.material = ink
			blank_ground.add_child(sprite)

func _restyle() -> void:
	if not growing:
		show_settled(board, true)
		return
	_build_pattern(growth_before, board)
	_adopt_directions(true)
	_sync_coral(false, true)
	_sync_workshop(false, true)
	_sync_zen(false)
	clock = minf(clock, pattern.duration)
	if coral_reef:
		coral_visuals.advance(clock)
	if zen_garden: zen_visuals.advance(clock)
	growing = clock < pattern.duration
	_sync_construction(false, true, clock, false)
	set_process(growing)
	visual_state_changed.emit(pattern, growing, true, clock, placement_revision)
	if not growing:
		growth_finished.emit()
	queue_redraw()

func _sync_coral(settled: bool, preserve: bool) -> void:
	if coral_visuals != null and not preserve:
		coral_visuals.clear()
	if coral_reef:
		if coral_visuals == null:
			coral_visuals = CoralLayer.new()
			coral_visuals.z_index = 1
			add_child(coral_visuals)
		coral_visuals.show()
		coral_visuals.reconcile(pattern, settled, true)
		coral_visuals.advance(0 if settled else clock)
		update_geometry()
	elif coral_visuals != null:
		coral_visuals.hide()

func _sync_zen(settled: bool) -> void:
	if zen_garden:
		if zen_visuals == null:
			zen_visuals = ZenLayer.new()
			zen_visuals.z_index = 1
			add_child(zen_visuals)
		zen_visuals.show()
		zen_visuals.reconcile(pattern, settled, complete_background)
		if zen_floor == null:
			zen_floor = ColorRect.new()
			zen_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
			zen_floor.z_index = -1
			zen_floor.material = ZenLayer.sand_material()
			add_child(zen_floor)
			move_child(zen_floor, 0)
		zen_floor.show()
		update_geometry()
	else:
		if zen_visuals != null: zen_visuals.hide()
		if zen_floor != null: zen_floor.hide()

func _sync_workshop(settled: bool, preserve: bool, reverse: bool = false) -> void:
	if clockwork_visuals != null and not preserve:
		clockwork_visuals.clear()
	if clockwork:
		if clockwork_visuals == null:
			clockwork_visuals = Workshop.new()
			add_child(clockwork_visuals)
			clockwork_visuals.cue.connect(workshop_cue.emit)
		clockwork_visuals.show()
		clockwork_visuals.reconcile(pattern, settled, preserve, reverse)
		if reverse:
			pattern.dismantling = true
			pattern.duration = maxf(pattern.duration, clockwork_visuals.retire_duration)
		clockwork_visuals.advance(0)
		update_geometry()
	elif clockwork_visuals != null:
		clockwork_visuals.hide()

func animate_growth(before: Array, after: Array) -> void:
	placement_revision += 1
	board = after
	growth_before = before.duplicate(true)
	_build_pattern(before, after)
	_adopt_directions(true)
	clock = 0
	_sync_coral(false, true)
	_sync_workshop(false, true)
	_sync_zen(false)
	announced_flowers.clear()
	growing = pattern.duration > 0
	_sync_construction(false, true)
	set_process(growing)
	visual_state_changed.emit(pattern, growing, true, clock, placement_revision)
	if growing:
		growth_started.emit()
	queue_redraw()

func _sync_construction(settled: bool, preserve: bool, at: float = 0.0, restart: bool = true) -> void:
	var events: Dictionary = LegacyEvents.collect(pattern, Palette.theme_id(), zen_visuals, clockwork_visuals)
	if Palette.theme_id() == "vines": events.merge(Vines.center_events(pattern, growth_before, settled))
	construction_state.reconcile(events, 0.0 if settled else pattern.duration, at, settled, preserve, restart)
	clock = construction_state.schedule.clock
	growing = construction_state.schedule.running()

func advance_growth(delta: float) -> void:
	if not growing:
		return
	clock = construction_state.advance(delta)
	if coral_reef:
		coral_visuals.advance(clock)
	if zen_garden: zen_visuals.advance(clock)
	if clockwork and clockwork_visuals != null:
		clockwork_visuals.advance(clock)
	visual_clock_advanced.emit(clock)
	for corner: Vector2i in pattern.flowers:
		var flower: Dictionary = pattern.flowers[corner]
		if not flower.old and not announced_flowers.has(corner) and clock >= flower.start + Growth.FLOWER_POP * 0.12:
			announced_flowers[corner] = true
			flower_opened.emit(corner, flower.color)
	if not construction_state.schedule.running():
		growing = false
		set_process(false)
		growth_finished.emit()
	queue_redraw()

func _process(delta: float) -> void:
	advance_growth(delta)

func update_geometry() -> void:
	if board.is_empty():
		return
	var side: float = minf(size.x, size.y)
	field = Rect2((size - Vector2.ONE * side) / 2, Vector2.ONE * side)
	if board_frame != null and board_frame.is_present():
		field = Frame.fit(Rect2(Vector2.ZERO, size))
		side = field.size.x
		board_frame.surround(field)
	# Keep the raised north edge and its shadow inside the field, including
	# high-resolution gallery captures. The logical board remains square.
	var edge_allowance: float = 3.0 * Platform.SOURCE_DEPTH / Platform.SOURCE_CELL + 0.02
	pitch = maxf(1, minf((side - 16.0) / board.size(), (side - 2.0) / (board.size() + 2 * edge_allowance)))
	grid_inset = maxf(8, (side - board.size() * pitch) / 2)
	if occupied_platform != null:
		occupied_platform.configure(_point(Vector2.ZERO), pitch, Palette.platform_color(), coral_reef, 4.0 if clockwork or zen_garden else -1.0, not zen_garden)
	if zen_garden and zen_visuals != null:
		zen_visuals.position = _point(Vector2.ZERO)
		zen_visuals.scale = Vector2.ONE * pitch / 256.0
		zen_visuals.configure_surface(occupied_platform)
	if zen_garden and zen_floor != null:
		zen_floor.position = Vector2.ZERO
		zen_floor.size = size
		zen_floor.material.set_shader_parameter("cell_origin", -_point(Vector2.ZERO) / pitch)
		zen_floor.material.set_shader_parameter("area_cells", size / pitch)
	if clockwork_visuals != null:
		clockwork_visuals.position = _point(Vector2.ZERO)
		clockwork_visuals.scale = Vector2.ONE * pitch / 256.0
		clockwork_visuals.configure_surface(occupied_platform)
	if reef_water != null:
		var framed: bool = board_frame != null and board_frame.is_present()
		reef_water.configure(field, _point(Vector2.ZERO), pitch, board_frame.get_rect() if framed else field, board_frame.texture if framed else null)
	if coral_visuals != null:
		coral_visuals.position = _point(Vector2.ZERO)
		coral_visuals.scale = Vector2.ONE * pitch / 256.0
		coral_visuals.configure_surface(occupied_platform)

	if blank_ground != null and complete_background:
		blank_ground.position = _point(Vector2.ZERO)
		blank_ground.scale = Vector2.ONE * pitch / 256.0
		for sprite: Sprite2D in blank_ground.get_children():
			sprite.material.set_shader_parameter("occupancy_mask", occupied_platform.mask_texture)
			sprite.material.set_shader_parameter("grid_size", occupied_platform.grid_size)
			sprite.material.set_shader_parameter("screen_pixel", 256.0 / pitch)

	_sync_axes()

func _sync_axes() -> void:
	var enabled: bool = show_axes and show_guides and not complete_background and not board.is_empty()
	if axes_overlay == null:
		if not enabled: return
		axes_overlay = Axes.new()
		axes_overlay.name = "SymmetryAxes"
		add_child(axes_overlay)
	axes_overlay.visible = enabled
	if enabled:
		axes_overlay.configure(Rect2(_point(Vector2.ZERO), Vector2.ONE * board.size() * pitch), pitch)

func surface_depth() -> float:
	return 4.0 if clockwork or zen_garden else Platform.depth(pitch)

func _floor_point(position_in_grid: Vector2) -> Vector2:
	return field.position + Vector2.ONE * grid_inset + position_in_grid * pitch

func _point(position_in_grid: Vector2) -> Vector2:
	return _floor_point(position_in_grid) - Vector2(0, surface_depth())

static func pop(progress: float) -> float:
	var t: float = clampf(progress, 0, 1)
	return smoothstep(0, 1, t) + sin(t * PI) * 0.15

func _adopt_directions(preserve: bool) -> void:
	var retained: Dictionary = {}
	for edge: Dictionary in pattern.edges:
		var key: Vector4i = Growth.edge_key(edge.a, edge.b)
		if preserve and edge.old and direction_by_edge.has(key) and direction_by_edge[key].color == edge.color:
			edge.flow = direction_by_edge[key].flow
		retained[key] = {"color": edge.color, "flow": edge.flow}
	direction_by_edge = retained

func _draw() -> void:
	if board.is_empty():
		return
	update_geometry()
	if clockwork and paper_background:
		var paper := Workshop.texture("artwork/background/drafting_paper_1080x1650.png")
		var factor: float = maxf(size.x / paper.get_width(), size.y / paper.get_height())
		var extent: Vector2 = paper.get_size() * factor
		draw_texture_rect(paper, Rect2((size - extent) * 0.5, extent), false)
	if show_guides:
		_draw_guides()
	if coral_reef or clockwork or zen_garden:
		return
	Vines.draw(self)

func _draw_guides() -> void:
	var n: int = board.size()
	var ink := Color("9b95a3", 0.20)
	var width: float = maxf(0.75, pitch * 0.012)
	for y in range(n):
		for x in range(n + 1):
			if Growth.value(board, Vector2i(x - 1, y)) == 0 and Growth.value(board, Vector2i(x, y)) == 0:
				draw_line(_floor_point(Vector2(x, y)), _floor_point(Vector2(x, y + 1)), ink, width, true)
	for y in range(n + 1):
		for x in range(n):
			if Growth.value(board, Vector2i(x, y - 1)) == 0 and Growth.value(board, Vector2i(x, y)) == 0:
				draw_line(_floor_point(Vector2(x, y)), _floor_point(Vector2(x + 1, y)), ink, width, true)

func _port_tangent(cell: Vector2i, neighbor: Vector2i) -> Vector2:
	var direction := Vector2(neighbor - cell)
	var connected: Array = []
	for offset: Vector2i in Growth.DIRECTIONS:
		if Growth.value(board, cell + offset) == Growth.value(board, cell):
			connected.append(Vector2(offset))
	if connected.size() == 2 and is_zero_approx(connected[0].dot(connected[1])):
		var other: Vector2 = connected[1] if connected[0] == direction else connected[0]
		return (direction - other).normalized()
	return direction

func _curve(a: Vector2, b: Vector2, tangent_a: Vector2 = Vector2.ZERO, tangent_b: Vector2 = Vector2.ZERO) -> Dictionary:
	var length: float = a.distance_to(b)
	var direction: Vector2 = (b - a).normalized()
	return {"a": a, "b": b, "ca": a + (direction if tangent_a == Vector2.ZERO else tangent_a) * length * 0.34, "cb": b + (-direction if tangent_b == Vector2.ZERO else tangent_b) * length * 0.34}

func _curve_point(curve: Dictionary, t: float, wave: float = 0) -> Vector2:
	var one: float = 1 - t
	var base: Vector2 = one * one * one * curve.a + 3 * one * one * t * curve.ca + 3 * one * t * t * curve.cb + t * t * t * curve.b
	var delta: Vector2 = curve.b - curve.a
	var normal := Vector2(-delta.y, delta.x).normalized()
	var curl: float = sin(t * TAU) * sin(t * PI) * pitch * 0.018
	var ripple: float = sin(t * TAU + clock * 11) * sin(t * PI) * pitch * 0.025 * wave
	return base + normal * (curl + ripple)

func _curve_tangent(curve: Dictionary, t: float) -> Vector2:
	return (_curve_point(curve, minf(1, t + 0.005)) - _curve_point(curve, maxf(0, t - 0.005))).normalized()

func _vine(curve: Dictionary, start: float, end: float, ink: Color, wave: float) -> void:
	if end <= start:
		return
	var points := PackedVector2Array()
	for i in range(21):
		points.append(_curve_point(curve, lerpf(start, end, i / 20.0), wave))
	draw_polyline(points, Color(ink, ink.a * 0.10), maxf(2.5, pitch * 0.115), true)
	draw_polyline(points, Color(ink, ink.a * 0.36), maxf(1.6, pitch * 0.060), true)
	draw_polyline(points, Color(ink, ink.a * 0.92), maxf(0.9, pitch * 0.029), true)

func _paint_leaf(root: Vector2, direction: Vector2, length: float, width: float, ink: Color, scale: float = 1) -> void:
	if length * scale < 0.6 or width * scale < 0.4:
		return
	# The watercolor texture's veins run root-to-tip, not in screen coordinates.
	draw_set_transform(root, direction.angle(), Vector2.ONE)
	draw_texture_rect(leaf_texture, Rect2(0, -width * scale / 2, length * scale, width * scale), false, ink)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_link(link: Dictionary) -> void:
	var a := _point(Vector2(link.a))
	var b := _point(Vector2(link.b))
	var curve: Dictionary = _curve(a, b)
	var t: float = 1 if link.old else clampf((clock - link.start) / Growth.LINK_GROW, 0, 1)
	_vine(curve, 0, t, Palette.pigment(link.color), 0 if link.old else 1 - t)
	for fraction: float in [0.25, 0.5, 0.75]:
		var scale: float = 1 if link.old else pop((clock - link.start - fraction * Growth.LINK_GROW) / Growth.STAR_POP)
		if scale > 0:
			_star(_curve_point(curve, fraction), pitch * 0.045 * scale, Palette.blossom(link.color))

func _star(center: Vector2, radius: float, ink: Color) -> void:
	if radius < 0.35 or ink.a <= 0.01:
		return
	var points := PackedVector2Array()
	for i in range(8):
		points.append(center + Vector2.from_angle(i * TAU / 8) * radius * (1.0 if i % 2 == 0 else 0.23))
	draw_colored_polygon(points, ink)
	draw_polyline(PackedVector2Array([points[0], points[2], points[4], points[6], points[0]]), Color(ink, 0.18), 0.6, true)

func _draw_flower(corner: Vector2i, flower: Dictionary) -> void:
	var progress: float = clampf((clock - flower.start) / Growth.FLOWER_POP, 0, 1)
	if progress <= 0:
		return
	var center := _point(Vector2(corner))
	var stem: Color = Palette.pigment(flower.color)
	var ink: Color = Palette.blossom(flower.color)
	var support_scale: float = minf(1, pop(progress / 0.60))
	var base: Vector2 = center + Vector2(0, pitch * 0.455)
	var curve: Dictionary = _curve(base, center, Vector2(-0.18, -1).normalized(), Vector2(0, 1))
	_vine(curve, 0, support_scale, stem, 0)
	# Red-marked reference: leaf stems rise from underneath and cradle the bloom.
	for side: float in [-1.0, 1.0]:
		_paint_leaf(base + Vector2(0, -pitch * 0.025), Vector2(side * 0.72, -0.88).normalized(), pitch * 0.31, pitch * 0.12, Color(stem, 0.88), support_scale)
		_paint_leaf(base + Vector2(0, -pitch * 0.10), Vector2(side * 0.55, -1).normalized(), pitch * 0.19, pitch * 0.08, Color(stem.lightened(0.15), 0.76), support_scale)
	var scale: float = minf(1, pop((progress - 0.12) / 0.88))
	var radius: float = pitch * Growth.FLOWER_RADIUS * scale
	if radius < 0.6:
		return
	for layer in range(3):
		draw_circle(center, radius * (0.72 + layer * 0.12), Color(ink, 0.025), true, -1, true)
	for petal in range(8):
		var direction := Vector2.from_angle(petal * TAU / 8)
		_paint_leaf(center + direction * radius * 0.04, direction, radius * 0.96, radius * 0.55, Color(ink, 0.96))
		_paint_leaf(center + direction * radius * 0.03, direction, radius * 0.72, radius * 0.25, Color(ink.lightened(0.25), 0.62))
	draw_circle(center, radius * 0.11, Palette.tile(flower.color), true, -1, true)
	for i in range(8):
		var offset := Vector2.from_angle(i * TAU / 8) * radius * 0.14
		draw_circle(center + offset, maxf(0.35, radius * 0.022), Color(stem, 0.62), true, -1, true)
