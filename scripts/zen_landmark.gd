class_name ZenLandmark
extends Sprite2D

const SURFACE = preload("res://shaders/zen_landmark.gdshader")
const LANTERN = preload("res://art/themes/zen_garden/artwork/architecture/stone_lantern_2x2_visual.png")
const ROCKS := [
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_01_peak_and_low_bedrock_visual.png"),
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_02_peak_and_low_bedrock_visual.png"),
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_03_peak_and_low_bedrock_visual.png"),
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_04_peak_and_low_bedrock_visual.png")]
const GROW_SECONDS := 0.45
var origin := Vector2i.ZERO
var color := 1
var variant := 0
var start := -100.0
var growing := false

static func identity(cell: Vector2i, pigment: int) -> String:
	return "%d/%d/%d" % [pigment, cell.y, cell.x]

static func rock_variant(cell: Vector2i) -> int:
	# Stable through growth, Undo, Erase and rebuilding a gallery capture.
	return int(((cell.x * 73856093) ^ (cell.y * 19349663) ^ 1409) & 0xffffffff) % ROCKS.size()

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ink := ShaderMaterial.new()
	ink.shader = SURFACE
	material = ink

func configure(event: Dictionary, settled: bool) -> void:
	origin = event.origin
	color = event.color
	variant = rock_variant(origin) if color == 2 else 0
	texture = ROCKS[variant] if color == 2 else LANTERN
	position = (Vector2(origin) + Vector2.ONE) * 256.0
	rotation = 0.0
	# Fit within the two-cell square without distorting the nonsquare masters.
	scale = Vector2.ONE * 512.0 / maxf(texture.get_width(), texture.get_height())
	var extent: Vector2 = texture.get_size() * scale
	material.set_shader_parameter("artwork_origin", position - extent * 0.5)
	material.set_shader_parameter("artwork_pixels", extent)
	start = event.start
	growing = not settled and not event.old
	modulate.a = 0.0 if growing else 1.0

func advance(clock: float) -> void:
	if not growing: return
	modulate.a = smoothstep(0, 1, clampf((clock - start) / GROW_SECONDS, 0, 1))
	if modulate.a >= 1.0: growing = false

func configure_surface(platform) -> void:
	material.set_shader_parameter("occupancy_mask", platform.mask_texture)
	material.set_shader_parameter("grid_size", platform.grid_size)
	material.set_shader_parameter("cell_pixels", 256.0)
	material.set_shader_parameter("screen_pixel", 256.0 / platform.cell_pixels)
