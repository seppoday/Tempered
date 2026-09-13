extends BoxContainer

@onready var confirm_button: Button = %ConfirmButton

var cards: Array[PanelContainer] = []
var selected_cards: Array[PanelContainer] = []

const CARD_SCENE = preload("uid://dab7n6msl1buh")

signal picks_confirmed(picks: Array[Dictionary])

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)

func _on_confirm_pressed() -> void:
	if selected_cards.is_empty():
		return

	var picks: Array[Dictionary] = []
	for card in selected_cards:
		picks.append(card.result_data)

	picks_confirmed.emit(picks)
	print(picks)

func display_results(results: Array[Dictionary]) -> void:
	for existing in get_children():
		existing.queue_free()
	cards.clear()
	selected_cards.clear()

	for result in results:
		var card := CARD_SCENE.instantiate()
		add_child(card)
		card.setup(result)
		card.toggled.connect(_on_card_toggled)
		cards.append(card)

func _on_card_toggled(card: PanelContainer, wants_selected: bool) -> void:
	if wants_selected:
		if selected_cards.size() >= PlayerData.picks_per_cycle:
			return  # limit osiągnięty, ignoruj żądanie
		selected_cards.append(card)
		card.set_selected(true)
	else:
		selected_cards.erase(card)
		card.set_selected(false)
	
	if selected_cards.is_empty():
		confirm_button.disabled = true
	else:
		confirm_button.disabled = false
