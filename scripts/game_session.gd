extends RefCounted

const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
var path := "user://game_state.json"

static func number(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= low and value <= high

static func vector(value, low: int, high: int) -> bool:
	return value is Array and value.size() == 2 and number(value[0],low,high) and number(value[1],low,high)

static func encode_cells(cells: Array) -> Array:
	return cells.map(func(cell: Vector2i): return [cell.x,cell.y])

static func decode_cells(cells: Array) -> Array:
	return cells.map(func(cell: Array): return Vector2i(int(cell[0]),int(cell[1])))

static func valid_shape(cells, name: String) -> bool:
	if not cells is Array: return false
	if name.is_empty(): return cells.is_empty()
	if name not in Rules.PIECES or cells.size() != Rules.PIECES[name].cells.size(): return false
	for cell in cells:
		if not vector(cell,0,3): return false
	var actual: Array = decode_cells(cells)
	for mirrored in [false,true]:
		var expected: Array = Rules.flip(Rules.PIECES[name].cells) if mirrored else Rules.PIECES[name].cells
		for turn in range(4):
			if actual.size() == expected.size() and actual.all(func(cell):return expected.has(cell)) and expected.all(func(cell):return actual.has(cell)):
				return true
			expected = Rules.rotate(expected)
	return false

static func pack(game) -> Dictionary:
	var history: Array = []
	for step: Dictionary in game.history:
		history.append({"name":step.name,"color":step.color,"cells":encode_cells(step.cells),"anchor":[step.anchor.x,step.anchor.y]})
	return {"board":game.board,"queue":game.queue,"index":game.index,"moves":game.moves,"color":game.current_color,
		"difficulty":game.difficulty,"lost":game.lost,"undo":game.undo_left,"skip":game.skip_left,"erase":game.erase_left,
		"history":history,"seed":str(game.rng.seed),"rng_state":str(game.rng.state)}

static func valid_game(data) -> bool:
	if not data is Dictionary: return false
	var board = data.get("board")
	if not board is Array or board.size() not in [9,11]: return false
	var n: int = board.size()
	for row in board:
		if not row is Array or row.size() != n: return false
		for cell in row:
			if not number(cell,0,2): return false
	var queue = data.get("queue")
	if not queue is Array or queue.is_empty() or queue.size() > 10000: return false
	if not queue.all(func(name):return name is String and (name.is_empty() or name in Rules.PIECES)): return false
	for field: String in ["index","moves","color","difficulty","undo","skip","erase"]:
		if not number(data.get(field),0,100000): return false
	if int(data.index) >= queue.size() or int(data.color) not in [1,2] or int(data.difficulty) not in [0,1,2]: return false
	if int(data.undo)>3 or int(data.skip)>3 or int(data.erase)>3 or not data.get("lost") is bool: return false
	for field: String in ["seed","rng_state"]:
		if not data.get(field) is String or not data[field].is_valid_int(): return false
	var history = data.get("history")
	if not history is Array or history.size()>3: return false
	for step in history:
		if not step is Dictionary or not step.get("name") is String: return false
		if step.name not in Rules.PIECES or not valid_shape(step.get("cells"),step.name): return false
		if not number(step.get("color"),1,2) or not vector(step.get("anchor"),0,n-1): return false
		for cell: Array in step.cells:
			if int(step.anchor[0])+int(cell[0])>=n or int(step.anchor[1])+int(cell[1])>=n: return false
	return true

static func unpack(data: Dictionary):
	var game = Game.new(data.board.size(),int(data.seed),int(data.difficulty))
	game.board = data.board.map(func(row):return row.map(func(value):return int(value)))
	game.queue = data.queue.duplicate()
	game.index = int(data.index)
	game.moves = int(data.moves)
	game.current_color = int(data.color)
	game.lost = data.lost
	game.undo_left = int(data.undo)
	game.skip_left = int(data.skip)
	game.erase_left = int(data.erase)
	game.rng.seed = int(data.seed)
	game.rng.state = int(data.rng_state)
	game.history = []
	for step: Dictionary in data.history:
		game.history.append({"name":step.name,"color":int(step.color),"cells":decode_cells(step.cells),"anchor":Vector2i(int(step.anchor[0]),int(step.anchor[1]))})
	game._refresh_over()
	return game

static func valid(data) -> bool:
	if not data is Dictionary or data.get("schema") != "tiles.session.v1": return false
	if data.get("theme","") not in Themes.ids() or not valid_game(data.get("game")): return false
	if not number(data.get("palette"),0,4) or not number(data.get("preset_size"),9,11) or int(data.preset_size) not in [9,11]: return false
	if not number(data.get("preset_difficulty"),0,2) or not data.get("axes") is bool: return false
	if not data.get("hover") is bool or not data.get("tray_moved") is bool or not vector(data.get("selected"),-100000,100000): return false
	var name: String = data.game.queue[int(data.game.index)]
	# Finished games have no offered piece to display.
	var offered = data.get("offered")
	if not valid_art(data.get("art",{}),data.game.board.size()): return false
	if offered is Array and offered.is_empty() and (data.game.lost or name.is_empty() or not data.game.board.any(func(row):return row.has(0))): return true
	return valid_shape(offered,name)

static func valid_art(data, n: int) -> bool:
	if not data is Dictionary: return false
	var edges = data.get("edges",[])
	var cores = data.get("leaf_cores",[])
	if not edges is Array or not cores is Array or edges.size()>512 or cores.size()>121: return false
	for record in edges:
		if not record is Dictionary or not record.get("edge") is Array or record.edge.size()!=4: return false
		if not record.edge.all(func(value):return number(value,0,n-1)): return false
		if not number(record.get("color"),1,2) or not number(record.get("flow"),-1,1): return false
	for cell in cores:
		if not cell is Array or cell.size()!=3 or not number(cell[0],0,n-1) or not number(cell[1],0,n-1) or not number(cell[2],1,2): return false
	return true

func load_state() -> Dictionary:
	for candidate in [path,path+".bak"]:
		var file := FileAccess.open(candidate,FileAccess.READ)
		if file == null or file.get_length()>2000000: continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) == OK and valid(parser.data):
			return parser.data
	return {}

func save_state(data: Dictionary) -> bool:
	if not valid(data): return false
	var target := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return false
	var temporary := target+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var previous := load_state()
	if not previous.is_empty():
		var backup := FileAccess.open(target+".bak.tmp",FileAccess.WRITE)
		if backup != null:
			backup.store_string(JSON.stringify(previous))
			backup.flush()
			backup.close()
			DirAccess.rename_absolute(target+".bak.tmp",target+".bak")
	return DirAccess.rename_absolute(temporary,target) == OK
