extends "res://scripts/growth.gd"
# Keep the base graph/edge schedule; the active flower and overlap values now
# come from the same Tier 2 definition used to draw the petals.
const Sets = preload("res://scripts/vines_sets.gd")
func flower_seconds() -> float:
	return float(Sets.flower().animation.duration_seconds)
func flower_link_fraction() -> float:
	Sets.install()
	return float(Sets.tier2.definition.schedule.link_overlap_fraction)

var formation_base_starts:Dictionary={}
func build(before:Array,after:Array)->void:
	super.build(before,after)
	formation_base_starts.clear()
	for corner in flowers:formation_base_starts[corner]=flowers[corner].start
	reschedule_formations({})

func reschedule_formations(sprite_events:Dictionary)->void:
	var delay:float=Sets.tier2.definition.schedule.get("after_tier1_seconds",0.0)
	for corner:Vector2i in flowers:
		var event:Dictionary=flowers[corner]
		if event.old:continue
		var ready:float=formation_base_starts[corner]
		for shot in sprite_events.values():
			if shot.old:continue
			var owner:String=shot.owner
			if owner.get_slice_count("/")!=6 or owner.get_slice("/",0)!="vines":continue
			var cell:=Vector2i(int(owner.get_slice("/",3)),int(owner.get_slice("/",2)))
			var other:=Vector2i(int(owner.get_slice("/",5)),int(owner.get_slice("/",4)))
			var area:=Rect2i(corner-Vector2i.ONE,Vector2i(2,2))
			if area.has_point(cell) and area.has_point(other):ready=maxf(ready,shot.end)
		event.tier1_ready=ready
		event.start=ready+delay
		duration=maxf(duration,event.start+flower_seconds())
	for link in links:
		if link.old:continue
		link.start=maxf(formation_complete(flowers[link.a]),formation_complete(flowers[link.b]))+float(Sets.tier3.definition.schedule.get("after_tier2_seconds",0.0))
		duration=maxf(duration,link.start+LINK_GROW+STAR_POP)

func formation_complete(event:Dictionary)->float:
	if event.old:return -100.0
	return float(event.start)+flower_seconds()
