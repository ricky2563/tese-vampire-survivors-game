extends Area2D

var travelled_distance = 0
var speed = 400
var bullet_range = 1200 # Distância máxima que a bala viaja
var piercing = 0
var enemies_hit = []

# --- NOVAS VARIÁVEIS ---
var damage = 30
var hit_radius = 20.0 # O tamanho da "área de impacto" matemática da bala
var hit_cooldown = 0.0 # Impede que a bala acerte no mesmo inimigo 60 vezes num segundo

func _physics_process(delta):
	# 1. Movimento da Bala
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * speed * delta
	
	travelled_distance += speed * delta
	if travelled_distance > bullet_range:
		queue_free()
		return # Sai da função para evitar erros depois de destruída
		
	# 2. COLISÃO MATEMÁTICA (Para a Horda do MultiMesh)
	if hit_cooldown > 0:
		hit_cooldown -= delta
	else:
		# Pergunta ao Autoload se bateu nalguma coordenada inimiga
		if EnemyManager.check_bullet_hit(global_position, hit_radius, damage):
			piercing -= 1
			hit_cooldown = 0.1 # Dá um pequeno tempo antes de poder furar o próximo (evita gastar o piercing todo num só frame)
			
			if piercing < 0:
				queue_free()
				return

# ==========================================
# 3. COLISÃO FÍSICA (Para os Bosses)
# ==========================================
# Mantemos este sinal ativado! Como os bosses continuam a ser CharacterBody2D,
# a física normal do Godot vai detetá-os aqui.
func _on_body_entered(body):
	if body.has_method("take_damage"):
		
		# evitar hits duplicados
		if body in enemies_hit:
			return
		
		enemies_hit.append(body)
		body.take_damage(damage)
		
		# reduz piercing
		piercing -= 1
		
		if piercing < 0:
			queue_free()
