extends Control

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html" 
const AUTH_URL = "https://api.intra.42.fr/oauth/authorize?client_id=%s&redirect_uri=%s&response_type=code"
const CLIENT_SECRET = "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"

# Token'ı global olarak saklıyoruz
var current_access_token = ""

func _ready():
	# Oyun web ortamında çalışıyorsa URL'i kontrol et
	if OS.has_feature("web"):
		# Motorun ve JS köprüsünün tam senkronize olması için kısa bir süre bekle
		await get_tree().create_timer(0.5).timeout
		check_for_auth_code()

func _on_button_pressed() -> void:
	print("Butona tıklandı sinyali alındı!")
	var url = AUTH_URL % [CLIENT_ID, REDIRECT_URI]
	
	if OS.has_feature("web"):
		var js_command = "window.top.location.href = '" + url + "';"
		JavaScriptBridge.eval(js_command)
	else:
		OS.shell_open(url)

func check_for_auth_code():
	var search_query = JavaScriptBridge.eval("window.location.search")
	print("Tarayıcıdan okunan ham veri: ", search_query)
	
	if search_query and search_query.begins_with("?code="):
		var auth_code = search_query.replace("?code=", "").split("&")[0]
		print("Harika! Code yakalandı: ", auth_code)
		
		# Giriş yapıldığı için Login butonunu gizle
		$Button.hide()
		get_access_token(auth_code)
	elif search_query:
		print("Farklı bir parametre yakalandı veya hata oluştu: ", search_query)


# --- 1. AŞAMA: TOKEN ALMA ---

func get_access_token(code: String):
	print("Token için istek atılıyor...")
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_token_request_completed)
	
	var token_url = "https://api.intra.42.fr/oauth/token"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "grant_type=authorization_code&client_id=%s&client_secret=%s&code=%s&redirect_uri=%s" % [CLIENT_ID, CLIENT_SECRET, code, REDIRECT_URI]
	
	var error = http_request.request(token_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("HTTP İsteği oluşturulurken yerel bir hata oluştu!")

func _on_token_request_completed(_result, response_code, _headers, body):
	var response_string = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.parse_string(response_string)
		current_access_token = json["access_token"]
		print("Mükemmel! Access Token kaydedildi.")
		
		# Giriş başarılı, öğrenci çağırma butonunu göster
		$NextStudentButton.show()
		$Label.text = "Giriş başarılı! Öğrenci çağırmak için butona bas."
	else:
		print("Token alınamadı! Hata Kodu: ", response_code)


# --- 2. AŞAMA: RASTGELE KİŞİ LİSTESİ ÇEKME ---

func _on_next_student_button_pressed():
	if current_access_token != "":
		$Label.text = "Arşivde dosya aranıyor..."
		get_random_user()

func get_random_user():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_random_list_completed.bind(http_request))
	
	var random_page = randi_range(1, 500)
	var url = "https://api.intra.42.fr/v2/users?page[size]=50&page[number]=" + str(random_page)
	var headers = ["Authorization: Bearer " + current_access_token]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_random_list_completed(_result, response_code, _headers, body, http_request):
	http_request.queue_free()
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json.size() > 0:
			var random_index = randi_range(0, json.size() - 1)
			var user_id = json[random_index]["id"]
			get_detailed_user_data(user_id)
		else:
			get_random_user() # Sayfa boşsa tekrar dene
	else:
		print("Liste çekilemedi! Hata: ", response_code)


# --- 3. AŞAMA: KİŞİ DETAYLARINI ÇEKME VE FİLTRELEME ---

func get_detailed_user_data(user_id: int):
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
		
		var has_c_piscine = false
		var is_core_student = false
		var cursus_users = json["cursus_users"]
		
		# Cursus kontrolü
		for cursus in cursus_users:
			var cursus_name = cursus["cursus"]["name"]
			if cursus_name == "42cursus":
				is_core_student = true
			if cursus_name == "C Piscine":
				has_c_piscine = true
		
		# Filtre: C Piscine almamışsa (Discovery vb.) pas geç, anında yenisini çek
		if not has_c_piscine:
			print("Discovery veya farklı bir profil denk geldi. Pas geçiliyor...")
			get_random_user()
			return
			
		# Verileri ayıkla
		var login = json["login"]
		var campus_name = "Bilinmiyor"
		if json.has("campus") and json["campus"].size() > 0:
			campus_name = json["campus"][0]["name"]
		
		# Arayüze yazdır
		var text_to_show = "--- GELEN DOSYA ---\n"
		text_to_show += "Öğrenci: " + login + "\n"
		text_to_show += "Kampüs: " + campus_name + "\n\n"
		text_to_show += "[GİZLİ GERÇEK] Havuzu Geçti mi?: " + ("EVET" if is_core_student else "HAYIR")
		
		$Label.text = text_to_show
		
	else:
		print("Kişi detayları çekilemedi! Hata: ", response_code)
