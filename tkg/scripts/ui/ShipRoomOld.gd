class_name ShipRoomOld
extends ShipRoom

## The Old hangar's mothball racks (Jon, Nov 24: A16 approved): a locked maker's tarps under one sodium lamp.
## Why: docs/why/ShipRoom.md#rooms


func hull_amb() -> float:
	return 0.35


func tuck() -> int:
	return 4


func band_colour() -> Color:
	return Color8(9, 8, 7)
