extends PanelContainer

signal page_changed
signal closed

const InterfaceTheme = preload("res://scripts/interface_theme.gd")
const Interface = preload("res://scripts/interface_palette.gd")
const Palette = preload("res://scripts/palette.gd")

var pages: Dictionary
var menu_buttons: Array
var palette_list: Control
var frame: BoardFrame
var paid_heading: Label
var paid_divider: HSeparator
var menu_title: Label
var menu_close: Button
var back_button: Button

var page := "Settings"
var history: Array[String] = []

func open_page(next_page: String, remember: bool = true) -> void:
	if next_page == "Settings":
		history.clear()
	elif remember and visible and next_page != page:
		history.append(page)
	page = next_page
	show()
	page_changed.emit()

func close() -> void:
	hide()
	history.clear()
	closed.emit()

func go_back() -> void:
	if history.is_empty():
		close()
	else:
		open_page(history.pop_back(), false)

func layout(view_size: Vector2, anchor_bottom: float, pad: float, requested_clearance: float, theme_labels: Dictionary, style_button: Callable, can_replay: Callable) -> void:
	for control: Control in menu_buttons:
		control.hide()
	var options: Array = pages.get(page, pages["Settings"]).duplicate()
	var first_paid: Button
	if page == "Themes":
		var locked := options.filter(func(button: Button): return not can_replay.call(button.get_meta("theme_id")))
		options = options.filter(func(button: Button): return can_replay.call(button.get_meta("theme_id")))
		if not locked.is_empty():
			first_paid = locked[0]
			options.append_array(locked)
	var section_height := 30.0 if first_paid != null else 0.0
	var rim := frame.thin_rim if frame.apply_theme(Palette.theme_id()) else 0.0
	var row_units := options.size() + (1 if page == "Game Presets" else 0)
	var width := minf(view_size.x - 2 * pad, maxf(view_size.x * 0.70, 400.0))
	var max_height := view_size.y - 2 * pad
	var close_side := maxf(44, InterfaceTheme.FONT.get_height(InterfaceTheme.FONT_SIZE) + 8)
	var min_row := 112.0 if page in ["Themes", "Audio"] else 46.0
	var clearance := minf(requested_clearance, maxf(0.0, (max_height - 2 * rim - close_side - section_height - min_row * row_units) / (options.size() + 2)))
	clearance = minf(clearance, maxf(0.0, (width - 2 * rim - 2 * close_side) / 3.0))
	var inset := rim + clearance
	var title_height := close_side + clearance
	var gap := clearance
	var preferred_row := maxf(min_row, 66.0)
	var height := minf(max_height, 2 * inset + title_height + section_height + preferred_row * row_units + gap * (options.size() - 1))
	var content_width := width - 2 * inset
	var content_height := height - 2 * inset
	var row_height := (content_height - title_height - section_height - gap * (options.size() - 1)) / row_units
	var panel_style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	panel_style.set_content_margin_all(inset)
	add_theme_stylebox_override("panel", panel_style)
	var y: float = minf(anchor_bottom + pad, view_size.y - pad - height)
	_set_rect(self, Rect2((view_size.x - width) / 2, maxf(pad, y), width, height))
	_set_rect(palette_list, Rect2(Vector2.ONE * inset, Vector2(content_width, content_height)))
	if frame.is_present():
		frame.surround(Rect2(Vector2.ONE * (rim - inset), Vector2(width, height) - 2 * Vector2.ONE * rim))
	menu_title.text = ""
	menu_title.hide()
	menu_title.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
	menu_close.show()
	menu_close.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
	_set_rect(menu_close, Rect2(content_width - close_side, 0, close_side, close_side))
	_set_rect(menu_title, Rect2(close_side + gap, 0, maxf(1, content_width - 2 * (close_side + gap)), title_height - gap))
	back_button.show()
	back_button.add_theme_font_size_override("font_size", InterfaceTheme.FONT_SIZE)
	_set_rect(back_button, Rect2(0, 0, close_side, close_side))
	var theme_options: Array = pages["Themes"]
	for i in range(theme_options.size()):
		var id: String = theme_options[i].get_meta("theme_id")
		theme_options[i].text = ("✓ " if id == Palette.theme_id() else "") + theme_labels[id]
		var tile: Control = theme_options[i].get_child(0)
		var longest_word := 0.0
		for word: String in theme_labels[id].split(" "):
			longest_word = maxf(longest_word, InterfaceTheme.FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,InterfaceTheme.FONT_SIZE).x)
		var tile_side: float = maxf(16, minf(minf(row_height - 16, content_width * 0.23), content_width-longest_word-38))
		theme_options[i].set_meta("menu_right_inset", tile_side + 20)
		_set_rect(tile, Rect2(content_width - tile_side - 12, (row_height - tile_side) / 2, tile_side, tile_side))
	var row_y := title_height
	for i in range(options.size()):
		if options[i] is Label:
			var label: Label = options[i]
			label.show()
			label.add_theme_font_size_override("font_size",InterfaceTheme.FONT_SIZE)
			label.add_theme_color_override("font_color",Interface.text())
			_set_rect(label,Rect2(0,row_y,content_width,row_height*2))
			row_y += row_height*2 + gap
			continue
		if options[i] is VBoxContainer:
			var row: VBoxContainer = options[i]
			row.show()
			var label: Label = row.get_child(0)
			label.add_theme_font_size_override("font_size",InterfaceTheme.FONT_SIZE)
			label.add_theme_color_override("font_color",Interface.text())
			label.size.x = content_width
			label.update_minimum_size()
			row.update_minimum_size()
			_set_rect(row,Rect2(0,row_y,content_width,row_height))
			row_y += row_height + gap
			continue
		var button: Button = options[i]
		if button == first_paid:
			paid_divider.show()
			paid_heading.show()
			paid_heading.add_theme_font_size_override("font_size", 18)
			_set_rect(paid_divider, Rect2(0, row_y, content_width, 2))
			_set_rect(paid_heading, Rect2(0, row_y + 2, content_width, section_height - 2))
			row_y += section_height
		button.show()
		if pages["Vine colors"].has(button):
			button.set_meta("menu_right_inset", row_height + 12)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 22 if page == "Themes" and row_height < 85 else InterfaceTheme.FONT_SIZE)
		style_button.call(button)
		button.size.x = content_width
		button.update_minimum_size()
		_set_rect(button, Rect2(0, row_y, content_width, row_height))
		row_y += row_height + gap

func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
