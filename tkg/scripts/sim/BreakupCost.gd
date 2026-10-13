extends Node

## What a death costs the frame it starts on (combat polish, Oct 13).
##   godot --headless --path . -- sheet=BreakupCost
## Times, for each enemy kind's drawn canvas: ShipBreakup.cut, wreck_image, a
## whole breakup setup, and EnemyArt drawing the dead ship (which cuts too).

func _ready() -> void:
	_run.call_deferred()


func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0


func _run() -> void:
	await get_tree().process_frame
	for id in [&"cutter", &"hulk", &"whale", &"hellbender", &"custodian"]:
		var t: EnemyTemplate = DB.enemies[id]
		var e := Combat.EnemyState.new()
		e.template = t
		e.max_hp = t.max_hull
		e.hp = e.max_hp
		var art := EnemyArt.new()
		art.set_enemy(e, false)
		var img := art.snapshot()
		var used := art.used_rect()
		var t0 := Time.get_ticks_usec()
		ShipBreakup.cut(img, used, 7, t.boss)
		var c := _ms(t0)
		t0 = Time.get_ticks_usec()
		ShipBreakup.wreck_image(img, used, 7, t.boss, 0)
		var w := _ms(t0)
		t0 = Time.get_ticks_usec()
		var b := ShipBreakup.new()
		b.setup(img, used, Vector2.ZERO, 0, 7, t.boss)
		var s := _ms(t0)
		b.free()
		e.hp = 0
		t0 = Time.get_ticks_usec()
		art.set_enemy(e, false)
		var d := _ms(t0)
		art.free()
		print("breakupcost %-10s used %s  cut %.1f ms  wreck %.1f ms  setup %.1f ms  dead draw %.1f ms"
			% [id, used.size, c, w, s, d])
	get_tree().quit()
