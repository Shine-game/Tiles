extends Panel

signal back_requested

const Gallery = preload("res://scripts/gallery.gd")
const GalleryExport = preload("res://scripts/gallery_export.gd")
const InterfaceTheme = preload("res://scripts/interface_theme.gd")

var gallery: Gallery
var image: TextureRect
var previous: Button
var next: Button
var close: Button
var back: Button
var page: Button
var save: Button
var share: Button
var status: Label
var file_dialog: FileDialog
var exporter: Node
var export_busy := false
var export_source := ""
var entries: Array = []
var index := 0

func configure(store: Gallery, make_button: Callable) -> void:
	gallery = store
	z_index = 100
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	exporter = GalleryExport.new()
	exporter.completed.connect(_export_completed)
	add_child(exporter)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG image"])
	file_dialog.title = "Save Image"
	file_dialog.file_selected.connect(save_file)
	file_dialog.canceled.connect(func(): _export_completed("save", false, ""))
	add_child(file_dialog)
	image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	previous = make_button.call("‹", func(): _turn_page(-1))
	next = make_button.call("›", func(): _turn_page(1))
	close = make_button.call("×", func(): hide())
	back = make_button.call("‹", go_back)
	back.tooltip_text = "Back"
	close.tooltip_text = "Close"
	page = make_button.call("0 / 0", func(): pass)
	save = make_button.call("Save to Photos" if OS.has_feature("android") else "Save Image", export_image.bind(false))
	share = make_button.call("Share", export_image.bind(true))
	share.tooltip_text = "Open the phone's sharing menu" if exporter.can_share() else exporter.unavailable_message()
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 2
	status.clip_text = true
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	for control: Control in [previous, next, back, close, page, save, share]:
		control.reparent(self)

func apply_theme(shared_theme: Theme) -> void:
	file_dialog.theme = shared_theme

func layout(view_size: Vector2, pad: float) -> void:
	size = view_size
	var height: float = clampf(size.y * 0.08, 32, 56)
	_set_rect(close, Rect2(size.x - pad - height, pad, height, height))
	_set_rect(back, Rect2(pad,pad,height,height))
	var status_height := clampf(size.y * 0.045, 24, 44)
	var navigation_y := size.y - pad - height
	var status_y := navigation_y - pad - status_height
	var actions_y := status_y - pad - height
	_set_rect(image, Rect2(pad, height+2*pad, size.x-2*pad, maxf(1,actions_y-height-3*pad)))
	_layout_row([save,share],Rect2(pad,actions_y,size.x-2*pad,height),pad)
	_set_rect(status,Rect2(pad,status_y,size.x-2*pad,status_height))
	status.add_theme_font_size_override("font_size",InterfaceTheme.FONT_SIZE)
	_layout_row([previous, page, next], Rect2(pad,navigation_y,size.x-2*pad,height),pad)

func open_gallery() -> void:
	entries = gallery.entries()
	index = 0
	show_page()
	show()

func go_back() -> void:
	hide()
	back_requested.emit()

func _turn_page(direction: int) -> void:
	index = clampi(index + direction, 0, maxi(0, entries.size() - 1))
	show_page()

func show_page() -> void:
	image.texture = null if entries.is_empty() else gallery.picture(entries[index])
	page.text = "%d / %d" % [0 if entries.is_empty() else index + 1, entries.size()]
	if not export_busy:
		status.text = "Your saved designs will appear here." if entries.is_empty() else (exporter.unavailable_message() if OS.has_feature("android") and not exporter.can_share() else "")
	_refresh_actions()

func _refresh_actions() -> void:
	var empty := entries.is_empty()
	save.disabled = empty or export_busy or (OS.has_feature("android") and not exporter.can_share())
	share.disabled = empty or export_busy or not exporter.can_share()
	previous.disabled = export_busy or index <= 0
	next.disabled = export_busy or index >= entries.size()-1

func export_image(should_share: bool) -> void:
	if entries.is_empty() or export_busy: return
	var record: Dictionary = entries[index]
	var path: String = gallery.image_path(record)
	if path.is_empty():
		status.text = "This image is no longer available."
		return
	export_busy = true
	_refresh_actions()
	if should_share:
		status.text = "Opening sharing menu…"
		exporter.share_image(path,str(record.id))
	elif OS.has_feature("android"):
		status.text = "Saving image…"
		exporter.save_image(path,str(record.id))
	else:
		export_source = path
		file_dialog.current_file = "Tiles_"+str(record.id)+".png"
		var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if DirAccess.dir_exists_absolute(pictures): file_dialog.current_dir = pictures
		file_dialog.popup_centered(Vector2i(mini(700,int(size.x-24)),mini(500,int(size.y-24))))

func save_file(destination: String) -> void:
	var result := GalleryExport.export_copy(export_source,destination)
	_export_completed("save",result.ok,result.message)

func _export_completed(_operation: String, _success: bool, message: String) -> void:
	export_busy = false
	export_source = ""
	status.text = message
	_refresh_actions()

func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _layout_row(controls: Array, rect: Rect2, gap: float) -> void:
	var width: float = (rect.size.x - gap * (controls.size() - 1)) / controls.size()
	for i in range(controls.size()):
		_set_rect(controls[i], Rect2(rect.position + Vector2(i * (width + gap), 0), Vector2(width, rect.size.y)))
