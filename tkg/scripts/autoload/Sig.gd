extends Node
## Global signal bus. UI listens, systems emit — nothing reaches across scenes.

# Run / meta
signal run_started()
signal run_ended(won: bool, reason: String)
signal resources_changed()          ## scrap, fuel, exotic, hull, heat
signal ship_changed()               ## modules installed/removed, hull swapped
signal log_line(text: String, kind: StringName)

# Map
signal jumped(node_index: int)
signal map_changed()
signal screen_changed()             ## a screen was swapped in; nav re-evaluates

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
## `who` is the enemy involved: the victim when it is your shot, the attacker
## when it is theirs, -1 when nothing sensible applies. Fights hold several
## enemies now, so an event that only says "someone took damage" cannot be
## drawn — the effects layer would have to guess which hull to hit.
signal damage_dealt(amount: int, to_player: bool, who: int)
signal charge_fired(card_name: String)
signal overheated(burn: int)
