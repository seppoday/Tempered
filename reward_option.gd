class_name RewardOption
extends RefCounted

enum Type { ITEM, UPGRADE }

var type: Type
var item_definition: ItemDefinition        # używane gdy type == ITEM
var upgrade_slot: EquipmentSlot.Type       # używane gdy type == UPGRADE
var upgrade_display_item: ItemDefinition   # do pokazania na karcie (ikona/nazwa itemu, który dostanie upgrade)
