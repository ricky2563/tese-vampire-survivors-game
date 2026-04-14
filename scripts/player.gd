extends CharacterBody2D

@export var speed = 150.0
@export var max_health = 100.0

@onready var health_bar = $HealthBar
@onready var level_label = $HUD/LevelLabel
@onready var umbrella_icon = $HUD/WeaponsContainer/IconUmbrella

# --- NOVO: Referência para o AnimatedSprite2D ---
@onready var anim = $AnimatedSprite2D

@export var experience = 0
@export var experience_required = 20
@export var level = 1
@export var umbrella_scene: PackedScene

@onready var experience_bar = $HUD/ExperienceBar

# --- Variáveis de Atributos ---
var health = 100.0
var armor = 0.0
var health_regen = 0.0

var upgrades_owned = []
var pickup_range_level = 0
var max_health_level = 0
var armor_level = 0
var regen_level = 0
var move_speed_level = 0

var is_facing_right = true 
var is_dead = false
var can_umbrella = true
var umbrella_cooldown = 5.0
var is_shield_active = false
var flicker_tween: Tween

var weapons = {
	"bow": {
		"level": 0
	}
}

func _input(event):
	# Se o jogador estiver morto ou o menu de upgrade estiver aberto, não faz nada
	if is_dead or get_tree().paused:
		return
		
	# Verifica se a tecla E foi pressionada e se o cooldown terminou
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if can_umbrella:
			deploy_umbrella()
		else:
			print("Guarda-chuva em cooldown!")

func deploy_umbrella():
	if umbrella_scene == null:
		print("Erro: Cena do Guarda-Chuva não atribuída no Inspector!")
		return
		
	# --- FASE 1: USOU A HABILIDADE ---
	can_umbrella = false
	is_shield_active = true
	
	# Instancia e adiciona o escudo
	var shield = umbrella_scene.instantiate()
	add_child(shield)
	
	print("Guarda-chuva ATIVADO!")
	
	# --- FASE 2: ATUALIZAR HUD (INÍCIO COOLDOWN) ---
	# 1. Faz o ícone ficar semi-transparente imediatamente
	umbrella_icon.modulate.a = 0.2
	
	# 2. Cria e inicia o Tween para piscar o Alpha (de 0.2 a 0.8 repetidamente)
	flicker_tween = create_tween()
	
	# Define o loop infinito para o piscar
	flicker_tween.set_loops() 
	
	# Transição de 0.2 a 0.8 durante 0.3 segundos
	flicker_tween.tween_property(umbrella_icon, "modulate:a", 0.8, 0.3) 
	
	# Transição de volta de 0.8 a 0.2 durante 0.3 segundos
	flicker_tween.tween_property(umbrella_icon, "modulate:a", 0.2, 0.3)
	
	print("HUD: Ícone começou a piscar (cooldown)")

	# --- FASE 3: DURAÇÃO DO ESCUDO ---
	# Espera os 2 segundos de duração do escudo ativo
	await get_tree().create_timer(2.0, false).timeout
	is_shield_active = false
	
	# --- FASE 4: RESTO DO COOLDOWN (AJUSTADO) ---
	# Espera o resto do tempo do cooldown total
	# (umbrella_cooldown - 2.0s que já passaram)
	await get_tree().create_timer(umbrella_cooldown - 2.0, false).timeout
	
	# --- FASE 5: PRONTO A USAR (FIM COOLDOWN) ---
	can_umbrella = true
	
	# 1. Cancela a animação de piscar (o Tween para)
	if is_instance_valid(flicker_tween):
		flicker_tween.kill() 
		
	# 2. Volta o ícone para opacidade total (1.0) para avisar que está pronto
	umbrella_icon.modulate.a = 1.0
	
	print("Guarda-chuva pronto a usar! HUD atualizada.")

func _ready():
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	
	experience_bar.max_value = experience_required
	experience_bar.value = experience
	
	level_label.text = "Lvl. " + str(level)
	
	# Começa com a animação parado
	anim.play("idle_right")

func _physics_process(delta):
	# --- ALTERAÇÃO AQUI: Lógica da Regeneração de Vida ---
	if health < max_health and health_regen > 0:
		health += health_regen * delta
		health = min(health, max_health)
		health_bar.value = health

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction:
		velocity = direction * speed
		
		# --- Lógica de Direção ---
		if direction.x > 0:
			is_facing_right = true
		elif direction.x < 0:
			is_facing_right = false
			
		if is_facing_right:
			anim.play("move_right")
		else:
			anim.play("move_left")
			
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		
		# --- Lógica de Parar ---
		if is_facing_right:
			anim.play("idle_right")
		else:
			anim.play("idle_left")
			
	move_and_slide()

func take_damage(amount):
	# Se o jogador já estiver morto, sai da função imediatamente e ignora o ataque!
	if is_dead:
		return
		
	var damage_reduction = armor * 0.10 # Corta 10% por nível
	var actual_damage = amount * (1.0 - damage_reduction)
	actual_damage = max(0.0, actual_damage)
	
	health -= actual_damage
	health_bar.value = health 
	
	if health <= 0:
		die()

func die():
	# 1. Marca como morto para que os outros inimigos parem de dar dano neste frame
	is_dead = true 
	print("Morreu!")
	get_tree().call_deferred("reload_current_scene")
	
func gain_experience(amount):
	experience += amount
	experience_bar.value = experience
	
	if experience >= experience_required:
		level_up()

func level_up():
	level += 1
	experience = 0 
	experience_required += 15 
	
	experience_bar.max_value = experience_required
	experience_bar.value = experience
	level_label.text = "Lvl. " + str(level)
	
	print("LEVEL UP! Nível Atual: ", level)
	
	show_upgrade_menu()
	
func show_upgrade_menu():
	get_tree().paused = true
	
	var menu = preload("res://scenes/upgrade_menu.tscn").instantiate()
	get_tree().current_scene.add_child(menu)
	
func get_weapon_upgrade(weapon_name, level):
	match weapon_name:
		"bow":
			match level:
				0: return "bow_amount"
				1: return "bow_piercing"
				2: return "bow_multishot" 
				3: return "bow_amount"
				4: return "bow_triple"   
				5: return "bow_piercing"
				6: return "bow_amount"
				7: return "bow_multishot" 
				8: return "bow_piercing"
								
	return "none"
