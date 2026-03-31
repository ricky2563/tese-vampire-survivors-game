extends CanvasLayer

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	var gun = player.get_node("gun")
	
	var possible_upgrades = []
	
	# só adiciona se ainda não tiver
	if "triple_shot" not in player.upgrades_owned:
		possible_upgrades.append("triple_shot")
		
	if gun.piercing_level < 3:
		possible_upgrades.append("piercing")
		
	if player.pickup_range_level < 5:
		possible_upgrades.append("pickup_range")
	
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

func apply_upgrade(type):
	var player = get_tree().get_first_node_in_group("player")
	var gun = player.get_node("gun")
	
	if type == "triple_shot":
		gun.triple_shot = true
		player.upgrades_owned.append("triple_shot")
	elif type == "piercing":
		if gun.piercing_level < 3:
			gun.piercing_level += 1
	elif type == "pickup_range":
		if player.pickup_range_level < 5:
			player.pickup_range_level += 1
			# atualizar gems existentes
			var gems = get_tree().get_nodes_in_group("gem")
			for gem in gems:
				gem.update_pickup_range()
	
	get_tree().paused = false
	queue_free()
	
func setup_button(button, type):
	var player = get_tree().get_first_node_in_group("player")
	var gun = player.get_node("gun")

	match type:
		"triple_shot":
			button.text = "Triple Shot"
		"piercing":
			button.text = "Piercing +" + str(gun.piercing_level + 1)
		"pickup_range":
			button.text = "Pickup Range +" + str(player.pickup_range_level + 1)
		"nothing":
			button.text = "Nada"
		"nothing2":
			button.text = "Nada 2"
	
	button.pressed.connect(func(): apply_upgrade(type))
