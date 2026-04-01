extends CharacterBody2D

@export var speed = 40
@export var player: Node2D
@export var fire_hand_scene: PackedScene
@export var meteor_scene: PackedScene

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
	var r = randf()
	
	if r < 0.6:
		fire_hand_attack()
	else:
		meteor_rain_attack()
	
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
	
func meteor_rain_attack():
	if not player:
		return
	
	var meteor_count = 4
	var positions = []
	var min_distance = 80
	
	var attempts = 0
	
	while positions.size() < meteor_count and attempts < 50:
		var angle = randf_range(0, TAU)
		var distance = randf_range(80, 200)
		
		var pos = player.global_position + Vector2.RIGHT.rotated(angle) * distance
		
		var too_close = false
		
		for p in positions:
			if p.distance_to(pos) < min_distance:
				too_close = true
				break
		
		if not too_close:
			positions.append(pos)
		
		attempts += 1
	
	# spawn final
	for pos in positions:
		spawn_meteor(pos)
		await get_tree().create_timer(0.15, false).timeout
		
func spawn_meteor(pos):
	var meteor = meteor_scene.instantiate()
	
	meteor.target_position = pos
	
	get_tree().current_scene.add_child(meteor)
