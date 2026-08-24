class_name DocumentData
extends Resource

## One thing somebody else wrote, recovered out of a system.
##
## The archive is primary sources and never exposition — see `docs/lore.md` §5.
## Every field here exists to keep it that way, and the ones that look like
## flavour are the ones doing the work.
##
## `by` is the author's JOB, because a document with an author has a reason to
## exist that is not the player's benefit, and a document with a job has an
## audience that already knew the context. That is the whole trick: a clerk
## writing for another clerk cannot stop to explain the world, so the world
## arrives sideways or not at all.
##
## `body` is capped by convention rather than by code at about a hundred and
## fifty words. This is a game about flying a ship. An archive that takes an
## evening is an archive that gets read once, by three people.

@export var id: StringName = &""
## What it is, in the register of a filing system rather than of a story.
## "CARGO MANIFEST, UNSIGNED", not "The Unsigned Manifest".
@export var title: String = ""
## Who wrote it and why they were holding a pen. Never a narrator.
@export var by: String = ""
## Its own date, in its own epoch. THE EPOCHS DO NOT RECONCILE, deliberately —
## each manufacturer counts from something different and none of them says from what.
## Enough internal consistency for a careful reader to feel duration; never
## enough to build a timeline. Duration is the horror; chronology is a wiki.
@export var dated: String = ""
@export_multiline var body: String = ""
## Which manufacturer's paperwork this is, or empty for a document that belongs to
## nobody — a pilot's private log, a transponder, a thing scratched into a wall.
## Only colours the entry. There is no faction standing and never will be.
@export var manufacturer: StringName = &""

## The shallowest shell this can be recovered from, 0 at the rim.
##
## Depth is the only gate. `design-doc.md`'s greed clock says you die because you
## went one jump too far, and it is worth there being something down there that
## is not a better gun — so the entries that unsettle most sit deepest, and a
## player who never leaves the frontier reads invoices.
@export var depth: int = 0

## What it was recovered FROM, filled in when it is found rather than authored.
## The same manifest off a derelict at layer three and a hulk at layer eight is
## not the same document, and this is the half that says so.
var found_at: String = ""
