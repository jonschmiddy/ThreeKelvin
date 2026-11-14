class_name EncounterText
extends RefCounted

## The event's words as plain strings, for the rules (`OptionResolve`) and the screens alike; no node, no colour.

## The ledger rows that moved, as one line: "FUEL -16 · HULL -3", or "".
static func moved_line(bill: Array) -> String:
	var bits: Array = []
	for r in bill:
		if String(r.text) != "—":
			bits.append("%s %s" % [r.name, r.text])
	return " · ".join(bits)


## One line of body for the list. The rest lives in the detail view.
static func first_sentence(body: String) -> String:
	var cut := body.find(". ")
	if cut < 0:
		return body
	return body.substr(0, cut + 1)
