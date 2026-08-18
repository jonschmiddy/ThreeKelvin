extends Node
## Screen flow. Owns the single content container and swaps screens into it,
## and decides what happens when you arrive at a map node.

var content: Control
var hud: HudBar
var current: Control
var combat: Combat

func register(content_holder: Control, hud_bar: HudBar) -> void:
	content = content_holder
	hud = hud_bar
	Sig.jumped.connect(_on_jumped)
	Sig.run_ended.connect(_on_run_ended)

func _swap(screen: Control) -> void:
	if current != null:
		current.queue_free()
	current = screen
	content.add_child(screen)

func new_run() -> void:
	Run.start_new_run()
	show_map()

func show_map() -> void:
	# The chart is the only place jumps are offered, so it is the one chokepoint
	# where being out of fuel has to resolve rather than stall.
	Run.check_stranded()
	if Run.dead:
		show_game_over()
		return
	var s := MapScreen.new()
	_swap(s)
	s.setup()

func show_game_over() -> void:
	var s := GameOverScreen.new()
	_swap(s)
	s.setup()

func jump_to(index: int) -> void:
	Run.jump_to(index)

func _on_jumped(_index: int) -> void:
	resolve_current_node()

func resolve_current_node() -> void:
	var n: MapGen.MapNode = Run.node_at()
	Run.log_line("Jumped to %s%s. Danger %d." % [
		MapGen.region_name(n.region),
		"" if n.manufacturer == &"" else " (%s)" % DB.manufacturer_name(n.manufacturer),
		n.danger], &"you")

	match n.type:
		MapGen.NodeType.GOAL:
			Run.log_line("The farlight fills the viewport. Something is guarding it.", &"big")
			start_combat(DB.enemies[&"custodian"])
		MapGen.NodeType.FIGHT:
			if n.cleared:
				show_map()
			else:
				var pool := DB.fight_pool(n.danger, n.region == MapGen.Region.FAUNA)
				start_combat(DB.enemies[pool.pick_random()])
		MapGen.NodeType.STATION:
			var s := StationScreen.new()
			_swap(s)
			s.setup()
		MapGen.NodeType.DERELICT:
			if n.cleared:
				show_map()
			else:
				_resolve_derelict(n)
		MapGen.NodeType.EVENT:
			if n.cleared:
				show_map()
			else:
				n.cleared = true
				var e := EventScreen.new()
				_swap(e)
				e.setup(EventTable.pick())
		_:
			show_map()

func _resolve_derelict(n: MapGen.MapNode) -> void:
	n.cleared = true
	var count := 2 if n.region == MapGen.Region.LAWLESS else 1
	for i in count:
		var force := n.manufacturer if n.region == MapGen.Region.TERRITORY else &""
		Run.cargo.append(LootGen.roll_module(n.danger, force,
			n.region == MapGen.Region.CORE or n.region == MapGen.Region.FAUNA))
	if randf() < 0.35:
		Run.found_hull = LootGen.roll_hull(n.danger)
		Run.log_line("A flyable hull is still attached: %s" % Run.found_hull.display_name(), &"good")
	Run.log_line("Derelict stripped. %d module%s recovered." % [
		count, "" if count == 1 else "s"], &"good")
	show_loot()

func start_combat(template: EnemyTemplate) -> void:
	combat = Combat.new()
	var s := CombatScreen.new()
	_swap(s)
	combat.start(template, Run.node_at().danger)
	s.setup(combat)

## Events can drop you straight into a fight (distress-beacon bait).
func start_ambush() -> void:
	var pool := DB.fight_pool(Run.node_at().danger, false)
	start_combat(DB.enemies[pool.pick_random()])

func after_combat(_c: Combat) -> void:
	if Run.dead or Run.won:
		show_game_over()
		return
	show_loot_or_map()

func after_event() -> void:
	if Run.dead:
		show_game_over()
		return
	show_loot_or_map()

func show_loot_or_map() -> void:
	if Run.cargo.is_empty() and Run.found_hull == null:
		show_map()
	else:
		show_loot()

func show_loot() -> void:
	var s := LootScreen.new()
	_swap(s)
	s.setup()

func _on_run_ended(_won: bool, _reason: String) -> void:
	pass  ## screens call show_game_over() so the player sees the summary first
