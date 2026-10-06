extends Node

## The star chart's galaxy as raw data, for prototypes drawn outside the game:
##   godot --path . -- sheet=ShowcaseDump out=<dir> [kinds=0,8,16]
##
## For seed 4242 and each kind asked for (forced as ChartLook's `kind=N` does
## it: roll the kind, lay the map out again), writes <dir>/raw_kind_NN.json:
## the rolled galaxy, the sky's own constants (`ChartSky.params`), the chart's
## geometry, every point of the chart's star field (drawn pixels at zoom 1,
## the galaxy's own squash, colours as indices into a table) and the turning
## core's points, the named clouds with their lobes, the globular clusters,
## the pulsars, every system with its links, YOU and the Hellbender.
## Nothing is drawn or photographed; GalaxyDump and ChartLook do that.

var out := "user://showcasedump"
var only: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("out="):
			out = s.substr(4)
		elif s.begins_with("kinds="):
			for k in s.substr(6).split(","):
				only.append(int(k))
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().gui_disable_input = true
	_run.call_deferred()


func _run() -> void:
	for _i in 5:
		await get_tree().process_frame
	StarchartScreen.MapChart.clock_override = 600.0
	for kind in GalaxyGen.count():
		if not only.is_empty() and not only.has(kind):
			continue
		Rng.forced = 4242
		Run.start_new_run(&"korvan", 1)
		var natural: int = Run.galaxy_kind
		if Run.galaxy_kind != kind:
			Run.galaxy_kind = kind
			Run.galaxy = GalaxyGen.roll(kind)
			Run.map = MapGen.generate(Run.MAP_CANVAS)
			Run.at = 0
			Run.trail = PackedInt32Array([0])
			Run._range_cache.clear()
			Run.chart_from(Run.node_at())
		Router.show_starchart()
		for _i in 30:
			await get_tree().process_frame
		var scp := Router.current as StarchartScreen
		scp.dismiss_primer()
		for _i in 10:
			await get_tree().process_frame
		var ch = scp._chart
		ch._go_to(StarchartScreen.MapChart.ZOOM_MIN, Vector2.ZERO, false)
		ch._build_stars()
		var d := _dump(ch, kind, natural)
		var path := out.path_join("raw_kind_%02d.json" % kind)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		print("SHOWCASEDUMP kind %d %s: chart %s, %d points, %d core, %d clouds, %d systems -> %s" % [
			kind, GalaxyGen.type_name(kind), ch.size, (d.points.x as Array).size(),
			(d.core.r as Array).size(), (d.clouds as Array).size(), (d.systems as Array).size(),
			ProjectSettings.globalize_path(path)])
	Rng.forced = 0
	get_tree().quit()


func _r(v: float) -> float:
	return snappedf(v, 0.00001)


func _hex(c: Color) -> String:
	return c.to_html(false)


## Any value the sky's params hold, as plain JSON.
func _plain(v: Variant) -> Variant:
	if v is Vector2:
		return [_r(v.x), _r(v.y)]
	if v is Vector3:
		return [_r(v.x), _r(v.y), _r(v.z)]
	if v is Vector4:
		return [_r(v.x), _r(v.y), _r(v.z), _r(v.w)]
	if v is Color:
		return _hex(v)
	if v is float:
		return _r(v)
	if v is PackedVector4Array or v is PackedVector3Array or v is PackedVector2Array \
			or v is PackedInt32Array or v is PackedFloat32Array or v is PackedStringArray or v is Array:
		var a: Array = []
		for e in v:
			a.append(_plain(e))
		return a
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _plain(v[k])
		return o
	return v


func _dump(ch, kind: int, natural: int) -> Dictionary:
	var r_max: float = ch._radius() * StarchartScreen.MapChart.DISC
	var g: Dictionary = {}
	for k in Run.galaxy:
		g[k] = _plain(Run.galaxy[k])
	var table: Array = []
	var index: Dictionary = {}
	var xs: Array = []
	var ys: Array = []
	var cs: Array = []
	var bs: Array = []
	var pos: PackedVector2Array = ch._star_pos
	var col: PackedColorArray = ch._star_col
	var big: PackedByteArray = ch._star_big
	for i in pos.size():
		var h := _hex(col[i])
		if not index.has(h):
			index[h] = table.size()
			table.append(h)
		xs.append(_r(pos[i].x / r_max))
		ys.append(_r(pos[i].y / r_max))
		cs.append(index[h])
		bs.append(int(big[i]))
	var cr: Array = []
	var ca: Array = []
	var cc: Array = []
	var crad: PackedFloat32Array = ch._core_rad
	var cang: PackedFloat32Array = ch._core_ang
	var ccol: PackedColorArray = ch._core_col
	for i in crad.size():
		var h2 := _hex(ccol[i])
		if not index.has(h2):
			index[h2] = table.size()
			table.append(h2)
		cr.append(_r(crad[i] / r_max))
		ca.append(_r(cang[i]))
		cc.append(index[h2])
	var globs: Array = []
	var gi: PackedInt32Array = ch._glob_i
	var gcs: PackedVector2Array = ch._glob_c
	for k in gcs.size():
		var a0 := gi[k * 2] if k * 2 < gi.size() else 0
		var a1 := gi[k * 2 + 1] if k * 2 + 1 < gi.size() else 0
		globs.append({"x": _r(gcs[k].x / r_max), "y": _r(gcs[k].y / r_max), "first": a0, "end": a1})
	var clouds: Array = []
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		var lobes: Array = []
		for l in cl.lobes.size():
			lobes.append([_r(cl.lobes[l].x), _r(cl.lobes[l].y), _r(cl.lobe_r[l])])
		clouds.append({
			"name": cl.name, "kind": NebulaField.Kind.keys()[cl.kind],
			"x": _r(cl.pos.x), "y": _r(cl.pos.y), "radius": _r(cl.radius),
			"hollow": _r(cl.hollow), "emission": cl.emission,
			"shape": NebulaField.Shape.keys()[cl.shape], "hue_roll": _r(cl.hue_roll),
			"base": _hex(cl.base_colour()), "edge": _hex(cl.edge_colour()),
			"tint": _hex(ch._region_tint(cl.pos * r_max)),
			"lobes": lobes,
		})
	var here: MapGen.MapNode = Run.node_at()
	var reach: Dictionary = {}
	for cand in Run.in_range():
		if Run.charted(cand):
			reach[(cand as MapGen.MapNode).index] = true
	var shown: Dictionary = ch._visible_set(here, reach.keys())
	var systems: Array = []
	for n in Run.map:
		var node: MapGen.MapNode = n
		var links: Array = []
		for li in node.links:
			links.append(li)
		systems.append({
			"i": node.index, "name": MapGen.star_name(node),
			"x": _r(node.gal.x), "y": _r(node.gal.y), "layer": node.layer,
			"type": MapGen.NodeType.keys()[node.type], "star": MapGen.Star.keys()[node.star],
			"col": _hex(MapGen.star_colour(node)),
			"region": MapGen.Region.keys()[node.region],
			"development": MapGen.Development.keys()[node.development],
			"danger": node.danger, "near_pulsar": node.near_pulsar,
			"charted": shown.has(node.index), "sensed": node.sensed, "visited": node.visited,
			"cleared": node.cleared, "reach": reach.has(node.index),
			"links": links,
		})
	var pulsars: Array = []
	for p in ch._pulsar:
		pulsars.append([_r((p as Vector2).x / r_max), _r((p as Vector2).y / r_max)])
	var hb := Run.hellbender_at
	return {
		"kind": kind, "name": GalaxyGen.type_name(kind), "natural_kind": natural,
		"seed": 4242, "galaxy_seed": Run.galaxy_seed, "spin": _r(Run.galaxy_spin),
		"galaxy_name": Run.galaxy_name, "galaxy_title": Run.galaxy_title,
		"params": g,
		"sky": _plain(ChartSky.params(true)),
		"chart": {"w": ch.size.x, "h": ch.size.y, "radius": _r(ch._radius()), "r_max": _r(r_max),
			"zoom_min": StarchartScreen.MapChart.ZOOM_MIN, "zoom_max": StarchartScreen.MapChart.ZOOM_MAX,
			"disc": StarchartScreen.MapChart.DISC, "tilt": ChartSky.TILT,
			"turn_minutes": ChartSky.TURN_MINUTES, "hole_k": ChartSky.HOLE_K, "disc_k": ChartSky.DISC_K,
			"shadow": _r(ch._shadow_r() / r_max), "core_clear": _r(ch._core_clear() / r_max),
			"bulge": _r(ch._radius() * float(Run.galaxy.get("bulge", 0.2)) / r_max),
			"nebula_extent": NebulaField.EXTENT},
		"colours": table,
		"points": {"x": xs, "y": ys, "c": cs, "big": bs},
		"core": {"r": cr, "a": ca, "c": cc},
		"globulars": globs,
		"clouds": clouds, "pulsars": pulsars,
		"systems": systems, "here": here.index,
		"trail": Array(Run.trail),
		"sense_radius": _r(Run.sense_radius()), "jump_range": _r(Run.jump_range()),
		"hellbender": {"at": hb, "alive": Run.hellbender_alive(), "hp": Run.hellbender_hp,
			"x": _r(Run.map[hb].gal.x) if hb >= 0 and hb < Run.map.size() else null,
			"y": _r(Run.map[hb].gal.y) if hb >= 0 and hb < Run.map.size() else null},
	}
