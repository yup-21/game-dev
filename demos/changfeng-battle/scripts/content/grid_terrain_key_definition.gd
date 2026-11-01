@tool
class_name WuxiaGridTerrainKeyDefinition
extends Resource
## Single glyph mapping for manually painted GRID row text.
@export var symbol: String = ""
@export_enum("road", "bridge", "water", "rock", "bamboo") var terrain_kind: String = "road"

func valid_key() -> bool:
    return symbol.length() == 1 and terrain_kind in ["road","bridge","water","rock","bamboo"]
