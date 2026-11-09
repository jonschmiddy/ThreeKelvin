extends Node

## Two edges of Combat: a card costing credits, and a turn that starts after a drone wins.
## Run as `-- sheet=CombatEdgeTest`.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_credit_card()
	_drone_ends_it()
	h.verdict("combatedgetest")
	get_tree().quit(h.code())


func _fresh() -> Combat:
	h.seed_run(777)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var cb := Combat.new()
	cb.plan(DB.enemies[&"lancer"], 1)
	return cb


## A card the player cannot pay for is not playable, so it is greyed and never spent.
func _credit_card() -> void:
	var cb := _fresh()
	var smelt := CardData.new()
	smelt.name = "Smelt"
	smelt.energy = 1
	smelt.credit_cost = 5
	smelt.brace = 10
	cb.hand.assign([smelt])
	cb.energy = 3
	Run.credits = 0
	h._ok("with no credits, a 5 credit card cannot be played", not cb.can_play(smelt))
	cb.play(0)
	h._ok("and playing it anyway keeps the card and the energy (%d cards, %d energy)"
		% [cb.hand.size(), cb.energy], cb.hand.size() == 1 and cb.energy == 3)
	Run.credits = 5
	h._ok("with the credits it can be played", cb.can_play(smelt))


## A drone that kills the last foe ends the fight; the due charge must not fire after it.
func _drone_ends_it() -> void:
	var cb := _fresh()
	cb.enemies[0].hp = 1
	var drone := Combat.Drone.new()
	drone.damage = 50
	cb.drones.append(drone)
	var blast := CardData.new()
	blast.name = "Blast"
	blast.heat = 4
	var charged := Combat.ChargingCard.new()
	charged.card = blast
	charged.turns_left = 1
	cb.charging.append(charged)
	var starts := [0]
	var count := func(_t: int) -> void: starts[0] += 1
	Sig.turn_started.connect(count)
	var heat := Run.heat
	cb.begin_turn()
	Sig.turn_started.disconnect(count)
	h._ok("the drone wins the fight", cb.finished)
	h._ok("the charge does not fire after the win (heat %d to %d)" % [heat, Run.heat],
		Run.heat == heat)
	h._ok("and no new turn is announced (%d)" % starts[0], starts[0] == 0)
