class_name ZenVisuals
extends Node2D

const Geometry = preload("res://scripts/zen_geometry.gd")
const Centerpiece = preload("res://scripts/zen_centerpiece.gd")
const SAND_SHADER = preload("res://shaders/zen_sand.gdshader")
const SAND = preload("res://art/themes/zen_garden/artwork/ground/sand_ground_256.png")
const CORE = preload("res://art/themes/zen_garden/artwork/cores/stepping_stone_core_256.png")
const STONES = [
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_N_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_E_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_S_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_W_256.png")]
static var relief_textures: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var registry: Dictionary = {}
var pending: Dictionary = {}
var blank_cells: Dictionary = {}
var centerpieces: Dictionary = {}

static func sand_material(origin: Vector2 = Vector2.ZERO) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = SAND_SHADER
	ink.set_shader_parameter("sand", SAND)
	ink.set_shader_parameter("cell_origin", origin)
	return ink

static func unfinished_cells(board: Array) -> Dictionary:
	var result: Dictionary = {}
	for y in range(board.size() - 1):
		for x in range(board.size() - 1):
			var color: int = board[y][x]
			if color == 0: continue
			if board[y][x + 1] == color and board[y + 1][x] == color and board[y + 1][x + 1] == color:
				for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
					result[Vector2i(x, y) + offset] = true
	return result

func clear(keep_centers: bool = false) -> void:
	for child: Node in get_children():
		if keep_centers and child.has_meta("zen_centerpiece"): continue
		remove_child(child)
		child.queue_free()
	materials.clear()
	registry.clear()
	pending.clear()
	blank_cells.clear()
	if not keep_centers: centerpieces.clear()

func reconcile(model, settled: bool, complete: bool = false) -> void:
	clear(true)
	var board: Array = model.board
	var retained_centers: Dictionary = {}
	blank_cells = unfinished_cells(board)
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
			if color == 0 or blank_cells.has(cell): continue
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
				var stage := Centerpiece.stage_for(mask)
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
					var sprite := Sprite2D.new()
					sprite.texture = CORE if mask == 0 else STONES[d]
					sprite.position = (Vector2(cell) + Vector2.ONE * 0.5) * 256
					sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	advance(100.0 if settled else 0.0)

func advance(clock: float) -> void:
	for center: Node in centerpieces.values(): center.advance(clock)
	for sprite: CanvasItem in pending.keys():
		var progress := clampf((clock - float(pending[sprite])) / 0.30, 0, 1)
		sprite.modulate.a = smoothstep(0, 1, progress)
		if progress >= 1: pending.erase(sprite)

func configure_surface(platform) -> void:
	for ink: ShaderMaterial in materials:
		ink.set_shader_parameter("clip_to_surface", true)
		ink.set_shader_parameter("occupancy_mask", platform.mask_texture)
		ink.set_shader_parameter("grid_size", platform.grid_size)
		ink.set_shader_parameter("cell_pixels", 256.0)
		ink.set_shader_parameter("screen_pixel", 256.0 / platform.cell_pixels)
