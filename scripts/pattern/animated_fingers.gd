extends RefCounted
# Continuous visual animation is independent of the finite construction clock.
const Assets = preload("res://scripts/pattern/asset_library.gd")
const ROOT := "res://art/themes/coral_reef/artwork/fingers/"
static var data: Dictionary = {}
static func definition() -> Dictionary:
	if data.is_empty(): data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "salmon.json"))
	return data

static func choices(a: Vector2i, b: Vector2i) -> Array:
	var config := definition()
	var rng := RandomNumberGenerator.new()
	rng.seed = JSON.stringify([config.seed, a.x, a.y, b.x, b.y]).sha256_text().substr(0,15).hex_to_int()
	var variants: Array = range(config.variants.size())
	for i in range(variants.size()-1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = variants[i]
		variants[i] = variants[j]
		variants[j] = temp
	var axis := Vector2(b-a).normalized()
	var result: Array = []
	for i in range(int(config.count)):
		var angle: float = axis.angle() + i * TAU / config.count
		result.append({"variant": variants[i % variants.size()], "angle": angle,
			"origin_cells": (Vector2(a+b)/2 + Vector2.ONE) + axis * cos(i*TAU/config.count) * Vector2(b-a).length()/2,
			"flip_x": rng.randf() < 0.5, "period": rng.randf_range(config.cycle_seconds[0], config.cycle_seconds[1]), "phase": rng.randf()})
	return result

static func frame_index(chosen: Dictionary, seconds: float) -> int:
	var sequence: Array = definition().frame_sequence
	return int(sequence[int(floor(fposmod(seconds/chosen.period + chosen.phase, 1.0)*sequence.size()))]) - 1

static func frame_texture(chosen: Dictionary, seconds: float) -> Texture2D:
	return Assets.texture(ROOT + definition().variants[chosen.variant][frame_index(chosen, seconds)])

static func render_spec(event: Dictionary) -> Dictionary:
	var config := definition()
	var chosen: Dictionary = event.animated_finger
	var forward := Vector2(config.direction[0], config.direction[1])
	var form := Vector2(-1 if chosen.flip_x else 1, 1)
	var matrix := Transform2D(chosen.angle - (forward*form).angle(), form*float(config.scale), 0, Vector2.ZERO)
	matrix.origin = chosen.origin_cells*256.0 - matrix.basis_xform(Vector2(config.origin_px[0],config.origin_px[1]))
	return {"asset": {"provider": "texture", "path": ROOT + config.variants[chosen.variant][0]}, "source_transform": matrix, "texture_filter": 2, "material": null}
