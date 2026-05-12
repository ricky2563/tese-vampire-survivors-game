extends CanvasLayer

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	
	# Se ainda tiveres o painel antigo na cena, isto esconde-o para não atrapalhar
	if has_node("Panel"):
		get_node("Panel").hide()
	
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
	
	# Se não houver nada, pomos a cura
	if final_selection.size() == 0:
		final_selection.append("heal")
	
	final_selection.shuffle()
	
	# ==========================================
	# 4. CONSTRUIR O MENU DINAMICAMENTE
	# ==========================================
	build_dynamic_menu(final_selection)

func build_dynamic_menu(selection):
	# Fundo Escuro
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# ========================================================
	# O SEGREDO INFALÍVEL: CenterContainer
	# Ocupa o ecrã todo e empurra o que tem dentro para o meio
	# ========================================================
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Contentor Central (agora dentro do CenterContainer)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox) # Adicionado ao 'center' em vez de diretamente à cena
	
	# Título LEVEL UP!
	var title = Label.new()
	title.text = "LEVEL UP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.modulate = Color(1.0, 0.8, 0.0) # Dourado
	vbox.add_child(title)
	
	# Espaço extra abaixo do título
	var margin = Control.new()
	margin.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(margin)
	
	# Cria os botões baseados na tua seleção final
	for type in selection:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(320, 60)
		setup_button(btn, type)
		vbox.add_child(btn)
		
	# --- NOVO: BOTÃO DE CURA AUTOMÁTICA ---
	if selection.size() == 1 and selection[0] == "heal":
		var auto_btn = Button.new()
		auto_btn.custom_minimum_size = Vector2(320, 60)
		auto_btn.text = "Always Heal +5 (Automático)"
		auto_btn.modulate = Color(0.5, 1.0, 0.5) # Verde
		auto_btn.pressed.connect(func(): apply_upgrade("auto_heal"))
		vbox.add_child(auto_btn)

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
			draw_temporary_pickup_ring(player)
				
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
			
		"heal":
			player.health += 5.0
			player.health = min(player.health, player.max_health)
			if is_instance_valid(player.health_bar):
				player.health_bar.value = player.health
		
		"auto_heal":
			player.auto_heal_enabled = true
			player.health += 5.0
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
			var lados = ["Fires Front and Back", "Fires in 4 Directions"]
			var idx = min(gun.multi_direction_level, 1)
			button.text = "Bow: " + lados[idx]
		"pickup_range": button.text = "Pickup Range (Lv " + str(player.pickup_range_level + 1) + ")"
		"max_health": button.text = "Max Health: +10 (Lv " + str(player.max_health_level + 1) + ")"
		"armor": button.text = "Armor: Reduces damage by 2.5% (Lv " + str(player.armor_level + 1) + ")"
		"health_regen": button.text = "Regen: +0.1/s (Lv " + str(player.regen_level + 1) + ")"
		"move_speed": button.text = "Agility: +5 base speed (Lv " + str(player.move_speed_level + 1) + ")"
		"bonus_damage": button.text = "Damage: +5 base damage (Lv " + str(player.bonus_damage_level + 1) + ")"
		"luck": button.text = "Crit Chance: +10% (Lv " + str(player.luck_level + 1) + ")"
		"heal": button.text = "Heal 5 HP"

	button.pressed.connect(func(): apply_upgrade(type))
	

func draw_temporary_pickup_ring(player):
	var ring = Line2D.new()
	
	# O raio da gema (20 + 10 por nível)
	var gem_radius = 20.0 + (player.pickup_range_level * 10.0)
	
	# O tamanho aproximado da hitbox do teu jogador (Ajusta este número se precisares!)
	var player_body_offset = 15.0 
	
	# O raio final do anel visual é a soma dos dois
	var radius = gem_radius + player_body_offset
	
	# Matemática simples para desenhar um círculo com 64 pontas
	var circle_points = PackedVector2Array()
	for i in range(65):
		var angle = (i / 64.0) * TAU
		circle_points.append(Vector2(cos(angle), sin(angle)) * radius)
		
	ring.points = circle_points
	ring.width = 1.0
	ring.default_color = Color(0.0, 0.0, 0.0, 0.7) 
	
	player.add_child(ring)
	
	var tween = ring.create_tween()
	tween.tween_interval(4.5) 
	tween.tween_property(ring, "modulate:a", 0.0, 0.5) 
	tween.tween_callback(ring.queue_free)
