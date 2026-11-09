class_name ManufacturerData
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var tagline: String = ""
## The mark colour, which `manufacturer_colour()` returns as it is the half that reads on dark UI.
@export var colour: Color = Color.WHITE
## Two colours, since a banner is a mark on a field. Verity and Calyx run light fields on purpose.
@export var field: Color = Color("#16202e")
## Company, not mechanics: `identity` says what flying them does, and the choice is an allegiance.
@export_multiline var backstory: String = ""
@export_multiline var identity: String = ""
@export var set3_name: String = ""
@export var set3_text: String = ""
@export var set5_name: String = ""
@export var set5_text: String = ""
