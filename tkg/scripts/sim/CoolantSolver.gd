class_name CoolantSolver
extends RefCounted

## A scripted Coolant player: every route pipe turned to its goal, no wasted turn, through the
## game's own taps (`MiniGameTest`, `-- minigame coolant auto=1`).
## Why: docs/why/MiniGame.md#tests


## The canvas points to tap, in order: each route tile as often as it needs turning.
static func taps(g: GameCoolant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var w: int = g.P.w
	var tiles: Array[Dictionary] = g.P.tiles
	for i in tiles.size():
		for k in GameCoolant.need(tiles[i]):
			out.append(Vector2i(g.GX + (i % w) * g.S + g.S / 2, g.GY + (i / w) * g.S + g.S / 2))
	return out


static func solve(g: GameCoolant) -> void:
	for p in taps(g):
		g.down(p)
		g.up(p)
