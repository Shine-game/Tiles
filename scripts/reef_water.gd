class_name ReefWater
extends Node2D

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

func configure(bounds: Rect2, top_origin: Vector2, pitch: float) -> void:
	for plane: ColorRect in [floor_plane, light_plane]:
		plane.position = bounds.position
		plane.size = bounds.size
	light_plane.material.set_shader_parameter("rect_pixels", bounds.size)
	light_plane.material.set_shader_parameter("cell_origin", top_origin - bounds.position)
	light_plane.material.set_shader_parameter("cell_pixels", pitch)

func freeze_phase(seconds: float) -> void:
	light_plane.material.set_shader_parameter("time_override", seconds)
