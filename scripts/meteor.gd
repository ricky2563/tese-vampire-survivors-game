extends Node2D

@export var fall_time = 1.0
@export var damage = 25
@export var shadow_scene: PackedScene

var shadow
var target_position
var start_position

@onready var sprite = $Sprite2D

func _ready():
	start_position = target_position + Vector2(0, -300)
	global_position = start_position
	
	create_shadow()
	
	await get_tree().create_timer(0.3).timeout 
	
	fall()

func fall():
	var elapsed = 0.0
	
	while elapsed < fall_time:
		var t = elapsed / fall_time
		
		global_position = start_position.lerp(target_position, t)
		
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	
	impact()

func impact():
	for body in $Area2D.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(damage)
			
	if shadow:
		shadow.queue_free()
	queue_free()

func create_shadow():
	if shadow_scene == null:
		print("Shadow scene não atribuída!")
		return
	
	shadow = shadow_scene.instantiate()
	shadow.global_position = target_position
	
	get_tree().current_scene.add_child(shadow)
