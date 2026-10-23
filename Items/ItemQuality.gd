@tool
extends RefCounted
class_name ItemQuality

# Shared item-name colors. Use these for inventory, tooltips, loot labels,
# and the Item Creator preview so every screen agrees on rarity colors.
const NAME_COLORS := {
	"Common": Color("dedede"),
	"Uncommon": Color("57db66"),
	"Rare": Color("f5d64d"),
	"Epic": Color("b879ff"),
	"Legendary": Color("ffad45"),
	"Mythic": Color("ff67c4")
}

static func get_name_color(quality: String) -> Color:
	return NAME_COLORS.get(quality, Color.WHITE)
