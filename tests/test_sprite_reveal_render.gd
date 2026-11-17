extends SceneTree
# Requires a real rendering backend (run with X11/GL compatibility, not --headless).
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const ShaderSource = preload("res://shaders/sprite_reveal.gdshader")
var failures := 0
var checks := 0
var viewport: SubViewport
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func _initialize() -> void: run.call_deferred()
func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(64, 32)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	art.fill(Color(0.8, 0.3, 0.1, 1))
	var field := Image.create(32, 32, false, Image.FORMAT_RF)
	for y in range(32):
		for x in range(32): field.set_pixel(x, y, Color(float(x) / 31.0, 0, 0, 1))
	var sprite := Renderer.sprite({"asset": ImageTexture.create_from_image(art), "source_transform": Transform2D.IDENTITY})
	sprite.material = Renderer.material(ShaderSource, {"reveal_field": ImageTexture.create_from_image(field), "reveal_progress": 0.0})
	viewport.add_child(sprite)
	var image := await capture()
	check(image.get_pixel(4, 16).a == 0, "Zero progress completely hidden")
	sprite.material.set_shader_parameter("reveal_progress", 0.5)
	image = await capture()
	check(image.get_pixel(4, 16).a > 0.99 and image.get_pixel(27, 16).a < 0.01, "Half reveal exposes root and clips tip")
	check(absf(image.get_pixel(4, 16).r - 0.8) < 0.02, "Shader preserves source color")
	sprite.transform = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(63, 0))
	image = await capture()
	check(image.get_pixel(58, 16).a > 0.99 and image.get_pixel(36, 16).a < 0.01, "Reflection carries reveal field with art")
	sprite.material.set_shader_parameter("reveal_progress", 1.0)
	image = await capture()
	check(image.get_pixel(36, 16).a > 0.99, "Full progress exposes tip")
	sprite.material.set_shader_parameter("time_field", true)
	sprite.material.set_shader_parameter("field_start", 2.0)
	sprite.material.set_shader_parameter("visual_clock", 2.5)
	image = await capture()
	check(image.get_pixel(58, 16).a > 0.99 and image.get_pixel(36, 16).a < 0.01, "Timed arrival field clips against shared clock")
	sprite.material.set_shader_parameter("soft_seconds", 0.4)
	sprite.material.set_shader_parameter("visual_clock", 2.0 + 4.0 / 31.0 + 0.2)
	image = await capture()
	check(image.get_pixel(58, 16).a > 0.3 and image.get_pixel(58, 16).a < 0.7, "Timed field applies soft completion interval")
	sprite.material.set_shader_parameter("time_field", false)
	sprite.material.set_shader_parameter("reveal_progress", 1.0)
	sprite.material.set_shader_parameter("recolor", true)
	sprite.material.set_shader_parameter("palette_source", Color(0.8, 0.3, 0.1))
	sprite.material.set_shader_parameter("palette_target", Color(0.2, 0.8, 0.4))
	image = await capture()
	var tinted := image.get_pixel(58, 16)
	check(tinted.g > tinted.r and tinted.g > tinted.b and tinted.a > 0.99, "Palette treatment changes hue and preserves alpha")
	print("Sprite shader rendering: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
