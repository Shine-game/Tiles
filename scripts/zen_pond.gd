class_name ZenPond
extends Node2D

const Landmark = preload("res://scripts/zen_landmark.gd")
const MASK_SHADER = preload("res://shaders/zen_pond_mask.gdshader")
const WATER_SHADER = preload("res://shaders/zen_pond.gdshader")
const ROOT := "res://art/themes/zen_garden/artwork/"
const DIRECTIONS := ["n", "e", "s", "w"]
const PLANTS := ["01_shore_sedge.png", "02_shore_fern.png", "03_shore_herbs.png", "04_shore_rush.png", "05_shore_clover.png", "06_shore_reeds.png"]
const FILL_SECONDS := 0.85
const PLANT_SECONDS := 0.35
const MASK_CELL := 128.0
static var textures: Dictionary = {}
static var shores: Dictionary = {}
var mask_view: SubViewport
var flood_layer: Node2D
var dry_layer: Node2D
var water: ColorRect
var regions: Dictionary = {}
var peaks: Array = []
var plants: Dictionary = {}

static func source(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(ROOT + path)
	return textures[path]

static func mask_path(variant: int, kind: String) -> String:
	return "watersheds/%02d/%s.png" % [variant + 1, kind]

static func shore_points(variant: int, direction: int) -> Array:
	var key := "%d/%d" % [variant, direction]
	if shores.has(key): return shores[key]
	var image := source(mask_path(variant, "water_" + DIRECTIONS[direction])).get_image()
	var points: Array = []
	# Follow the authored water/rock boundary, rather than inventing a coast.
	for tangent in [0.34, 0.66]:
		var uv := Vector2.ZERO
		for step in range(256):
			var inward := float(step) / 512.0
			uv = [Vector2(tangent, inward), Vector2(1.0 - inward, tangent), Vector2(tangent, 1.0 - inward), Vector2(inward, tangent)][direction]
			if image.get_pixel(mini(int(uv.x * image.get_width()), image.get_width() - 1), mini(int(uv.y * image.get_height()), image.get_height() - 1)).r < 0.5: break
		points.append(uv * 512.0)
	shores[key] = points
	return points

func _init() -> void:
	z_index = 4
	mask_view = SubViewport.new()
	mask_view.size = Vector2i(2, 2)
	mask_view.disable_3d = true
	mask_view.transparent_bg = true
	mask_view.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	mask_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mask_view)
	flood_layer = Node2D.new()
	dry_layer = Node2D.new()
	mask_view.add_child(flood_layer)
	mask_view.add_child(dry_layer)
	water = ColorRect.new()
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.material = ShaderMaterial.new()
	water.material.shader = WATER_SHADER
	water.material.set_shader_parameter("flood_mask", mask_view.get_texture())
	add_child(water)

func mask_sprite(path: String, origin: Vector2i, protect: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = source(path)
	sprite.centered = false
	sprite.position = Vector2(origin) * MASK_CELL
	sprite.scale = Vector2.ONE * MASK_CELL * 2.0 / sprite.texture.get_width()
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = MASK_SHADER
	sprite.material.set_shader_parameter("protect_rock", protect)
	(dry_layer if protect else flood_layer).add_child(sprite)
	return sprite

func reconcile(model, settled: bool) -> void:
	for layer: Node2D in [flood_layer, dry_layer]:
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	regions.clear()
	peaks.clear()
	mask_view.size = Vector2i(2, 2) if model.ponds.is_empty() else Vector2i.ONE * int(model.board.size() * MASK_CELL)
	water.size = Vector2.ONE * model.board.size() * 256.0
	water.material.set_shader_parameter("board_pixels", water.size.x)
	var retained: Dictionary = {}
	for origin: Vector2i in model.colonies:
		var event: Dictionary = model.colonies[origin]
		if event.color != 2 or model.ponds.is_empty(): continue
		var variant := Landmark.rock_variant(origin)
		var peak := mask_sprite(mask_path(variant, "rock_occlusion"), origin, true)
		peaks.append({"sprite": peak, "start": -100.0 if settled or event.old else event.start})
	for key: String in model.ponds:
		var event: Dictionary = model.ponds[key]
		var variant := Landmark.rock_variant(event.origin)
		var region := mask_sprite(mask_path(variant, "water_" + DIRECTIONS[event.direction]), event.origin, false)
		region.material.set_shader_parameter("direction", event.direction)
		var start: float = -100.0 if settled or event.old else event.start
		regions[key] = {"sprite": region, "start": start}
		var points := shore_points(variant, event.direction)
		for i in range(2):
			var plant_key := key + "/%d" % i
			retained[plant_key] = true
			if not plants.has(plant_key):
				var plant := Sprite2D.new()
				plant.texture = source("shoreline_plants/" + PLANTS[(variant * 2 + event.direction + i) % PLANTS.size()])
				plant.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				plant.position = Vector2(event.origin) * 256.0 + points[i]
				plant.scale = Vector2.ONE * 92.0 / plant.texture.get_width()
				plant.offset.y = -plant.texture.get_height() * 0.18
				add_child(plant)
				plants[plant_key] = {"sprite": plant, "start": start}
			plants[plant_key].start = start
	for key: String in plants.keys():
		if retained.has(key): continue
		remove_child(plants[key].sprite)
		plants[key].sprite.queue_free()
		plants.erase(key)
	var ordered: Array = plants.keys()
	ordered.sort()
	for i in range(ordered.size()): move_child(plants[ordered[i]].sprite, i + 2)
	visible = not regions.is_empty()
	advance(100.0 if settled else 0.0)

func advance(clock: float) -> void:
	if regions.is_empty(): return
	for region: Dictionary in regions.values():
		region.sprite.material.set_shader_parameter("amount", smoothstep(0, 1, clampf((clock - region.start) / FILL_SECONDS, 0, 1)))
	for peak: Dictionary in peaks:
		peak.sprite.material.set_shader_parameter("amount", smoothstep(0, 1, clampf((clock - peak.start) / Landmark.GROW_SECONDS, 0, 1)))
	for plant: Dictionary in plants.values():
		plant.sprite.modulate.a = smoothstep(0, 1, clampf((clock - plant.start - FILL_SECONDS) / PLANT_SECONDS, 0, 1))
	mask_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func configure_surface(platform) -> void:
	water.material.set_shader_parameter("occupancy_mask", platform.mask_texture)
	water.material.set_shader_parameter("grid_size", platform.grid_size)
	water.material.set_shader_parameter("cell_pixels", 256.0)
	water.material.set_shader_parameter("screen_pixel", 256.0 / platform.cell_pixels)
