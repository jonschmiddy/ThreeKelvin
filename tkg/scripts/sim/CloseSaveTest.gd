extends Node

## CLOSING THE WINDOW SAVES, as SAVE & EXIT does (`Router.save_on_close`;
## release check, Oct 18, Jon "r3:yes").
##   godot --headless --path . -- sheet=CloseSaveTest
##
## The autosave writes on a screen change and nowhere else, so a wreck looted
## on LOCAL and then the window's X lost the loot: the export's own first-run
## bot came back from a relaunch 19 credits and a part short. Through the real
## notification (`NOTIFICATION_WM_CLOSE_REQUEST`, sent to the tree as the
## window sends it) and a real load:
##   - a used run, a wreck looted on LOCAL, the window closed: the save on disk
##     has the loot, and a resume puts it in the hold;
##   - closed mid-fight: the save from before the fight stands (no hull, heat or
##     credits banked from inside it) and the fight is marked to start again;
##   - closed on the title: nothing is written.
## Its own scratch save (`SaveGame.path` under a harness), never the player's.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _close() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().process_frame


func _ids_aboard(id: StringName) -> int:
	var c := 0
	for m in Run.installed:
		if (m as ModuleData).id == id:
			c += 1
	for m in Run.cargo:
		if m is ModuleData and (m as ModuleData).id == id:
			c += 1
	return c


func _run() -> void:
	await get_tree().process_frame
	SaveGame.clear()
	await _loot_case()
	await _fight_case()
	await _title_case()
	SaveGame.clear()
	h.verdict("closesavetest")
	get_tree().quit(h.code())


## A system to stand in, with nothing waiting there to start a fight.
func _park() -> MapGen.MapNode:
	var at: MapGen.MapNode = null
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n):
			at = n
			break
	Run.at = at.index
	SectorScreen._approached_at = at.index
	for raw in Run.map:
		(raw as MapGen.MapNode).ambush_rolled = true
		(raw as MapGen.MapNode).ambush_pending = false
	return at


func _loot_case() -> void:
	print("a wreck looted on LOCAL, then the window closed")
	h.seed_run(6061)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n := _park()
	Run.jumps = 3   # a used run, past its launch
	Router.show_local()
	await _frames(10)
	h._ok("LOCAL is up and the run is saved", Router.current is SectorScreen and SaveGame.has_save())
	var w := Run.new_wreck(n, DB.enemies[&"cutter"])
	var part := LootGen.roll_module(2)
	w.items.append(CreditChit.of(37))
	w.items.append(part)
	var credits0 := Run.credits
	var had := _ids_aboard(part.id)
	var got_c: bool = await Run.take_from_jetsam(n, w, 0)
	var got_p: bool = await Run.take_from_jetsam(n, w, 1)
	h._ok("took 37 credits and a %s" % part.id, got_c and got_p and Run.credits == credits0 + 37
		and _ids_aboard(part.id) == had + 1)
	var before := SaveGame._read()
	h._ok("the save on disk does not have them yet (the bug)", int(before.get("credits", -1)) == credits0)
	await _close()
	var after := SaveGame._read()
	h._ok("closing the window wrote them (%d credits)" % int(after.get("credits", -1)),
		int(after.get("credits", -1)) == credits0 + 37)
	# relaunch: nothing in memory, the save read back
	Run.hull = null
	h._ok("the save loads", SaveGame.load_into_run())
	h._ok("and the credits are aboard", Run.credits == credits0 + 37)
	h._ok("and the part is in the hold", _ids_aboard(part.id) == had + 1)
	var back := Run.node_at()
	var bw: MapGen.Jetsam = null
	for raw in back.jetsam:
		if (raw as MapGen.Jetsam).slot == w.slot:
			bw = raw
	h._ok("and the wreck knows both were taken", bw != null and back.taken.has(bw.option(0))
		and back.taken.has(bw.option(1)))


func _fight_case() -> void:
	print("closed mid-fight")
	h.seed_run(6062)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_park()
	Run.jumps = 3
	Router.show_local()
	await _frames(10)
	var saved := SaveGame._read()
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(30)
	h._ok("a fight is on", Router.in_combat())
	Run.add_credits(500)
	Run.hp = maxi(1, Run.hp - 10)
	await _close()
	var after := SaveGame._read()
	h._ok("nothing from inside the fight is banked (credits %d, hull %d)" % [
		int(after.get("credits", -1)), int(after.get("hp", -1))],
		int(after.get("credits", -1)) == int(saved.get("credits", -2))
		and int(after.get("hp", -1)) == int(saved.get("hp", -2)))
	h._ok("and the fight is marked to start again", after.has("fight"))
	Router.combat = null


func _title_case() -> void:
	print("closed on the title")
	SaveGame.clear()
	Run.hull = null
	Router.show_launcher()
	await _frames(10)
	await _close()
	h._ok("nothing is written", not SaveGame.has_save())
