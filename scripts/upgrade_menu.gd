extends CanvasLayer

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	
	var possible_upgrades = []
	
	# só adiciona se ainda não tiver
	if "triple_shot" not in player.upgrades_owned:
		possible_upgrades.append("triple_shot")
	
	# adiciona opções fake para preencher
	possible_upgrades.append("nothing")
	possible_upgrades.append("nothing2")
	possible_upgrades.append("nothing3")
	
	# baralhar opções
	possible_upgrades.shuffle()
	
	# aplicar aos botões
	setup_button($Panel/Button, possible_upgrades[0])
	setup_button($Panel/Button2, possible_upgrades[1])
	setup_button($Panel/Button3, possible_upgrades[2])

func _on_Button_pressed():
	apply_upgrade("triple_shot")

func apply_upgrade(type):
	var player = get_tree().get_first_node_in_group("player")
	
	if type == "triple_shot":
		var gun = player.get_node("gun")
		gun.triple_shot = true
		player.upgrades_owned.append("triple_shot")
	
	get_tree().paused = false
	queue_free()


func _on_button_pressed():
	apply_upgrade("triple_shot")
	
func setup_button(button, type):
	match type:
		"triple_shot":
			button.text = "Triple Shot"
		"nothing":
			button.text = "Nada"
		"nothing2":
			button.text = "Nada 2"
	
	button.pressed.connect(func(): apply_upgrade(type))
