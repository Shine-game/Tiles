class_name ReefWater
extends Node2D

const Frame = preload("res://scripts/board_frame.gd")
const LAGOON = preload("res://shaders/reef_lagoon.gdshader")
const CAUSTICS = preload("res://shaders/reef_caustics.gdshader")
var floor_plane: ColorRect
var light_plane: ColorRect

func _init() -> void:
	floor_plane = _plane(LAGOON, -1)
	light_plane = _plane(CAUSTICS, 20)
	freeze_phase(-1)

func _plane(shader: Shader, layer: int) -> ColorRect:
	var plane := ColorRect.new()
	plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plane.z_index = layer
	var ink := ShaderMaterial.new()
	ink.shader = shader
	plane.material = ink
	add_child(plane)
	return plane

func configure(bounds: Rect2, top_origin: Vector2, pitch: float, lighting_bounds: Rect2 = Rect2(), frame_artwork: Texture2D = null) -> void:
	if lighting_bounds.size == Vector2.ZERO:
		lighting_bounds = bounds
	floor_plane.position = bounds.position
	floor_plane.size = bounds.size
	light_plane.position = lighting_bounds.position
	light_plane.size = lighting_bounds.size
	light_plane.material.set_shader_parameter("rect_pixels", lighting_bounds.size)
	light_plane.material.set_shader_parameter("cell_origin", top_origin - lighting_bounds.position)
	light_plane.material.set_shader_parameter("cell_pixels", pitch)
	light_plane.material.set_shader_parameter("frame_enabled", frame_artwork != null)
	light_plane.material.set_shader_parameter("frame_artwork", frame_artwork)
	if frame_artwork != null:
		light_plane.material.set_shader_parameter("frame_source_pixels", frame_artwork.get_size())
		light_plane.material.set_shader_parameter("frame_margins", Frame.margins())

func freeze_phase(seconds: float) -> void:
	light_plane.material.set_shader_parameter("time_override", seconds)
