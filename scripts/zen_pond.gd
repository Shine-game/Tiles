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
var plant_choices: Dictionary = {}
var plant_random := RandomNumberGenerator.new()

static func source(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(ROOT + path)
	return textures[path]

static func mask_path(variant: int, kind: String) -> String:
	return "watersheds/%02d/%s.png" % [variant + 1, kind]

# Overlapping 2x2 centers are one cell apart. Each connecting triangle runs
# from its center to their shared midpoint, not to the far edge of its 2x2.
static func sector_scale(direction: int) -> Vector2:
	return Vector2(1.0, 0.5) if direction % 2 == 0 else Vector2(0.5, 1.0)

static func sector_point(origin: Vector2i, direction: int, point: Vector2) -> Vector2:
	return (Vector2(origin) + Vector2.ONE) * 256.0 + (point - Vector2.ONE * 256.0) * sector_scale(direction)

static func lateral_pixel(image: Image, direction: int, depth: float, side: int) -> Vector2:
	# Traverse parallel to the shared base. The outermost flood texels locate
	# the two sloping watershed boundaries, not the central rock shoreline.
	var point := Vector2.ZERO
	for step in range(512):
		var tangent := float(step if side == 0 else 511 - step) / 511.0
		point = [Vector2(tangent, depth), Vector2(1.0 - depth, tangent), Vector2(tangent, 1.0 - depth), Vector2(depth, tangent)][direction]
		var pixel := Vector2i(point * 511.0)
		if image.get_pixelv(pixel).r > 0.5: return point * 512.0
	return point * 512.0

static func shore_points(variant: int, direction: int) -> Array:
	var key := "%d/%d" % [variant, direction]
	if shores.has(key): return shores[key]
	# Later sets include an unoccluded sector outline. Use that for the
	# laterals so an interior exposed boulder cannot become a shrub boundary.
	var kind: String = ("water_" if variant == 0 else "watershed_") + DIRECTIONS[direction]
	var image := source(mask_path(variant, kind)).get_image()
	var points: Array = []
	for side in range(2):
		var point := lateral_pixel(image, direction, 0.24, side)
		var tangent := (lateral_pixel(image, direction, 0.26, side) - lateral_pixel(image, direction, 0.22, side)) * sector_scale(direction)
		points.append({"position": point, "angle": tangent.angle()})
	shores[key] = points
	return points

func reset_choices() -> void:
	plant_random.randomize()
	plant_choices.clear()

func plant_texture(key: String) -> Texture2D:
	if not plant_choices.has(key): plant_choices[key] = plant_random.randi_range(0, PLANTS.size() - 1)
	return source("shoreline_plants/" + PLANTS[plant_choices[key]])

func appearance_signature() -> String:
	# Include only currently visible groups; erased/undone cached choices do
	# not change the identity of an otherwise identical saved picture.
	var keys: Array = plants.keys()
	keys.sort()
	var choices: Array = []
	for key: String in keys: choices.append([key, plant_choices[key]])
	return JSON.stringify(choices).sha256_text()

func copy_choices(other: ZenPond) -> void:
	plant_choices = other.plant_choices.duplicate()
	for key: String in plants: plants[key].sprite.texture = plant_texture(key)

func _init() -> void:
	reset_choices()
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
		# Source masks are unchanged; compress only the connection axis so
		# opposing bases meet halfway between these overlapping formations.
		region.scale *= sector_scale(event.direction)
		region.position = sector_point(event.origin, event.direction, Vector2.ZERO) * MASK_CELL / 256.0
		region.material.set_shader_parameter("direction", event.direction)
		var start: float = -100.0 if settled or event.old else event.start
		regions[key] = {"sprite": region, "start": start}
		var points := shore_points(variant, event.direction)
		for i in range(2):
			var plant_key := key + "/%d" % i
			retained[plant_key] = true
			if not plants.has(plant_key):
				var plant := Sprite2D.new()
				plant.texture = plant_texture(plant_key)
				plant.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				plant.position = sector_point(event.origin, event.direction, points[i].position)
				# Follow each sloping side while keeping the supplied foliage upright.
				plant.rotation = points[i].angle
				if cos(plant.rotation) < 0: plant.rotation += PI
				plant.scale = Vector2.ONE * 92.0 / plant.texture.get_width()
				plant.offset.y = -plant.texture.get_height() * 0.18
				add_child(plant)
				plants[plant_key] = {"sprite": plant, "start": start}
			plants[plant_key].sprite.texture = plant_texture(plant_key)
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
