extends RefCounted

const Rules = preload("res://scripts/rules.gd")
const COMMANDS := ["rotate", "flip", "color", "place", "undo", "erase", "skip"]
signal completed(action: String, result: Dictionary)

# Policy runs before any calculation or mutation. Both normal play and practice
# use the same real TileGame commands.
# Transforms return presentation state; callers apply it when animation completes.
func execute(action: String, game, request: Dictionary = {}, policy: Callable = Callable()) -> Dictionary:
	if action not in COMMANDS: return failure(action,"Unknown action.")
	if policy.is_valid() and not policy.call(action,request): return failure(action,"Action is not available.")
	var result: Dictionary
	match action:
		"rotate", "flip":
			var cells: Variant = request.get("cells",[])
			if not cells is Array or cells.is_empty() or not cells.all(func(cell): return cell is Vector2i):
				return failure(action,"Choose a piece.")
			result = {"ok":true,"cells":Rules.rotate(cells) if action == "rotate" else Rules.flip(cells)}
		"color":
			var current: Variant = request.get("color",0)
			if not current is int or current not in [1,2]: return failure(action,"Invalid piece color.")
			var chosen: Variant = request.get("choice",3-current)
			if not chosen is int or chosen not in [1,2]: return failure(action,"Invalid piece color.")
			result = {"ok":true,"color":chosen}
		_: result = _apply_game(action,game,request)
	result["action"] = action
	result["source"] = request.get("source","player")
	if result.ok: completed.emit(action,result.duplicate(true))
	return result

func _apply_game(action: String, game, request: Dictionary) -> Dictionary:
	if game == null: return failure(action,"No active game.")
	match action:
		"place":
			if not request.get("cells") is Array or not request.get("anchor") is Vector2i:
				return failure(action,"Choose a piece and position.")
			if not request.cells.all(func(cell): return cell is Vector2i):
				return failure(action,"Choose a piece and position.")
			return game.place(request.cells,request.anchor)
		"undo": return {"ok":game.undo()}
		"erase":
			if not request.get("cell") is Vector2i: return failure(action,"Choose a square.")
			return {"ok":game.erase(request.cell)}
		"skip":
			if not request.get("replacement","") is String: return failure(action,"Invalid replacement piece.")
			return {"ok":game.skip(request.get("replacement",""))}
	return failure(action,"Unknown action.")

# Scenario setup is separate from player commands: no joker or move is consumed,
# and no player-action completion signal is emitted.
func offer(game, name: String, color: int = 0) -> bool:
	return game != null and game.offer_piece(name,color)

static func failure(action: String, reason: String) -> Dictionary:
	return {"ok":false,"action":action,"reason":reason}
