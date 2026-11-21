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

static func fingerprint(board: Array, palette_index: int, theme: String = "vines", theme_version: String = "", surface_revision: String = "") -> String:
	if not surface_revision.is_empty():
		return JSON.stringify([board, palette_index, theme, theme_version, surface_revision]).sha256_text()
	if not theme_version.is_empty():
		return JSON.stringify([board, palette_index, theme, theme_version]).sha256_text()
	# Preserve legacy vine fingerprints so old saves still deduplicate.
	return JSON.stringify([board, palette_index] if theme == "vines" else [board, palette_index, theme]).sha256_text()

func save_design(board: Array, palette_index: int, image: Image, theme: String = "vines", theme_version: String = "", surface_revision: String = "") -> Dictionary:
	if image == null or image.is_empty(): return {"ok":false,"error":"capture"}
	var design_key := fingerprint(board,palette_index,theme,theme_version,surface_revision)
	for record: Dictionary in entries():
		if record.get("fingerprint","") == design_key: return {"ok":true,"id":record.id}
	if FileAccess.file_exists(directory) or DirAccess.make_dir_recursive_absolute(directory) != OK: return {"ok":false,"error":"storage"}
	var id := "%020d-%s" % [int(Time.get_unix_time_from_system()*1000),design_key.left(8)]
	var path := directory.path_join(id)
	var png_temp := path+".png.tmp"
	var json_temp := path+".json.tmp"
	if image.save_png(png_temp) != OK:
		DirAccess.remove_absolute(png_temp)
		return {"ok":false,"error":"image_write"}
	var file := FileAccess.open(json_temp,FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(png_temp)
		return {"ok":false,"error":"metadata_write"}
	file.store_string(JSON.stringify({"id":id,"fingerprint":design_key,"board":board,"palette":palette_index,"theme":theme,"theme_version":theme_version,"surface_revision":surface_revision}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(png_temp)
		DirAccess.remove_absolute(json_temp)
		return {"ok":false,"error":"metadata_write"}
	if DirAccess.rename_absolute(png_temp,path+".png") != OK:
		DirAccess.remove_absolute(png_temp)
		DirAccess.remove_absolute(json_temp)
		return {"ok":false,"error":"image_commit"}
	# JSON is the commit marker: Gallery never lists a half-written record.
	if DirAccess.rename_absolute(json_temp,path+".json") != OK:
		DirAccess.remove_absolute(path+".png")
		DirAccess.remove_absolute(json_temp)
		return {"ok":false,"error":"metadata_commit"}
	return {"ok":true,"id":id}

func picture(record: Dictionary) -> ImageTexture:
	var image := Image.load_from_file(directory.path_join(str(record.id) + ".png"))
	return null if image == null or image.is_empty() else ImageTexture.create_from_image(image)

func image_path(record: Dictionary) -> String:
	var id := str(record.get("id", ""))
	if id.is_empty() or not id.is_valid_filename() or id.begins_with("."):
		return ""
	var path := directory.path_join(id + ".png")
	return path if FileAccess.file_exists(path) else ""
