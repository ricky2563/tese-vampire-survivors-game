extends CharacterBody2D

@export var speed = 80.0
@export var health = 30.0
@export var gem_scene: PackedScene

var player = null 
var player_in_range = null 

@onready var damage_timer = $Timer

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if player:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		move_and_slide()

func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = body 
		
		attack_player()
		
		damage_timer.start()

# 2. Jogador fugiu da área
func _on_hitbox_body_exited(body):
	if body == player_in_range:
		player_in_range = null # Já não há ninguém para bater
		damage_timer.stop() # Para o relógio

# 3. O Timer chegou ao fim (0.5s passaram)
func _on_timer_timeout():
	if player_in_range:
		attack_player()

# Função auxiliar para não repetir código
func attack_player():
	if player_in_range:
		player_in_range.take_damage(2)

func take_damage(amount):
	health -= amount
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	if health <= 0:
		die()

func die():
	if gem_scene:
		var new_gem = gem_scene.instantiate()
		new_gem.global_position = global_position
		get_tree().root.call_deferred("add_child", new_gem)
	
	queue_free()
