class_name ZenCenterpiece
extends Node2D

const Timing = preload("res://scripts/pattern/growth_schedule.gd")
const ROOT := "res://art/themes/zen_garden/artwork/centers/"
const FILES := ["one_flat_top_stone_256.png", "three_stone_cairn_256.png", "tall_bamboo_behind_cairn_visual.png"]
const TEXTURES := [
	preload("res://art/themes/zen_garden/artwork/centers/one_flat_top_stone_256.png"),
	preload("res://art/themes/zen_garden/artwork/centers/three_stone_cairn_256.png"),
	preload("res://art/themes/zen_garden/artwork/centers/tall_bamboo_behind_cairn_visual.png")]
const ADDITION = preload("res://shaders/zen_center_addition.gdshader")
# The supplied stone is 112 source pixels wide; at this scale its radius is
# 33.6 logical pixels, inside the innermost groove's 40-pixel radius.
const CANVAS_PIXELS := 256.0 * 0.60
const GROW_SECONDS := 0.30
var grow_seconds := GROW_SECONDS
var stage := 0
var artwork: Sprite2D
var progress: Array[float] = [0.0, 0.0, 0.0]
var growing: Dictionary = {}

static func stage_for(mask: int) -> int:
	var canonical: int = preload("res://scripts/zen_geometry.gd").canonical(mask).mask
	return {3: 1, 11: 2, 15: 3}.get(canonical, 0)

func _init() -> void:
	set_meta("zen_centerpiece", true)
	z_index = 2
	artwork = Sprite2D.new()
	artwork.name = "CenterArtwork"
	artwork.texture = TEXTURES[0]
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork.scale = Vector2.ONE * CANVAS_PIXELS / 256.0
	var ink := ShaderMaterial.new()
	ink.shader = ADDITION
	ink.set_shader_parameter("stack_artwork", TEXTURES[1])
	ink.set_shader_parameter("bamboo_artwork", TEXTURES[2])
	artwork.material = ink
	add_child(artwork)

func configure_artwork(textures: Array[Texture2D], canvas_scale: float, seconds: float) -> void:
	artwork.texture = textures[0]
	artwork.material.set_shader_parameter("stack_artwork", textures[1])
	artwork.material.set_shader_parameter("bamboo_artwork", textures[2])
	artwork.scale = Vector2.ONE * canvas_scale
	grow_seconds = seconds

func configure(next_stage: int, settled: bool, start: float = 0.0) -> void:
	var previous := stage
	stage = next_stage
	growing.clear()
	for i in range(3):
		if not settled and i >= previous and i < stage:
			progress[i] = 0.0
			growing[i] = start
		else:
			progress[i] = 1.0 if i < stage else 0.0
	_update_material()

func advance(clock: float) -> void:
	for i: int in growing.keys():
		progress[i] = Timing.smooth(float(growing[i]), grow_seconds, clock)
		if progress[i] >= 1: growing.erase(i)
	_update_material()

func _update_material() -> void:
	# One fixed canvas prevents both motion of the base and repeated blending of
	# its almost-opaque source pixels. All stages have exactly the same pivot.
	artwork.modulate.a = progress[0]
	artwork.material.set_shader_parameter("stack_progress", progress[1])
	artwork.material.set_shader_parameter("bamboo_progress", progress[2])
