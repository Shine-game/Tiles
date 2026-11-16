class_name ZenLandmark
extends Sprite2D

const Sets = preload("res://scripts/zen_sets.gd")
const Components = preload("res://scripts/pattern/component_renderer.gd")
const Timing = preload("res://scripts/pattern/growth_schedule.gd")
const SURFACE = preload("res://shaders/zen_landmark.gdshader")
const LANTERN = preload("res://art/themes/zen_garden/artwork/architecture/stone_lantern_2x2_visual.png")
const ROCKS := [
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_01_peak_and_low_bedrock_visual.png"),
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_02_peak_and_low_bedrock_visual.png"),
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_03_peak_and_low_bedrock_visual.png"),
	preload("res://art/themes/zen_garden/artwork/rock_formations/rock_04_peak_and_low_bedrock_visual.png")]
const GROW_SECONDS := 0.45
const PATTERN_SECONDS := 0.30
const PATTERN_HOLD_SECONDS := 0.10
# Center of the visible pedestal footprint in the supplied 1254x1254 master.
const LANTERN_BASE_PIVOT := Vector2(627.0, 1090.0)
var origin := Vector2i.ZERO
var color := 1
var variant := 0
var start := -100.0
var growing := false
var grow_seconds := GROW_SECONDS

static func identity(cell: Vector2i, pigment: int) -> String:
	return "%d/%d/%d" % [pigment, cell.y, cell.x]

static func rock_variant(cell: Vector2i) -> int:
	# Stable through growth, Undo, Erase and rebuilding a gallery capture.
	return Sets.rock_variant(cell)

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func configure(event: Dictionary, settled: bool) -> void:
	origin = event.origin
	color = event.color
	variant = rock_variant(origin) if color == 2 else 0
	var spec := Sets.landmark_spec(origin, color)
	Components.configure_sprite(self, spec)
	grow_seconds = float(spec.animation.duration_seconds)
	if material == null: material = Components.material_providers[spec.material.provider].call(spec.material.params)
	var extent: Vector2 = texture.get_size() * scale
	material.set_shader_parameter("artwork_origin", position + (offset - texture.get_size() * 0.5) * scale)
	material.set_shader_parameter("artwork_pixels", extent)
	start = event.start
	growing = not settled and not event.old
	modulate.a = 0.0 if growing else 1.0

func advance(clock: float) -> void:
	if not growing: return
	modulate.a = Timing.smooth(start, grow_seconds, clock)
	if modulate.a >= 1.0: growing = false

func configure_surface(platform) -> void:
	material.set_shader_parameter("occupancy_mask", platform.mask_texture)
	material.set_shader_parameter("grid_size", platform.grid_size)
	material.set_shader_parameter("cell_pixels", 256.0)
	material.set_shader_parameter("screen_pixel", 256.0 / platform.cell_pixels)
