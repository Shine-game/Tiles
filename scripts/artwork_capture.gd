extends RefCounted
const EXPORT_SIZE := 2160
const CANVAS_SIZE := 900
const BoardView = preload("res://scripts/board_view.gd")

# Shared clean artwork renderer. The viewport belongs to the caller's scene, so
# removing that scene cancels its capture without leaving an orphan viewport.
func render(owner: Control, live_view: Control, snapshot: Array, theme_id: String) -> Image:
	if DisplayServer.get_name() == "headless": return null
	var viewport := SubViewport.new()
	viewport.size = Vector2i.ONE*EXPORT_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	owner.add_child(viewport)
	var artwork = BoardView.new()
	artwork.size = Vector2.ONE*CANVAS_SIZE
	# Render the same scene at a higher pixel density, preserving frame proportions
	# and display-space effects while sampling the original sprite textures.
	artwork.scale = Vector2.ONE*(float(EXPORT_SIZE)/CANVAS_SIZE)
	artwork.flush_frame = true
	artwork.show_guides = false
	artwork.show_axes = false
	artwork.complete_background = true
	artwork.paper_background = theme_id == "clockwork"
	viewport.add_child(artwork)
	artwork.show_settled(snapshot)
	if live_view.board_frame != null and live_view.board_frame.is_present():
		artwork.board_frame.thin_rim = live_view.board_frame.rim_at_width(artwork.size.x)
		artwork.board_frame.apply_theme(theme_id,live_view.board_frame.artwork_texture())
		artwork.update_geometry()
	artwork.direction_by_edge = live_view.direction_by_edge.duplicate(true)
	artwork._adopt_directions(true)
	if live_view.coral_visuals != null and artwork.coral_visuals != null:
		artwork.coral_visuals.copy_order(live_view.coral_visuals)
	if live_view.clockwork_visuals != null and artwork.clockwork_visuals != null:
		artwork.clockwork_visuals.copy_motion(live_view.clockwork_visuals)
	if live_view.zen_visuals != null and artwork.zen_visuals != null:
		artwork.zen_visuals.copy_landmark_order(live_view.zen_visuals)
	artwork.construction_state.copy_from(live_view.construction_state)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport): return null
	if not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree():
		viewport.queue_free()
		return null
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image
