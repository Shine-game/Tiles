class_name ZenVisuals
extends Node2D

const Geometry = preload("res://scripts/zen_geometry.gd")
const Centerpiece = preload("res://scripts/zen_centerpiece.gd")
const Pond = preload("res://scripts/zen_pond.gd")
const Landmark = preload("res://scripts/zen_landmark.gd")
const SAND_SHADER = preload("res://shaders/zen_sand.gdshader")
const SAND = preload("res://art/themes/zen_garden/artwork/ground/sand_ground_256.png")
const CORE = preload("res://art/themes/zen_garden/artwork/cores/stepping_stone_core_256.png")
const STONES = [
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_N_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_E_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_S_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_W_256.png")]
const STONE_SCALE := 0.70
static var relief_textures: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var registry: Dictionary = {}
var pending: Dictionary = {}
var formation_cells: Dictionary = {}
var centerpieces: Dictionary = {}
var landmarks: Dictionary = {}
var landmark_order: Dictionary = {}
var pond: ZenPond
var landmark_layer: Node2D
var next_landmark_order := 0

static func sand_material(origin: Vector2 = Vector2.ZERO) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = SAND_SHADER
	ink.set_shader_parameter("sand", SAND)
	ink.set_shader_parameter("cell_origin", origin)
	return ink

static func stone_sprite(cell: Vector2i, direction: int = -1) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = CORE if direction < 0 else STONES[direction]
	var anchor := Vector2.ZERO if direction < 0 else Vector2(Geometry.OFFSETS[direction]) * 128.0
	# Shrink each half around its boundary midpoint, never the cell center.
	# Opposite halves therefore keep the same edge and tangential profile.
	sprite.position = (Vector2(cell) + Vector2.ONE * 0.5) * 256.0 + anchor
	sprite.offset = -anchor
	sprite.scale = Vector2.ONE * STONE_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite

func clear(keep_features: bool = false) -> void:
	for child: Node in get_children():
		if keep_features and (child.has_meta("zen_centerpiece") or child == landmark_layer or child == pond): continue
		remove_child(child)
		child.queue_free()
	materials.clear()
	registry.clear()
	pending.clear()
	formation_cells.clear()
	if not keep_features:
		centerpieces.clear()
		landmarks.clear()
		landmark_order.clear()
		landmark_layer = null
		pond = null
		next_landmark_order = 0

func reconcile(model, settled: bool, complete: bool = false) -> void:
	clear(true)
	var board: Array = model.board
	var retained_centers: Dictionary = {}
	for origin: Vector2i in model.colonies:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			formation_cells[origin + offset] = true
	for y in range(board.size()):
		for x in range(board.size()):
			var cell := Vector2i(x, y)
			var color: int = board[y][x]
			if color == 0 and not complete: continue
			var group := Node2D.new()
			add_child(group)
			registry[cell] = group
			var face := ColorRect.new()
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.position = Vector2(cell) * 256
			face.size = Vector2.ONE * 256
			face.material = sand_material(Vector2(cell))
			materials.append(face.material)
			group.add_child(face)
			# Both landmark types preserve their ordinary four-cell pattern below.
			if color == 0: continue
			var mask := Geometry.neighbor_mask(board, cell)
			if color == 1:
				var spec := Geometry.canonical(mask)
				if not relief_textures.has(spec.mask):
					relief_textures[spec.mask] = ImageTexture.create_from_image(Geometry.height_image(spec.mask))
				var sprite := Sprite2D.new()
				sprite.texture = relief_textures[spec.mask]
				sprite.position = (Vector2(cell) + Vector2.ONE * 0.5) * 256
				sprite.rotation = spec.turns * PI / 2
				var ink := sand_material(Vector2(cell))
				ink.set_shader_parameter("has_relief", true)
				ink.set_shader_parameter("relief_map", sprite.texture)
				ink.set_shader_parameter("tile_angle", sprite.rotation)
				sprite.material = ink
				materials.append(ink)
				group.add_child(sprite)
				var stage := 0 if formation_cells.has(cell) else Centerpiece.stage_for(mask)
				if stage > 0:
					if not centerpieces.has(cell):
						var center := Centerpiece.new()
						center.position = (Vector2(cell) + Vector2.ONE * 0.5) * 256
						add_child(center)
						centerpieces[cell] = center
					var start := maxf(0, float(model.arrivals.get(cell, 0)))
					centerpieces[cell].configure(stage, settled, start)
					retained_centers[cell] = true
			else:
				for d in range(4):
					if mask != 0 and not mask & (1 << d): continue
					var sprite := stone_sprite(cell, -1 if mask == 0 else d)
					group.add_child(sprite)
					if mask == 0: break
			if not settled and float(model.arrivals.get(cell, -100.0)) >= 0:
				# Only decoration fades in; the new sand slab is immediately solid.
				for i in range(1, group.get_child_count()):
					var sprite: CanvasItem = group.get_child(i)
					pending[sprite] = float(model.arrivals[cell])
	for cell: Vector2i in centerpieces.keys():
		if retained_centers.has(cell): continue
		var center: Node = centerpieces[cell]
		remove_child(center)
		center.queue_free()
		centerpieces.erase(cell)
	_sync_landmarks(model, settled)
	if pond == null:
		pond = Pond.new()
		add_child(pond)
	pond.reconcile(model, settled)
	advance(100.0 if settled else 0.0)

func _sync_landmarks(model, settled: bool) -> void:
	if landmark_layer == null:
		landmark_layer = Node2D.new()
		landmark_layer.name = "ZenLandmarks"
		landmark_layer.z_index = 3
		add_child(landmark_layer)
	var retained: Dictionary = {}
	for origin: Vector2i in model.colonies:
		var event: Dictionary = model.colonies[origin]
		var key := Landmark.identity(origin, event.color)
		retained[key] = true
		if not landmarks.has(key):
			var sprite := Landmark.new()
			landmark_layer.add_child(sprite)
			landmarks[key] = sprite
			landmark_order[key] = next_landmark_order
			next_landmark_order += 1
		landmarks[key].configure(event, settled)
	for key: String in landmarks.keys():
		if retained.has(key): continue
		var sprite: Node = landmarks[key]
		landmark_layer.remove_child(sprite)
		sprite.queue_free()
		landmarks.erase(key)
		landmark_order.erase(key)
	_sort_landmarks()

func _sort_landmarks() -> void:
	var keys: Array = landmarks.keys()
	keys.sort_custom(func(a: String, b: String): return int(landmark_order[a]) < int(landmark_order[b]))
	for i in range(keys.size()): landmark_layer.move_child(landmarks[keys[i]], i)

func copy_landmark_order(source: ZenVisuals) -> void:
	landmark_order = source.landmark_order.duplicate()
	next_landmark_order = source.next_landmark_order
	_sort_landmarks()

func advance(clock: float) -> void:
	if pond != null: pond.advance(clock)
	for landmark: Node in landmarks.values(): landmark.advance(clock)
	for center: Node in centerpieces.values(): center.advance(clock)
	for sprite: CanvasItem in pending.keys():
		var progress := clampf((clock - float(pending[sprite])) / 0.30, 0, 1)
		sprite.modulate.a = smoothstep(0, 1, progress)
		if progress >= 1: pending.erase(sprite)

func configure_surface(platform) -> void:
	if pond != null: pond.configure_surface(platform)
	for landmark: Node in landmarks.values(): landmark.configure_surface(platform)
	for ink: ShaderMaterial in materials:
		ink.set_shader_parameter("clip_to_surface", true)
		ink.set_shader_parameter("occupancy_mask", platform.mask_texture)
		ink.set_shader_parameter("grid_size", platform.grid_size)
		ink.set_shader_parameter("cell_pixels", 256.0)
		ink.set_shader_parameter("screen_pixel", 256.0 / platform.cell_pixels)
