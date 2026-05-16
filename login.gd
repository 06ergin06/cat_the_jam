extends Control

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html" 
const AUTH_URL = "https://api.intra.42.fr/oauth/authorize?client_id=%s&redirect_uri=%s&response_type=code"
const CLIENT_SECRET = "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"

# Token ve Stoklama değişkenleri
var current_access_token = ""
var student_buffer = []
var is_fetching = false
var waiting_for_first_student = false
const MAX_BUFFER_SIZE = 5

func _ready():
	if OS.has_feature("web"):
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
	
	if search_query and search_query.begins_with("?code="):
		var auth_code = search_query.replace("?code=", "").split("&")[0]
		$Button.hide()
		get_access_token(auth_code)


# --- 1. AŞAMA: TOKEN ALMA ---

func get_access_token(code: String):
	$Label.text = "Token alınıyor..."
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
		$NextStudentButton.show()
		$Label.text = "Giriş başarılı! Öğrenci çağırmak için butona bas."
	else:
		$Label.text = "Token alınamadı! Hata Kodu: " + str(response_code)


# --- 2. AŞAMA: BUTON KONTROLÜ VE STOKLAMA ---

func _on_next_student_button_pressed():
	if current_access_token == "": return
	
	if student_buffer.size() > 0:
		# Depo doluysa doğrudan çek, göster ve eksileni tamamla
		var student = student_buffer.pop_front()
		display_student(student)
		check_and_fill_buffer()
	else:
		# Depo boşsa (Buffer bittiğinde), ilk mantığa dön ve beklemeye al
		$Label.text = "Arşivde dosya aranıyor, lütfen bekleyin..."
		$NextStudentButton.disabled = true
		waiting_for_first_student = true
		
		# Eğer arka planda dönen bir motor yoksa motoru çalıştır
		if not is_fetching:
			check_and_fill_buffer()

func check_and_fill_buffer():
	if is_fetching or student_buffer.size() >= MAX_BUFFER_SIZE:
		return
		
	is_fetching = true
	get_random_user()

func display_student(student: Dictionary):
	var text_to_show = "--- GELEN DOSYA ---\n"
	text_to_show += "Öğrenci: " + student["login"] + "\n"
	text_to_show += "Kampüs: " + student["campus"] + "\n\n"
	text_to_show += "[GİZLİ GERÇEK] Havuzu Geçti mi?: " + ("EVET" if student["is_core"] else "HAYIR")
	$Label.text = text_to_show


# --- 3. AŞAMA: RASTGELE KİŞİ LİSTESİ ÇEKME ---

func get_random_user():
	# KESİN KURALLI RATE LIMIT KORUMASI
	await get_tree().create_timer(0.6).timeout
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_random_list_completed.bind(http_request))
	
	var random_page = randi_range(1, 150) # Cursus 9'da sayfa sayısı tüm kullanıcılara göre daha azdır, aralığı daraltmakta fayda var
	
	# ÇÖZÜM: Sadece C Piscine (ID: 9) öğrencilerini getiren uç nokta
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
			get_random_user()
			
	elif response_code == 429:
		print("API İstek Sınırı aşıldı! Sistem kendini 2 saniye beklemeye aldı...")
		await get_tree().create_timer(2.0).timeout
		get_random_user()
	else:
		is_fetching = false
		print("Liste çekilemedi! Hata: ", response_code)
		# UI kilitli kalmasın diye başarısızlık durumunda buton açılır
		if waiting_for_first_student:
			$Label.text = "Bir bağlantı hatası oluştu. Tekrar deneyin."
			$NextStudentButton.disabled = false
			waiting_for_first_student = false


# --- 4. AŞAMA: KİŞİ DETAYLARINI ÇEKME VE FİLTRELEME ---

func get_detailed_user_data(user_id: int):
	# KESİN KURALLI RATE LIMIT KORUMASI
	await get_tree().create_timer(0.6).timeout
	
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
		var cursus_users = json["cursus_users"]
		
		for cursus in cursus_users:
			var cursus_name = cursus["cursus"]["name"]
			if cursus_name == "42cursus":
				is_core_student = true
			if cursus_name == "C Piscine":
				has_c_piscine = true
		
		if not has_c_piscine:
			print("Discovery pas geçiliyor...")
			get_random_user()
			return
			
		var login = json["login"]
		var campus_name = "Bilinmiyor"
		if json.has("campus") and typeof(json["campus"]) == TYPE_ARRAY and json["campus"].size() > 0:
			campus_name = json["campus"][0]["name"]
		
		var student_data = {
			"login": login,
			"campus": campus_name,
			"is_core": is_core_student
		}
		
		student_buffer.append(student_data)
		print("Arka planda hazır: ", login, " (Depo: ", student_buffer.size(), "/", MAX_BUFFER_SIZE, ")")
		
		# Kullanıcı butona basmış ve ilk veriyi bekliyorsa hemen ekrana yansıt
		if waiting_for_first_student:
			var first_student = student_buffer.pop_front()
			display_student(first_student)
			waiting_for_first_student = false
			$NextStudentButton.disabled = false
			
		# Depo eksikse arama döngüsünü tetikle
		is_fetching = false
		check_and_fill_buffer()
		
	elif response_code == 429:
		print("API İstek Sınırı aşıldı! Sistem kendini 2 saniye beklemeye aldı...")
		await get_tree().create_timer(2.0).timeout
		get_random_user()
	else:
		is_fetching = false
		print("Kişi detayları çekilemedi! Hata: ", response_code)
		# UI kilitli kalmasın diye başarısızlık durumunda buton açılır
		if waiting_for_first_student:
			$Label.text = "Bir bağlantı hatası oluştu. Tekrar deneyin."
			$NextStudentButton.disabled = false
			waiting_for_first_student = false
