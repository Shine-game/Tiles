extends "res://scripts/growth.gd"
# Keep the base graph/edge schedule; the active flower and overlap values now
# come from the same Tier 2 definition used to draw the petals.
const Sets = preload("res://scripts/vines_sets.gd")
func flower_seconds() -> float:
	return float(Sets.flower().animation.duration_seconds)
func flower_link_fraction() -> float:
	Sets.install()
	return float(Sets.tier2.definition.schedule.link_overlap_fraction)
