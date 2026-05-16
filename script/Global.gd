extends Node

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html"
const CLIENT_SECRET = "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"

var auth_code = ""
var access_token = ""
var student_pool = []
var is_fetching = false

# Ayarlar
var initial_target = 3       # Oyuna başlamak için gereken ilk sayı
var max_buffer_size = 15     # Arka planda maksimum kaç kişi biriktirecek

# Sahneye haber vermek için sinyaller
signal initial_fetch_done
signal pool_updated

func load_pool_from_disk():
	if FileAccess.file_exists("user://pool_data.json"):
		var file = FileAccess.open("user://pool_data.json", FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_ARRAY:
			student_pool = data
			return true
	return false

func save_current_pool():
	var file = FileAccess.open("user://pool_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(student_pool, "\t"))
	file.close()

# Sıradaki öğrenciyi verir ve listeden siler
func get_next_student():
	if student_pool.size() > 0:
		var student = student_pool.pop_front()
		save_current_pool()
		
		# Oyuncu kartı çektiği an havuz kontrol edilir, azalmışsa arka planda doldurma tetiklenir
		check_and_fill_buffer()
		return student
	return null

func check_and_fill_buffer():
	if not is_fetching and student_pool.size() < max_buffer_size and access_token != "":
		is_fetching = true
		get_random_user()

# --- API İŞLEMLERİ (ARKAPLANDA ÇALIŞIR) ---

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
		access_token = json["access_token"]
		check_and_fill_buffer()
	else:
		print("Token Hatası: ", response_code)

func get_random_user():
	if student_pool.size() >= max_buffer_size:
		is_fetching = false
		return
		
	await get_tree().create_timer(0.6).timeout 
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_random_list_completed.bind(http_request))
	
	var random_page = randi_range(1, 150)
	var url = "https://api.intra.42.fr/v2/cursus/9/users?page[size]=50&page[number]=" + str(random_page)
	var headers = ["Authorization: Bearer " + access_token]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_random_list_completed(_result, response_code, _headers, body, http_request):
	http_request.queue_free()
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json != null and typeof(json) == TYPE_ARRAY and json.size() > 0:
			var random_index = randi_range(0, json.size() - 1)
			get_detailed_user_data(json[random_index]["id"])
		else:
			get_random_user()
	else:
		get_random_user()

func get_detailed_user_data(user_id: int):
	await get_tree().create_timer(0.6).timeout
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_detailed_data_completed.bind(http_request))
	
	var url = "https://api.intra.42.fr/v2/users/" + str(user_id)
	var headers = ["Authorization: Bearer " + access_token]
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
		
		for cursus in json["cursus_users"]:
			if cursus["cursus"]["name"] == "42cursus": is_core_student = true
			if cursus["cursus"]["name"] == "C Piscine":
				has_c_piscine = true
				if cursus.has("end_at") and cursus["end_at"] != null:
					pool_finished = true
					if cursus.has("grade"):
						match cursus["grade"]:
							"Passed": pool_status = "passed"
							"Failed": pool_status = "failed"
							_: pool_status = "completed_unknown"
		
		if not has_c_piscine:
			get_random_user()
			return
			
		var campus_name = json["campus"][0]["name"] if json.has("campus") and json["campus"].size() > 0 else "Bilinmiyor"
		if is_core_student and pool_status == "completed_unknown": pool_status = "passed"
			
		var student_data = {
			"login": json["login"],
			"campus": campus_name,
			"is_core": is_core_student,
			"pool_status": pool_status,
			"pool_finished": pool_finished
		}
		
		student_pool.append(student_data)
		save_current_pool()
		pool_updated.emit()
		
		# OYUNA GEÇİŞ TETİKLEYİCİSİ: İlk defa 3 kişiye ulaştığımız an yükleme ekranına geç sinyali veriyoruz
		if student_pool.size() == initial_target:
			initial_fetch_done.emit()
			
		# Durmaksızın arka planda max_buffer_size (15) olana kadar çekmeye devam et
		get_random_user()
	else:
		get_random_user()
