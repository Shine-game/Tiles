extends Control

const Palette = preload("res://scripts/interface_palette.gd")
var states: Array = []
var pitch := 64.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	resized.connect(queue_redraw)

func configure(bounds: Rect2, cell_pitch: float) -> void:
	position = bounds.position
	size = bounds.size
	pitch = cell_pitch
	queue_redraw()

func axes() -> Array:
	var center := size / 2
	return [
		[Vector2(center.x, 0), Vector2(center.x, size.y)],
		[Vector2(0, center.y), Vector2(size.x, center.y)],
		[Vector2.ZERO, size],
		[Vector2(0, size.y), Vector2(size.x, 0)],
	]

# One visual vocabulary for the button, tutorial, and playing field.
static func appearance(possible: bool, complete: bool) -> Dictionary:
	return {"visible":possible or complete,"color":Palette.accent(1) if complete else Color(Palette.text(),0.42),"width":3.0 if complete else 1.5}

static func rotation_state(values: Array, indices: Array = [4,5,6]) -> Dictionary:
	var possible := false
	var complete := false
	for index: int in indices:
		possible = possible or values[index].possible
		complete = complete or values[index].complete
	return {"possible":possible,"complete":complete}

static func paint(canvas: CanvasItem, bounds: Rect2, values: Array, indices: Array = [0,1,2,3,4,5,6]) -> void:
	if values.size() < 7: return
	var center := bounds.get_center()
	var directions := [Vector2.DOWN,Vector2.RIGHT,Vector2(1,-1),Vector2(1,1)]
	for index: int in range(4):
		if index not in indices: continue
		var style := appearance(values[index].possible,values[index].complete)
		if not style.visible: continue
		var offset: Vector2 = directions[index]*bounds.size/2
		canvas.draw_line(center-offset,center+offset,style.color,style.width,true)
	var turns: Array = indices.filter(func(index):return index >= 4)
	if turns.is_empty(): return
	var rotation := rotation_state(values,turns)
	var style := appearance(rotation.possible,rotation.complete)
	if not style.visible: return
	var radius := minf(bounds.size.x,bounds.size.y)*0.08
	canvas.draw_arc(center,radius,-PI/2,TAU-PI/2-0.3,48,style.color,style.width,true)
	var tip := center+Vector2(0,-radius)
	canvas.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-radius*0.25,-radius*0.16),tip+Vector2(-radius*0.25,radius*0.16)]),style.color)

func _draw() -> void:
	paint(self,Rect2(Vector2.ZERO,size),states)
