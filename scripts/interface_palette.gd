extends RefCounted
const Palette = preload("res://scripts/palette.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
static func theme_id() -> String: return Palette.theme_id()
static func directional_bevel() -> bool: return Themes.profile(theme_id()).ui.has("button_shadow")
static func surface_color(key: String) -> Color:
	return Color(Themes.profile(Palette.theme_id()).ui[key])
static func background() -> Color: return surface_color("background")
static func panel_background() -> Color: return controls()
static func controls() -> Color: return surface_color("controls")
static func light() -> Color: return surface_color("lit_edge")
static func shade() -> Color: return surface_color("shaded_edge")
static func text() -> Color: return surface_color("text")
static func muted() -> Color:
	return Color(Themes.profile(theme_id()).ui.disabled_text) if Themes.profile(theme_id()).ui.has("disabled_text") else text().lerp(controls(), 0.5)
static func shadow() -> Color:
	return Color(Themes.profile(theme_id()).ui.button_shadow) if Themes.profile(theme_id()).ui.has("button_shadow") else shade()
static func accent(_color: int = 1) -> Color: return text()
