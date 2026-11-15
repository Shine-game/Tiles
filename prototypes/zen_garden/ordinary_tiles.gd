extends Control

const Geometry = preload("res://scripts/zen_geometry.gd")
const Platform = preload("res://scripts/occupied_platform.gd")
const SAND_SHADER = preload("res://shaders/zen_sand.gdshader")
const SAND = preload("res://art/themes/zen_garden/artwork/ground/sand_ground_256.png")
const STONES = [
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_N_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_E_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_S_256.png"),
	preload("res://art/themes/zen_garden/artwork/stone_paths/half_stone_W_256.png")]
const CORE = preload("res://art/themes/zen_garden/artwork/cores/stepping_stone_core_256.png")
const FIXTURE = ["000010000", "011111110", "010010010", "011111110", "100010000", "011111110", "010010010", "011111110", "000010000"]
var family := 0
var atlas := false
var board_size := 9
var turn := 0
var light_turn := 0
var lighting := true
var materials: Array[ShaderMaterial] = []
var textures: Dictionary = {}
var board_layer: Node2D
var title: Label
var subtitle: Label
var status: Label
var mode_buttons: Array[Button] = []

func _ready() -> void:
	var bg := ColorRect.new()
	bg.z_index = -3
	bg.color = Color("f5f2e9")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	title = label("Zen Garden", 34, Vector2(30, 18))
	subtitle = label("Ordinary tiles · first review", 18, Vector2(32, 62))
	for i in range(3):
		var index := i
		var choice := button(["Raked sand", "Stepping stones", "Mixed"][i], Rect2(30 + i * 222, 100, 216, 48), func(): family = index; rebuild())
		mode_buttons.append(choice)
	board_layer = Node2D.new()
	add_child(board_layer)
	button("Rotate layout", Rect2(30, 890, 216, 52), func(): turn = (turn + 1) % 4; rebuild())
	button("Move light", Rect2(252, 890, 216, 52), func(): light_turn = (light_turn + 1) % 4; update_light())
	button("9 × 9 / 11 × 11", Rect2(474, 890, 216, 52), func(): board_size = 11 if board_size == 9 else 9; rebuild())
	button("All 16 shapes / field", Rect2(30, 952, 327, 52), func(): atlas = not atlas; rebuild())
	button("Lighting on / off", Rect2(363, 952, 327, 52), func(): lighting = not lighting; update_light())
	status = label("", 17, Vector2(32, 1020))
	label("Same sand · four-pixel lip · matching edge ports", 16, Vector2(32, 1056))
	rebuild()

func label(text: String, font_size: int, at: Vector2) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("4c5847"))
	add_child(node)
	return node

func button(text: String, box: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = box.position
	node.size = box.size
	node.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e8ecdf") if state == "pressed" else Color("f5f2e9")
		style.border_color = Color("89947e")
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		node.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, Color("4c5847"))
	node.pressed.connect(action)
	add_child(node)
	return node

func fixture() -> Array:
	var grid: Array = []
	for y in range(board_size):
		var row: Array = []
		for x in range(board_size):
			var offset := (board_size - 9) / 2
			var sx := x - int(offset)
			var sy := y - int(offset)
			var occupied: bool = sx >= 0 and sx < 9 and sy >= 0 and sy < 9 and FIXTURE[sy][sx] == "1"
			row.append((2 if family == 1 or family == 2 and sx > 4 else 1) if occupied else 0)
		grid.append(row)
	for t in range(turn):
		var rotated: Array = []
		for y in range(board_size):
			var row: Array = []
			for x in range(board_size): row.append(grid[board_size - 1 - x][y])
			rotated.append(row)
		grid = rotated
	return grid

func sand_material(cell: Vector2, relief: Texture2D = null) -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SAND_SHADER
	shader_material.set_shader_parameter("sand", SAND)
	shader_material.set_shader_parameter("cell_origin", cell)
	shader_material.set_shader_parameter("has_relief", relief != null)
	if relief != null: shader_material.set_shader_parameter("relief_map", relief)
	materials.append(shader_material)
	return shader_material

func rebuild() -> void:
	for child: Node in board_layer.get_children():
		board_layer.remove_child(child)
		child.queue_free()
	materials.clear()
	for i in range(mode_buttons.size()):
		mode_buttons[i].modulate = Color.WHITE if i == family else Color(1, 1, 1, 0.68)
	var pitch := 660.0 / board_size
	var origin := Vector2(30, 180)
	var ground := ColorRect.new()
	ground.z_index = -2
	ground.position = origin
	ground.size = Vector2.ONE * 660
	ground.material = sand_material(Vector2.ZERO)
	ground.material.set_shader_parameter("area_cells", Vector2.ONE * board_size)
	board_layer.add_child(ground)
	var grid := fixture()
	if atlas:
		for row: Array in grid: row.fill(0)
		for mask in range(16):
			var cell := Vector2i(1 + mask % 4 * 2, 1 + mask / 4 * 2)
			grid[cell.y][cell.x] = 2 if family == 1 or family == 2 and mask % 4 >= 2 else 1
	# The shared occupancy union removes walls/shadows at every internal join,
	# including A/B borders. A fixed lip does not enable Clockwork materials.
	var slab := Platform.new()
	slab.sync(grid)
	slab.configure(origin, pitch, Color("e9e3d6"), false, 4.0, false)
	board_layer.add_child(slab)
	for y in range(board_size):
		for x in range(board_size):
			if grid[y][x] == 0: continue
			var cell := Vector2i(x, y)
			var mask: int = Geometry.neighbor_mask(grid, cell)
			if atlas: mask = Geometry.rotate_mask(((y - 1) / 2) * 4 + (x - 1) / 2, turn)
			add_tile(cell, mask, grid[y][x], origin, pitch)
			if atlas:
				var annotation := Label.new()
				annotation.text = "%02d" % mask
				annotation.position = origin + Vector2(cell) * pitch + Vector2(0, pitch + 8)
				annotation.add_theme_font_size_override("font_size", 16)
				annotation.add_theme_color_override("font_color", Color("64705d"))
				board_layer.add_child(annotation)
	status.text = "%d × %d · %.0f px cells · %s" % [board_size, board_size, pitch * 0.75, "all connection shapes" if atlas else "same-color joins only"]
	update_light()

func add_tile(cell: Vector2i, mask: int, color: int, origin: Vector2, pitch: float) -> void:
	var face := ColorRect.new()
	face.position = origin + Vector2(cell) * pitch
	face.size = Vector2.ONE * pitch
	face.material = sand_material(Vector2(cell))
	board_layer.add_child(face)
	if color == 1:
		var spec: Dictionary = Geometry.canonical(mask)
		if not textures.has(spec.mask): textures[spec.mask] = ImageTexture.create_from_image(Geometry.height_image(spec.mask))
		var motif := Sprite2D.new()
		motif.texture = textures[spec.mask]
		motif.position = face.position + Vector2.ONE * pitch / 2
		motif.scale = Vector2.ONE * pitch / 256.0
		motif.rotation = spec.turns * PI / 2
		# Neutral sand stays in board space even while the height geometry rotates.
		motif.material = sand_material(Vector2(cell), textures[spec.mask])
		motif.material.set_shader_parameter("tile_angle", motif.rotation)
		board_layer.add_child(motif)
	else:
		for direction in range(4):
			if not mask & (1 << direction) and mask != 0: continue
			var stone := Sprite2D.new()
			stone.texture = CORE if mask == 0 else STONES[direction]
			stone.position = face.position + Vector2.ONE * pitch / 2
			stone.scale = Vector2.ONE * pitch / 256.0
			stone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			board_layer.add_child(stone)
			if mask == 0: break

func update_light() -> void:
	var xy := Vector2(-0.45, -0.55).rotated(light_turn * PI / 2)
	for shader_material: ShaderMaterial in materials:
		shader_material.set_shader_parameter("light_dir", Vector3(xy.x, xy.y, 0.70))
		shader_material.set_shader_parameter("lighting_enabled", lighting)
