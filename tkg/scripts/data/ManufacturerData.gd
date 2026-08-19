class_name ManufacturerData
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var tagline: String = ""
## The mark colour: emblem, accents, anything this house draws ON its ground.
## What manufacturer_colour() returns, because it is the half that reads on a
## dark UI.
@export var colour: Color = Color.WHITE
## The banner ground. Two colours per house rather than one, because a banner is
## a mark ON a field and one hex cannot be both. Halcyon and Calyx run light
## fields on purpose — they read against the void natively, which is what makes
## luxury and clinical look like themselves next to five dark houses.
@export var field: Color = Color("#16202e")
@export_multiline var identity: String = ""
@export var set3_name: String = ""
@export var set3_text: String = ""
@export var set5_name: String = ""
@export var set5_text: String = ""
