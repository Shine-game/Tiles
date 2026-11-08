class_name TilePalette
extends RefCounted

# Logical cell IDs remain 1/2; changing a palette never changes the puzzle.
const PAIRS = [
	{"name": "Rose / Violet", "colors": [Color("ff3988"), Color("903dff")], "floor": Color("fff5fb")},
	{"name": "Blue / Snow", "colors": [Color("238bff"), Color("ffffff")], "floor": Color("14253f")},
	{"name": "Violet / Snow", "colors": [Color("aa44ff"), Color("ffffff")], "floor": Color("261b3f")},
	{"name": "Rose / Snow", "colors": [Color("ff438f"), Color("ffffff")], "floor": Color("351b34")},
	{"name": "Blue / Rose", "colors": [Color("246bff"), Color("ff45a0")], "floor": Color("f5f3ff")},
]
const INVALID := Color("96999c")
const INVALID_BORDER := Color("6f7377")
static var selected_index := 0

static func select(index: int) -> bool:
	if index < 0 or index >= PAIRS.size():
		return false
	selected_index = index
	return true

static func tile(color: int) -> Color:
	return PAIRS[selected_index].colors[0 if color == 1 else 1]

static func accent(color: int) -> Color:
	return tile(3 - color)

static func pigment(color: int) -> Color:
	return tile(color)

static func blossom(color: int) -> Color:
	return accent(color)

static func floor_color() -> Color:
	return PAIRS[selected_index].floor

static func dark() -> bool:
	return floor_color().get_luminance() < 0.4

static func background() -> Color:
	return floor_color().darkened(0.06) if dark() else floor_color()

static func controls() -> Color:
	return floor_color().lightened(0.10) if dark() else floor_color().darkened(0.055)

static func text() -> Color:
	return Color("f7f2ff") if dark() else Color("40334d")

static func muted() -> Color:
	return Color("8794ae") if dark() else Color("9b8ca6")

static func grid() -> Color:
	return Color("bbc9e4") if dark() else Color("947c9c")
