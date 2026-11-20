extends Control

const Themes = preload("res://scripts/pattern/theme_registry.gd")
const LeafCenters = preload("res://scripts/pattern/leaf_centers.gd")
var theme_id := "vines"
var core: Texture2D
var core_region := Rect2()
var leaves: Array = []
var leaf_bounds := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var profile := Themes.profile(theme_id)
	var leaf_config: Dictionary = profile.get("junctions", {}).get("leaf_centers", {})
	if not leaf_config.is_empty():
		leaves = LeafCenters.placements(leaf_config, Vector2i.ZERO, 1, 0)
		var first := true
		for spec: Dictionary in leaves:
			var used := Rect2(spec.asset.get_image().get_used_rect())
			var bounds: Rect2 = spec.source_transform * used
			leaf_bounds = bounds if first else leaf_bounds.merge(bounds)
			first = false
	else:
		var path: String = profile.get("preview", {}).get("core", "")
		if not path.is_empty():
			core = load(path)
			core_region = Rect2(core.get_image().get_used_rect())

func _draw() -> void:
	var extent := minf(size.x, size.y) * 0.84
	if not leaves.is_empty():
		var factor := extent / maxf(leaf_bounds.size.x, leaf_bounds.size.y)
		var fit := Transform2D(0, Vector2.ONE * factor, 0, size/2 - leaf_bounds.get_center()*factor)
		for spec: Dictionary in leaves:
			draw_set_transform_matrix(fit * spec.source_transform)
			draw_texture(spec.asset, Vector2.ZERO)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	elif core != null and core_region.has_area():
		var dimensions := core_region.size * extent / maxf(core_region.size.x, core_region.size.y)
		draw_texture_rect_region(core, Rect2((size-dimensions)/2, dimensions), core_region)
