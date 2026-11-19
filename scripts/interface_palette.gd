extends RefCounted

const Palette = preload("res://scripts/palette.gd")

# Keep the Zen game artwork active while its interface uses neutral styling.
static func background() -> Color:
	return Color.WHITE if Palette.zen_garden else Palette.background()

static func controls() -> Color:
	return Color("eeeeee") if Palette.zen_garden else Palette.controls()

static func text() -> Color:
	return Color("202020") if Palette.zen_garden else Palette.text()

static func muted() -> Color:
	return Color("999999") if Palette.zen_garden else Palette.muted()

static func accent(color: int = 1) -> Color:
	return Color("888888") if Palette.zen_garden else Palette.tile(color)
