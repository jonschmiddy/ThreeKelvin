extends Node

## EVENTS RESOLVED ON LOCAL, photographed (`LocalEventDrawer`):
##   godot --path . --windowed --position 3840,0 -- sheet=EventShot keepwindow
##       out=<dir> [seed=1] [node=11] [layout=row|column|card] [flow] [compare] [reveal]
##       [revealav=<dir>]
##
## `flow`     the map's list, an event's page (one sentence and GO), GO -- the
##            flight and the zoom down, filmed into `flow/` -- the band up, the
##            result, the bar under the view after CONTINUE, the map with the
##            event stamped, and a fight event to its hand. Stills `01_`..`08_`.
## `compare`  a short, a medium and a long event (the shortest, middle and
##            longest bodies in `OptionTable`) in all three layouts, each still
##            as the game draws it (`cmp_<layout>_<size>.png`), with the empty
##            area of the drawer -- pixels that are bare panel, no text or card --
##            printed as `[eventshot] empty <layout> <size> <px> <of> <share>`.
## `reveal`   the medium event's text arriving (`SignalText`), one layout,
##            stepped on a fixed 30 fps clock so the frames play at true speed,
##            into `reveal_<layout>/`.
## `revealav` the same reveal SEEN AND HEARD on the real clock. The text runs
##            itself and the SFX bus is drained from an AudioEffectCapture every
##            frame (as FlightClip's tape) into `<dir>/audio.wav`; Music and
##            Ambient are muted. About 30 frames a second are saved with their
##            times (`frames.txt`, "index seconds") so ffmpeg can lay them to the
##            sound. Prints the blips played (`Audio.tape`) against the letters,
##            and the most `text_blip` voices ever sounding at once, with and
##            without the ones fading out.
## Needs a window.

const FPS := 30.0

var _args: PackedStringArray
var _out := ""


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _secs(t: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(t * 1000.0):
		await RenderingServer.frame_post_draw


func _img() -> Image:
	return GameShell.input_target(get_tree()).get_texture().get_image()


func _shot(name: String) -> void:
	_img().save_png("%s/%s.png" % [_out, name])
	print("  eventshot: %s" % name)


func _run() -> void:
	var tree := get_tree()
	_out = _arg("out", "user://eventshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await tree.process_frame
	Rng.forced = int(_arg("seed", "1"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	LocalEventDrawer.layout = StringName(_arg("layout", "column"))
	var idx := int(_arg("node", "11"))
	var n: MapGen.MapNode = Run.map[idx]
	Run.at = idx
	n.visited = true
	OptionTable.ensure(n)
	SectorScreen._approached_at = idx
	print("  eventshot: %s (node %d), %d options: %s" % [MapGen.star_name(n), idx, n.options.size(), n.options])
	if "flow" in _args:
		await _flow(n)
	if "compare" in _args:
		await _compare(n)
	if "reveal" in _args:
		await _reveal(n)
	if _arg("revealav") != "":
		await _reveal_av(n, _arg("revealav"))
	tree.quit()


# ------------------------------------------------------------------ the flow

func _flow(n: MapGen.MapNode) -> void:
	Router.show_system()
	await _secs(1.5)
	_shot("01_map_list")
	var map := Router.current as SystemMapScreen
	if map == null:
		print("  eventshot: FAIL no map")
		return
	# the first event with a checked choice, to show its odds on LOCAL
	var pick := -1
	var pick_b := -1
	var pick_bc = null
	for bi in map.view.layout.bodies.size():
		for bc in map.view.layout.bodies[bi].beacons:
			if bc.opt < 0:
				continue
			var o := OptionTable.by_id(n.options[bc.opt])
			for c in o.get("choices", []):
				if (c as Dictionary).has("check") and pick < 0:
					pick = bc.opt
					pick_b = bi
					pick_bc = bc
	if pick < 0:
		print("  eventshot: FAIL no checked event here")
		return
	map.open_beacon(pick_b, pick_bc)
	await _secs(0.4)
	_shot("02_event_page")
	# GO: the flight, the zoom down, the band lifting and its text arriving
	var flow := _out + "/flow"
	DirAccess.make_dir_recursive_absolute(flow)
	map.go_event(pick)
	var k := 0
	var t0 := Time.get_ticks_msec()
	var settle := 0
	while Time.get_ticks_msec() - t0 < 20000:
		await _secs(0.033)
		_img().save_png("%s/f_%04d.png" % [flow, k])
		k += 1
		var lo := Router.current as SectorScreen
		var d: LocalEventDrawer = lo.get("_events") if lo != null else null
		if d != null and d.page == &"event" and d.text != null and d.text.done:
			settle += 1
			if settle > 20:
				break
	print("  eventshot: flow %d frames, %.1f s" % [k, (Time.get_ticks_msec() - t0) / 1000.0])
	_shot("03_drawer_open")
	var lo2 := Router.current as SectorScreen
	var d2: LocalEventDrawer = lo2.get("_events")
	var o2 := OptionTable.by_id(n.options[pick])
	var j := 0
	for jj in (o2.get("choices", []) as Array).size():
		if ((o2.choices as Array)[jj] as Dictionary).has("check"):
			j = jj
			break
	await d2.choose(j)
	await _secs(0.1)
	d2.text.skip()
	await _secs(0.5)
	_shot("04_result")
	d2.continue_on()
	await _secs(0.8)
	_shot("05_local_bar")
	Router.show_system()
	await _secs(1.5)
	_shot("06_map_stamped")
	# A FIGHT EVENT, to its hand
	var fo := -1
	var fj := -1
	for i in n.options.size():
		if EncounterDrawer.option_state(n, i).kind != &"open":
			continue
		var choices: Array = OptionTable.by_id(n.options[i]).get("choices", [])
		for jj in choices.size():
			if bool((choices[jj] as Dictionary).get("fight", false)) and fo < 0:
				fo = i
				fj = jj
	if fo < 0:
		print("  eventshot: no fight event open here")
		return
	Router.show_local()
	await _secs(0.8)
	var lo3 := Router.current as SectorScreen
	var d3: LocalEventDrawer = lo3.get("_events")
	d3.open(fo)
	await _secs(0.15)
	d3.text.skip()
	await _secs(0.6)
	_shot("07_fight_event")
	await d3.choose(fj)
	await _secs(0.3)
	if is_instance_valid(d3) and d3.page == &"result":
		d3.text.skip()
		await _secs(0.5)
		_shot("07b_fight_result")
		d3._drop()
		d3._fight()
	await _secs(2.5)
	_shot("08_fight_hand")


# ------------------------------------------------------------------ layouts

## The shortest, the middle and the longest event bodies in the table.
func _sizes() -> Array:
	var all: Array = OptionTable.all().duplicate()
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("body", "")).length() < String(b.get("body", "")).length())
	return [["short", all[0].id], ["medium", all[all.size() / 2].id], ["long", all[all.size() - 1].id]]


func _plant(n: MapGen.MapNode, id: StringName) -> int:
	n.options.append(id)
	return n.options.size() - 1


func _compare(n: MapGen.MapNode) -> void:
	Router.show_local()
	await _secs(1.0)
	var lo := Router.current as SectorScreen
	var d: LocalEventDrawer = lo.get("_events")
	var sizes := _sizes()
	var at := {}
	for s: Array in sizes:
		at[s[0]] = _plant(n, StringName(s[1]))
	for layout: StringName in [&"row", &"column", &"card"]:
		LocalEventDrawer.layout = layout
		for s: Array in sizes:
			d.open(int(at[s[0]]))
			await _secs(0.15)
			if d.text != null:
				d.text.skip()
			await _secs(0.6)
			var img := _img()
			img.save_png("%s/cmp_%s_%s.png" % [_out, layout, s[0]])
			var r := d.panel.get_global_rect()
			var e := _empty(img, Rect2i(r))
			print("[eventshot] empty %s %s %d %d %.3f h%d" % [layout, s[0], e[0], e[1], float(e[0]) / maxf(1.0, float(e[1])), int(r.size.y)])
			d._drop()
			await _secs(0.5)
	LocalEventDrawer.layout = &"column"


## [bare panel pixels, all pixels] inside r: bare is the panel's own colour,
## with no text, card or rule on it.
func _empty(img: Image, r: Rect2i) -> Array:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var bg := UITheme.PANEL
	var bare := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if absf(c.r - bg.r) < 0.035 and absf(c.g - bg.g) < 0.035 and absf(c.b - bg.b) < 0.035:
				bare += 1
	return [bare, r.get_area()]


# ------------------------------------------------------------------ the text arriving

func _reveal(n: MapGen.MapNode) -> void:
	Router.show_local()
	await _secs(1.0)
	var lo := Router.current as SectorScreen
	var d: LocalEventDrawer = lo.get("_events")
	var i := _plant(n, StringName(_sizes()[1][1]))
	var dir := "%s/reveal_%s" % [_out, LocalEventDrawer.layout]
	DirAccess.make_dir_recursive_absolute(dir)
	d.open(i)
	# its clock stepped by hand at 30 a second, so the frames are true speed
	var k := 0
	var tail := 0
	while k < 600:
		if d.text != null:
			d.text.set_process(false)
			d.text._process(1.0 / FPS)
		await RenderingServer.frame_post_draw
		_img().save_png("%s/f_%04d.png" % [dir, k])
		k += 1
		if d.text != null and d.text.done:
			tail += 1
			if tail > 20:
				break
	print("  eventshot: reveal %d frames (%.1f s at %d fps)" % [k, k / FPS, int(FPS)])


func _reveal_av(n: MapGen.MapNode, dir: String) -> void:
	Router.show_local()
	await _secs(1.0)
	var lo := Router.current as SectorScreen
	var d: LocalEventDrawer = lo.get("_events")
	var i := _plant(n, StringName(_sizes()[1][1]))
	DirAccess.make_dir_recursive_absolute(dir)
	for bn in [&"Music", &"Ambient"]:
		var bi := AudioServer.get_bus_index(bn)
		if bi >= 0:
			AudioServer.set_bus_mute(bi, true)
	var sfx := AudioServer.get_bus_index(&"SFX")
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 2.0
	AudioServer.add_bus_effect(sfx, cap)
	Audio.tape.clear()
	Audio.taping = true
	await RenderingServer.frame_post_draw
	cap.clear_buffer()
	var pcm := PackedVector2Array()
	var t0 := Time.get_ticks_usec()
	d.open(i)
	var times := PackedStringArray()
	var k := 0
	var next := 0.0
	var most := 0
	var most_full := 0
	var started := false
	var done_at := -1.0
	while true:
		await RenderingServer.frame_post_draw
		pcm.append_array(cap.get_buffer(cap.get_frames_available()))
		var t := float(Time.get_ticks_usec() - t0) / 1e6
		var live := 0
		var full := 0
		for vi in Audio._sfx.size():
			var p: AudioStreamPlayer = Audio._sfx[vi]
			if p.playing and p.get_meta(&"asked", &"") == SignalText.BLIP:
				live += 1
				var f: Tween = Audio._fade[vi]
				if f == null or not f.is_valid():
					full += 1
		most = maxi(most, live)
		most_full = maxi(most_full, full)
		if t >= next:
			_img().save_png("%s/f_%04d.png" % [dir, k])
			times.append("%d %.4f" % [k, t])
			k += 1
			next += 1.0 / FPS
		if d.text != null and not d.text.done:
			started = true
		if started and done_at < 0.0 and d.text.done:
			done_at = t
		if (done_at >= 0.0 and t - done_at > 1.5) or t > 40.0:
			break
	pcm.append_array(cap.get_buffer(cap.get_frames_available()))
	AudioServer.remove_bus_effect(sfx, AudioServer.get_bus_effect_count(sfx) - 1)
	Audio.taping = false
	var tf := FileAccess.open(dir + "/frames.txt", FileAccess.WRITE)
	tf.store_string("
".join(times) + "
")
	tf.close()
	_write_wav(dir + "/audio.wav", pcm)
	var blips := 0
	for e in Audio.tape:
		if StringName(e[0]) == SignalText.BLIP:
			blips += 1
	var letters := String(OptionTable.by_id(n.options[i]).get("body", "")).replace(" ", "").length()
	print("  eventshot: revealav %d frames, %.2f s, text done at %.2f s, %d blips for %d letters (cps %.0f), most %d blips sounding (%d at full level, the rest fading out)" % [
		k, float(k) / FPS, done_at, blips, letters, SignalText.cps, most, most_full])


## The SFX capture as a 16-bit wav at the mix rate. On a surround output the
## capture hands over one 512-frame block per speaker pair in turn; the front
## pair is the phase with the energy (as FlightClip's tape).
func _write_wav(path: String, pcm: PackedVector2Array) -> void:
	var pairs := int(AudioServer.get_speaker_mode()) + 1
	if pairs > 1:
		var best := PackedVector2Array()
		var best_e := -1.0
		for ph in pairs:
			var front := PackedVector2Array()
			var at := ph * 512
			while at < pcm.size():
				front.append_array(pcm.slice(at, mini(at + 512, pcm.size())))
				at += 512 * pairs
			var e := 0.0
			for q in front:
				e += q.length_squared()
			if e > best_e:
				best_e = e
				best = front
		pcm = best
	var rate := int(AudioServer.get_mix_rate())
	var data := PackedByteArray()
	data.resize(pcm.size() * 4)
	for k in pcm.size():
		data.encode_s16(k * 4, int(clampf(pcm[k].x, -1.0, 1.0) * 32767.0))
		data.encode_s16(k * 4 + 2, int(clampf(pcm[k].y, -1.0, 1.0) * 32767.0))
	var w := FileAccess.open(path, FileAccess.WRITE)
	w.store_buffer("RIFF".to_ascii_buffer())
	w.store_32(36 + data.size())
	w.store_buffer("WAVEfmt ".to_ascii_buffer())
	w.store_32(16)
	w.store_16(1)
	w.store_16(2)
	w.store_32(rate)
	w.store_32(rate * 4)
	w.store_16(4)
	w.store_16(16)
	w.store_buffer("data".to_ascii_buffer())
	w.store_32(data.size())
	w.store_buffer(data)
	w.close()
	print("  eventshot: audio %.2f s at %d Hz, %d speaker pairs, to %s" % [float(pcm.size()) / float(rate), rate, pairs, path])
