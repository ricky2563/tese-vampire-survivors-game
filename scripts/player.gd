extends CharacterBody2D

@export var speed = 150.0
@export var health = 100.0

@onready var health_bar = $HealthBar
@onready var level_label = $HUD/LevelLabel

@export var experience = 0
@export var experience_required = 100
@export var level = 1

@onready var experience_bar = $HUD/ExperienceBar

func _ready():
	# Garante que a barra começa cheia e com o valor máximo correto
	health_bar.max_value = health
	health_bar.value = health
	
	experience_bar.max_value = experience_required
	experience_bar.value = experience
	
	level_label.text = "Lvl. " + str(level)

func _physics_process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction:
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
	move_and_slide()

func take_damage(amount):
	health -= amount
	
	health_bar.value = health 
	
	print("Auch! Vida restante: ", health)
	
	if health <= 0:
		die()

func die():
	print("Morreu!")
	get_tree().reload_current_scene()
	
func gain_experience(amount):
	experience += amount
	experience_bar.value = experience
	
	if experience >= experience_required:
		level_up()

func level_up():
	level += 1
	experience = 0 # Reseta a barra (ou guarda o excedente: experience -= experience_required)
	experience_required += 50 # O próximo nível é mais difícil
	
	experience_bar.max_value = experience_required
	experience_bar.value = experience
	level_label.text = "Lvl. " + str(level)
	
	print("LEVEL UP! Nível Atual: ", level)
