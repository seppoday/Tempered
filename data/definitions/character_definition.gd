class_name CharacterDefinition extends Resource

@export var id: String
@export var character_name: String
@export var starting_weapon_id: String

@export_category("Starting Attributes")
@export var starting_str: int = 10
@export var starting_dex: int = 10
@export var starting_int: int = 10
@export var starting_con: int = 10

@export_category("Growth Rates")
@export var str_growth: float = 1.0
@export var dex_growth: float = 1.0
@export var int_growth: float = 1.0
@export var con_growth: float = 1.0

@export_category("Base Stats")
@export var base_dmg: float = 10.0
@export var base_magic: float = 0.0
@export var base_def: float = 0.0
@export var base_vit: float = 100.0
@export var base_speed: float = 0.0
@export var base_luck: float = 0.0
@export var base_status: float = 0.0
@export var base_crit: float = 0.0
