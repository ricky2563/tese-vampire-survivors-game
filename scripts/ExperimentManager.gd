extends Node

var participant_id: String = ""
var version_a_is_dda: bool = false
var current_version: String = ""

# ==========================================
# DADOS DO SUPABASE (Substitui com os teus!)
# ==========================================
const SUPABASE_URL = "https://zrzmgguurdrossumphkz.supabase.co" # Só a base do URL, sem a barra no fim
const SUPABASE_KEY = "sb_publishable_a_qm5SGRqQTJiPntKg8WVA_mJUr8IvX"

var dda_csv_cache = ""
var player_csv_cache = ""

var http_storage_dda: HTTPRequest
var http_storage_player: HTTPRequest
var http_database: HTTPRequest

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	# Gera o ID seguro de 5 letras/números (ex: P-K7M2R)
	participant_id = "P-" + generate_short_id()
	
	# Atira a moeda ao ar: a Versão A vai ter DDA ativo?
	version_a_is_dda = (randi() % 2 == 0)
	print("Sessão Iniciada! ID: ", participant_id)
	
	# Cria os nós de internet automaticamente
	http_storage_dda = HTTPRequest.new()
	http_storage_player = HTTPRequest.new()
	http_database = HTTPRequest.new()
	
	add_child(http_storage_dda)
	add_child(http_storage_player)
	add_child(http_database)
	
	http_storage_dda.request_completed.connect(_on_dda_uploaded)
	http_storage_player.request_completed.connect(_on_player_uploaded)
	http_database.request_completed.connect(_on_db_saved)

func generate_short_id() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" # Sem O, I, 0, 1
	var id = ""
	for i in range(5): id += chars[randi() % chars.length()]
	return id

# ==========================================
# INÍCIO DE PARTIDA (Chamado pelos Botões do Menu)
# ==========================================
func start_run(selection: String):
	current_version = selection
	dda_csv_cache = ""
	player_csv_cache = ""
	
	DDAManager.current_test_mode = DDAManager.TestMode.DYNAMIC
	
	match selection:
		"A": DDAManager.is_dda_active = version_a_is_dda
		"B": DDAManager.is_dda_active = not version_a_is_dda
		"EASY":
			DDAManager.is_dda_active = true
			DDAManager.current_test_mode = DDAManager.TestMode.ALWAYS_EASY
		"CHALLENGE":
			DDAManager.is_dda_active = true
			DDAManager.current_test_mode = DDAManager.TestMode.ALWAYS_CHALLENGE
			
	get_tree().paused = false
			
	get_tree().change_scene_to_file("res://world.tscn")

# Código para mostrar no ecrã final (ex: P-K7M2R-A)
func get_form_code() -> String:
	return participant_id + "-" + current_version

# ==========================================
# RECEÇÃO DE DADOS E UPLOAD PARA O SUPABASE
# ==========================================
func receive_dda_csv(csv_string: String):
	dda_csv_cache = csv_string
	check_and_upload()

func receive_player_csv(csv_string: String):
	player_csv_cache = csv_string
	check_and_upload()

func check_and_upload():
	# Só avança quando tiver recebido o ficheiro do DDA e o da Vida do Player!
	if dda_csv_cache != "" and player_csv_cache != "":
		print("📦 A iniciar upload para o Supabase Storage...")
		
		var time_stamp = str(Time.get_unix_time_from_system())
		var dda_filename = "dda_" + participant_id + "_" + current_version + "_" + time_stamp + ".csv"
		var player_filename = "player_" + participant_id + "_" + current_version + "_" + time_stamp + ".csv"
		
		var headers = ["Authorization: Bearer " + SUPABASE_KEY, "apikey: " + SUPABASE_KEY, "Content-Type: text/csv"]
		
		# 1. Envia o DDA para o Storage (Balde 'telemetry')
		var url_dda = SUPABASE_URL + "/storage/v1/object/telemetry/" + dda_filename
		http_storage_dda.request(url_dda, headers, HTTPClient.METHOD_POST, dda_csv_cache)
		
		# 2. Envia o Jogador para o Storage (Balde 'telemetry')
		var url_player = SUPABASE_URL + "/storage/v1/object/telemetry/" + player_filename
		http_storage_player.request(url_player, headers, HTTPClient.METHOD_POST, player_csv_cache)

var dda_public_url = ""
var player_public_url = ""

func _on_dda_uploaded(result, response_code, headers, body):
	if response_code >= 200 and response_code < 300:
		var response = JSON.parse_string(body.get_string_from_utf8())
		dda_public_url = SUPABASE_URL + "/storage/v1/object/public/telemetry/" + response.Key.replace("telemetry/", "")
		check_db_insert()
	else:
		print("❌ Erro Upload DDA (", response_code, "): ", body.get_string_from_utf8())

func _on_player_uploaded(result, response_code, headers, body):
	if response_code >= 200 and response_code < 300:
		var response = JSON.parse_string(body.get_string_from_utf8())
		player_public_url = SUPABASE_URL + "/storage/v1/object/public/telemetry/" + response.Key.replace("telemetry/", "")
		check_db_insert()
	else:
		print("❌ Erro Upload Player (", response_code, "): ", body.get_string_from_utf8())

# 3. Grava na tabela 'sessions' (O mesmo que o teu React faz)
func check_db_insert():
	if dda_public_url != "" and player_public_url != "":
		print("📦 Ficheiros carregados! A registar na base de dados...")
		
		var estado_dda = " [DDA ATIVO]" if DDAManager.is_dda_active else " [BASE]"
		var session_name = participant_id + " - Versão " + current_version + estado_dda
		
		var payload = {
			"name": session_name,
			"dda_url": dda_public_url,
			"player_url": player_public_url,
			"created_at": Time.get_datetime_string_from_system(true) + "Z"
		}
		
		var headers = ["Authorization: Bearer " + SUPABASE_KEY, "apikey: " + SUPABASE_KEY, "Content-Type: application/json", "Prefer: return=minimal"]
		var db_url = SUPABASE_URL + "/rest/v1/sessions"
		
		http_database.request(db_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func _on_db_saved(result, response_code, headers, body):
	if response_code >= 200 and response_code < 300:
		print("✅ SESSÃO GRAVADA COM SUCESSO NO SUPABASE!")
		
		# Limpa os links para a próxima partida não enviar dados repetidos
		dda_public_url = ""
		player_public_url = ""
	else:
		print("❌ Erro a gravar na Base de Dados (", response_code, "): ", body.get_string_from_utf8())
