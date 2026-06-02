extends Node2D

@export var fall_time = 0.5 # Voltou a meio segundo para cair com suavidade
@export var telegraph_time = 1.5 
@export var damage = 15
@export var shadow_scene: PackedScene
@export var phase_4_texture: Texture2D

var shadow
var target_position
var start_position
var is_phase_4 = false

@onready var sprite = $Sprite2D

func _ready():
	if is_phase_4 and phase_4_texture != null:
		sprite.texture = phase_4_texture
		
	# Fica invisível durante o aviso
	sprite.visible = false
		
	# Altura corrigida! Já não vêm da lua, vêm só de cima do ecrã (-600)
	start_position = target_position + Vector2(0, -600) 
	global_position = start_position
	
	create_shadow()
	start_telegraph()

func start_telegraph():
	if shadow:
		shadow.scale = Vector2(0.2, 0.1) 
		var tween = create_tween()
		tween.tween_property(shadow, "scale", Vector2(1.5, 0.7), telegraph_time).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(fall) 
	else:
		fall() 

func fall():
	# Fica visível para a queda
	sprite.visible = true 
	
	var tween = create_tween()
	# CORRIGIDO: Voltei a usar TRANS_CUBIC. A queda agora parece gravidade real em vez de um estalo.
	tween.tween_property(self, "global_position", target_position, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(impact)

func impact():
	var player_target = null
	for body in $Area2D.get_overlapping_bodies():
		if body.is_in_group("player"):
			player_target = body
			break
	
	if player_target:
		player_target.take_damage(damage, "Boss: Meteor Attack")
			
	if shadow:
		shadow.queue_free()
	queue_free()

func create_shadow():
	if shadow_scene == null:
		return
	
	shadow = shadow_scene.instantiate()
	shadow.global_position = target_position
	shadow.z_index = -1 
	
	get_tree().current_scene.add_child(shadow)
