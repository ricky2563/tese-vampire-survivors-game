extends Node2D

# ========================
# MODOS DE SPAWN
# ========================
enum SpawnMode {
	CONTINUOUS,
	HORDE,
	WAVES_WITH_BOSS,
	LINE_HORDE
}

@export var spawn_mode: SpawnMode = SpawnMode.CONTINUOUS

# ========================
# SCENES
# ========================
# APAGÁMOS A ENEMY_SCENE DAQUI!
@export var boss_scene: PackedScene
@export var boss_scene_fire: PackedScene
@export var dda_panel_scene: PackedScene
var panel_instance: CanvasLayer

# ========================
# CONTROLO
# ========================
var max_enemies = 1000
var enemies_spawned = 0
var game_time = 0.0
var boss_fire_spawned = false
var barrier_right_spawned = false
var barrier_left_spawned = false
var is_game_over = false
var is_paused = false
var pause_canvas: CanvasLayer = null


func _ready():
	# 1. Congela o jogo logo ao abrir para esperar pela escolha do jogador
	get_tree().paused = true
	
	# 2. Limpa os dados da partida anterior
	EnemyManager.clear_all_enemies()
	
	# 3. Reset de variáveis de controlo do mundo
	enemies_spawned = 0
	game_time = 0.0
	boss_fire_spawned = false
	barrier_right_spawned = false
	barrier_left_spawned = false
	
	# 4. Chama o Menu de Seleção de DDA
	create_mode_selection_menu()


func create_mode_selection_menu():
	var canvas = CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS # Crucial para funcionar em pausa
	canvas.layer = 120 # Fica acima de tudo
	add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "SELECT TEST MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	# --- BOTÕES ---
	create_mode_button(vbox, "DYNAMIC (Normal DDA)", Color(0.8, 0.8, 0.8), canvas, DDAManager.TestMode.DYNAMIC)
	create_mode_button(vbox, "ALWAYS EASY (Min Limit)", Color(0.4, 1.0, 0.4), canvas, DDAManager.TestMode.ALWAYS_EASY)
	create_mode_button(vbox, "ALWAYS CHALLENGE (Max Limit)", Color(1.0, 0.4, 0.4), canvas, DDAManager.TestMode.ALWAYS_CHALLENGE)

# Função auxiliar para desenhar os botões
func create_mode_button(container, text, color, canvas, mode_enum):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(350, 60)
	btn.modulate = color
	container.add_child(btn)
	
	btn.pressed.connect(func():
		DDAManager.current_test_mode = mode_enum
		print("TEST MODE SELECTED: ", mode_enum)
		canvas.queue_free() # Destrói o menu
		start_the_game()    # Arranca o jogo
	)

func start_the_game():
	get_tree().paused = false # Descongela o jogo
	print("Jogo Iniciado! O tempo começou a contar.")

# ========================
# TIME CONTROL
# ========================

var cage_spawned = false

func _process(delta):
	if is_game_over: return
	game_time += delta
	
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	$CanvasLayer/GameTime.text = str(minutes) + ":" + str(seconds).pad_zeros(2)
	
	if game_time >= 60.0:
		EnemyManager.difficulty_multiplier = 1.0 + ((game_time - 60.0) / 10.0) * 0.15
	# EVENTO: A Gaiola de Caos (Aos 1 minuto)
	if game_time >= 60.0 and not cage_spawned:
		spawn_barrier_right()
		spawn_barrier_left()
		spawn_barrier_top()    # (Nova função abaixo)
		spawn_barrier_bottom() # (Nova função abaixo)
		cage_spawned = true
		print("EVENTO: Gaiola de Sobrevivência Ativada!")
		
	# EVENTO: O Fire Boss aparece 5 segundos depois da Gaiola fechar
	if game_time >= 65.0 and not boss_fire_spawned:
		spawn_boss_fire()
		boss_fire_spawned = true
		print("EVENTO: Fire Boss entrou na Gaiola!")
	
	if game_time >= 600.0:
		check_time_limit_endgame()

# ========================================================
# END CYCLE
# ========================================================
func check_time_limit_endgame():
	var bosses = get_tree().get_nodes_in_group("boss")
	var boss_is_alive = false
	
	for b in bosses:
		if is_instance_valid(b) and "current_health" in b and b.current_health > 0:
			boss_is_alive = true
			break
			
	if boss_is_alive:
		trigger_game_over(false, "Time Out!\nBoss is still alive")
	else:
		trigger_game_over(true, "You win!\nSurvived 10min and defeated the boss")

func trigger_game_over(is_win: bool, message: String):
	if is_game_over: return
	is_game_over = true
	get_tree().paused = true # Pára o jogo
	
	# 1. Exporta tudo!
	var player = get_player()
	if player and player.has_method("export_telemetry_to_csv"):
		player.export_telemetry_to_csv()
	if DDAManager.has_method("export_dda_telemetry"):
		DDAManager.export_dda_telemetry()
		
	# 2. Mostra o menu dinâmico
	create_restart_menu(is_win, message)

func create_restart_menu(is_win: bool, message: String):
	var canvas = CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS 
	canvas.layer = 100 
	add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = Color(0.2, 1.0, 0.2) if is_win else Color(1.0, 0.2, 0.2)
	vbox.add_child(label)
	
	var btn = Button.new()
	btn.text = "RESTART GAME"
	btn.custom_minimum_size = Vector2(250, 60)
	btn.pressed.connect(restart_game)
	vbox.add_child(btn)

func restart_game():
	get_tree().paused = false 
	EnemyManager.clear_all_enemies()

	get_tree().reload_current_scene()

# ========================
# MAIN SPAWNER (Game states)
# ========================
func _on_enemy_spawner_timeout():
	if EnemyManager.enemies.size() >= max_enemies:
		return
	
	if game_time < 30:
		early_game()
	elif game_time < 55:
		mid_game()
	else:
		boss_chaos_phase()
		
# ========================
# GAME STATES MUDADOS PARA CAOS
# ========================
func early_game():
	# Começa calmo
	for i in range(5):
		spawn_enemy_around_player(700)
		
func mid_game():
	# Já manda pacotes de 15 inimigos e hordas frequentes
	for i in range(15):
		spawn_enemy_around_player(800)
	
	if randi() % 4 == 0:
		spawn_horde()

func late_game():
	# 1. Nasce "carne para canhão" (15 esqueletos rápidos)
	for i in range(15):
		spawn_enemy_around_player(600, false)
		
	# 2. Nascem TANKS (Paredes de betão móveis para bloquear os tiros)
	for i in range(8):
		spawn_enemy_around_player(650, true) 
		
	# 3. Pequeno evento de Horda frequente para obfuscar a visão
	if randi() % 3 == 0:
		spawn_horde()
		
func boss_chaos_phase():
	# CAOS ABSOLUTO: O PC aguenta, vamos testar o limite visual!
	
	# 1. Reposição Extrema (Nasce lixo mais rápido do que o arco mata)
	for i in range(45): # Subiu de 28 para 80 esqueletos por tick!
		spawn_enemy_around_player(650, false)
		
	for i in range(6): # Subiu de 6 para 15 Tanks
		spawn_enemy_around_player(700, true) 
		
	# 2. Roleta Russa de Eventos (Eventos Múltiplos)
	var evento_chance = randi() % 100
	
	if evento_chance < 35:
		# 35% chance: Horda Dupla (Enche o ecrã de forma circular)
		spawn_horde()
		spawn_horde()
		
	elif evento_chance < 65:
		# 30% chance: Duas Linhas (Cortam o mapa)
		spawn_line_horde()
		spawn_line_horde()
		
	elif evento_chance < 85:
		# 20% chance: Parede Simples (Para obrigar o jogador a desviar-se)
		var wall_dir = randi() % 4
		if wall_dir == 0: spawn_barrier_right()
		elif wall_dir == 1: spawn_barrier_left()
		elif wall_dir == 2: spawn_barrier_top()
		else: spawn_barrier_bottom()

# ========================
# SCENARIO 1 — CONTÍNUO
# ========================
func spawn_continuous():
	for i in range(5):
		spawn_enemy_around_player(700)
		enemies_spawned += 5
	
	# Boss aparece de X em X inimigos
	if enemies_spawned % 150 == 0:
		spawn_boss()

# ========================
# SCENARIO 2 — HORDA
# ========================
func spawn_horde():
	var player = get_player()
	if not player:
		return
	
	var base_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var base_position = player.global_position + (base_direction * 500)
	
	for i in range(20):
		var offset = Vector2(randf_range(-30,30), randf_range(-30,30))
		spawn_enemy_at(base_position + offset)

# ========================
# SCENARIO 3 — WAVES + BOSS
# ========================
func spawn_wave_with_boss():
	var player = get_player()
	if not player:
		return
	
	var base_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var base_position = player.global_position + (base_direction * 600)
	
	# Spawn inimigos em grupo
	for i in range(20):
		var offset = Vector2(randf_range(-40,40), randf_range(-40,40))
		spawn_enemy_at(base_position + offset)
	
	# 50% chance de boss no meio
	if randf() < 0.5:
		var boss = boss_scene.instantiate()
		boss.global_position = base_position
		add_child(boss)
		
# ========================
# SCENARIO 4 — Horda Linha
# ========================
func spawn_line_horde():
	var player = get_player()
	if not player:
		return
	
	# Base vertical aleatória em torno do jogador
	var base_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var base_position = player.global_position + (base_direction * 500)
	
	var group_size = 15      # Aumentámos o tamanho da linha
	var vertical_spacing = 40
	var horizontal_spread = 15
	
	for i in range(group_size):
		var offset = Vector2(randf_range(-horizontal_spread, horizontal_spread),
							 i * vertical_spacing - (group_size*vertical_spacing/2))
		
		# Spawna apenas inimigos! (Meti "true" para serem Tanks e formarem uma linha dura de quebrar)
		spawn_enemy_at(base_position + offset, true)

# ========================
# SCENARIO 5 — BARREIRA
# ========================
func spawn_barrier_right():
	var player = get_player()
	if not player:
		return
		
	var distance_to_right = 800 # Distância do player à barreira (ajusta para nascerem fora do ecrã)
	var columns = 2             # A tua "densidade" (espessura da parede, 4 colunas)
	var rows = 25               # Altura da parede (quantidade de inimigos de cima a baixo)
	var spacing = 40            # Espaço em píxeis entre cada inimigo
	
	# O centro da barreira (à direita do player)
	var center_pos = player.global_position + Vector2(distance_to_right, 0)
	
	# Para a barreira ficar centrada com o player, calculamos onde fica o "topo" dela
	var start_y = center_pos.y - ((rows * spacing) / 2.0)
	
	# Loop duplo para criar a espessura (colunas) e a altura (linhas)
	for col in range(columns):
		for row in range(rows):
			var spawn_pos = Vector2(
				center_pos.x + (col * spacing), 
				start_y + (row * spacing)
			)
			
			spawn_pos += Vector2(randf_range(-5, 5), randf_range(-5, 5))
			
			spawn_enemy_at(spawn_pos, true)
		await get_tree().process_frame

func spawn_barrier_left():
	var player = get_player()
	if not player:
		return
		
	var distance_to_left = 800 
	var columns = 2            
	var rows = 25              
	var spacing = 40           
	
	# O centro da barreira (à ESQUERDA do player, por isso usamos o sinal de menos -)
	var center_pos = player.global_position + Vector2(-distance_to_left, 0)
	
	var start_y = center_pos.y - ((rows * spacing) / 2.0)
	
	for col in range(columns):
		for row in range(rows):
			# Subtraímos o col * spacing para a espessura crescer para a esquerda
			var spawn_pos = Vector2(
				center_pos.x - (col * spacing), 
				start_y + (row * spacing)
			)
			spawn_pos += Vector2(randf_range(-5, 5), randf_range(-5, 5))
			spawn_enemy_at(spawn_pos, true)
		await get_tree().process_frame

func spawn_barrier_top():
	var player = get_player()
	if not player: return
		
	var distance_to_top = 500 
	var columns = 25  # Agora a largura é grande (25 inimigos de lado a lado)
	var rows = 2      # E a espessura é 3
	var spacing = 40
	
	var center_pos = player.global_position + Vector2(0, -distance_to_top)
	var start_x = center_pos.x - ((columns * spacing) / 2.0)
	
	for col in range(columns):
		for row in range(rows):
			var spawn_pos = Vector2(start_x + (col * spacing), center_pos.y - (row * spacing))
			spawn_pos += Vector2(randf_range(-5, 5), randf_range(-5, 5))
			spawn_enemy_at(spawn_pos, true)
		await get_tree().process_frame

func spawn_barrier_bottom():
	var player = get_player()
	if not player: return
		
	var distance_to_bottom = 500 
	var columns = 25  
	var rows = 2      
	var spacing = 40
	
	var center_pos = player.global_position + Vector2(0, distance_to_bottom)
	var start_x = center_pos.x - ((columns * spacing) / 2.0)
	
	for col in range(columns):
		for row in range(rows):
			var spawn_pos = Vector2(start_x + (col * spacing), center_pos.y + (row * spacing))
			spawn_pos += Vector2(randf_range(-5, 5), randf_range(-5, 5))
			spawn_enemy_at(spawn_pos, true)
		await get_tree().process_frame

# ========================
# SPAWN BOSS (GENÉRICO)
# ========================
func spawn_boss():
	var player = get_player()
	if not player:
		return
	
	if boss_scene == null:
		return
		
	var boss = boss_scene.instantiate()
	
	var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var spawn_position = player.global_position + (random_direction * 700)
	
	boss.global_position = spawn_position
	add_child(boss)

# ========================
# SPAWN BOSS (Fire)
# ========================
func spawn_boss_fire():
	var player = get_player()
	if not player:
		return
	
	if boss_scene_fire == null:
		print("Boss fire não atribuído!")
		return
	
	var boss = boss_scene_fire.instantiate()
	
	# spawn perto do player (para veres bem)
	var offset = Vector2(150, 200)
	boss.global_position = player.global_position + offset
	
	add_child(boss)

# ========================
# HELPERS
# ========================
func get_player():
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p):
		return p
	return null

func spawn_enemy_around_player(distance, is_tank = false):
	var player = get_player()
	if not player: return
	
	var dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var pos = player.global_position + (dir * distance)
	
	spawn_enemy_at(pos, is_tank)

func spawn_enemy_at(pos, is_tank = false):
	EnemyManager.spawn_enemy(pos, false, is_tank)

# ========================
# DEBUG CONTROLS (OPCIONAL)
# ========================
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if not is_game_over and not is_paused:
					print("A tentar pausar...")
					get_viewport().set_input_as_handled() # <--- O SEGREDO ESTÁ AQUI
					toggle_pause()
			KEY_1:
				spawn_mode = SpawnMode.CONTINUOUS
				print("Modo: CONTINUOUS")
			KEY_2:
				spawn_mode = SpawnMode.HORDE
				print("Modo: HORDE")
			KEY_3:
				spawn_mode = SpawnMode.WAVES_WITH_BOSS
				print("Modo: WAVES WITH BOSS")
			KEY_4:
				spawn_mode = SpawnMode.LINE_HORDE
				print("Modo: HORDE LINE")
			KEY_B:
				spawn_barrier_right()
				print("Barreira da Direita Spawnada!")
			KEY_N:
				spawn_boss_fire()
				print("Boss FIRE spawnado")
			KEY_L:
				clear_enemies()
			KEY_TAB:
				toggle_panel()
		update_label()

func update_label():
	$CanvasLayer/Label.text = ["CONTINUOUS", "HORDE", "WAVES", "LINE"][spawn_mode]
	
func clear_enemies():
	EnemyManager.clear_all_enemies()
		
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		boss.queue_free()
	
	enemies_spawned = 0
	print("Tela limpa!")
	
func toggle_panel():
	if panel_instance == null:
		# Verifica se tu não te esqueceste de arrastar a cena no Inspector!
		if dda_panel_scene != null:
			panel_instance = dda_panel_scene.instantiate()
			add_child(panel_instance)
			print("Painel DDA Aberto pela 1ª vez.")
		else:
			print("ERRO: Esqueceste-te de arrastar o ficheiro painel_dda.tscn para a variável no World!")
	else:
		# Se já existe, liga e desliga a visibilidade
		panel_instance.visible = !panel_instance.visible
		
func toggle_pause():
	if is_game_over: return

	is_paused = !is_paused
	get_tree().paused = is_paused

	if is_paused:
		print("MENU: Pausa ativada! Congelou.")
		if pause_canvas == null:
			create_pause_menu()
		pause_canvas.visible = true
	else:
		print("MENU: Jogo retomado.")
		if pause_canvas != null:
			pause_canvas.visible = false

func create_pause_menu():
	pause_canvas = CanvasLayer.new()
	# PROCESS_MODE_ALWAYS garante que este menu continua a funcionar enquanto o jogo dorme!
	pause_canvas.process_mode = Node.PROCESS_MODE_ALWAYS 
	pause_canvas.layer = 105 # Fica acima do HUD normal
	add_child(pause_canvas)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8) # Fundo escuro semi-transparente
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_canvas.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_canvas.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	# --- BOTÃO CONTINUAR ---
	var btn_continue = Button.new()
	btn_continue.text = "Continuar (ESC)"
	btn_continue.custom_minimum_size = Vector2(250, 60)
	btn_continue.pressed.connect(toggle_pause)
	
	# O Truque: O Botão ouve a tecla ESC sozinho mesmo com o jogo pausado!
	var esc_shortcut = Shortcut.new()
	var esc_event = InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_shortcut.events = [esc_event]
	btn_continue.shortcut = esc_shortcut
	
	vbox.add_child(btn_continue)

	# --- BOTÃO RESET ---
	var btn_reset = Button.new()
	btn_reset.text = "Reiniciar (R)"
	btn_reset.custom_minimum_size = Vector2(250, 60)
	btn_reset.pressed.connect(restart_game)
	
	# O Truque: O Botão ouve a tecla R sozinho mesmo com o jogo pausado!
	var r_shortcut = Shortcut.new()
	var r_event = InputEventKey.new()
	r_event.keycode = KEY_R
	r_shortcut.events = [r_event]
	btn_reset.shortcut = r_shortcut
	
	vbox.add_child(btn_reset)
