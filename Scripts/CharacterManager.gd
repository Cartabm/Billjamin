extends Node

enum CharacterClass {
	ARCHER,
	ROGUE
}

var selected_class: CharacterClass = CharacterClass.ARCHER
# Gameplay tags are based on class, never character name.
const CLASS_TAGS := {
	CharacterClass.ARCHER: ["ranged", "physical"],
	CharacterClass.ROGUE: ["melee", "physical"]
}


func get_selected_class_tags() -> Array[String]:
	var tags: Array[String] = []

	for tag in CLASS_TAGS.get(selected_class, []):
		tags.append(tag)

	return tags
const ARCHER_SCENE: PackedScene = preload("res://Scenes/player.tscn")
const ROGUE_SCENE: PackedScene = preload("res://Scenes/RoguePlayer.tscn")

# Unique ID of the currently selected character.
# Assigned by Supabase when the character is created.
var selected_character_id: String = ""

# Character name, separate from the account name.
var selected_character_name: String = ""

# Whether this character has unlocked their personal stash.
var personal_stash_unlocked: bool = false


func has_selected_character() -> bool:
	return not selected_character_id.is_empty()


func clear_selected_character() -> void:
	selected_character_id = ""
	selected_character_name = ""
	personal_stash_unlocked = false

func select_character(character: Dictionary) -> void:
	selected_character_id = str(character.get("id", ""))
	selected_character_name = str(character.get("character_name", ""))
	personal_stash_unlocked = bool(character.get("personal_stash_unlocked", false))

	match str(character.get("class_id", "")):
		"archer":
			selected_class = CharacterClass.ARCHER
		"rogue":
			selected_class = CharacterClass.ROGUE
		_:
			push_warning("Unknown character class: " + str(character.get("class_id", "")))

func get_selected_player_scene() -> PackedScene:
	if not has_selected_character():
		push_warning("No character selected.")
		return null

	match selected_class:
		CharacterClass.ARCHER:
			return ARCHER_SCENE

		CharacterClass.ROGUE:
			return ROGUE_SCENE

	return null
