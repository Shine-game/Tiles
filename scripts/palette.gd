class_name TilePalette
extends RefCounted

const Themes = preload("res://scripts/pattern/theme_registry.gd")
# Logical IDs and player palette choice stay independent of theme artwork.
static var PAIRS: Array = Themes.palette_pairs()
const INVALID := Color("96999c")
const INVALID_BORDER := Color("6f7377")
static var selected_index := 0
static var THEMES: Array = Themes.ids()
static var active_theme: String = Themes.specification().default
# Read-only compatibility views used by specialized renderers, never separate state.
static var coral_reef: bool:
	get: return Themes.profile(active_theme).hooks.environment == "coral_reef"
static var clockwork: bool:
	get: return Themes.profile(active_theme).hooks.environment == "clockwork"

static func theme_id() -> String:
	return active_theme

static func theme_version() -> String:
	return Themes.profile(active_theme).version

static func theme_name() -> String:
	return theme_label(active_theme)

static func theme_label(id: String) -> String:
	return Themes.label(id)

static func select_theme(id: String) -> bool:
	if id not in THEMES: return false
	active_theme = id
	return true

static func select(index: int) -> bool:
	if index < 0 or index >= PAIRS.size(): return false
	selected_index = index
	return true

static func tile(color: int) -> Color:
	var colors: Array = Themes.profile(active_theme).colors
	return PAIRS[selected_index].colors[0 if color == 1 else 1] if colors.is_empty() else Color(colors[0 if color == 1 else 1])

static func accent(color: int) -> Color:
	return tile(3 - color)

static func pigment(color: int) -> Color:
	return tile(color)

static func blossom(color: int) -> Color:
	return accent(color)

static func _ui(key: String, fallback: Color) -> Color:
	var ui: Dictionary = Themes.profile(active_theme).ui
	return Color(ui[key]) if ui.has(key) else fallback

static func floor_color() -> Color:
	return _ui("floor", PAIRS[selected_index].floor)

static func dark() -> bool:
	return floor_color().get_luminance() < 0.4

static func background() -> Color:
	return _ui("background", floor_color())

static func controls() -> Color:
	return _ui("controls", Color.WHITE)

static func text() -> Color:
	return _ui("text", Color.BLACK)

static func muted() -> Color:
	return _ui("muted", Color.GRAY)

static func grid() -> Color:
	return _ui("seams", Color("bbc9e4") if dark() else Color("947c9c"))

static func garden() -> Color:
	return _ui("garden", floor_color().lightened(0.09) if dark() else floor_color().darkened(0.035))

static func platform_color() -> Color:
	return _ui("platform", garden())
