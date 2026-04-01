extends CanvasLayer

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	
	var possible_upgrades = []
	
	# ========================
	# WEAPON UPGRADES
	# ========================
	for weapon_name in player.weapons.keys():
		var weapon = player.weapons[weapon_name]
		var upgrade = player.get_weapon_upgrade(weapon_name, weapon.level)
		
		if upgrade != "none":
			possible_upgrades.append(upgrade)
	
	# ========================
	# GLOBAL UPGRADES
	# ========================
	if player.pickup_range_level < 5:
		possible_upgrades.append("pickup_range")
	
	# preencher até 3 opções
	while possible_upgrades.size() < 3:
		possible_upgrades.append("nothing")
	
	possible_upgrades.shuffle()
	
	setup_button($Panel/Button, possible_upgrades[0])
	setup_button($Panel/Button2, possible_upgrades[1])
	setup_button($Panel/Button3, possible_upgrades[2])

func apply_upgrade(type):
	var player = get_tree().get_first_node_in_group("player")
	var gun = player.get_node("gun")
	
	match type:
		# ========================
		# BOW
		# ========================
		"bow_amount":
			gun.amount_level += 1
			player.weapons["bow"]["level"] += 1
		
		"bow_piercing":
			gun.piercing_level += 1
			player.weapons["bow"]["level"] += 1
		
		"bow_triple":
			gun.triple_shot = true
			player.weapons["bow"]["level"] += 1
		
		# ========================
		# GLOBAL
		# ========================
		"pickup_range":
			if player.pickup_range_level < 5:
				player.pickup_range_level += 1
				
				var gems = get_tree().get_nodes_in_group("gem")
				for gem in gems:
					gem.update_pickup_range()
	
	get_tree().paused = false
	queue_free()
	
func setup_button(button, type):
	var player = get_tree().get_first_node_in_group("player")
	var gun = player.get_node("gun")

	match type:
		"bow_amount":
			button.text = "Bow: Amount +" + str(gun.amount_level + 1)
		"bow_triple":
			button.text = "Bow: Triple Shot"
		"bow_piercing":
			button.text = "Bow: Piercing +" + str(gun.piercing_level + 1)
		"pickup_range":
			button.text = "Pickup Range +" + str(player.pickup_range_level + 1)
		"nothing":
			button.text = "Nada"
		"nothing2":
			button.text = "Nada 2"
	
	button.pressed.connect(func(): apply_upgrade(type))
