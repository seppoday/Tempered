class_name WaveDefinition extends Resource

@export var id: String
@export var duration: float = 60.0
@export var spawn_rate: float = 1.0 # Wrogów na sekundę
@export var hp_multiplier: float = 1.0 # Mnożnik zdrowia wrogów w tej fali
@export var enemies: Array[WaveEnemyEntry] = []