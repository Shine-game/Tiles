extends Node

signal completed(operation: String, success: bool, message: String)
var backend: Object
var busy := false
var pending_operation := ""

func _ready() -> void:
	if backend == null and Engine.has_singleton("TilesGallery"):
		backend = Engine.get_singleton("TilesGallery")
	if backend != null:
		backend.connect("operation_completed", _on_completed)

func can_share() -> bool:
	return backend != null

func save_image(path: String, id: String) -> void:
	_start("save", path, id)

func share_image(path: String, id: String) -> void:
	_start("share", path, id)

func _start(operation: String, path: String, id: String) -> void:
	if busy: return
	if backend == null:
		completed.emit(operation, false, "This feature is unavailable in this build.")
		return
	if not FileAccess.file_exists(path):
		completed.emit(operation, false, "This image is no longer available.")
		return
	busy = true
	pending_operation = operation
	backend.call("save_image" if operation == "save" else "share_image", ProjectSettings.globalize_path(path), id)

func _on_completed(operation: String, success: bool, message: String) -> void:
	if operation != pending_operation: return
	busy = false
	pending_operation = ""
	completed.emit(operation, success, message)

static func export_copy(source: String, destination: String) -> Dictionary:
	if destination.get_extension().to_lower() != "png":
		return {"ok": false, "message": "Choose a filename ending in .png."}
	if not FileAccess.file_exists(source):
		return {"ok": false, "message": "This image is no longer available."}
	var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))
	return {"ok": error == OK, "message": "Image saved." if error == OK else "Could not save this image."}
