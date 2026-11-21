extends RefCounted

# Stable identifiers are the persisted contract. Legacy numbers are adapters for
# the existing controller and old saves, not the displayed card numbers.
const ORDER := ["rotate", "flip", "color", "place", "vertical", "horizontal", "rotational", "repair", "reveal"]
const CARD_COUNT := 8
const REPAIR_ORDER := ["wrong_placement", "undo", "erase", "replace", "place_replacement", "save"]
const LESSONS := {
	"rotate": {"number":1,"legacy":2,"caption":"Tap the piece to rotate it.","actions":["rotate"],"axis_mode":"teaching","fixture":"prepared_l","next":"flip"},
	"flip": {"number":1,"legacy":3,"caption":"Press Flip to mirror it.","actions":["flip"],"axis_mode":"teaching","fixture":"prepared_l","next":"color"},
	"color": {"number":1,"legacy":4,"caption":"Press Color to choose its color.","actions":["color"],"axis_mode":"teaching","fixture":"prepared_l","next":"place"},
	"place": {"number":1,"legacy":5,"caption":"Drag the piece into position and press Place.","actions":["place"],"axis_mode":"teaching","fixture":"prepared_l","next":"vertical"},
	"vertical": {"number":2,"legacy":6,"caption":"Complete the vertical symmetry.","actions":["rotate","flip","color","place"],"axis_mode":"teaching","fixture":"vertical","next":"horizontal"},
	"horizontal": {"number":3,"legacy":7,"caption":"Complete the horizontal symmetry.","actions":["rotate","flip","color","place"],"axis_mode":"teaching","fixture":"horizontal","next":"rotational"},
	"rotational": {"number":4,"legacy":8,"caption":"Complete the rotational symmetry.","actions":["rotate","flip","color","place"],"axis_mode":"teaching","fixture":"rotational","next":"repair"},
	"repair": {"number":5,"legacy":10,"caption":"","actions":[],"axis_mode":"predictive","fixture":"repair","next":"reveal"},
	"reveal": {"number":8,"legacy":11,"caption":"Choose your theme and create intricate worlds.","actions":[],"axis_mode":"predictive","fixture":"final","next":""}
}
const REPAIR := {
	"wrong_placement": {"number":5,"caption":"The hint button shows achievable symmetries. Make an asymmetric placement and the game ends.","header":"","actions":["rotate","flip","color","place"],"offer":1,"target":"offer","next":"undo"},
	"undo": {"number":6,"caption":"Undo your last move.","header":"Save the pattern","actions":["undo"],"offer":-1,"target":"","next":"erase"},
	"erase": {"number":6,"caption":"Erase a square.","header":"","actions":["erase"],"offer":-1,"target":"erase_square","next":"replace"},
	"replace": {"number":6,"caption":"Get a different piece and place it.","header":"","actions":["rotate","flip","color","skip"],"offer":-1,"target":"","next":"place_replacement"},
	"place_replacement": {"number":6,"caption":"Get a different piece and place it.","header":"","actions":["rotate","flip","color","place"],"offer":2,"target":"offer","next":"save"},
	"save": {"number":7,"caption":"Bold axis! Your board is symmetrical right now. You can save a picture here if you want.","header":"","actions":["save"],"offer":-1,"target":"","next":""}
}

static func id(value: Variant) -> String:
	if value is String: return value if LESSONS.has(value) else ORDER[0]
	if value is int:
		if value == 1: return ORDER[0]
		if value == 9: return "repair"
		for key: String in ORDER:
			if LESSONS[key].legacy == value: return key
	return ORDER[0]

static func legacy(value: Variant) -> int:
	return LESSONS[id(value)].legacy

static func checkpoint(value: Variant) -> String:
	return value if value is String and value in REPAIR_ORDER else REPAIR_ORDER[0]

static func phase(value: Variant) -> int:
	return REPAIR_ORDER.find(checkpoint(value))+2

static func checkpoint_for_phase(value: int) -> String:
	return REPAIR_ORDER[clampi(value-2,0,REPAIR_ORDER.size()-1)]

static func definition(value: Variant, repair_phase: int = 2) -> Dictionary:
	var key := id(value)
	return REPAIR[checkpoint_for_phase(repair_phase)] if key == "repair" else LESSONS[key]

static func captions() -> Array:
	var result: Array = []
	for key: String in ORDER: result.append(LESSONS[key].caption)
	for key: String in REPAIR_ORDER: result.append(REPAIR[key].caption)
	return result
