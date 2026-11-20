extends RefCounted
const Palette = preload("res://scripts/palette.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
static func theme_id() -> String: return Palette.theme_id()
static func surface_color(key: String) -> Color:
	return Color(Themes.profile(Palette.theme_id()).ui[key])
static func background() -> Color: return surface_color("background")
static func controls() -> Color: return surface_color("controls")
static func light() -> Color: return surface_color("lit_edge")
static func shade() -> Color: return surface_color("shaded_edge")
static func text() -> Color: return surface_color("text")
static func muted() -> Color: return text().lerp(controls(), 0.5)
static func accent(_color: int = 1) -> Color: return text()
