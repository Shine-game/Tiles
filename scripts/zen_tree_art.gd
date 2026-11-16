extends RefCounted
const ROOT := "res://art/themes/zen_garden/artwork/trees/"
# Source region and woody attachment point in the unchanged supplied masters.
const BRANCHES := {
	"spring": [
		["individual_first_set/spring_sakura_medium_02.png", Rect2(63, 404, 1120, 464), Vector2(68, 721)],
		["individual_first_set/spring_sakura_long_03.png", Rect2(111, 261, 984, 711), Vector2(116, 768)]],
	"summer": [
		["individual_first_set/summer_green_short_01.png", Rect2(446, 469, 374, 323), Vector2(452, 601)],
		["individual_first_set/summer_green_long_02.png", Rect2(80, 256, 1120, 727), Vector2(85, 780)]],
	"autumn": [
		["individual_first_set/autumn_red_short_01.png", Rect2(341, 382, 539, 464), Vector2(345, 693)],
		["individual_first_set/autumn_red_medium_02.png", Rect2(193, 278, 865, 695), Vector2(198, 387)],
		["individual_first_set/autumn_red_long_03.png", Rect2(47, 201, 1162, 848), Vector2(52, 817)]],
	"winter": [
		["winter/winter_bare_branches_light_snow_3x3_sheet.png", Rect2(24, 28, 488, 304), Vector2(43, 308)],
		["winter/winter_bare_branches_light_snow_3x3_sheet.png", Rect2(24, 350, 488, 306), Vector2(54, 612)],
		["winter/winter_bare_branches_light_snow_3x3_sheet.png", Rect2(24, 682, 488, 322), Vector2(45, 944)]]}
static var textures: Dictionary = {}
static func asset(season: String, choice: int) -> Dictionary:
	var entry: Array = BRANCHES[season][choice % BRANCHES[season].size()]
	if not textures.has(entry[0]): textures[entry[0]] = load(ROOT + entry[0])
	var master: Texture2D = textures[entry[0]]
	var atlas := AtlasTexture.new()
	atlas.atlas = master
	atlas.region = entry[1]
	atlas.filter_clip = true
	var rect: Rect2 = entry[1]
	var pivot: Vector2 = entry[2] - rect.position
	return {"texture": atlas, "size": rect.size, "pivot": pivot, "uv_rect": Vector4(rect.position.x / master.get_width(), rect.position.y / master.get_height(), rect.size.x / master.get_width(), rect.size.y / master.get_height())}
