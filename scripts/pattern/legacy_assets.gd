extends RefCounted
# Normalize source-package metadata without rewriting the supplied manifests.
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Geometry = preload("res://scripts/zen_geometry.gd")
const Maze = preload("res://scripts/labyrinth_renderer.gd")
static var installed := false

static func install() -> void:
	if installed: return
	installed = true
	Assets.register_provider("zen.rake_relief", _rake, _rake_parameters)
	Renderer.register_draw_provider("legacy.vines", _vines)
	Renderer.register_draw_provider("legacy.labyrinth", _maze)

static func _rake_parameters(params: Dictionary) -> Array:
	var mask: Variant = params.get("mask", -1)
	if not (mask is int or mask is float) or float(mask) != floorf(float(mask)) or int(mask) not in [0, 1, 3, 5, 11, 15]: return ["zen.rake_relief needs a canonical mask (0, 1, 3, 5, 11 or 15)"]
	return []

static func _rake(params: Dictionary) -> Texture2D:
	return ImageTexture.create_from_image(Geometry.height_image(int(params.mask)))

static func _vines(view) -> void:
	view._draw_vines_pattern()

static func _maze(view) -> void:
	Maze.draw(view)

static func component(meta: Dictionary, treatment: String, root: String) -> Dictionary:
	var paths: Dictionary = meta.get("assets", meta.get("artwork", {}))
	var errors: Array = []
	if not paths.has(treatment): return {"ok": false, "errors": ["No artwork treatment: " + treatment]}
	var asset := {"provider": "texture", "path": Assets.path_for(paths[treatment], root)}
	errors.append_array(Assets.validate(asset))
	var pivot: Array = meta.get("pivot", meta.get("pivot_px", []))
	var placement: Dictionary = {}
	if pivot.size() == 2: placement.pivot_px = Renderer.vector(pivot)
	# Keep growth/protection fields separate from artwork; directional masks
	# need not share the artwork's rotation or path.
	var mask: String = meta.get("growth_field", meta.get("reveal_mask", meta.get("growth_mask", "")))
	return {"ok": errors.is_empty(), "errors": errors, "asset": asset, "placement": placement, "reveal_mask": "" if mask.is_empty() else Assets.path_for(mask, root)}
