@tool
extends RefCounted

const REQUIRED_CLASSES = ["Lorg/shinegame/tiles/gallery/GalleryPlugin;", "Lorg/shinegame/tiles/gallery/GalleryImageProvider;"]

static func contains_text(bytes: PackedByteArray, text: String) -> bool:
	var hex := bytes.hex_encode()
	return hex.contains(text.to_utf8_buffer().hex_encode()) or hex.contains(text.to_utf16_buffer().hex_encode())

static func plugin_classes(dex: PackedByteArray) -> Dictionary:
	var found := {}
	if dex.size()<112 or dex.slice(0,4)!="dex\n".to_utf8_buffer(): return found
	var strings := dex.decode_u32(56)
	var string_offset := dex.decode_u32(60)
	var types := dex.decode_u32(64)
	var type_offset := dex.decode_u32(68)
	var classes := dex.decode_u32(96)
	var class_offset := dex.decode_u32(100)
	if strings>1000000 or types>1000000 or classes>1000000: return found
	if string_offset+strings*4>dex.size() or type_offset+types*4>dex.size() or class_offset+classes*32>dex.size(): return found
	for i in range(classes):
		var type_index := dex.decode_u32(class_offset+i*32)
		if type_index>=types: continue
		var string_index := dex.decode_u32(type_offset+type_index*4)
		if string_index>=strings: continue
		var offset := dex.decode_u32(string_offset+string_index*4)
		var length_bytes := 0
		while offset<dex.size() and dex[offset]&128 and length_bytes<5:
			offset+=1
			length_bytes+=1
		offset+=1
		for descriptor: String in REQUIRED_CLASSES:
			var bytes := descriptor.to_utf8_buffer()
			if offset+bytes.size()<dex.size() and dex.slice(offset,offset+bytes.size())==bytes and dex[offset+bytes.size()]==0:
				found[descriptor]=true
	return found

static func inspect(path: String) -> Dictionary:
	var errors: Array[String] = []
	var zip := ZIPReader.new()
	if zip.open(path)!=OK: return {"ok":false,"errors":["Could not open APK: "+path]}
	var files := zip.get_files()
	var manifest := zip.read_file("AndroidManifest.xml") if files.has("AndroidManifest.xml") else PackedByteArray()
	for text in ["org.godotengine.plugin.v2.TilesGallery", "org.shinegame.tiles.gallery.GalleryPlugin", "org.shinegame.tiles.gallery.GalleryImageProvider", ".galleryshare"]:
		if not contains_text(manifest,text): errors.append("Missing manifest entry: "+text)
	var classes := {}
	for file: String in files:
		if file.get_base_dir().is_empty() and file.begins_with("classes") and file.ends_with(".dex"):
			classes.merge(plugin_classes(zip.read_file(file)))
	zip.close()
	for descriptor: String in REQUIRED_CLASSES:
		if not classes.has(descriptor): errors.append("Missing compiled class: "+descriptor)
	return {"ok":errors.is_empty(),"errors":errors}
