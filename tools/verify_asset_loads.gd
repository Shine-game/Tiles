extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var report = JSON.parse_string(FileAccess.get_file_as_string("res://docs/asset-inventory/current.json"))
	var checked := 0
	var failures: Array = []
	for entry in report.assets:
		if entry.status != "required_by_active_dependencies": continue
		var path: String = "res://" + entry.path
		var resource = load(path)
		if resource == null: failures.append(path)
		elif entry.kind == "image" and not resource is Texture2D: failures.append(path)
		elif entry.kind == "audio" and not resource is AudioStreamOggVorbis: failures.append(path)
		elif entry.kind == "font" and not resource is Font: failures.append(path)
		checked += 1
	print("Verified asset loads: ", checked, "; failures: ", failures)
	quit(0 if failures.is_empty() else 1)
