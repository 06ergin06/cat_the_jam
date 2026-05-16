extends Control

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html" 
const AUTH_URL = "https://api.intra.42.fr/oauth/authorize?client_id=%s&redirect_uri=%s&response_type=code"
const CLIENT_SECRET = "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"

# Dosya yolu (kullanıcı görmez)
const SAVE_PATH = "user://pool_data.json"

# Token ve sayaç değişkenleri
var current_access_token = ""
var is_fetching = false
var target_student_count = 10
var saved_students = 0
var initial_student_count = 0

# ---------- Oyun içi log paneli ----------
var log_panel : TextEdit = null

func _ready():
	# Log panelini bağla (sahnede "LogPanel" isimli bir TextEdit olmalı)
	log_panel = get_node_or_null("LogPanel")
	if log_panel:
		log_panel.text = ""  # Temiz başlat
		log_panel.editable = false
	
	if OS.has_feature("web"):
		await get_tree().create_timer(0.5).timeout
		check_for_auth_code()

# ---------- Log fonksiyonu ----------
func log_to_panel(message: String):
	print(message)  # Aynı zamanda tarayıcı konsoluna da düşer (F12)
	if log_panel:
		log_panel.text += message + "\n"
		# Otomatik en alta kaydır
		log_panel.caret_line = log_panel.get_line_count() - 1

# Giriş butonu
func _on_button_pressed() -> void:
	log_to_panel("Giriş butonuna tıklandı!")
	var url = AUTH_URL % [CLIENT_ID, REDIRECT_URI]
	
	if OS.has_feature("web"):
		var js_command = "window.top.location.href = '" + url + "';"
		JavaScriptBridge.eval(js_command)
	else:
		OS.shell_open(url)

func check_for_auth_code():
	var search_query = JavaScriptBridge.eval("window.location.search")
	
	if search_query and search_query.begins_with("?code="):
		var auth_code = search_query.replace("?code=", "").split("&")[0]
		$Button.hide()
		get_access_token(auth_code)

# --- TOKEN ALMA ---
func get_access_token(code: String):
	$Label.text = "Token alınıyor..."
	log_to_panel("Token alınıyor...")
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_token_request_completed)
	
	var token_url = "https://api.intra.42.fr/oauth/token"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "grant_type=authorization_code&client_id=%s&client_secret=%s&code=%s&redirect_uri=%s" % [CLIENT_ID, CLIENT_SECRET, code, REDIRECT_URI]
	
	http_request.request(token_url, headers, HTTPClient.METHOD_POST, body)

func _on_token_request_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		current_access_token = json["access_token"]
		$Label.text = "Giriş başarılı! 10 öğrenci toplanıyor..."
		log_to_panel("Token alındı, veri toplama başlıyor...")
		start_auto_collection()
	else:
		$Label.text = "Token alınamadı! Hata Kodu: " + str(response_code)
		log_to_panel("Token hatası: " + str(response_code))

# --- OTOMATİK TOPLAMA ---
func start_auto_collection():
	var current_data = load_existing_data()
	initial_student_count = current_data.size()
	log_to_panel("Başlangıçta dosyada %d öğrenci var." % initial_student_count)
	log_to_panel("Mevcut dosya içeriği:\n" + JSON.stringify(current_data, "\t"))
	
	if initial_student_count >= target_student_count:
		$Label.text = "Dosya zaten %d öğrenci içeriyor, işlem durduruldu." % initial_student_count
		log_to_panel("Dosya dolu, yeni veri çekilmeyecek.")
		return
	
	var needed = target_student_count - initial_student_count
	$Label.text = "Toplanacak %d öğrenci kaldı. İşlem başlıyor..." % needed
	log_to_panel("Hedef: %d öğrenci daha toplanacak." % needed)
	saved_students = 0
	is_fetching = true
	get_random_user()

# --- RASTGELE KİŞİ LİSTESİ ---
func get_random_user():
	await get_tree().create_timer(0.6).timeout
	
	if (initial_student_count + saved_students) >= target_student_count:
		is_fetching = false
		$Label.text = "Toplama tamamlandı! %d öğrenci kaydedildi." % saved_students
		log_to_panel("Toplama tamamlandı.")
		return
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_random_list_completed.bind(http_request))
	
	var random_page = randi_range(1, 150)
	var url = "https://api.intra.42.fr/v2/cursus/9/users?page[size]=50&page[number]=" + str(random_page)
	var headers = ["Authorization: Bearer " + current_access_token]
	
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
			log_to_panel("Boş liste geldi, yeni sayfa deneniyor...")
			get_random_user()
	elif response_code == 429:
		log_to_panel("Rate limit aşıldı! 2 saniye bekleniyor...")
		await get_tree().create_timer(2.0).timeout
		get_random_user()
	else:
		log_to_panel("Liste çekilemedi! Hata: " + str(response_code))
		get_random_user()

# --- KİŞİ DETAYLARI (ARTIK HAVUZ DURUMU DA VAR) ---
func get_detailed_user_data(user_id: int):
	await get_tree().create_timer(0.6).timeout
	
	if (initial_student_count + saved_students) >= target_student_count:
		is_fetching = false
		$Label.text = "Toplama tamamlandı! %d öğrenci kaydedildi." % saved_students
		log_to_panel("Toplama tamamlandı (detay aşaması).")
		return
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_detailed_data_completed.bind(http_request))
	
	var url = "https://api.intra.42.fr/v2/users/" + str(user_id)
	var headers = ["Authorization: Bearer " + current_access_token]
	
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
		
		# Havuz durumu için değişkenler
		var pool_status = "unknown"
		var pool_finished = false
		
		var cursus_users = json["cursus_users"]
		
		for cursus in cursus_users:
			var cursus_name = cursus["cursus"]["name"]
			if cursus_name == "42cursus":
				is_core_student = true
			
			if cursus_name == "C Piscine":
				has_c_piscine = true
				# --- Havuz detaylarını oku ---
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
		
		if not has_c_piscine:
			log_to_panel("Havuzsuz öğrenci atlandı...")
			get_random_user()
			return
			
		var login = json["login"]
		var campus_name = "Bilinmiyor"
		if json.has("campus") and typeof(json["campus"]) == TYPE_ARRAY and json["campus"].size() > 0:
			campus_name = json["campus"][0]["name"]
		if is_core_student and pool_status == "completed_unknown":
			pool_status = "passed"
		# Öğrenci verisi (kampüs ve havuz durumu dahil)
		var student_data = {
			"login": login,
			"campus": campus_name,
			"is_core": is_core_student,
			"pool_status": pool_status,
			"pool_finished": pool_finished
		}
		
		save_student_to_file(student_data)
		saved_students += 1
		
		var current_total = initial_student_count + saved_students
		log_to_panel("Kaydedildi: %s | Kampüs: %s | Core: %s | Havuz: %s (Bitti: %s) [%d/%d]" % [
			login, campus_name, str(is_core_student), pool_status, str(pool_finished), current_total, target_student_count
		])
		$Label.text = "Toplanan: %d / %d (Son: %s)" % [current_total, target_student_count, login]
		
		if current_total >= target_student_count:
			is_fetching = false
			$Label.text = "Tamamlandı! %d öğrenci dosyaya yazıldı." % target_student_count
			log_to_panel("Hedefe ulaşıldı, işlem bitti.")
			return
		
		get_random_user()
		
	elif response_code == 429:
		log_to_panel("Rate limit aşıldı! 2 saniye bekleniyor...")
		await get_tree().create_timer(2.0).timeout
		get_random_user()
	else:
		log_to_panel("Detay çekilemedi! Hata: " + str(response_code))
		get_random_user()

# --- DOSYA İŞLEMLERİ ---
func load_existing_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		log_to_panel("Dosya henüz yok, boş başlanıyor.")
		return []
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		var data = json.data
		if typeof(data) == TYPE_ARRAY:
			return data
	log_to_panel("Dosya okunamadı, boş dizi döndürülüyor.")
	return []

func save_student_to_file(student: Dictionary):
	var current_list = load_existing_data()
	current_list.append(student)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_list, "\t"))
		file.close()
	else:
		log_to_panel("HATA: Dosya yazılamadı!")
