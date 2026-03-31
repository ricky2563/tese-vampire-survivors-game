extends CharacterBody2D

@export var speed = 80.0
@export var health = 30.0
@export var gem_scene: PackedScene
@export var is_boss = false
@export var xp_value = 10

var player = null 
var player_in_range = null 

@onready var damage_timer = $Timer
@onready var anim = $AnimatedSprite2D

# --- NOVO: Referência ao nó de som ---
@onready var hit_sound = $HitSound

func _ready():
	player = get_tree().get_first_node_in_group("player")
	anim.play("right")
	
	if is_boss:
		xp_value = 100  # boss dá mais XP

func _physics_process(delta):
	if player:
		var direction = global_position.direction_to(player.global_position)
		var separation = get_separation_force()
		velocity = (direction * speed) + separation
		move_and_slide()
		
		# Animação Esquerda/Direita
		if direction.x > 0:
			anim.play("right")
		elif direction.x < 0:
			anim.play("left")

func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = body 
		attack_player()
		damage_timer.start()

func _on_hitbox_body_exited(body):
	if body == player_in_range:
		player_in_range = null
		damage_timer.stop()

func _on_timer_timeout():
	if player_in_range:
		attack_player()

func attack_player():
	if player_in_range:
		player_in_range.take_damage(5)

func take_damage(amount):
	health -= amount
	modulate = Color.RED
	
	# --- NOVO: Tocar o som ---
	# Mudamos ligeiramente o tom (pitch) para não parecer robótico
	hit_sound.pitch_scale = randf_range(0.8, 1.2)
	hit_sound.play()
	# -------------------------
	
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health <= 0:
		die()

func die():
	if gem_scene:
		var new_gem = gem_scene.instantiate()
		new_gem.global_position = global_position
		new_gem.xp_amount = xp_value
		get_tree().root.call_deferred("add_child", new_gem)
	
	queue_free()
	
func boss_flash():
	while true:
		modulate = Color(1,0.5,0.5) # vermelho claro
		await get_tree().create_timer(0.3).timeout
		modulate = Color(1,1,1)
		await get_tree().create_timer(0.3).timeout
		
func get_separation_force():
	var separation_force = Vector2.ZERO
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for other in enemies:
		if other == self:
			continue
		
		var distance = global_position.distance_to(other.global_position)
		
		if distance < 20: # distância mínima desejada
			var push_dir = global_position.direction_to(other.global_position)
			separation_force -= push_dir * 50 # força de afastamento
	
	return separation_force
