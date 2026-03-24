extends CharacterBody2D

@export var speed = 60
@export var player: Node2D
@export var fire_hand_scene: PackedScene

@onready var attack_timer = $AttackTimer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	attack_timer.start()

func _physics_process(delta):
	if player:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		move_and_slide()

func _on_attack_timer_timeout():
	fire_hand_attack()
	
func fire_hand_attack():
	if not player:
		return
	
	if fire_hand_scene == null:
		print("Fire hand scene não atribuída!")
		return
	
	var attack = fire_hand_scene.instantiate()
	
	# spawn perto do player
	var offset = Vector2(randf_range(-50,50), randf_range(-50,50))
	attack.global_position = player.global_position + offset
	
	get_tree().root.add_child(attack)
