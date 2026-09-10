class_name CharacterDefinition extends Resource

@export var id: String
@export var character_name: String
@export var starting_weapon_id: String

@export_category("Starting Stats")
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
@export var base_hp: float = 100.0
@export var base_dmg: float = 10.0
@export var base_magic_dmg: float = 0.0
@export var base_attack_speed: float = 1.0
@export var base_crit_chance: float = 0.05
@export var base_crit_damage: float = 1.5
@export var base_armor: float = 0.0
@export var base_dodge: float = 0.0