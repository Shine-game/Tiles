extends SceneTree
const Export = preload("res://scripts/gallery_export.gd")
const Gallery = preload("res://scripts/gallery.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
class FakeBackend extends RefCounted:
	signal operation_completed(operation: String, success: bool, message: String)
	var calls: Array = []
	func save_image(path: String, id: String): calls.append(["save",path,id])
	func share_image(path: String, id: String): calls.append(["share",path,id])
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize():run.call_deferred()
func run():
	var folder := "/tmp/tiles-export-test-%d" % Time.get_ticks_usec()
	var gallery = Gallery.new()
	gallery.directory = folder
	var image := Image.create(2160,2160,false,Image.FORMAT_RGBA8)
	image.fill(Color.MAGENTA)
	var saved: Dictionary = gallery.save_design(Rules.create_board(9),0,image)
	var record: Dictionary = gallery.entries()[0]
	var source: String = gallery.image_path(record)
	check(saved.ok and not source.is_empty(),"Saved artwork has an exportable PNG path")
	check(Image.load_from_file(source).get_size() == Vector2i(2160,2160),"Save and Share retain the 2160-pixel original")
	check(gallery.picture(record).get_image().get_size() == Vector2i(900,900),"Gallery browsing loads the smaller preview")
	var preview_path := source.get_basename()+".preview.png"
	check(FileAccess.file_exists(preview_path),"Preview is stored separately from the export original")
	DirAccess.remove_absolute(preview_path)
	check(gallery.picture(record).get_image().get_size() == Vector2i(900,900) and Image.load_from_file(source).get_size() == Vector2i(2160,2160),"A missing preview never damages or downscales the original")
	check(gallery.image_path({"id":"../private"}).is_empty(),"Export paths cannot escape the gallery")
	var copied: Dictionary = Export.export_copy(source,folder+"/export.png")
	check(copied.ok and FileAccess.get_file_as_bytes(source)==FileAccess.get_file_as_bytes(folder+"/export.png"),"Desktop export preserves the exact original PNG")
	check(not Export.export_copy(source,folder+"/export.jpg").ok,"Save requires a PNG destination")
	var backend = FakeBackend.new()
	var service = Export.new()
	service.backend = backend
	root.add_child(service)
	service.share_image(source,str(record.id))
	check(service.busy and backend.calls[0]==["share",ProjectSettings.globalize_path(source),str(record.id)],"Share hands the chosen saved image to the native plugin")
	check(Image.load_from_file(backend.calls[0][1]).get_size() == Vector2i(2160,2160),"Native Share receives the high-resolution PNG")
	service.save_image(source,str(record.id))
	check(backend.calls.size()==1,"Duplicate exports are blocked while busy")
	backend.operation_completed.emit("share",true,"Choose an app")
	check(not service.busy,"Opening the native chooser completes handoff without claiming publication")
	service.save_image(source,str(record.id))
	check(backend.calls[1][0]=="save","Photos export uses the same saved image")
	backend.operation_completed.emit("save",false,"Permission declined")
	check(not service.busy,"Permission denial releases controls")
	service.queue_free()
	await process_frame
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.gallery.directory=folder
	scene._open_gallery()
	check(not scene.gallery_panel.save.disabled and scene.gallery_panel.share.disabled,"Desktop Gallery offers Save and marks mobile-only sharing unavailable")
	scene.gallery_panel.export_image(false)
	check(scene.gallery_panel.file_dialog.visible and scene.gallery_panel.export_busy,"Desktop Save opens a file chooser")
	scene.gallery_panel.save_file(folder+"/from-ui.png")
	check(FileAccess.file_exists(folder+"/from-ui.png") and not scene.gallery_panel.export_busy,"Gallery Save exports and restores controls")
	check(Image.load_from_file(folder+"/from-ui.png").get_size() == Vector2i(2160,2160),"Desktop Save exports 2160 pixels rather than the preview")
	scene.gallery_panel.file_dialog.hide()
	scene.gallery_panel.entries=[]
	scene.gallery_panel.show_page()
	check(scene.gallery_panel.save.disabled and scene.gallery_panel.share.disabled,"Empty gallery disables both actions")
	for dimensions in [Vector2(320,568),Vector2(720,1100),Vector2(844,390)]:
		scene.size=dimensions
		scene._layout()
		for frame in range(2):await process_frame
		var bounds:=Rect2(Vector2.ZERO,dimensions).grow(0.2)
		for control: Control in [scene.gallery_panel.save,scene.gallery_panel.share,scene.gallery_panel.status,scene.gallery_panel.image,scene.gallery_panel.close,scene.gallery_panel.back]:
			check(bounds.encloses(control.get_rect()),"Gallery image, actions and navigation fit every viewport")
		check(scene.gallery_panel.image.get_rect().end.y <= scene.gallery_panel.save.position.y,"Export actions stay below the artwork")
	scene.queue_free()
	await process_frame
	for name in DirAccess.open(folder).get_files():DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("Gallery export: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
