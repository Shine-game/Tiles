extends RefCounted
# Zen's ordinary sets. Ponds, historical trees and landmarks stay project-owned.
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const Catalog = preload("res://scripts/pattern/legacy_assets.gd")
const Geometry = preload("res://scripts/zen_geometry.gd")
const Centerpiece = preload("res://scripts/zen_centerpiece.gd")
const ROOT := "res://art/themes/zen_garden/sets/"
const DIRECTIONS := ["N", "E", "S", "W"]
static var families: Dictionary = {}

static func install() -> void:
	if not families.is_empty(): return
	Catalog.install()
	Assets.register_provider("zen.rake_overlap", _overlap, _overlap_parameters)
	Renderer.register_node_provider("zen.rake_centerpiece", _center)
	for family: String in ["rakes", "stones"]:
		var tiers: Array = []
		for tier in [0, 1]:
			var loaded := Assets.load_set(ROOT + family + "-tier%d.json" % tier)
			assert(loaded.ok, str(loaded.errors))
			for composition: Dictionary in loaded.definition.compositions.values():
				for part: Dictionary in composition.parts.values():
					for asset: Dictionary in part.get("stage_artwork", []):
						assert(Assets.validate(asset, loaded.root).is_empty(), "Invalid Zen stage artwork")
			tiers.append(loaded)
		families[family] = tiers

static func centers(color: int, mask: int) -> Dictionary:
	install()
	var tiers: Array = families["rakes" if color == 1 else "stones"]
	return Cells.center_parts(mask, tiers[0], tiers[1])

static func _placed(part: Dictionary, cell: Vector2i) -> Dictionary:
	var spec := part.duplicate(true)
	spec.asset_root = ROOT
	spec.position_cells = Cells.anchor(cell)
	return spec

static func rake_spec(cell: Vector2i, mask: int) -> Dictionary:
	var selected := centers(1, mask)
	var canonical := Geometry.canonical(mask)
	var part: Dictionary = selected.rake if selected.has("rake") else Cells.parts_for_role(families.rakes[1], "vine").rake
	var spec := _placed(part, cell)
	if mask != 0 and canonical.mask != 1: spec.asset.params.mask = canonical.mask
	spec.quarter_turns = canonical.turns
	return spec

static func stone_specs(cell: Vector2i, mask: int) -> Array[Dictionary]:
	var selected := centers(2, mask)
	var specs: Array[Dictionary] = []
	# The endpoint core is below the directional path ending, and is a distinct
	# source file so later endpoint artwork edits cannot change isolated tiles.
	for part: Dictionary in selected.values(): specs.append(_placed(part, cell))
	if mask == 0: return specs
	var vine: Dictionary = Cells.parts_for_role(families.stones[1], "vine").half
	for direction in range(4):
		if not mask & (1 << direction): continue
		var spec := _placed(vine, cell)
		spec.asset = Assets.select_variant(spec.asset, DIRECTIONS[direction])
		var anchor := Vector2(Geometry.OFFSETS[direction]) * 128.0
		spec.position_cells = Cells.anchor(cell, vine.anchor, direction)
		spec.offset_px = -anchor
		specs.append(spec)
	return specs

static func center_spec(cell: Vector2i, mask: int) -> Dictionary:
	var selected := centers(1, mask)
	return _placed(selected.center, cell) if selected.has("center") else {}

static func _center(spec: Dictionary) -> CanvasItem:
	var node := Centerpiece.new()
	var textures: Array[Texture2D] = []
	for asset: Dictionary in spec.stage_artwork: textures.append(Assets.resolve(asset, spec.asset_root))
	node.configure_artwork(textures, spec.animation.canvas_scale, spec.animation.duration_seconds)
	return node

static func _overlap_parameters(params: Dictionary) -> Array:
	if params.get("ending_mask") != 1: return ["Rake overlap requires the north endpoint ending"]
	if params.get("port_guard_pixels") != 32: return ["Rake overlap must preserve the existing 32-pixel edge profile"]
	var errors := Assets.validate(params.get("core_path"))
	if not errors.is_empty(): return errors
	var source := Assets.texture(params.core_path)
	if source.get_size() != Vector2(256, 256) or source.get_image().get_format() != Image.FORMAT_RF:
		return ["Rake endpoint core must be the 256-pixel floating-point relief texture"]
	return []

static func _overlap(params: Dictionary) -> Texture2D:
	var core: Image = Assets.texture(params.core_path).get_image()
	var ending := Geometry.height_image(int(params.ending_mask))
	var heights := core.get_data().to_float32_array()
	var path := ending.get_data().to_float32_array()
	for i in range(heights.size()):
		# Relief layers share one sand surface. Combining their grooves avoids
		# a second opaque sand sprite concealing the core underneath it.
		heights[i] = path[i] if i < int(params.port_guard_pixels) * Geometry.SIZE else minf(heights[i], path[i])
	return ImageTexture.create_from_image(Image.create_from_data(256, 256, false, Image.FORMAT_RF, heights.to_byte_array()))
