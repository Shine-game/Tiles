class_name GardenGallery
extends RefCounted

# App-private storage needs no Android photo/storage permission.
var directory := "user://gallery"

func entries() -> Array:
	var result: Array = []
	var folder := DirAccess.open(directory)
	if folder == null:
		return result
	for name: String in folder.get_files():
		if name.ends_with(".json"):
			var file := FileAccess.open(directory.path_join(name), FileAccess.READ)
			if file == null:
				continue
			var record = JSON.parse_string(file.get_as_text())
			if not record is Dictionary or record.get("id", "") != name.get_basename() or not record.get("board") is Array:
				continue
			var grid: Array = record.board
			if grid.size() not in [9, 11] or not grid.all(func(row): return row is Array and row.size() == grid.size() and row.all(func(value): return value is float or value is int)):
				continue
			if int(record.get("palette", -1)) not in range(5):
				continue
			# JSON numbers are floats; restore logical integer cells on disk reads.
			for y in range(grid.size()):
				grid[y] = grid[y].map(func(value): return int(value))
			if FileAccess.file_exists(directory.path_join(str(record.id) + ".png")):
				result.append(record)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.id) > str(b.id))
	return result

func save_design(board: Array, palette_index: int, image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {"ok": false}
	var fingerprint := JSON.stringify([board, palette_index]).sha256_text()
	for record: Dictionary in entries():
		if record.get("fingerprint", "") == fingerprint:
			return {"ok": true, "id": record.id}
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {"ok": false}
	var id := "%020d-%s" % [int(Time.get_unix_time_from_system() * 1000), fingerprint.left(8)]
	var path := directory.path_join(id)
	if image.save_png(path + ".png") != OK:
		return {"ok": false}
	var file := FileAccess.open(path + ".json", FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(path + ".png")
		return {"ok": false}
	file.store_string(JSON.stringify({"id": id, "fingerprint": fingerprint, "board": board, "palette": palette_index}))
	file.close()
	return {"ok": true, "id": id}

func picture(record: Dictionary) -> ImageTexture:
	var image := Image.load_from_file(directory.path_join(str(record.id) + ".png"))
	return null if image == null or image.is_empty() else ImageTexture.create_from_image(image)
