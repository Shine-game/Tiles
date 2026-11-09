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
static var labyrinth := false
const HEDGE_GREEN := Color("119d45")
const HEDGE_ROSE := Color("f43877")
const SAND := Color("efe1c3")

static func select(index: int) -> bool:
	if index < 0 or index >= PAIRS.size():
		return false
	selected_index = index
	return true

static func tile(color: int) -> Color:
	if labyrinth:
		return HEDGE_GREEN if color == 1 else HEDGE_ROSE
	return PAIRS[selected_index].colors[0 if color == 1 else 1]

static func accent(color: int) -> Color:
	return tile(3 - color)

static func pigment(color: int) -> Color:
	return tile(color)

static func blossom(color: int) -> Color:
	return accent(color)

static func floor_color() -> Color:
	return SAND if labyrinth else PAIRS[selected_index].floor

static func dark() -> bool:
	return floor_color().get_luminance() < 0.4

static func background() -> Color:
	return Color.WHITE

static func controls() -> Color:
	return Color("eeedf3")

static func text() -> Color:
	return Color("40334d")

static func muted() -> Color:
	return Color("9b8ca6")

static func grid() -> Color:
	return Color("bbc9e4") if dark() else Color("947c9c")

static func garden() -> Color:
	if labyrinth:
		return Color("f6e9ce")
	# One continuous terrace, including boundaries between the two pigments.
	return floor_color().lightened(0.09) if dark() else floor_color().darkened(0.035)
