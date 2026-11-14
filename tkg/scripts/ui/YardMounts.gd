class_name YardMounts
extends RefCounted

## The sharp hull's fitted weapons on the front door: drawn on a hull standing, put on
## its ghost, and the kit a chassis launches with (`YardInfo` keeps the band's words).

## The fitted weapons drawn on a hull standing in the yard (`MountPoints`, passive).
static func mount(view: ShipView, hull: HullData, kit: Array[ModuleData]) -> MountPoints:
	var pts := MountPoints.new()
	pts.ship = hull
	pts.fitted = kit
	view.add_child(pts)
	pts.attach(view)
	pts.passive()
	pts.use_parent_material = true
	pts.refresh()
	return pts


## What a chassis launches with, fitted on `Run` for a moment and put back.
static func kit_for(m: StringName, w: HullData.Weight, tier: int) -> Array[ModuleData]:
	var hull := Run.hull
	var was := Run.installed.duplicate()
	var hp := Run.hp
	Run.fit_chassis(m, w, tier)
	var out: Array[ModuleData] = []
	out.assign(Run.installed)
	Run.hull = hull
	Run.installed.assign(was)
	Run.hp = hp
	return out


## The sharp copy's weapons where the hull is this frame (LAUNCH's lift flies it).
static func follow(ghost: Control, s: YardStandSet) -> void:
	if s._view == null:
		return
	for c in ghost.get_children():
		if c is MountPoints:
			var at := s._view.global_position - ghost.global_position
			if (c as Control).position != at:
				(c as Control).position = at
				(c as MountPoints).refresh()


## The sharp copy over the blur carries the picked ship's weapons too.
static func ghost_mounts(ghost: Control, s: YardStandSet) -> void:
	for c in ghost.get_children():
		c.queue_free()
	if s == null or s.mounts == null or not is_instance_valid(s.mounts) or s._view == null:
		return
	var pts := MountPoints.new()
	pts.ship = s.mounts.ship
	pts.fitted = s.mounts.fitted
	ghost.add_child(pts)
	pts.attach(s._view)
	pts.passive()
	pts.use_parent_material = true
	pts.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pts.position = s._view.global_position - ghost.global_position
	pts.size = s._view.size
	pts.refresh()
