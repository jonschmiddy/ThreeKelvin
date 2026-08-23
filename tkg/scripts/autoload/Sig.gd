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
## The developer switch was flipped. Anything that BUILDS controls behind
## DevMode.enabled has to rebuild here: the HUD is constructed once at boot and
## would otherwise keep whichever tabs it was born with until the game restarts.
signal dev_mode_changed()
## A page was recovered out of a system. The archive tab counts, and the HUD
## shows the count, so both have to hear it — and it fires from the one door in
## Archive rather than from the three encounters that go through that door.
signal archive_changed()
## A contract was taken, finished or paid. The station board and the ledger both
## read it, and it fires from RunState rather than from the four places that can
## move a contract.
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
## `who` is the enemy involved: the victim when it is your shot, the attacker
## when it is theirs, -1 when nothing sensible applies. Fights hold several
## enemies now, so an event that only says "someone took damage" cannot be
## drawn — the effects layer would have to guess which hull to hit.
signal damage_dealt(amount: int, to_player: bool, who: int)
signal charge_fired(card_name: String)
signal overheated(burn: int)

# Party. Emitted by NetSession only. The session layer is a system like any
# other here — it never touches a screen, it says what happened and the lobby
# listens. See scripts/net/NetSession.gd.
signal party_state_changed(state: int)   ## NetSession.State as an int
signal party_changed()                   ## somebody joined, left, or readied
signal party_launched(seed_value: int)   ## the host started the dive
signal party_failed(reason: String)      ## refused, dropped, or never reached
## The party consumed a system — somebody stripped a wreck, won a fight or
## answered a hail. RunState listens and marks its own copy of the map.
##
## It exists because a seed gives four machines an IDENTICAL galaxy rather than
## a SHARED one. Everything a node holds is positional and therefore already
## agrees; what does not agree is whether it is still there. Without this every
## player strips every wreck and the hold economy is paid four times over.
signal party_map_changed()
## A shared fight moved: somebody shot, somebody joined, the enemy took its
## turn, or it ended. `at` is the system it is happening in — a party can be in
## more than one fight at once, in different places, so an event that only says
## "a fight changed" cannot be acted on.
signal party_fight_changed(at: int)
## Something in a shared fight is swinging at YOU. `kind`/`pick` name the intent
## by index into the enemy's own scaled lists; see NetSession._swing(). Sent to
## one machine only, because everything it resolves against — dodge, block,
## brace, hull — exists only there.
signal party_fight_swing(at: int, which: int, kind: int, pick: int)
