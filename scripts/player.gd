extends CharacterBody2D

@export var speed = 150.0
@export var health = 100.0

@onready var health_bar = $HealthBar
@onready var level_label = $HUD/LevelLabel

# --- NOVO: Referência para o AnimatedSprite2D ---
@onready var anim = $AnimatedSprite2D 

@export var experience = 0
@export var experience_required = 20
@export var level = 1

@onready var experience_bar = $HUD/ExperienceBar

# --- NOVO: Variável para lembrar para onde estamos a olhar ---
var is_facing_right = true 
var upgrades_owned = []
var pickup_range_level = 0
var is_dead = false

var weapons = {
	"bow": {
		"level": 0
	}
}

func _ready():
	health_bar.max_value = health
	health_bar.value = health
	
	experience_bar.max_value = experience_required
	experience_bar.value = experience
	
	level_label.text = "Lvl. " + str(level)
	
	# Começa com a animação parado
	anim.play("idle_right")

func _physics_process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction:
		velocity = direction * speed
		
		# --- NOVO: Lógica de Direção ---
		# Se mover para a direita, atualiza a memória para true
		if direction.x > 0:
			is_facing_right = true
		# Se mover para a esquerda, atualiza a memória para false
		elif direction.x < 0:
			is_facing_right = false
			
		# Toca a animação de correr com o sufixo correto (_left ou _right)
		if is_facing_right:
			anim.play("move_right")
		else:
			anim.play("move_left")
			
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		
		# --- NOVO: Lógica de Parar ---
		# Quando para, usa a memória (is_facing_right) para saber que idle usar
		if is_facing_right:
			anim.play("idle_right")
		else:
			anim.play("idle_left")
			
	move_and_slide()

func take_damage(amount):
	# Se o jogador já estiver morto, sai da função imediatamente e ignora o ataque!
	if is_dead:
		return
	health -= amount
	health_bar.value = health 
	print("Auch! Vida restante: ", health)
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
				1: return "bow_amount"
				2: return "bow_piercing"
				3: return "bow_amount"
				4: return "bow_triple"
				5: return "bow_piercing"
				6: return "bow_piercing"
	
	return "none"
