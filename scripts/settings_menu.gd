extends PanelContainer

signal page_changed
signal closed

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
