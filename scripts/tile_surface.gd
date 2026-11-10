class_name TileSurface
extends RefCounted

const Palette = preload("res://scripts/palette.gd")
const Platform = preload("res://scripts/occupied_platform.gd")

static func depth(unit: float) -> float:
	return Platform.depth(unit)

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
	slab.configure(face.position, face.size.x, color, Palette.coral_reef)
	# The four-pixel inter-square gap is not part of the logical cell pitch.
	# Keep the same depth as a committed cell despite this smaller face.
	slab.depth_pixels = thickness
	var margin: float = thickness * 2.0 + 1.0
	slab.position = face.position - Vector2.ONE * margin
	slab.size = face.size + Vector2(0, thickness) + Vector2.ONE * 2 * margin
	slab.material.set_shader_parameter("depth_pixels", thickness)
	slab.material.set_shader_parameter("margin_pixels", margin)
	slab.material.set_shader_parameter("rect_pixels", slab.size)
	slab.show()
