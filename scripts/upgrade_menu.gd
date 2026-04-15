extends CanvasLayer

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	
	var bow_upgrade = "none"
	var other_upgrades = []
	
	# ==========================================
	# 1. IDENTIFICAR UPGRADE DO ARCO (PRIORIDADE)
	# ==========================================
	if player.weapons.has("bow"):
		bow_upgrade = player.get_weapon_upgrade("bow", player.weapons["bow"]["level"])
	
	# ==========================================
	# 2. COLECIONAR TODOS OS OUTROS UPGRADES
	# ==========================================
	for weapon_name in player.weapons.keys():
		if weapon_name == "bow": continue 
		
		var weapon = player.weapons[weapon_name]
		var up = player.get_weapon_upgrade(weapon_name, weapon.level)
		if up != "none":
			other_upgrades.append(up)
	
	# Passivas
	if player.pickup_range_level < 5: other_upgrades.append("pickup_range")
	if player.max_health_level < 5: other_upgrades.append("max_health")
	if player.armor_level < 5: other_upgrades.append("armor")
	if player.regen_level < 5: other_upgrades.append("health_regen")
	if player.move_speed_level < 5: other_upgrades.append("move_speed")
	if player.bonus_damage_level < 5: other_upgrades.append("bonus_damage")
	if player.luck_level < 5: other_upgrades.append("luck")
	
	# ==========================================
	# 3. MONTAR A SELEÇÃO FINAL
	# ==========================================
	var final_selection = []
	
	if bow_upgrade != "none":
		final_selection.append(bow_upgrade)
	
	other_upgrades.shuffle()
	
	for upgrade in other_upgrades:
		if final_selection.size() < 3:
			final_selection.append(upgrade)
	
	# --- ALTERAÇÃO AQUI: Em vez de "nothing", pomos "heal" ---
	if final_selection.size() == 0:
		final_selection.append("heal")
	
	final_selection.shuffle()
	
	# ==========================================
	# 4. LÓGICA DE MOSTRAR E ESCONDER BOTÕES
	# ==========================================
	var btn1 = $Panel/Button
	var btn2 = $Panel/Button2
	var btn3 = $Panel/Button3
	
	# Esconde todos por defeito
	btn1.hide()
	btn2.hide()
	btn3.hide()
	
	# Mostra e configura apenas os necessários
	if final_selection.size() == 3:
		btn1.show()
		setup_button(btn1, final_selection[0])
		btn2.show()
		setup_button(btn2, final_selection[1])
		btn3.show()
		setup_button(btn3, final_selection[2])
		
	elif final_selection.size() == 2:
		btn1.show()
		setup_button(btn1, final_selection[0])
		btn2.show()
		setup_button(btn2, final_selection[1])
		
	elif final_selection.size() == 1:
		btn1.show()
		setup_button(btn1, final_selection[0])

func apply_upgrade(type):
	var player = get_tree().get_first_node_in_group("player")
	var gun = player.get_node("gun")
	
	match type:
		"bow_amount":
			gun.amount_level += 1
			player.weapons["bow"]["level"] += 1
		"bow_piercing":
			gun.piercing_level += 1
			player.weapons["bow"]["level"] += 1
		"bow_triple":
			gun.triple_shot = true
			player.weapons["bow"]["level"] += 1
		"bow_multishot":
			gun.multi_direction_level += 1
			player.weapons["bow"]["level"] += 1
			
		"pickup_range":
			player.pickup_range_level += 1
			var gems = get_tree().get_nodes_in_group("gem")
			for gem in gems: gem.update_pickup_range()
				
		"max_health":
			player.max_health_level += 1
			player.max_health += 10.0
			if is_instance_valid(player.health_bar):
				player.health_bar.max_value = player.max_health
				player.health_bar.value = player.health
			
		"armor":
			player.armor_level += 1
			player.armor += 1.0
			
		"health_regen":
			player.regen_level += 1
			player.health_regen += 0.1
			
		"move_speed":
			player.move_speed_level += 1
			player.speed += 5.0
			
		"bonus_damage":
			player.bonus_damage_level += 1
			player.extra_damage += 5
			
		"luck":
			player.luck_level += 1
			player.crit_chance += 0.10
			
		# --- ALTERAÇÃO AQUI: Lógica de Cura ---
		"heal":
			player.health += 5.0
			# Garante que a cura não ultrapassa a vida máxima
			player.health = min(player.health, player.max_health)
			if is_instance_valid(player.health_bar):
				player.health_bar.value = player.health
	
	get_tree().paused = false
	queue_free()

func setup_button(button, type):
	var player = get_tree().get_first_node_in_group("player")
	var gun = player.get_node("gun")

	match type:
		"bow_amount": button.text = "Bow: Amount +" + str(gun.amount_level + 1)
		"bow_triple": button.text = "Bow: Triple Shot"
		"bow_piercing": button.text = "Bow: Piercing +" + str(gun.piercing_level + 1)
		"bow_multishot":
			var lados = ["Frente/Trás", "4 Lados"]
			var idx = min(gun.multi_direction_level, 1)
			button.text = "Bow: " + lados[idx]
		"pickup_range": button.text = "Pickup Range (Lv " + str(player.pickup_range_level + 1) + ")"
		"max_health": button.text = "Max Health +10 (Lv " + str(player.max_health_level + 1) + ")"
		"armor": button.text = "Armor +1 (Lv " + str(player.armor_level + 1) + ")"
		"health_regen": button.text = "Regen +0.1/s (Lv " + str(player.regen_level + 1) + ")"
		"move_speed": button.text = "Speed +5 (Lv " + str(player.move_speed_level + 1) + ")"
		"bonus_damage": button.text = "Damage +5 (Lv " + str(player.bonus_damage_level + 1) + ")"
		"luck": button.text = "Crit Chance +10% (Lv " + str(player.luck_level + 1) + ")"
		"heal": button.text = "Heal 5 HP" # O novo botão de recompensa contínua
	
	# Os botões agora estão sempre ativos (removi o disabled)
	button.disabled = false
	
	if button.pressed.is_connected(apply_upgrade):
		button.pressed.disconnect(apply_upgrade)
	button.pressed.connect(func(): apply_upgrade(type))
