extends SceneTree
const Check = preload("res://addons/tiles_gallery/apk_check.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func dex_fixture() -> PackedByteArray:
	# Minimal class table fixture; checks presence, not a runnable Android program.
	var dex := PackedByteArray()
	dex.resize(192)
	for i in range(8): dex[i]="dex\n035".to_utf8_buffer()[i] if i<7 else 0
	dex.encode_u32(56,2)
	dex.encode_u32(60,112)
	dex.encode_u32(64,2)
	dex.encode_u32(68,120)
	dex.encode_u32(96,2)
	dex.encode_u32(100,128)
	for i in range(2):
		dex.encode_u32(112+i*4,dex.size())
		dex.encode_u32(120+i*4,i)
		dex.encode_u32(128+i*32,i)
		var name: PackedByteArray=Check.REQUIRED_CLASSES[i].to_utf8_buffer()
		dex.append(name.size())
		dex.append_array(name)
		dex.append(0)
	return dex
func fixture(path: String, manifest: PackedByteArray, dex: PackedByteArray) -> void:
	var zip := ZIPPacker.new()
	zip.open(path)
	zip.start_file("AndroidManifest.xml")
	zip.write_file(manifest)
	zip.close_file()
	zip.start_file("classes.dex")
	zip.write_file(dex)
	zip.close_file()
	zip.close()
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var path := "/tmp/tiles-apk-check-%d.zip" % Time.get_ticks_usec()
	var manifest := "org.godotengine.plugin.v2.TilesGallery org.shinegame.tiles.gallery.GalleryPlugin org.shinegame.tiles.gallery.GalleryImageProvider org.example.game.galleryshare"
	var dex := dex_fixture()
	fixture(path,manifest.to_utf8_buffer(),dex)
	check(Check.inspect(path).ok,"Complete registration and class definitions pass")
	fixture(path,manifest.to_utf16_buffer(),dex)
	check(Check.inspect(path).ok,"UTF-16 binary-manifest strings are recognized")
	fixture(path,"org.example.game".to_utf16_buffer(),dex)
	check(not Check.inspect(path).ok,"Missing plugin manifest fails even with compiled classes")
	fixture(path,manifest.to_utf8_buffer(),PackedByteArray())
	check(not Check.inspect(path).ok,"Missing plugin classes fail even with manifest registration")
	var references_only := dex.duplicate()
	references_only.encode_u32(96,0)
	check(Check.plugin_classes(references_only).is_empty(),"Referenced descriptors alone do not count as compiled classes")
	check(Check.plugin_classes(PackedByteArray([1,2,3])).is_empty(),"Truncated DEX is handled safely")
	DirAccess.remove_absolute(path)
	print("Gallery APK checks: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
