class_name TileBoardView
extends Control

signal workshop_cue(kind: String)
signal growth_finished
signal growth_started
signal growth_canceled
signal flower_opened(corner: Vector2i, color: int)
signal visual_state_changed(pattern, animating: bool, preserve: bool, clock: float, placement_id: int)
signal visual_clock_advanced(clock: float)
const JunctionLayer = preload("res://scripts/pattern/junction_layer.gd")
const Tier1Layer = preload("res://scripts/pattern/tier1_layer.gd")
const Tier1Sources = preload("res://scripts/pattern/tier1_sources.gd")
const VinesFormationLayer = preload("res://scripts/vines_formation_layer.gd")
const FountainWater = preload("res://scripts/vines_fountain_water.gd")
const VineModel = preload("res://scripts/vines_growth.gd")
const Vines = preload("res://scripts/vines_sets.gd")
const ComponentState = preload("res://scripts/pattern/component_state.gd")
const ThemeEvents = preload("res://scripts/pattern/theme_events.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const ClockSets = preload("res://scripts/clockwork_sets.gd")
const Palette = preload("res://scripts/palette.gd")
const Brush = preload("res://scripts/botanical_brush.gd")
const Frame = preload("res://scripts/board_frame.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const Clock = preload("res://scripts/clockwork_growth.gd")
const Workshop = preload("res://scripts/clockwork_visuals.gd")
const CoralSets = preload("res://scripts/coral_sets.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Coral = preload("res://scripts/coral_growth.gd")
const Water = preload("res://scripts/reef_water.gd")
const CoralLayer = preload("res://scripts/coral_visuals.gd")
const Rules = preload("res://scripts/rules.gd")
const Axes = preload("res://scripts/field_axes.gd")
const Growth = preload("res://scripts/growth.gd")
var tutorial_tile_layer: Control
var tutorial_underlay: Array = []:
	set(value):
		tutorial_underlay = value.duplicate(true)
		_sync_tutorial_underlay()
		queue_redraw()
var tile_floor: ColorRect
var vines_formations: Node2D
var fountain_water: Node2D
var zen_garden := false
var zen_visuals
var zen_floor: ColorRect
var board: Array = []
var pattern = Growth.new()
var construction_state := ComponentState.new()
var tier1_layer: PatternTier1Layer
var junction_layer: PatternJunctionLayer
var sprite_elapsed := 0.0
var sprite_reverse := false
var generative_tier1: bool:
	get: return Tier1Sources.active(Palette.theme_id())
var clock := 0.0
var growing := false
var field := Rect2()
var pitch := 1.0
var grid_inset := 8.0
var flush_frame := false
var direction_by_edge: Dictionary = {}
var leaf_texture: Texture2D = Brush.leaf()
var announced_flowers: Dictionary = {}
var axes_states: Array = []
var axes_overlay: Control
var show_axes := false:
	set(enabled):
		show_axes = enabled
		_sync_axes()
var show_guides := true
var growth_speed := 1.0
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
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)

func show_settled(grid: Array, preserve_direction: bool = false) -> void:
	sprite_elapsed = clock
	var reverse: bool = preserve_direction and clockwork and clockwork_visuals != null and board != grid
	sprite_reverse = reverse
	growth_canceled.emit()
	announced_flowers.clear()
	board = grid
	_build_pattern(grid, grid)
	growth_before = grid.duplicate(true)
	_adopt_directions(preserve_direction)
	_sync_coral(true, preserve_direction)
	_sync_workshop(true, preserve_direction, reverse)
	_sync_zen(true)
	clock = 0
	growing = clockwork and (pattern.duration > 0 or reverse)
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
	if Palette.theme_id() == "vines":
		Vines.install()
		if tile_floor == null:
			tile_floor = ColorRect.new()
			tile_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile_floor.z_index = -2
			add_child(tile_floor)
	if tile_floor != null:
		tile_floor.visible = Palette.theme_id() == "vines"
		tile_floor.color = Palette.floor_color()
	clockwork = Palette.clockwork
	coral_reef = Palette.coral_reef
	zen_garden = Palette.zen_garden
	var model_hooks := { "clockwork": Clock, "coral_reef": Coral, "vines": VineModel}
	if zen_garden: model_hooks["zen_garden"] = load("res://scripts/zen_growth.gd")
	pattern = model_hooks[Themes.profile(Palette.theme_id()).hooks.growth].new()
	pattern.build(before, after)
	if fountain_water == null and Palette.theme_id() == "vines" and Vines.tier2.definition.water.get("enabled", true):
		fountain_water = FountainWater.new()
		fountain_water.view = self
		add_child(fountain_water)
	if fountain_water != null:
		fountain_water.visible = Palette.theme_id() == "vines" and Vines.tier2.definition.water.get("enabled", true)
		fountain_water.set_process(fountain_water.visible and not pattern.links.is_empty())
		fountain_water.queue_redraw()
	if board_frame == null:
		board_frame = Frame.new()
		board_frame.thin_rim = 14.0 if flush_frame else 0.0
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
				sprite.texture = Assets.part_texture(ClockSets.ground_part("plate_%02d" % choice.variant))
				turn = choice.rotation
			else:
				var choice: Dictionary = Coral.ground_choice(cell)
				sprite.texture = Assets.part_texture(CoralSets.ground_part(choice.id), "salmon")
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
				ink.set_shader_parameter("metal_lip", Workshop.texture("artwork/ground/clockwork_ui_edge_lip_color0_1.png"))
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
		coral_visuals.generative_tier1 = generative_tier1
		coral_visuals.show()
		coral_visuals.reconcile(pattern, settled, true)
		coral_visuals.advance(0 if settled else clock)
		update_geometry()
	elif coral_visuals != null:
		coral_visuals.hide()

func _sync_zen(settled: bool) -> void:
	if zen_garden:
		var ZenLayer = load("res://scripts/zen_visuals.gd")
		if zen_visuals == null:
			zen_visuals = ZenLayer.new()
			zen_visuals.z_index = 1
			add_child(zen_visuals)
		zen_visuals.generative_tier1 = generative_tier1
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
		clockwork_visuals.generative_tier1 = generative_tier1
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
	sprite_elapsed = clock
	sprite_reverse = false
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
	if tier1_layer == null:
		tier1_layer = Tier1Layer.new()
		add_child(tier1_layer)
	var okay := tier1_layer.prepare(pattern, Palette.theme_id(), growth_before, settled, preserve, at, restart, sprite_elapsed if restart else 0.0, sprite_reverse)
	if not okay: push_error("Tier 1 preparation failed: " + str(tier1_layer.diagnostics))
	if Palette.theme_id() == "vines": pattern.reschedule_formations(pattern.sprite_growth_events)
	if junction_layer == null:
		junction_layer = JunctionLayer.new()
		add_child(junction_layer)
	if not junction_layer.prepare(pattern, Palette.theme_id(), growth_before, settled, preserve, at, restart, sprite_elapsed if restart else 0.0): push_error(str(junction_layer.diagnostics))
	var events: Dictionary = ThemeEvents.collect(pattern, Palette.theme_id(), zen_visuals, clockwork_visuals)
	events.merge(junction_layer.events)
	events.merge(tier1_layer.retirement_events())
	if Palette.theme_id() == "vines": events.merge(Vines.center_events(pattern, growth_before, settled))
	construction_state.reconcile(events, 0.0 if settled else maxf(pattern.duration, pattern.sprite_visual_duration), at, settled, preserve, restart)
	clock = construction_state.schedule.clock
	growing = construction_state.schedule.running()
	if not tier1_layer.present(construction_state, _sprite_view_transform()): push_error("Tier 1 presentation failed: " + str(tier1_layer.diagnostics))
	if not junction_layer.present(construction_state, _sprite_view_transform()): push_error(str(junction_layer.diagnostics))
	if Palette.theme_id() == "vines":
		if vines_formations==null:
			vines_formations=VinesFormationLayer.new()
			add_child(vines_formations)
		vines_formations.show()
		vines_formations.transform=_sprite_view_transform()
		vines_formations.sync(self,settled)
	elif vines_formations!=null:vines_formations.hide()
	sprite_elapsed = 0.0
	sprite_reverse = false

func advance_growth(delta: float) -> void:
	if not growing:
		return
	clock = construction_state.advance(delta)
	if tier1_layer != null: tier1_layer.advance(construction_state)
	if junction_layer != null: junction_layer.advance(construction_state)
	if coral_reef:
		coral_visuals.advance(clock)
	if zen_garden: zen_visuals.advance(clock)
	if clockwork and clockwork_visuals != null:
		clockwork_visuals.advance(clock)
	if vines_formations!=null and vines_formations.visible:vines_formations.advance(clock)
	visual_clock_advanced.emit(clock)
	for corner: Vector2i in pattern.flowers:
		var flower: Dictionary = pattern.flowers[corner]
		if not flower.old and not announced_flowers.has(corner) and clock >= flower.start + pattern.flower_seconds() * 0.12:
			announced_flowers[corner] = true
			flower_opened.emit(corner, flower.color)
	if not construction_state.schedule.running():
		growing = false
		set_process(false)
		growth_finished.emit()
	queue_redraw()

func _process(delta: float) -> void:
	advance_growth(delta*growth_speed)

func update_geometry() -> void:
	if board.is_empty():
		return
	var side: float = minf(size.x, size.y)
	field = Rect2((size - Vector2.ONE * side) / 2, Vector2.ONE * side)
	if flush_frame and (board_frame == null or not board_frame.is_present()):
		field = Rect2(field.position + Vector2.ONE * 14, field.size - Vector2.ONE * 28)
		side = field.size.x
	if board_frame != null and board_frame.is_present():
		if flush_frame:
			field = Rect2(field.position + Vector2.ONE * board_frame.thin_rim, field.size - Vector2.ONE * board_frame.thin_rim * 2)
		else:
			field = Frame.fit(Rect2(Vector2.ZERO, size), Palette.theme_id())
		side = field.size.x
		board_frame.surround(field)
	if tile_floor != null and tile_floor.visible:
		tile_floor.position = field.position
		tile_floor.size = field.size
	# Keep the raised north edge and its shadow inside the field, including
	# high-resolution gallery captures. The logical board remains square.
	var edge_allowance: float = 3.0 * Platform.SOURCE_DEPTH / Platform.SOURCE_CELL + 0.02
	pitch = maxf(1, minf((side - 16.0) / board.size(), (side - 2.0) / (board.size() + 2 * edge_allowance)))
	grid_inset = maxf(8, (side - board.size() * pitch) / 2)
	if flush_frame:
		pitch = side / board.size()
		grid_inset = 0.0
	if vines_formations!=null and vines_formations.visible:vines_formations.transform=_sprite_view_transform()
	if occupied_platform != null:
		occupied_platform.configure(_point(Vector2.ZERO), pitch, Palette.platform_color(), coral_reef, 4.0 if clockwork or zen_garden else -1.0, not zen_garden)
	_sync_tutorial_underlay()
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

	if tier1_layer != null: tier1_layer.set_view_transform(_sprite_view_transform())
	if junction_layer != null: junction_layer.transform = _sprite_view_transform()
	_sync_axes()

func _sprite_view_transform() -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * pitch, 0.0, _point(Vector2.ZERO))

func set_axis_states(states: Array) -> void:
	axes_states = states.duplicate(true)
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
		axes_overlay.states = axes_states if not axes_states.is_empty() else Rules.symmetry_states(board)
		axes_overlay.configure(Rect2(_point(Vector2.ZERO), Vector2.ONE * board.size() * pitch), pitch)

func surface_depth() -> float:
	return 4.0 if clockwork or zen_garden else Platform.depth(pitch)

func _floor_point(position_in_grid: Vector2) -> Vector2:
	return field.position + Vector2.ONE * grid_inset + position_in_grid * pitch + (Vector2(0, surface_depth()) if flush_frame else Vector2.ZERO)

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
		var paper := Workshop.texture("artwork/background/clockwork_ui_drafting_paper_1080x1650_color0_1.png")
		var factor: float = maxf(size.x / paper.get_width(), size.y / paper.get_height())
		var extent: Vector2 = paper.get_size() * factor
		draw_texture_rect(paper, Rect2((size - extent) * 0.5, extent), false)
	if flush_frame and (board_frame == null or not board_frame.is_present()):
		draw_rect(field.grow(7), Color("999999") if Palette.zen_garden else Color(Palette.text(), 0.4), false, 14, true)
	if tutorial_underlay.is_empty() and show_guides:
		_draw_guides()
	if coral_reef or clockwork or zen_garden:
		return
	Vines.draw(self)

func _sync_tutorial_underlay() -> void:
	if tutorial_tile_layer == null and not tutorial_underlay.is_empty():
		tutorial_tile_layer = Control.new()
		tutorial_tile_layer.name = "TutorialTiles"
		tutorial_tile_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Vines and their junctions use -1. Keep the retained tiles below both.
		tutorial_tile_layer.z_index = -2
		tutorial_tile_layer.draw.connect(_draw_tutorial_tiles)
		add_child(tutorial_tile_layer)
	if tutorial_tile_layer != null:
		tutorial_tile_layer.visible = not tutorial_underlay.is_empty()
		tutorial_tile_layer.queue_redraw()
	if occupied_platform != null:
		occupied_platform.visible = tutorial_underlay.is_empty() and occupied_platform.occupancy_bytes.has(255)

func tutorial_tile_color(cell: Vector2i) -> Color:
	var pigment: int = tutorial_underlay[cell.y][cell.x]
	if pigment == 0: return Color("FFF9F3")
	var original := Palette.tile(pigment)
	if pattern == null or not pattern.arrivals.has(cell): return original
	if Growth.value(growth_before,cell) == pigment: return Palette.platform_color()
	# Replace the exercise color as artwork reaches this square, beneath the art.
	var reveal := clampf((clock-float(pattern.arrivals[cell]))/0.3,0,1)
	return original.lerp(Palette.platform_color(),reveal)

func _draw_tutorial_tiles() -> void:
	if tutorial_underlay.is_empty(): return
	var n := tutorial_underlay.size()
	var unit := field.size.x/n
	tutorial_tile_layer.draw_rect(field,Color("FFF9F3"))
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	for y in range(n):
		for x in range(n):
			style.bg_color = tutorial_tile_color(Vector2i(x,y))
			var rect := Rect2(field.position+Vector2(x,y)*unit,Vector2.ONE*unit)
			tutorial_tile_layer.draw_style_box(style,rect.grow(-1.5))

func _draw_guides() -> void:
	var n: int = board.size()
	var ink := Palette.grid() if Palette.theme_id() == "vines" else Color("9b95a3", 0.20)
	var width: float = maxf(0.75, pitch * 0.012)
	for y in range(n):
		for x in range(n + 1):
			if Growth.value(board, Vector2i(x - 1, y)) == 0 and Growth.value(board, Vector2i(x, y)) == 0:
				draw_line(_guide_point(Vector2(x, y)), _guide_point(Vector2(x, y + 1)), ink, width, true)
	for y in range(n + 1):
		for x in range(n):
			if Growth.value(board, Vector2i(x, y - 1)) == 0 and Growth.value(board, Vector2i(x, y)) == 0:
				draw_line(_guide_point(Vector2(x, y)), _guide_point(Vector2(x + 1, y)), ink, width, true)

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

func _guide_point(cell: Vector2) -> Vector2:
	return _point(cell) if flush_frame else _floor_point(cell)

func session_art_state() -> Dictionary:
	var edges: Array = []
	for key: Vector4i in direction_by_edge:
		var record: Dictionary = direction_by_edge[key]
		edges.append({"edge":[key.x,key.y,key.z,key.w],"color":record.color,"flow":record.flow})
	var cores: Dictionary = {}
	if junction_layer != null:
		for id: String in junction_layer.events:
			if not "/core/leaf_" in id: continue
			var cell: Vector2i = junction_layer.events[id].owner
			cores[str(cell)] = [cell.x,cell.y,int(id.get_slice("/",2))]
	edges.sort_custom(func(a,b):return JSON.stringify(a.edge)<JSON.stringify(b.edge))
	var sorted_cores := cores.values()
	sorted_cores.sort_custom(func(a,b):return JSON.stringify(a)<JSON.stringify(b))
	return {"edges":edges,"leaf_cores":sorted_cores}

func restore_session_art(grid: Array, data: Dictionary) -> void:
	direction_by_edge.clear()
	for record: Dictionary in data.get("edges",[]):
		var key := Vector4i(int(record.edge[0]),int(record.edge[1]),int(record.edge[2]),int(record.edge[3]))
		direction_by_edge[key] = {"color":int(record.color),"flow":int(record.flow)}
	if junction_layer == null:
		junction_layer = JunctionLayer.new()
		add_child(junction_layer)
	junction_layer.restore_leaf_cores(data.get("leaf_cores",[]),grid,Palette.theme_id())
	show_settled(grid,true)
