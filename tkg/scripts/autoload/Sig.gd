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

# Combat
signal combat_started(enemy_name: String)
signal combat_ended(result: StringName, summary: String)
signal turn_started(turn: int)
signal hand_changed()
signal enemy_changed()
signal player_combat_state_changed()
signal card_played(card: CardData)
signal damage_dealt(amount: int, to_player: bool)
signal charge_fired(card_name: String)
signal overheated(burn: int)
