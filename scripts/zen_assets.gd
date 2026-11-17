extends RefCounted
# Registered Zen relief texture provider; pattern sets own asset metadata.
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Geometry = preload("res://scripts/zen_geometry.gd")
static var installed := false

static func install() -> void:
	if installed: return
	installed = true
	Assets.register_provider("zen.rake_relief", _rake, _rake_parameters)

static func _rake_parameters(params: Dictionary) -> Array:
	var mask: Variant = params.get("mask", -1)
	if not (mask is int or mask is float) or float(mask) != floorf(float(mask)) or int(mask) not in [0, 1, 3, 5, 11, 15]: return ["zen.rake_relief needs a canonical mask (0, 1, 3, 5, 11 or 15)"]
	return []

static func _rake(params: Dictionary) -> Texture2D:
	return ImageTexture.create_from_image(Geometry.height_image(int(params.mask)))
