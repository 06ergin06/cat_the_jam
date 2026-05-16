extends Control

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html"
const CLIENT_SECRET = "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"

var all_students = []
var target_student_count = 3
var is_fetching = false
var status_label: Label

func _ready():
	status_label = Label.new()
	status_label.position = Vector2(20, 20)
	status_label.add_theme_font_size_override("font_size", 24)
	add_child(status_label)
	
	if Global.auth_code != "":
		status_label.text = "Sisteme giriş yapıldı. Token alınıyor..."
		get_access_token(Global.auth_code)
	else:
		status_label.text = "HATA: Global.auth_code boş geldi!"

# --- 1. AŞAMA: TOKEN ALMA ---
func get_access_token(code: String):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_token_received)
	
	var token_url = "https://api.intra.42.fr/oauth/token"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "grant_type=authorization_code&client_id=%s&client_secret=%s&code=%s&redirect_uri=%s" % [
		CLIENT_ID, CLIENT_SECRET, code, REDIRECT_URI.uri_encode()
	]
	
	http_request.request(token_url, headers, HTTPClient.METHOD_POST, body)

func _on_token_received(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		Global.access_token = json["access_token"]
		status_label.text = "Token Başarılı! Rastgele öğrenciler aranıyor..."
		start_fetching_data()
	else:
		status_label.text = "Token Hatası (Kod: " + str(response_code) + ")"

func start_fetching_data():
	if is_fetching: return
	is_fetching = true
	get_random_user()

# --- 2. AŞAMA: RASTGELE KULLANICI ARAMA ---
func get_random_user():
	if all_students.size() >= target_student_count:
		finish_and_save()
		return
		
	await get_tree().create_timer(0.6).timeout 
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_random_list_completed.bind(http_request))
	
	var random_page = randi_range(1, 150)
	var url = "https://api.intra.42.fr/v2/cursus/9/users?page[size]=50&page[number]=" + str(random_page)
	var headers = ["Authorization: Bearer " + Global.access_token]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_random_list_completed(_result, response_code, _headers, body, http_request):
	http_request.queue_free()
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json != null and typeof(json) == TYPE_ARRAY and json.size() > 0:
			var random_index = randi_range(0, json.size() - 1)
			var user_id = json[random_index]["id"]
			get_detailed_user_data(user_id)
		else:
			get_random_user()
			
	elif response_code == 429:
		status_label.text = "Limit aşıldı! 2 saniye dinleniliyor..."
		await get_tree().create_timer(2.0).timeout
		get_random_user()
	else:
		get_random_user()

# --- 3. AŞAMA: DETAYLARI ÇEKME VE AYIKLAMA ---
func get_detailed_user_data(user_id: int):
	await get_tree().create_timer(0.6).timeout
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_detailed_data_completed.bind(http_request))
	
	var url = "https://api.intra.42.fr/v2/users/" + str(user_id)
	var headers = ["Authorization: Bearer " + Global.access_token]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_detailed_data_completed(_result, response_code, _headers, body, http_request):
	http_request.queue_free()
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		
		if json == null or not json.has("cursus_users"):
			get_random_user()
			return
			
		var has_c_piscine = false
		var is_core_student = false
		var pool_status = "unknown"
		var pool_finished = false
		var cursus_users = json["cursus_users"]
		
		for cursus in cursus_users:
			var cursus_name = cursus["cursus"]["name"]
			if cursus_name == "42cursus":
				is_core_student = true
			
			if cursus_name == "C Piscine":
				has_c_piscine = true
				if cursus.has("end_at") and cursus["end_at"] != null:
					pool_finished = true
					if cursus.has("grade"):
						match cursus["grade"]:
							"Passed":
								pool_status = "passed"
							"Failed":
								pool_status = "failed"
							_:
								pool_status = "completed_unknown"
					else:
						pool_status = "completed_unknown"
				else:
					pool_status = "in_progress"
		
		# Sadece Piscine geçmişi olanları alıyoruz
		if not has_c_piscine:
			get_random_user()
			return
			
		var login = json["login"]
		var campus_name = "Bilinmiyor"
		if json.has("campus") and typeof(json["campus"]) == TYPE_ARRAY and json["campus"].size() > 0:
			campus_name = json["campus"][0]["name"]
			
		if is_core_student and pool_status == "completed_unknown":
			pool_status = "passed"
			
		var student_data = {
			"login": login,
			"campus": campus_name,
			"is_core": is_core_student,
			"pool_status": pool_status,
			"pool_finished": pool_finished
		}
		
		all_students.append(student_data)
		status_label.text = "Toplanan: %d / %d (Son Eklenen: %s)" % [all_students.size(), target_student_count, login]
		
		# İstenen sayıya ulaştı mı?
		if all_students.size() >= target_student_count:
			finish_and_save()
		else:
			get_random_user()
			
	elif response_code == 429:
		await get_tree().create_timer(2.0).timeout
		get_random_user()
	else:
		get_random_user()

# --- 4. AŞAMA: JSON İNDİRME VE OYUNA GEÇİŞ ---
func finish_and_save():
	is_fetching = false
	status_label.text = "Tamamlandı! 10 Öğrenci indiriliyor..."
	
	var json_string = JSON.stringify(all_students, "\t")
	
	if OS.has_feature("web"):
		var buffer = json_string.to_utf8_buffer()
		JavaScriptBridge.download_buffer(buffer, "piscine_students.json", "application/json")
	else:
		var file = FileAccess.open("user://piscine_students.json", FileAccess.WRITE)
		if file:
			file.store_string(json_string)
			file.close()
			
	await get_tree().create_timer(2.0).timeout
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainWorld.tscn")
