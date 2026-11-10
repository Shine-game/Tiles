class_name OccupiedPlatform
extends ColorRect

const EDGE_SHADER = preload("res://shaders/occupied_platform.gdshader")
const SOURCE_CELL := 256.0
const SOURCE_DEPTH := 24.0
const SURFACE_REVISION := "rounded24-v2"
var occupancy: Image
var mask_texture: ImageTexture
var occupancy_bytes := PackedByteArray()
var grid_size := 0
var mask_revision := 0
var cell_pixels := 1.0
var depth_pixels := 0.0
var top_origin := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1
	var shader_material := ShaderMaterial.new()
	shader_material.shader = EDGE_SHADER
	material = shader_material

static func depth(pitch: float) -> float:
	return pitch * SOURCE_DEPTH / SOURCE_CELL

func sync(grid: Array) -> void:
	var n: int = grid.size()
	var bytes := PackedByteArray()
	bytes.resize(n * n)
	for y in range(n):
		for x in range(n):
			bytes[y * n + x] = 255 if int(grid[y][x]) != 0 else 0
	if n == grid_size and bytes == occupancy_bytes:
		return
	visible = bytes.has(255)
	occupancy_bytes = bytes
	occupancy = Image.create_from_data(n, n, false, Image.FORMAT_R8, bytes)
	if grid_size == n and mask_texture != null:
		mask_texture.update(occupancy)
	else:
		mask_texture = ImageTexture.create_from_image(occupancy)
	grid_size = n
	mask_revision += 1
	(material as ShaderMaterial).set_shader_parameter("occupancy_mask", mask_texture)
	(material as ShaderMaterial).set_shader_parameter("grid_size", n)

static func surface_revision(theme: String) -> String:
	return "lagoon-waves24-v4" if theme == "coral_reef" else SURFACE_REVISION

func configure(origin: Vector2, pitch: float, ink: Color, underwater: bool = false) -> void:
	top_origin = origin
	cell_pixels = pitch
	depth_pixels = depth(pitch)
	var margin: float = depth_pixels * 2.0 + 1.0
	position = origin - Vector2.ONE * margin
	size = Vector2(grid_size * pitch, grid_size * pitch + depth_pixels) + Vector2.ONE * 2 * margin
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("cell_pixels", pitch)
	shader_material.set_shader_parameter("depth_pixels", depth_pixels)
	shader_material.set_shader_parameter("margin_pixels", margin)
	shader_material.set_shader_parameter("rect_pixels", size)
	shader_material.set_shader_parameter("ground_color", ink)
	shader_material.set_shader_parameter("submerged", underwater)

# Logical occupancy for input/geometry verification; rounded rendering does not
# remove any playable area from a cell.
# p is expressed in cells relative to the raised top origin.
func filled(point: Vector2) -> bool:
	var cell := Vector2i(floori(point.x), floori(point.y))
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size and occupancy_bytes[cell.y * grid_size + cell.x] != 0

func side_at(point: Vector2) -> bool:
	return not filled(point) and filled(point - Vector2(0, SOURCE_DEPTH / SOURCE_CELL))
