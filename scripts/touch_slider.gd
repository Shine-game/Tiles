extends HSlider

# Keep native mouse/keyboard handling. The game's pointer gestures deliberately
# disable touch-to-mouse emulation, so sliders need their own touch capture.
var _touch_id := -1
var _touch_start := 0.0

func _gui_input(event: InputEvent) -> void:
	if not editable:
		_end_touch()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _touch_id != -1: return
			_touch_id = event.index
			_touch_start = value
			grab_focus()
			drag_started.emit()
			_set_touch_value(event.position.x)
		elif event.index == _touch_id:
			if not event.canceled: _set_touch_value(event.position.x)
			_end_touch()
		else:
			return
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_set_touch_value(event.position.x)
		accept_event()

func _set_touch_value(x: float) -> void:
	var thumb_width := float(get_theme_icon("grabber").get_width())
	ratio = clampf((x-thumb_width/2)/maxf(1,size.x-thumb_width),0,1)

func _end_touch() -> void:
	if _touch_id == -1: return
	_touch_id = -1
	drag_ended.emit(not is_equal_approx(value,_touch_start))

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): _end_touch()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _end_touch()
