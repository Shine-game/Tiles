class_name TileSurface
extends RefCounted

const Palette = preload("res://scripts/palette.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const Zen = preload("res://scripts/zen_visuals.gd")

static func depth(unit: float) -> float:
	return 4.0 if Palette.clockwork or Palette.zen_garden else Platform.depth(unit)

static func _zen_top(slab, n: int, pitch: float, invalid: bool) -> void:
	var face = slab.get_node_or_null("ZenSand")
	if not Palette.zen_garden:
		if face != null: face.hide()
		return
	if face == null:
		face = ColorRect.new()
		face.name = "ZenSand"
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.material = Zen.sand_material()
		slab.add_child(face)
	var margin: float = slab.depth_pixels * 2 + 1
	face.position = Vector2.ONE * margin
	face.size = Vector2.ONE * n * pitch
	face.color = Color(0.70, 0.70, 0.70) if invalid else Color.WHITE
	face.material.set_shader_parameter("area_cells", Vector2.ONE * n)
	face.material.set_shader_parameter("clip_to_surface", true)
	face.material.set_shader_parameter("occupancy_mask", slab.mask_texture)
	face.material.set_shader_parameter("grid_size", n)
	face.material.set_shader_parameter("cell_pixels", pitch)
	face.material.set_shader_parameter("screen_pixel", 1.0)
	face.show()

# Reuse the exact occupied-ground renderer for each separate incoming square.
# Children are reused on redraw; hiding unused slabs handles shape changes.
static func begin(canvas: CanvasItem) -> void:
	canvas.set_meta("slab_index", 0)
	for child: Node in canvas.get_children():
		if child.has_meta("tile_slab"):
			child.hide()

static func draw(canvas: CanvasItem, face: Rect2, color: Color, thickness: float) -> void:
	var index: int = canvas.get_meta("slab_index", 0)
	canvas.set_meta("slab_index", index + 1)
	var name := "TileSlab%d" % index
	var slab = canvas.get_node_or_null(NodePath(name))
	if slab == null:
		slab = Platform.new()
		slab.name = name
		slab.set_meta("tile_slab", true)
		canvas.add_child(slab)
		slab.sync([[1]])
		slab.z_index = 0
	slab.configure(face.position, face.size.x, Palette.platform_color() if Palette.zen_garden and color != Palette.INVALID else color, Palette.coral_reef, 4.0 if Palette.clockwork or Palette.zen_garden else -1.0, not Palette.zen_garden)
	# The four-pixel inter-square gap is not part of the logical cell pitch.
	# Keep the same depth as a committed cell despite this smaller face.
	slab.depth_pixels = thickness
	var margin: float = thickness * 2.0 + 1.0
	slab.position = face.position - Vector2.ONE * margin
	slab.size = face.size + Vector2(0, thickness) + Vector2.ONE * 2 * margin
	slab.material.set_shader_parameter("depth_pixels", thickness)
	slab.material.set_shader_parameter("margin_pixels", margin)
	slab.material.set_shader_parameter("rect_pixels", slab.size)
	_zen_top(slab, 1, face.size.x, color == Palette.INVALID)
	slab.show()

# A piece is one occupied union, just like placed ground: no gaps, repeated
# internal walls, or stacked shadows along the joins between its squares.
static func draw_piece(canvas: CanvasItem, cells: Array, origin: Vector2, pitch: float, color: Color) -> void:
	if cells.is_empty():
		return
	var extent := 1
	for cell: Vector2i in cells:
		extent = maxi(extent, maxi(cell.x, cell.y) + 1)
	var grid: Array = []
	for y in range(extent):
		var row: Array = []
		row.resize(extent)
		row.fill(0)
		grid.append(row)
	for cell: Vector2i in cells:
		grid[cell.y][cell.x] = 1
	var slab = canvas.get_node_or_null("PieceSlab")
	if slab == null:
		slab = Platform.new()
		slab.name = "PieceSlab"
		slab.set_meta("tile_slab", true)
		slab.z_index = 0
		canvas.add_child(slab)
	slab.sync(grid)
	slab.configure(origin, pitch, Palette.platform_color() if Palette.zen_garden and color != Palette.INVALID else color, Palette.coral_reef, 4.0 if Palette.clockwork or Palette.zen_garden else -1.0, not Palette.zen_garden)
	_zen_top(slab, extent, pitch, color == Palette.INVALID)
	slab.show()
