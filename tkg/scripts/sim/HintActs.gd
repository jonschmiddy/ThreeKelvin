extends RefCounted

## THE PLAYER DOING WHAT A HINT TEACHES (`Hints.DONE`), for `-- hinttest` and
## `-- sheet=AshTutorTest`: through the screen that is up, the way a hand does
## it -- the chart's row pressed, an event's row in the map's list, a choice in
## the band, a card played, END TURN, a part out of a wreck's window, a module
## off your ship and back on, a wreck's own click, SECTOR LOOT, a deck's button,
## a drone's job, the till, the counter, SIGN, the fabricator; and the deep
## tutorial's (Oct 22): a discard picked, the pointer rested on a card, a
## malfunction purged, FLEE pressed, CONTINUE, THRUST held, a part put down or
## pointed at in the cutaway, the FAULTS drone, TAKE IT, another deck, the escape
## menu shut, LAUNCH. Not `Hints`: what the game does when the player does it,
## and `Hints` has to notice.
##
## `act(id)` returns what it did, or "" if the screen had nothing to do it with.


static func act(id: StringName) -> String:
	var cur = Router.current
	if cur == null or not is_instance_valid(cur):
		return ""
	var sc := cur as SectorScreen
	var st := cur as StationScreen
	match id:
		&"chart":
			var ch := cur as StarchartScreen
			if ch == null or ch._neigh == null:
				return ""
			for c in ch._neigh.get_children():
				var b := c as Button
				if b != null and b.is_visible_in_tree() and int(b.get_meta(&"node", -1)) != ch._selected:
					b.pressed.emit()
					return "picked %s in the chart's list" % MapGen.star_name(Run.map[int(b.get_meta(&"node"))])
		&"events":
			var map := cur as SystemMapScreen
			if map == null or map.panel == null:
				return ""
			for c in (map.panel as Node).find_children("*", "", true, false):
				if c is Control and c.has_method("set_doomed") and not c.get("finished") \
						and (c.get("press") as Callable).is_valid() and (c as Control).is_visible_in_tree():
					(c.get("press") as Callable).call()
					return "pressed an event's row in the map's list"
		&"drawer", &"odds":
			if sc == null or sc._events == null:
				return ""
			var d := sc._events
			var choices: Array = OptionTable.by_id(d.node.options[d.opt]).get("choices", [])
			# the one that leaves it be, if it has one (the event stays open for
			# what the run does next); else the first it can afford
			var pick := -1
			for j in choices.size():
				if OptionResolve.affordable(choices[j]) and (pick < 0 or bool((choices[j] as Dictionary).get("stay", false))):
					pick = j
			if pick < 0:
				return ""
			d.choose(pick)
			return "took choice %d in the band" % pick
		&"hand", &"energy", &"heat_corner", &"piles":
			var cb: Combat = Router.combat
			if cb == null:
				return ""
			for i in cb.hand.size():
				if cb.can_play(cb.hand[i] as CardData) and not (cb.hand[i] as CardData).unplayable:
					cb.play(i, 0)
					return "played a card"
		&"discard_pick":
			var cb: Combat = Router.combat
			if sc == null or cb == null or cb.choosing <= 0 or cb.hand.is_empty():
				return ""
			sc._on_card_picked(cb.hand[0])
			return "picked a card from the hand to discard"
		&"keywords":
			# the pointer rests on the card: its readout after the screen's delay
			if sc == null or sc._hand == null:
				return ""
			for v in sc._hand._views:
				if v != null and is_instance_valid(v) and v._body != null and v._body.text.contains("[u]"):
					sc._on_card_hovered(v, true)
					return "rested the pointer on %s" % v.card.name
		&"malfunction":
			var cb: Combat = Router.combat
			if cb == null:
				return ""
			for i in cb.hand.size():
				if (cb.hand[i] as CardData).unplayable and cb.can_play(cb.hand[i] as CardData):
					var nm := (cb.hand[i] as CardData).name
					cb.play(i, -1)
					if sc != null:
						sc._refresh_player()
					return "played (purged) %s" % nm
		&"flee_hail":
			if sc == null or not sc.fighting():
				return ""
			sc._on_flee()
			if sc._exit_ask != null:
				return "pressed FLEE (its question up)"
			sc._on_hail()
			if sc._exit_ask != null:
				return "pressed HAIL (its question up)"
		&"endturn", &"brace", &"heat", &"intent":
			if sc == null or not sc.fighting():
				return ""
			sc._on_end_turn()
			return "pressed END TURN"
		&"result":
			if sc == null or sc._events == null or sc._events.page != &"result":
				return ""
			sc._events.continue_on()
			return "pressed CONTINUE"
		&"hull":
			# (no action: the screen left once she has said it)
			Router.show_starchart()
			return "left LOCAL for the chart"
		&"map_fly":
			var map := cur as SystemMapScreen
			if map == null:
				return ""
			map._wasd["w"] = true
			return "held THRUST (the harness lets go after)"
		&"layers", &"contract_track", &"quest", &"jump_blocked":
			return act(&"chart")
		&"mounts":
			var cut := Hints._cut_of(cur)
			if cut == null or cut._mounts == null or cut._mounts._lit == null:
				return ""
			cut._mounts._unlight()
			return "put the part down"
		&"cards_from_parts":
			var cut := Hints._cut_of(cur)
			if cut == null or Run.installed.is_empty():
				return ""
			cut._show(Run.installed[0], cut._mount_line.get_global_rect() if cut._mount_line != null else Rect2())
			return "pointed at %s" % (Run.installed[0] as ModuleData).name
		&"attributes":
			return act(&"cutaway")
		&"faults":
			if st == null:
				return ""
			st._on_yard_service(3)
			if st._purge_prompt != null:
				return "clicked the FAULTS drone (its picker up)"
		&"hull_sale":
			if st == null:
				return ""
			var h0 := Run.hull
			st._on_yard_take()
			if Run.hull != h0:
				return "pressed TAKE IT"
		&"undock":
			if st == null:
				return ""
			for tab in [&"stock", &"hold", &"services"]:
				if st._tab != tab and st._tabs.has(tab) and st._tabs_on.get(tab, true):
					(st._tabs[tab] as Button).pressed.emit()
					return "picked the %s deck (another deck: UNDOCK's line goes)" % tab
		&"save":
			if not Hints.menu_up():
				return ""
			var n: Node = Router.content
			while n != null:
				if n.has_method("toggle_menu"):
					n.call("toggle_menu", false)
					return "shut the escape menu"
				n = n.get_parent()
		&"chassis_card":
			var cs := cur as ChassisSelect
			if cs == null:
				return ""
			for b in cs.find_children("*", "Button", true, false):
				if (b as Button).text == "LAUNCH":
					(b as Button).pressed.emit()
					return "pressed LAUNCH"
		&"salvage":
			var tv := Hints._transfer(sc)
			if tv == null or tv._jetsam == null or tv._jetsam.items.is_empty():
				return ""
			Run.take_from_jetsam(tv._node, tv._jetsam, 0)
			tv.refresh()
			return "took a part from the window into the hold"
		&"cutaway":
			# off the ship into the hold, and back on at the end of the frame (the
			# fight after this wants its cards); `Hints` reads the fit as it is
			# when it next looks, which is before then
			for m: ModuleData in Run.installed.duplicate():
				if Run.uninstall_module(m):
					Run.install_module.call_deferred(m)
					return "took %s off the ship (back on after)" % m.name
		&"wreck":
			if sc == null:
				return ""
			var n := Run.node_at()
			var k := 0
			for raw in Run.wrecks_here(n):
				var h: MapGen.Jetsam = raw
				if Run.jetsam_left(n, h) > 0:
					var sl := sc._view.slot(k)
					if sl != null and sl.is_visible_in_tree() and sl.opened.is_valid():
						sl.opened.call()
						return "clicked a wreck"
				k += 1
		&"loot":
			if sc == null:
				return ""
			var b := sc.find_child("SectorLoot", true, false) as Button
			if b != null and b.is_visible_in_tree():
				b.pressed.emit()
				return "pressed SECTOR LOOT"
		&"dock":
			if st == null:
				return ""
			for tab in [&"services", &"stock", &"hold"]:
				if st._tab != tab and st._tabs.has(tab) and st._tabs_on.get(tab, true):
					(st._tabs[tab] as Button).pressed.emit()
					return "picked the %s deck" % tab
		&"shipyard":
			if st == null:
				return ""
			for i in [0, 2]:
				var sig := [Run.credits, Run.hp, Run.fuel]
				st._on_yard_service(i)
				if [Run.credits, Run.hp, Run.fuel] != sig:
					return "paid drone %d's job" % i
		&"promenade":
			var n := Run.node_at()
			if st == null or n == null:
				return ""
			for i in n.shop.size():
				if n.taken.has(MapGen.OPTION_SHOP + i):
					continue
				var c0 := Run.credits
				st._on_till(n.shop[i])
				if Run.credits != c0:
					return "bought %s at the till" % (n.shop[i] as ModuleData).name
		&"exchange":
			if st == null:
				return ""
			# (a part, not the fabricator's relic: the deck after this one needs it)
			for it: HoldItem in Run.cargo.duplicate():
				if it is ModuleData and TradeCounter.offer(it) > 0:
					st._on_counter(it)
					return "sold %s at the counter" % it.name
		&"hiring_board":
			if st == null:
				return ""
			for b in st.find_children("*", "Button", true, false):
				if (b as Button).text == "SIGN" and (b as Button).is_visible_in_tree():
					(b as Button).pressed.emit()
					return "pressed SIGN on a note"
		&"laboratory":
			var n := Run.node_at()
			if st == null or n == null:
				return ""
			for r in Fabricator.available(n):
				if Fabricator.can_make(n, r):
					st._fabricate(r)
					return "made %s" % String(r.get("kind", "?"))
		&"ship":
			if sc != null and sc.open_cutaway() != null:
				return "opened the ship up"
			if st != null and st.open_cutaway() != null:
				return "opened the ship up"
	return ""


## What a station's decks need to be used by `act`: credits for a drone, the
## till and the fabricator; a part in the hold for the counter; the fabricator's
## materials. Done before a deck's line shows (what it adds would read as the
## deck used).
static func stock_up() -> void:
	Run.add_credits(4000)
	var n := Run.node_at()
	if n != null:
		for r in Fabricator.available(n):
			for mid in (r.mats as Dictionary).keys():
				# (into the hold, where the fabricator takes them from: `add_material`
				# puts them on the system's floor)
				for k in maxi(0, int(r.mats[mid]) - Run.material(mid)):
					Run.stow(MaterialData.of(MaterialTable.by_id(mid)))
	var sellable := false
	for it: HoldItem in Run.cargo:
		if it is ModuleData and TradeCounter.offer(it) > 0:
			sellable = true
	if not sellable:
		Run.stow(LootGen.roll_module(2, &"", false))
