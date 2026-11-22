extends RefCounted

static func load_owned(path: String, products: Dictionary) -> Dictionary:
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var owned := {}
	if stored is Array:
		for product: Variant in stored:
			if product is String and products.has(product): owned[product] = true
	return owned

static func save_owned(path: String, owned: Dictionary) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(owned.keys()))
	file.close()
	return DirAccess.rename_absolute(temporary, path) == OK
