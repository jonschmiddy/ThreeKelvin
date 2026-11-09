extends Node
## Global signal bus. UI listens, systems emit — nothing reaches across scenes.

# Run / meta
signal run_started()
signal run_ended(won: bool, reason: String)
signal resources_changed()          ## credits, fuel, exotic, hull, heat
signal ship_changed()               ## modules installed/removed, hull swapped
signal log_line(text: String, kind: StringName)

# Map
signal jumped(node_index: int)
signal map_changed()
signal screen_changed()             ## a screen was swapped in; nav re-evaluates
signal undock_wanted()              ## `Router.cast_off` refused a way off the berth
## The HUD is built once at boot, so anything building controls behind DevMode must rebuild here.
signal dev_mode_changed()

## On the bus so the meter can appear without Main rebuilding or settings holding a reference.
signal fps_meter_changed(on: bool)
## The rendering style was changed in Settings (`DisplaySettings.render_style`).
## The star chart and the sector map rebuild their pictures on it.
signal render_style_changed()
## The machine picked GRAPHICS for this computer (`DisplaySettings.machine_pick`).
## Nothing is rebuilt (the pictures up keep their pass); Settings redraws its row.
signal graphics_picked()
## Fires from RunState, not from the four places that can move a contract.
signal contracts_changed()

# Combat
signal combat_started(enemy_name: String)
signal combat_ended(result: StringName, summary: String)
signal turn_started(turn: int)
signal hand_changed()
signal enemy_changed()
## A hull came apart. Separate from enemy_changed because that fires for every
## scratch, and the moment something dies deserves its own beat.
signal enemy_destroyed(who: int)
signal player_combat_state_changed()
signal card_played(card: CardData)
## `who` is the enemy involved: fights hold several, so the effects layer cannot guess a hull.
signal damage_dealt(amount: int, to_player: bool, who: int)
signal charge_fired(card_name: String)
signal overheated(burn: int)
## Every attack: `damage_dealt` fires only on hull loss, so blocked swings left no trace (audit 6).
signal combat_hit(to_player: bool, who: int, dealt: int, absorbed: int, missed: int, hits: int)
## Hull you burned yourself at the end of a turn: `cause` is &"overheat" or
## &"junk". There was no signal for it, so the hull just dropped (item 9).
signal hull_burned(amount: int, cause: StringName)
## Emitted when the tracer arrives, not when the maths ran, so sound lands with the hit (F1, F2).
signal hit_landed(amount: int, to_player: bool, who: int, absorbed: int)

# Emitted by NetSession only. It never touches a screen: it says what happened.
signal party_state_changed(state: int)   ## NetSession.State as an int
signal party_changed()                   ## somebody joined, left, or readied
signal party_launched(seed_value: int)   ## the host started the dive
signal party_failed(reason: String)      ## refused, dropped, or never reached
signal party_notice(text: String)        ## a line every screen shows (`PartyNotice`)
## A seed gives four machines an identical galaxy, not a shared one: whether a node is still there.
## Without this every player strips every wreck and the hold economy is paid four times.
## Why: docs/why/Sig.md#party-map
signal party_map_changed()
## `at` is the system, since a party can be in several fights at once.
signal party_fight_changed(at: int)
## Sent to one machine only: dodge, block, brace and hull exist only there.
signal party_fight_swing(at: int, which: int, kind: int, pick: int)
