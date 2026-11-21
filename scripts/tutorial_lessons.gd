extends RefCounted

# Stable identifiers drive both the controller and persisted progress.
const ORDER := ["rotate", "flip", "color", "place", "vertical", "horizontal", "rotational", "repair", "reveal"]
const CARD_COUNT := 8
const REPAIR_ORDER := ["wrong_placement", "undo", "erase", "replace", "place_replacement", "save"]
const LESSONS := {
	"rotate": {"number":1,"caption":"Tap the piece to rotate it.","actions":["rotate"],"axis_mode":"teaching","fixture":"prepared_l","next":"flip"},
	"flip": {"number":1,"caption":"Press Flip to mirror it.","actions":["flip"],"axis_mode":"teaching","fixture":"prepared_l","next":"color"},
	"color": {"number":1,"caption":"Press Color to choose its color.","actions":["color"],"axis_mode":"teaching","fixture":"prepared_l","next":"place"},
	"place": {"number":1,"caption":"Drag the piece into position and press Place.","actions":["place"],"axis_mode":"teaching","fixture":"prepared_l","next":"vertical"},
	"vertical": {"number":2,"caption":"Complete the vertical symmetry.","actions":["rotate","flip","color","place"],"axis_mode":"teaching","fixture":"vertical","next":"horizontal"},
	"horizontal": {"number":3,"caption":"Complete the horizontal symmetry.","actions":["rotate","flip","color","place"],"axis_mode":"teaching","fixture":"horizontal","next":"rotational"},
	"rotational": {"number":4,"caption":"Complete the rotational symmetry.","actions":["rotate","flip","color","place"],"axis_mode":"teaching","fixture":"rotational","next":"repair"},
	"repair": {"number":5,"caption":"","actions":[],"axis_mode":"predictive","fixture":"repair","next":"reveal"},
	"reveal": {"number":8,"caption":"Choose your theme and create intricate worlds.","actions":["settings","themes","choose_theme"],"axis_mode":"predictive","fixture":"final","next":""}
}
const REPAIR := {
	"wrong_placement": {"number":5,"caption":"The hint button shows achievable symmetries. Make an asymmetric placement and the game ends.","header":"","actions":["rotate","flip","color","place"],"offer":1,"target":"offer","next":"undo"},
	"undo": {"number":6,"caption":"Undo your last move.","header":"Save the pattern","actions":["undo"],"offer":-1,"target":"","next":"erase"},
	"erase": {"number":6,"caption":"Erase a square.","header":"","actions":["erase"],"offer":-1,"target":"erase_square","next":"replace"},
	"replace": {"number":6,"caption":"Get a different piece and place it.","header":"","actions":["rotate","flip","color","skip"],"offer":-1,"target":"","next":"place_replacement"},
	"place_replacement": {"number":6,"caption":"Get a different piece and place it.","header":"","actions":["rotate","flip","color","place"],"offer":2,"target":"offer","next":"save"},
	"save": {"number":7,"caption":"Bold axis! Your board is symmetrical right now. You can save a picture here if you want.","header":"","actions":["save"],"offer":-1,"target":"","next":""}
}

static func checkpoint(value: Variant) -> String:
	return value if value is String and value in REPAIR_ORDER else REPAIR_ORDER[0]

static func definition(lesson_id: String, repair_checkpoint: String = "wrong_placement") -> Dictionary:
	return REPAIR[repair_checkpoint] if lesson_id == "repair" else LESSONS[lesson_id]

static func captions() -> Array:
	var result: Array = []
	for key: String in ORDER: result.append(LESSONS[key].caption)
	for key: String in REPAIR_ORDER: result.append(REPAIR[key].caption)
	return result
