class_name LootEntry extends Resource

enum EntryType {
	ITEM,
	MATERIAL
}

@export var entry_type: EntryType = EntryType.ITEM
@export var entry_id: String
@export var weight: int = 1