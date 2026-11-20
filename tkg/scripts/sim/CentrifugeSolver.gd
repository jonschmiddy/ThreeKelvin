class_name CentrifugeSolver
extends RefCounted

## A scripted Centrifuge player: each tube tapped in the rack, then tapped into the slot the
## balanced load has for it, then SPIN, through the game's own taps (`MiniGameTest`,
## `-- minigame centrifuge auto=1`).
## Why: docs/why/MiniGame.md#tests


## The canvas points to tap, in order (each a press and a release where it was pressed).
static func taps(g: GameCentrifuge) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sol: Array[int] = g.P.sol
	var tray: Array[int] = g.tray.duplicate()
	for i in sol.size():
		if not sol[i] or g.fixed.has(i):
			continue
		var j := tray.find(sol[i])
		out.append(g.cell_rect(j).get_center())
		out.append(g.slot_xy(i, 0.0, 0, 0))
		tray.remove_at(j)
	out.append(GameCentrifuge.SPIN.get_center())
	return out


static func solve(g: GameCentrifuge) -> void:
	for p in taps(g):
		g.down(p)
		g.up(p)
		g.tick(0.1)
