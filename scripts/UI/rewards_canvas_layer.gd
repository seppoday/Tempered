extends CanvasLayer

@onready var rewards_container: BoxContainer = %RewardsContainer
# Opcjonalnie: @onready var gold_label: Label = %GoldLabel

var _pending_loot: Array[LootEntry] = []

func _ready() -> void:
	await get_tree().physics_frame
	GameManager.state_changed.connect(_on_state_changed)
	
	# Podłączamy się do sygnałów managera
	RewardManager.rewards_generated.connect(_on_rewards_generated)
	RewardManager.reward_claimed.connect(_on_reward_claimed)

	for card in rewards_container.get_children():
		if card.has_signal("reward_selected") and not card.reward_selected.is_connected(_on_card_selected):
			card.reward_selected.connect(_on_card_selected)

	visible = GameManager.current_state == GameManager.State.ENEMY_REWARDS


# Wywoływane przez RewardManager, gdy trzeba pokazać nagrody
func _on_rewards_generated(gold_amount: int, loot_entries: Array[LootEntry]) -> void:
	_pending_loot = loot_entries
	
	# Tutaj możesz zaktualizować labelkę ze złotem, jeśli masz taką w UI
	# if gold_label: gold_label.text = "+%d Gold" % gold_amount
	
	_populate_reward_cards()

func _populate_reward_cards() -> void:
	var cards := rewards_container.get_children()

	for i in range(cards.size()):
		var card = cards[i]

		if card.has_method("reset_state"):
			card.reset_state()

		if i < _pending_loot.size():
			var loot: LootEntry = _pending_loot[i]
			if card.has_method("setup"):
				card.setup(loot.entry)
			else:
				Log.print("[WARNING] Karta nie posiada metody setup()!")
			card.visible = true
			card.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			card.visible = false
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_card_selected(card) -> void:
	var cards := rewards_container.get_children()
	var card_index := cards.find(card)

	if card_index == -1 or card_index >= _pending_loot.size():
		return

	# Od razu blokujemy UI, żeby gracz nie kliknął podwójnie
	for other_card in cards:
		other_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if other_card.has_method("lock"):
			other_card.lock()

	var loot: LootEntry = _pending_loot[card_index]
	
	# Przekazujemy odpowiedzialność do RewardManagera
	RewardManager.claim_item(loot)


func _on_reward_claimed() -> void:
	# Opcjonalnie: dodatkowe animacje po odebraniu nagrody
	pass


func _on_state_changed(new_state: GameManager.State) -> void:
	var is_active := new_state == GameManager.State.ENEMY_REWARDS

	if is_active:
		visible = true

		for child in rewards_container.get_children():
			child.offset_transform_enabled = true
			child.offset_transform_position = Vector2(0, -200)
			child.modulate.a = 0.0
			child.mouse_filter = Control.MOUSE_FILTER_STOP

		var delay := 0.0
		for child in rewards_container.get_children():
			UIAnim.slide_and_fade_in(child, Vector2.DOWN, 200.0, 0.5, true, delay)
			delay += 0.1
	else:
		if not visible:
			return

		var delay := 0.0
		var last_tween: Tween = null

		for child in rewards_container.get_children():
			last_tween = UIAnim.slide_and_fade_out(child, Vector2.DOWN, 200.0, 0.3, true, delay)
			delay += 0.08

		if last_tween:
			await last_tween.finished

		visible = false
